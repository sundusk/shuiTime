//
//  BackupManager.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import Foundation
import Compression
import SwiftData
import zlib

// MARK: - 备份数据结构
struct BackupData: Codable {
    let version: String
    let exportDate: String
    let items: [BackupItem]
}

struct BackupItem: Codable {
    let id: String
    let timestamp: String
    let content: String
    let iconName: String
    let type: String
    let imageBase64: String?
    let isLivePhoto: Bool?  // 🔥 Live Photo 标记（可选，兼容旧数据）
    let livePhotoVideoBase64: String?  // 🔥 Live Photo 视频数据
}

// MARK: - 备份管理器
class BackupManager {

    static let shared = BackupManager()
    static let compressedFileExtension = "zip"
    static let legacyCompressedFileExtension = "stzip"

    private let compressionHeader = Data("STBK1".utf8)
    private let zipEntryName = "shuiTime_backup.json"

    private init() {}

    // MARK: - 导出数据
    /// 导出所有 TimelineItem 数据到 JSON 文件
    /// - Parameter items: 要导出的时间线数据
    /// - Returns: 备份文件的 URL，失败返回 nil
    func exportData(items: [TimelineItem]) -> URL? {
        // 1. 转换数据为 BackupItem
        let backupItems = items.map { item -> BackupItem in
            let isoFormatter = ISO8601DateFormatter()
            let timestampString = isoFormatter.string(from: item.timestamp)

            // 图片转 Base64
            var imageBase64: String? = nil
            if let imageData = item.imageData {
                imageBase64 = imageData.base64EncodedString()
            }

            // 🔥 Live Photo 视频转 Base64
            var liveVideoBase64: String? = nil
            if let videoData = item.livePhotoVideoData {
                liveVideoBase64 = videoData.base64EncodedString()
            }

            return BackupItem(
                id: item.id.uuidString,
                timestamp: timestampString,
                content: item.content,
                iconName: item.iconName,
                type: item.type,
                imageBase64: imageBase64,
                isLivePhoto: item.isLivePhoto,
                livePhotoVideoBase64: liveVideoBase64
            )
        }

        // 2. 创建备份数据对象
        let isoFormatter = ISO8601DateFormatter()
        let backupData = BackupData(
            version: "1.0",
            exportDate: isoFormatter.string(from: Date()),
            items: backupItems
        )

        // 3. JSON 编码
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(backupData) else {
            print("❌ JSON 编码失败")
            return nil
        }

        // 4. 压缩备份内容
        guard let fileData = makeZipBackupData(from: jsonData) else {
            print("❌ ZIP 备份生成失败")
            return nil
        }

        // 5. 保存到 Documents 目录
        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            print("❌ 无法获取 Documents 目录")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "shuiTime_backup_\(dateFormatter.string(from: Date())).\(Self.compressedFileExtension)"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try fileData.write(to: fileURL)
            print("✅ 备份成功: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ 文件写入失败: \(error)")
            return nil
        }
    }

    // MARK: - 导入数据
    /// 从 JSON 文件导入数据
    /// - Parameters:
    ///   - url: JSON 文件的 URL
    ///   - context: SwiftData 的 ModelContext
    /// - Returns: 成功导入的条目数量，失败返回 nil
    func importData(from url: URL, context: ModelContext) -> Int? {
        // 1. 读取并解析文件（兼容旧 JSON 与新压缩格式）
        guard let backupData = loadBackupData(from: url) else {
            return nil
        }

        print("📦 开始导入备份 (版本: \(backupData.version), 导出时间: \(backupData.exportDate))")
        print("📦 共有 \(backupData.items.count) 条记录")

        // 3. 转换并插入数据（去重逻辑）
        var successCount = 0
        var skippedCount = 0
        let isoFormatter = ISO8601DateFormatter()

        for backupItem in backupData.items {
            // 解析时间戳
            guard let timestamp = isoFormatter.date(from: backupItem.timestamp) else {
                print("⚠️ 跳过无效时间戳: \(backupItem.timestamp)")
                continue
            }

            // 🔥 去重检查：查询是否已存在相同 content + timestamp + type 的记录
            let content = backupItem.content
            let type = backupItem.type
            let existingDescriptor = FetchDescriptor<TimelineItem>(
                predicate: #Predicate<TimelineItem> { item in
                    item.content == content &&
                    item.timestamp == timestamp &&
                    item.type == type
                }
            )
            
            if let existingItems = try? context.fetch(existingDescriptor), !existingItems.isEmpty {
                print("⏭️ 跳过重复记录: \(content.prefix(20))...")
                skippedCount += 1
                continue
            }

            // 解析图片数据
            var imageData: Data? = nil
            if let base64String = backupItem.imageBase64 {
                imageData = Data(base64Encoded: base64String)
            }

            // 🔥 解析 Live Photo 视频数据
            var liveVideoData: Data? = nil
            if let base64String = backupItem.livePhotoVideoBase64 {
                liveVideoData = Data(base64Encoded: base64String)
            }

            // 创建新的 TimelineItem
            let newItem = TimelineItem(
                content: backupItem.content,
                iconName: backupItem.iconName,
                timestamp: timestamp,
                imageData: imageData,
                type: backupItem.type,
                isLivePhoto: backupItem.isLivePhoto ?? false,
                livePhotoVideoData: liveVideoData
            )

            context.insert(newItem)
            successCount += 1
        }
        
        print("📊 导入统计: 新增 \(successCount) 条, 跳过重复 \(skippedCount) 条")

        // 4. 保存 Context
        do {
            try context.save()
            print("✅ 成功导入 \(successCount) 条记录")
            return successCount
        } catch {
            print("❌ 数据保存失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 覆盖导入数据
    /// 覆盖导入：先删除所有现有数据，再导入备份
    /// - Parameters:
    ///   - url: JSON 文件的 URL
    ///   - context: SwiftData 的 ModelContext
    /// - Returns: 成功导入的条目数量，失败返回 nil
    func importDataWithOverwrite(from url: URL, context: ModelContext) -> Int? {
        // 1. 读取并解析文件（兼容旧 JSON 与新压缩格式）
        guard let backupData = loadBackupData(from: url) else {
            return nil
        }

        print("🔄 开始覆盖导入 (版本: \(backupData.version), 导出时间: \(backupData.exportDate))")
        print("📦 备份共有 \(backupData.items.count) 条记录")
        
        // 3. 删除所有现有数据
        let descriptor = FetchDescriptor<TimelineItem>()
        if let existingItems = try? context.fetch(descriptor) {
            print("🗑️ 删除现有 \(existingItems.count) 条记录")
            for item in existingItems {
                context.delete(item)
            }
        }

        // 4. 导入备份数据
        var successCount = 0
        let isoFormatter = ISO8601DateFormatter()

        for backupItem in backupData.items {
            guard let timestamp = isoFormatter.date(from: backupItem.timestamp) else {
                print("⚠️ 跳过无效时间戳: \(backupItem.timestamp)")
                continue
            }

            var imageData: Data? = nil
            if let base64String = backupItem.imageBase64 {
                imageData = Data(base64Encoded: base64String)
            }

            var liveVideoData: Data? = nil
            if let base64String = backupItem.livePhotoVideoBase64 {
                liveVideoData = Data(base64Encoded: base64String)
            }

            let newItem = TimelineItem(
                content: backupItem.content,
                iconName: backupItem.iconName,
                timestamp: timestamp,
                imageData: imageData,
                type: backupItem.type,
                isLivePhoto: backupItem.isLivePhoto ?? false,
                livePhotoVideoData: liveVideoData
            )

            context.insert(newItem)
            successCount += 1
        }

        // 5. 保存
        do {
            try context.save()
            print("✅ 覆盖导入成功: \(successCount) 条记录")
            return successCount
        } catch {
            print("❌ 数据保存失败: \(error)")
            return nil
        }
    }

    // MARK: - 辅助方法
    private func loadBackupData(from url: URL) -> BackupData? {
        guard let fileData = try? Data(contentsOf: url) else {
            print("❌ 文件读取失败")
            return nil
        }

        let rawData: Data
        if fileData.starts(with: ZipArchive.localFileHeaderSignatureData)
            || fileData.starts(with: ZipArchive.endOfCentralDirectorySignatureData)
        {
            guard let zipData = extractJSONFromZip(fileData) else {
                print("❌ ZIP 备份解压失败")
                return nil
            }
            rawData = zipData
        } else if fileData.starts(with: compressionHeader) {
            let compressedData = fileData.dropFirst(compressionHeader.count)
            guard let decompressedData = Data(compressedData).performStreamCompression(
                operation: COMPRESSION_STREAM_DECODE,
                algorithm: COMPRESSION_LZFSE
            ) else {
                print("❌ 压缩备份解压失败")
                return nil
            }
            rawData = decompressedData
        } else {
            rawData = fileData
        }

        let decoder = JSONDecoder()
        guard let backupData = try? decoder.decode(BackupData.self, from: rawData) else {
            print("❌ JSON 解码失败")
            return nil
        }

        return backupData
    }

    private func makeZipBackupData(from jsonData: Data) -> Data? {
        ZipArchive.makeSingleEntryArchive(
            fileName: zipEntryName,
            uncompressedData: jsonData
        )
    }

    private func extractJSONFromZip(_ fileData: Data) -> Data? {
        guard let archive = ZipArchive(data: fileData) else {
            return nil
        }

        if let jsonEntry = archive.entries.first(where: { $0.fileName.hasSuffix(".json") }) {
            return archive.extract(entry: jsonEntry)
        }

        guard let firstEntry = archive.entries.first else {
            return nil
        }

        return archive.extract(entry: firstEntry)
    }

    /// 获取所有备份文件
    func getBackupFiles() -> [URL] {
        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            return files.filter {
                ["json", Self.compressedFileExtension, Self.legacyCompressedFileExtension]
                    .contains($0.pathExtension)
                    && $0.lastPathComponent.hasPrefix("shuiTime_backup_")
            }
            .sorted { (url1, url2) -> Bool in
                let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
            }
        } catch {
            print("❌ 读取备份文件列表失败: \(error)")
            return []
        }
    }

    /// 删除备份文件
    func deleteBackup(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ 删除备份文件: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ 删除失败: \(error)")
            return false
        }
    }
    
    // MARK: - 清理重复数据
    /// 清理数据库中的重复记录
    /// - Parameter context: SwiftData 的 ModelContext
    /// - Returns: 删除的重复记录数量
    func removeDuplicates(context: ModelContext) -> Int {
        // 1. 获取所有记录
        let descriptor = FetchDescriptor<TimelineItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        guard let allItems = try? context.fetch(descriptor) else {
            print("❌ 获取数据失败")
            return 0
        }
        
        print("📊 开始去重，共有 \(allItems.count) 条记录")
        
        // 2. 按 content + timestamp + type 分组，保留每组第一条
        var seen = Set<String>()
        var duplicatesToDelete: [TimelineItem] = []
        
        for item in allItems {
            // 生成唯一标识 key
            let key = "\(item.content)|\(item.timestamp.timeIntervalSince1970)|\(item.type)"
            
            if seen.contains(key) {
                // 已存在，标记为重复
                duplicatesToDelete.append(item)
            } else {
                // 首次出现，保留
                seen.insert(key)
            }
        }
        
        // 3. 删除重复记录
        for item in duplicatesToDelete {
            context.delete(item)
        }
        
        // 4. 保存
        do {
            try context.save()
            print("✅ 成功删除 \(duplicatesToDelete.count) 条重复记录")
            return duplicatesToDelete.count
        } catch {
            print("❌ 保存失败: \(error)")
            return 0
        }
    }
}

