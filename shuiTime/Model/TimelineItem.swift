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
    
    // 新增：存储图片数据
    // 使用 .externalStorage 允许系统把大图片存在数据库文件之外，避免数据库臃肿
    @Attribute(.externalStorage) var imageData: Data?
    
    // 修改 init 方法，增加 imageData 参数
    init(content: String, iconName: String = "circle.fill", timestamp: Date = Date(), imageData: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.iconName = iconName
        self.timestamp = timestamp
        self.imageData = imageData
    }
}
