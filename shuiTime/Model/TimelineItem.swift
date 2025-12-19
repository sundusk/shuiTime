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
    // 🔥 New: Highlight status
    var isHighlight: Bool
    
    @Attribute(.externalStorage) var imageData: Data?
    
    // 🔥 New: Store rich text data (Bold, Strikethrough, etc.)
    @Attribute(.externalStorage) var richContentData: Data?
    
    init(content: String, iconName: String = "circle.fill", timestamp: Date = Date(), imageData: Data? = nil, type: String = "timeline", isHighlight: Bool = false, richContentData: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.iconName = iconName
        self.timestamp = timestamp
        self.imageData = imageData
        self.type = type
        self.isHighlight = isHighlight
        self.richContentData = richContentData
    }
}