private extension Data {
    func performStreamCompression(
        operation: compression_stream_operation,
        algorithm: compression_algorithm
    ) -> Data? {
        if isEmpty {
            return Data()
        }

        let destinationBufferSize = 64 * 1024
        let flags = operation == COMPRESSION_STREAM_ENCODE
            ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            : 0

        return withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourceBaseAddress = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }

            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(
                capacity: destinationBufferSize
            )
            defer { destinationBuffer.deallocate() }

            var stream = compression_stream(
                dst_ptr: destinationBuffer,
                dst_size: destinationBufferSize,
                src_ptr: sourceBaseAddress,
                src_size: count,
                state: nil
            )
            var status = compression_stream_init(&stream, operation, algorithm)
            guard status != COMPRESSION_STATUS_ERROR else {
                return nil
            }
            defer { compression_stream_destroy(&stream) }

            var output = Data()

            repeat {
                status = compression_stream_process(&stream, flags)

                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let producedSize = destinationBufferSize - stream.dst_size
                    if producedSize > 0 {
                        output.append(destinationBuffer, count: producedSize)
                    }
                    stream.dst_ptr = destinationBuffer
                    stream.dst_size = destinationBufferSize
                default:
                    return nil
                }
            } while status == COMPRESSION_STATUS_OK

            return status == COMPRESSION_STATUS_END ? output : nil
        }
    }
}

