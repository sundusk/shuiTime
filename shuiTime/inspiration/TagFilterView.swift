//
//  TagFilterView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftUI
import SwiftData

struct TagFilterView: View {
    let tagName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 获取所有数据
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]
    
    // 筛选逻辑：包含标签即可 (不区分灵感或时间线)
    var filteredItems: [TimelineItem] {
        allItems.filter { item in
            item.content.contains(tagName)
        }
    }
    
    // 状态管理
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        ZStack {
            // 背景色 (系统分组背景，深色模式下为纯黑或深灰)
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("标签 #\(tagName) 下暂无内容")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) { // 卡片间距
                        ForEach(filteredItems) { item in
                            TagFilterCard(item: item, highlightTag: tagName)
                                .onTapGesture {
                                    // 点击卡片也可触发编辑，或者你可以留空
                                }
                                .contextMenu {
                                    Button { itemToEdit = item } label: { Label("修改", systemImage: "pencil") }
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showDeleteAlert = true
                                    } label: { Label("删除", systemImage: "trash") }
                                }
                            
                            // 图片点击处理 (通过回调或透明层，这里简单起见，如果卡片有点按事件，图片需单独处理)
                            // 由于 TagFilterCard 内部处理了图片显示，我们可以在那里加点击
                        }
                    }
                    .padding() // 列表边距
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("#\(tagName)")
        .navigationBarTitleDisplayMode(.inline)
        // 编辑弹窗
        .sheet(item: $itemToEdit) { item in
            InspirationInputView(itemToEdit: item)
        }
        // 删除确认
        .alert("确认删除?", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { itemToDelete = nil }
            Button("删除", role: .destructive) {
                if let item = itemToDelete {
                    withAnimation { modelContext.delete(item); try? modelContext.save() }
                }
                itemToDelete = nil
            }
        } message: { Text("删除后将无法恢复。") }
    }
}

// MARK: - 卡片组件 (仿 Flomo 样式)
struct TagFilterCard: View {
    let item: TimelineItem
    let highlightTag: String
    
    // 时间格式化
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: item.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 1. 顶部信息栏
            HStack {
                Text(dateString)
                    .font(.system(size: 13, weight: .regular, design: .monospaced)) // 等宽字体更像代码/日志风格
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 2. 内容区域 (标签 + 文本 混排)
            if !item.content.isEmpty {
                TagFilterLayout(spacing: 6) {
                    let segments = parseContent(item.content)
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        if segment.isTag {
                            Text(segment.text)
                                .font(.system(size: 15))
                                .foregroundColor(.blue) // 蓝色文字
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.15)) // 蓝色背景胶囊
                                .cornerRadius(6)
                        } else {
                            Text(segment.text)
                                .font(.system(size: 16))
                                .foregroundColor(Color(uiColor: .label)) // 自动适配深浅色
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            // 3. 图片区域
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .clipped()
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground)) // 卡片背景色
        .cornerRadius(12)
        // 微弱的阴影增加层次感
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    // 解析逻辑 (私有，不依赖外部)
    private struct TagTextSegment: Identifiable {
        let id = UUID()
        let text: String
        let isTag: Bool
    }
    
    private func parseContent(_ text: String) -> [TagTextSegment] {
        var segments: [TagTextSegment] = []
        // 保留换行符的分割逻辑
        let lines = text.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TagTextSegment(text: stringWord, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TagTextSegment(text: stringWord, isTag: false))
                }
                
                // 补空格 (如果不是该行最后一个词)
                if wordIndex < words.count - 1 {
                    segments.append(TagTextSegment(text: " ", isTag: false))
                }
            }
            
            // 补换行 (如果不是最后一行)
            // 注意：FlowLayout 处理换行比较麻烦，这里我们用一个占位符或者让 Layout 自动换行
            // 简单处理：将换行符作为一个宽带满的透明视图强制换行，或者这里简单地作为普通文本处理
            if lineIndex < lines.count - 1 {
                 // 在这里插入一个特殊的换行标记，或者仅仅加上 "\n" 字符
                 // 为了简单，我们插入一个宽度极大但不可见的 View 会比较复杂
                 // 这里简单处理：让 \n 成为一个普通段落，虽然 FlowLayout 可能不会强制换行。
                 // 完美方案需要自定义 Layout 处理 newline，这里简化为加一个空格
                 segments.append(TagTextSegment(text: "\n", isTag: false))
            }
        }
        return segments
    }
}

// MARK: - 专用流式布局 (私有)
private struct TagFilterLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    
    struct LayoutResult { var size: CGSize; var points: [CGPoint] }
    
    func flow(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // 如果遇到 "\n" 文本，强制换行 (简单 hack)
            // 这里我们无法直接读取 View 内容，所以只能依赖宽度判断
            // 或者如果之前逻辑里 \n 是单独一个 segment，我们可以通过某种方式识别？
            // 暂且只做自动换行
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            points.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return LayoutResult(size: CGSize(width: maxWidth, height: currentY + lineHeight), points: points)
    }
}
