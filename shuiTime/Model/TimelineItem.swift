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
    var type: String
    // 🔥 新增：是否为高亮/闪光点
    var isHighlight: Bool
    
    @Attribute(.externalStorage) var imageData: Data?
    
    init(content: String, iconName: String = "circle.fill", timestamp: Date = Date(), imageData: Data? = nil, type: String = "timeline", isHighlight: Bool = false) {
        self.id = UUID()
        self.content = content
        self.iconName = iconName
        self.timestamp = timestamp
        self.imageData = imageData
        self.type = type
        self.isHighlight = isHighlight
    }
}