private struct ZipArchive {
    struct Entry {
        let fileName: String
        let compressionMethod: UInt16
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    static let localFileHeaderSignature: UInt32 = 0x04034b50
    static let centralDirectorySignature: UInt32 = 0x02014b50
    static let endOfCentralDirectorySignature: UInt32 = 0x06054b50
    static let localFileHeaderSignatureData = Data([0x50, 0x4b, 0x03, 0x04])
    static let endOfCentralDirectorySignatureData = Data([0x50, 0x4b, 0x05, 0x06])

    let data: Data
    let entries: [Entry]

    init?(data: Data) {
        self.data = data
        guard let endRecordOffset = Self.findEndOfCentralDirectory(in: data),
              let entries = Self.parseEntries(in: data, endRecordOffset: endRecordOffset)
        else {
            return nil
        }
        self.entries = entries
    }

    func extract(entry: Entry) -> Data? {
        guard let localHeaderOffset = Int(exactly: entry.localHeaderOffset),
              let signature = data.readUInt32LE(at: localHeaderOffset),
              signature == Self.localFileHeaderSignature
        else {
            return nil
        }

        guard let fileNameLength = data.readUInt16LE(at: localHeaderOffset + 26),
              let extraFieldLength = data.readUInt16LE(at: localHeaderOffset + 28)
        else {
            return nil
        }

        let dataOffset = localHeaderOffset + 30 + Int(fileNameLength) + Int(extraFieldLength)
        guard let compressedSize = Int(exactly: entry.compressedSize),
              let payload = data.subdataIfInBounds(in: dataOffset..<(dataOffset + compressedSize))
        else {
            return nil
        }

        let extractedData: Data?
        switch entry.compressionMethod {
        case 0:
            extractedData = payload
        case 8:
            extractedData = payload.inflatedFromZIP(expectedSize: Int(entry.uncompressedSize))
        default:
            extractedData = nil
        }

        guard let extractedData,
              extractedData.zipCRC32 == entry.crc32
        else {
            return nil
        }

        return extractedData
    }

