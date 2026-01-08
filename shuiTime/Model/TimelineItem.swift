//
//  TimelineItem.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//
import Foundation
import SwiftData

@Model
final class TimelineItem {
    var id: UUID
    var timestamp: Date
    var content: String
    var iconName: String
    // 🔥 新增：类型区分 ("timeline" 或 "inspiration")
    var type: String

    @Attribute(.externalStorage) var imageData: Data?

    // 🔥 Live Photo 支持（默认值防止数据迁移错误）
    var isLivePhoto: Bool = false
    @Attribute(.externalStorage) var livePhotoVideoData: Data?

    init(
        content: String, iconName: String = "circle.fill", timestamp: Date = Date(),
        imageData: Data? = nil, type: String = "timeline", isLivePhoto: Bool = false,
        livePhotoVideoData: Data? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.iconName = iconName
        self.timestamp = timestamp
        self.imageData = imageData
        self.type = type
        self.isLivePhoto = isLivePhoto
        self.livePhotoVideoData = livePhotoVideoData
    }
}
