//
//  LastYearFeature.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/20.
//

import SwiftUI
import SwiftData

// MARK: - 1. 去年今日 "时光胶囊" 入口卡片 (保持之前设计，稍微优化)
struct LastYearCapsuleCard: View {
    let items: [TimelineItem]
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 背景层
                if let firstImageItem = items.first(where: { $0.imageData != nil }),
                   let data = firstImageItem.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(height: 120).clipped()
                        .blur(radius: 10)
                        .overlay(Color.black.opacity(0.2))
                } else {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.red.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(height: 120)
                }
                
                // 磨砂玻璃层
                Rectangle().fill(.ultraThinMaterial).opacity(0.85)
                
                // 内容层
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.15)).frame(width: 50, height: 50)
                        Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("那年今日")
                            .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                        Text("封存了 \(items.count) 条记忆")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 120)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 2. 去年今日 详情页 (全新 UI)
struct LastYearDetailView: View {
    let items: [TimelineItem]
    var onImageTap: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    // 获取当天的日期用于标题
    var dateString: String {
        guard let first = items.first else { return "那年今日" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: first.timestamp)
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大标题区域
                    VStack(spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 40)).foregroundColor(.orange.opacity(0.3))
                            .padding(.top, 20)
                        
                        Text(dateString)
                            .font(.title2).bold().foregroundColor(.primary)
                        
                        Text("共 \(items.count) 条回忆")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
                    .padding(.top, 60) // 避开关闭按钮
                    
                    // 瀑布流卡片列表
                    LazyVStack(spacing: 20) {
                        ForEach(items) { item in
                            MemoryCardRow(item: item, onImageTap: onImageTap)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
            
            // 关闭按钮 (悬浮在右上角)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                            .background(Circle().fill(Color(uiColor: .systemBackground).opacity(0.5)))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
    }
}

// MARK: - 3. 核心：回忆卡片组件 (MemoryCardRow)
struct MemoryCardRow: View {
    let item: TimelineItem
    var onImageTap: ((UIImage) -> Void)?
    
    // 解析标签
    private var tags: [String] {
        item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }
    
    // 清洗内容
    private var cleanContent: String {
        let pattern = "#[^\\s]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned = regex?.stringByReplacingMatches(in: item.content, options: [], range: NSRange(location: 0, length: item.content.utf16.count), withTemplate: "") ?? item.content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 1. 卡片头部：时间 + 类型标记
            HStack {
                // 时间
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 灵感标记 (如果存在)
                if item.type == "inspiration" {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                        Text("灵感")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                }
            }
            
            // 2. 图片区域 (全宽显示)
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { onImageTap?(uiImage) }
            }
            
            // 3. 文字区域
            if !cleanContent.isEmpty {
                Text(cleanContent)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 4. 底部标签栏
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        // 阴影优化：更有层次感
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 辅助样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