    static func makeSingleEntryArchive(fileName: String, uncompressedData: Data) -> Data? {
        guard let fileNameData = fileName.data(using: .utf8),
              let compressedData = uncompressedData.deflatedForZIP()
        else {
            return nil
        }

        let crc32 = uncompressedData.zipCRC32
        let compressedSize = UInt32(compressedData.count)
        let uncompressedSize = UInt32(uncompressedData.count)

        var localHeader = Data()
        localHeader.appendUInt32LE(localFileHeaderSignature)
        localHeader.appendUInt16LE(20)
        localHeader.appendUInt16LE(0)
        localHeader.appendUInt16LE(8)
        localHeader.appendUInt16LE(0)
        localHeader.appendUInt16LE(0)
        localHeader.appendUInt32LE(crc32)
        localHeader.appendUInt32LE(compressedSize)
        localHeader.appendUInt32LE(uncompressedSize)
        localHeader.appendUInt16LE(UInt16(fileNameData.count))
        localHeader.appendUInt16LE(0)
        localHeader.append(fileNameData)

        let localHeaderOffset: UInt32 = 0
        let centralDirectoryOffset = UInt32(localHeader.count + compressedData.count)

        var centralDirectory = Data()
        centralDirectory.appendUInt32LE(centralDirectorySignature)
        centralDirectory.appendUInt16LE(20)
        centralDirectory.appendUInt16LE(20)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt16LE(8)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt32LE(crc32)
        centralDirectory.appendUInt32LE(compressedSize)
        centralDirectory.appendUInt32LE(uncompressedSize)
        centralDirectory.appendUInt16LE(UInt16(fileNameData.count))
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt16LE(0)
        centralDirectory.appendUInt32LE(0)
        centralDirectory.appendUInt32LE(localHeaderOffset)
        centralDirectory.append(fileNameData)

        var endOfCentralDirectory = Data()
        endOfCentralDirectory.appendUInt32LE(endOfCentralDirectorySignature)
        endOfCentralDirectory.appendUInt16LE(0)
        endOfCentralDirectory.appendUInt16LE(0)
        endOfCentralDirectory.appendUInt16LE(1)
        endOfCentralDirectory.appendUInt16LE(1)
        endOfCentralDirectory.appendUInt32LE(UInt32(centralDirectory.count))
        endOfCentralDirectory.appendUInt32LE(centralDirectoryOffset)
        endOfCentralDirectory.appendUInt16LE(0)

        var archive = Data()
        archive.append(localHeader)
        archive.append(compressedData)
        archive.append(centralDirectory)
        archive.append(endOfCentralDirectory)
        return archive
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        let signature = endOfCentralDirectorySignatureData
        let minimumSize = 22
        guard data.count >= minimumSize else {
            return nil
        }

        let maxCommentLength = 65535
        let startIndex = max(0, data.count - minimumSize - maxCommentLength)
        let searchRange = startIndex...(data.count - minimumSize)

        for offset in searchRange.reversed() {
            if data.subdataIfInBounds(in: offset..<(offset + signature.count)) == signature {
                return offset
            }
        }

        return nil
    }

