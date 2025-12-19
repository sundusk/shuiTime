//
//  InspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

struct InspirationView: View {
    @Binding var showSideMenu: Bool
    @Environment(\.modelContext) private var modelContext
    
    // 只查询类型为 inspiration 的数据
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var items: [TimelineItem]
    
    @State private var showInputSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.min")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("点击右下角记录灵感")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(items) { item in
                                InspirationCardView(item: item)
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
                
                // 悬浮按钮
                HStack {
                    Spacer()
                    Button(action: { showInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("灵感集")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { withAnimation { showSideMenu = true } }) {
                        Image(systemName: "line.3.horizontal").foregroundColor(.primary)
                    }
                }
            }
            // 🔥 这里直接调用独立的 InspirationInputView
            .sheet(isPresented: $showInputSheet) {
                InspirationInputView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - 灵感卡片视图
// 这个视图比较小，也可以单独拆分，但暂时留在主文件里也没问题
struct InspirationCardView: View {
    let item: TimelineItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 顶部：时间
            HStack {
                Text(item.timestamp.formatted(date: .numeric, time: .standard))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 2. 图片内容
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .clipped()
            }
            
            // 3. 文字内容 (带 #标签 染色)
            if !item.content.isEmpty {
                Text(attributedContent(for: item.content))
                    .font(.body)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 解析逻辑
    func attributedContent(for text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .primary // 默认颜色
        
        if text.hasPrefix("#") {
            let separators = CharacterSet.whitespacesAndNewlines
            if let range = text.rangeOfCharacter(from: separators) {
                let tagString = String(text[..<range.lowerBound])
                if let attrRange = attributed.range(of: tagString) {
                    attributed[attrRange].foregroundColor = .blue
                }
            } else {
                attributed.foregroundColor = .blue
            }
        }
        return attributed
    }
}
