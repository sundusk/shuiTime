//
//  TagFilterView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftUI
import SwiftData
import UIKit

struct TagFilterView: View {
    let tagName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 获取所有数据
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]
    
    // 筛选逻辑
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
    
    // 🔥 新增：自定义菜单状态 (参考 InspirationView)
    @State private var showCustomMenu = false
    @State private var menuPosition: CGPoint = .zero
    @State private var itemForMenu: TimelineItem?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景色
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            TagFilterCard(
                                item: item,
                                highlightTag: tagName,
                                onMenuTap: { selectedItem, anchorPoint in
                                    self.itemForMenu = selectedItem
                                    self.menuPosition = anchorPoint
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        self.showCustomMenu = true
                                    }
                                },
                                onImageTap: { image in
                                    self.fullScreenImage = FullScreenImage(image: image)
                                }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: "TagFilterScrollSpace") // 🔥 关键：定义坐标空间用于定位菜单
            }
            
            // 🔥 新增：浮层菜单 (参考 InspirationView)
            if showCustomMenu {
                Color.black.opacity(0.01).ignoresSafeArea().onTapGesture { withAnimation { showCustomMenu = false } }
                
                VStack(spacing: 0) {
                    Button(action: {
                        showCustomMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { itemToEdit = itemForMenu }
                    }) {
                        HStack { Image(systemName: "pencil"); Text("修改"); Spacer() }
                            .padding().foregroundColor(.primary)
                    }
                    Divider()
                    Button(action: {
                        showCustomMenu = false
                        if let item = itemForMenu {
                            itemToDelete = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showDeleteAlert = true }
                        }
                    }) {
                        HStack { Image(systemName: "trash"); Text("删除"); Spacer() }
                            .padding().foregroundColor(.red)
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12).frame(width: 140)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .position(x: menuPosition.x - 70, y: menuPosition.y + 60)
                .transition(.scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .navigationTitle("#\(tagName)")
        .navigationBarTitleDisplayMode(.inline)
        // 图片全屏浏览
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
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

// MARK: - 卡片组件
struct TagFilterCard: View {
    let item: TimelineItem
    let highlightTag: String
    
    // 🔥 新增回调
    var onMenuTap: (TimelineItem, CGPoint) -> Void
    var onImageTap: ((UIImage) -> Void)?
    
    @State private var buttonFrame: CGRect = .zero
    
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
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // 🔥 修改：使用按钮触发菜单，而非长按
                Button(action: {
                    let anchor = CGPoint(x: buttonFrame.maxX, y: buttonFrame.maxY)
                    onMenuTap(item, anchor)
                }) {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.gray) // 保持灰色，不抢视觉
                        .padding(8) // 增加点击区域
                }
                .buttonStyle(.borderless)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { buttonFrame = geo.frame(in: .named("TagFilterScrollSpace")) }
                        .onChange(of: geo.frame(in: .named("TagFilterScrollSpace"))) { _, newFrame in
                            buttonFrame = newFrame
                        }
                })
            }
            
            // 2. 内容区域 (标签 + 富文本混排)
            if !item.content.isEmpty {
                TagFilterLayout(spacing: 6) {
                    // 灯泡图标
                    if item.isHighlight {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                            .padding(.top, 2)
                    }
                    
                    let segments = parseContent(item)
                    ForEach(segments) { segment in
                        if segment.isTag {
                            Text(segment.attributedText)
                                .font(.system(size: 15))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                        } else {
                            Text(segment.attributedText)
                                .font(.system(size: 16))
                                .foregroundColor(Color(uiColor: .label))
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
                    .contentShape(Rectangle())
                    // 🔥 新增：点击图片放大
                    .onTapGesture {
                        onImageTap?(uiImage)
                    }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isHighlight ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
    
    // MARK: - 内容解析逻辑
    
    private struct TagTextSegment: Identifiable {
        let id = UUID()
        let text: String
        let attributedText: AttributedString
        let isTag: Bool
    }
    
    private func parseContent(_ item: TimelineItem) -> [TagTextSegment] {
        if let data = item.richContentData,
           let nsAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            return splitRichTextIntoSegments(nsAttr)
        }
        return splitPlainTextIntoSegments(item.content)
    }
    
    private func splitRichTextIntoSegments(_ nsAttr: NSAttributedString) -> [TagTextSegment] {
        var segments: [TagTextSegment] = []
        let string = nsAttr.string as NSString
        var currentIndex = 0
        
        while currentIndex < string.length {
            let remainingRange = NSRange(location: currentIndex, length: string.length - currentIndex)
            let rangeOfSpace = string.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: remainingRange)
            
            let segmentRange: NSRange
            let separatorRange: NSRange
            
            if rangeOfSpace.location == NSNotFound {
                segmentRange = remainingRange
                separatorRange = NSRange(location: string.length, length: 0)
            } else {
                segmentRange = NSRange(location: currentIndex, length: rangeOfSpace.location - currentIndex)
                separatorRange = rangeOfSpace
            }
            
            if segmentRange.length > 0 {
                let wordSubAttr = nsAttr.attributedSubstring(from: segmentRange)
                let wordString = wordSubAttr.string
                let swiftUIAttributed = AttributedString(wordSubAttr)
                
                if wordString.hasPrefix("#") && wordString.count > 1 {
                    segments.append(TagTextSegment(text: wordString, attributedText: swiftUIAttributed, isTag: true))
                } else {
                    segments.append(TagTextSegment(text: wordString, attributedText: swiftUIAttributed, isTag: false))
                }
            }
            
            if separatorRange.length > 0 {
                let sepSubAttr = nsAttr.attributedSubstring(from: separatorRange)
                let swiftUIAttributed = AttributedString(sepSubAttr)
                segments.append(TagTextSegment(text: sepSubAttr.string, attributedText: swiftUIAttributed, isTag: false))
            }
            
            currentIndex = segmentRange.upperBound + separatorRange.length
        }
        return segments
    }
    
    private func splitPlainTextIntoSegments(_ text: String) -> [TagTextSegment] {
        var segments: [TagTextSegment] = []
        let lines = text.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                let attr = AttributedString(stringWord)
                
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TagTextSegment(text: stringWord, attributedText: attr, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TagTextSegment(text: stringWord, attributedText: attr, isTag: false))
                }
                
                if wordIndex < words.count - 1 {
                    segments.append(TagTextSegment(text: " ", attributedText: AttributedString(" "), isTag: false))
                }
            }
            
            if lineIndex < lines.count - 1 {
                 segments.append(TagTextSegment(text: "\n", attributedText: AttributedString("\n"), isTag: false))
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