    private static func parseEntries(in data: Data, endRecordOffset: Int) -> [Entry]? {
        guard let entryCount = data.readUInt16LE(at: endRecordOffset + 10),
              let centralDirectoryOffset = data.readUInt32LE(at: endRecordOffset + 16)
        else {
            return nil
        }

        var entries: [Entry] = []
        var cursor = Int(centralDirectoryOffset)

        for _ in 0..<entryCount {
            guard let signature = data.readUInt32LE(at: cursor),
                  signature == centralDirectorySignature,
                  let compressionMethod = data.readUInt16LE(at: cursor + 10),
                  let crc32 = data.readUInt32LE(at: cursor + 16),
                  let compressedSize = data.readUInt32LE(at: cursor + 20),
                  let uncompressedSize = data.readUInt32LE(at: cursor + 24),
                  let fileNameLength = data.readUInt16LE(at: cursor + 28),
                  let extraFieldLength = data.readUInt16LE(at: cursor + 30),
                  let fileCommentLength = data.readUInt16LE(at: cursor + 32),
                  let localHeaderOffset = data.readUInt32LE(at: cursor + 42)
            else {
                return nil
            }

            let fileNameStart = cursor + 46
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            guard let fileNameData = data.subdataIfInBounds(in: fileNameStart..<fileNameEnd),
                  let fileName = String(data: fileNameData, encoding: .utf8)
            else {
                return nil
            }

            entries.append(
                Entry(
                    fileName: fileName,
                    compressionMethod: compressionMethod,
                    crc32: crc32,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                )
            )

            cursor = fileNameEnd + Int(extraFieldLength) + Int(fileCommentLength)
        }

        return entries
    }
}

private extension Data {
    func deflatedForZIP() -> Data? {
        if isEmpty {
            return Data()
        }

        var stream = z_stream()
        let initStatus = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            -MAX_WBITS,
            MAX_MEM_LEVEL,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initStatus == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        let chunkSize = 64 * 1024
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { outputBuffer.deallocate() }

        var output = Data()
        return withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourceBaseAddress = sourceBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return nil
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourceBaseAddress)
            stream.avail_in = uInt(count)

            repeat {
                stream.next_out = outputBuffer
                stream.avail_out = uInt(chunkSize)

                let status = deflate(&stream, Z_FINISH)
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(outputBuffer, count: produced)
                }

                if status == Z_STREAM_END {
                    return output
                }

                if status != Z_OK {
                    return nil
                }
            } while stream.avail_out == 0

            return nil
        }
    }

    func inflatedFromZIP(expectedSize: Int) -> Data? {
        if isEmpty {
            return Data()
        }

        var stream = z_stream()
        let initStatus = inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initStatus == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        let chunkSize = Swift.max(64 * 1024, expectedSize)
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { outputBuffer.deallocate() }

        var output = Data()
        return withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourceBaseAddress = sourceBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return nil
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourceBaseAddress)
            stream.avail_in = uInt(count)

            while true {
                stream.next_out = outputBuffer
                stream.avail_out = uInt(chunkSize)

                let status = inflate(&stream, Z_NO_FLUSH)
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(outputBuffer, count: produced)
                }

                if status == Z_STREAM_END {
                    return output
                }

                if status != Z_OK {
                    return nil
                }

                if stream.avail_in == 0 && produced == 0 {
                    return nil
                }
            }
        }
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }

    func readUInt16LE(at offset: Int) -> UInt16? {
        guard let data = subdataIfInBounds(in: offset..<(offset + 2)) else {
            return nil
        }

        return data.withUnsafeBytes { buffer in
            buffer.load(as: UInt16.self).littleEndian
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32? {
        guard let data = subdataIfInBounds(in: offset..<(offset + 4)) else {
            return nil
        }

        return data.withUnsafeBytes { buffer in
            buffer.load(as: UInt32.self).littleEndian
        }
    }

    func subdataIfInBounds(in range: Range<Int>) -> Data? {
        guard range.lowerBound >= 0, range.upperBound <= count else {
            return nil
        }
        return subdata(in: range)
    }

    var zipCRC32: UInt32 {
        withUnsafeBytes { buffer in
            let baseAddress = buffer.bindMemory(to: Bytef.self).baseAddress
            return UInt32(crc32(0, baseAddress, uInt(count)))
        }
    }
}
