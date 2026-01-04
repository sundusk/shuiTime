//
//  BackupManager.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import Foundation
import SwiftData

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
}

// MARK: - 备份管理器
class BackupManager {

    static let shared = BackupManager()

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

            return BackupItem(
                id: item.id.uuidString,
                timestamp: timestampString,
                content: item.content,
                iconName: item.iconName,
                type: item.type,
                imageBase64: imageBase64
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

        // 4. 保存到 Documents 目录
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
        let fileName = "shuiTime_backup_\(dateFormatter.string(from: Date())).json"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: fileURL)
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
        // 1. 读取文件
        guard let jsonData = try? Data(contentsOf: url) else {
            print("❌ 文件读取失败")
            return nil
        }

        // 2. JSON 解码
        let decoder = JSONDecoder()
        guard let backupData = try? decoder.decode(BackupData.self, from: jsonData) else {
            print("❌ JSON 解码失败")
            return nil
        }

        print("📦 开始导入备份 (版本: \(backupData.version), 导出时间: \(backupData.exportDate))")
        print("📦 共有 \(backupData.items.count) 条记录")

        // 3. 转换并插入数据
        var successCount = 0
        let isoFormatter = ISO8601DateFormatter()

        for backupItem in backupData.items {
            // 解析时间戳
            guard let timestamp = isoFormatter.date(from: backupItem.timestamp) else {
                print("⚠️ 跳过无效时间戳: \(backupItem.timestamp)")
                continue
            }

            // 解析图片数据
            var imageData: Data? = nil
            if let base64String = backupItem.imageBase64 {
                imageData = Data(base64Encoded: base64String)
            }

            // 创建新的 TimelineItem
            let newItem = TimelineItem(
                content: backupItem.content,
                iconName: backupItem.iconName,
                timestamp: timestamp,
                imageData: imageData,
                type: backupItem.type
            )

            // 注意：这里重新生成 UUID，而不是使用备份中的 ID
            // 这样可以避免导入重复数据时的 ID 冲突

            context.insert(newItem)
            successCount += 1
        }

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

    // MARK: - 辅助方法
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
                $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("shuiTime_backup_")
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
}
