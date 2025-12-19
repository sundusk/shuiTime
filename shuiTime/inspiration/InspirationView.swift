//
//  InspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import UIKit // 🔥 引入 UIKit 以支持富文本解析

struct InspirationView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 🔥 修改查询逻辑：显示 类型为灵感 OR 标记为高亮(灯泡) 的内容
    @Query(filter: #Predicate<TimelineItem> { item in
        item.type == "inspiration" || item.isHighlight == true
    }, sort: \TimelineItem.timestamp, order: .reverse)
    private var items: [TimelineItem]
    
    // 保留修改和删除所需的状态
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    @State private var showCustomMenu = false
    @State private var menuPosition: CGPoint = .zero
    @State private var itemForMenu: TimelineItem?
    
    // 由父视图(ContentView)控制跳转
    @Binding var selectedTag: String?
    
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("暂无灵感记录")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(items) { item in
                            InspirationCardView(
                                item: item,
                                onMenuTap: { selectedItem, anchorPoint in
                                    self.itemForMenu = selectedItem
                                    self.menuPosition = anchorPoint
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        self.showCustomMenu = true
                                    }
                                },
                                onTagTap: { tag in
                                    self.selectedTag = tag
                                },
                                onImageTap: { image in
                                    self.fullScreenImage = FullScreenImage(image: image)
                                }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
                .coordinateSpace(name: "InspirationScrollSpace")
            }
            
            // 浮层菜单
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
        .navigationTitle("灵感集")
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
        .navigationDestination(item: $selectedTag) { tag in
            TagFilterView(tagName: tag)
        }
        
        // 保留编辑弹窗
        .sheet(item: $itemToEdit) { item in
            InspirationInputView(itemToEdit: item)
        }
        // 保留删除确认弹窗
        .alert("确认删除?", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { itemToDelete = nil }
            Button("删除", role: .destructive) { if let item = itemToDelete { deleteItem(item) } }
        } message: { Text("删除后将无法恢复。") }
    }
    
    private func deleteItem(_ item: TimelineItem) {
        withAnimation { modelContext.delete(item); try? modelContext.save() }
        itemToDelete = nil; itemForMenu = nil
    }
}

// MARK: - 灵感卡片视图 (支持富文本 + 灯泡图标)
struct InspirationCardView: View {
    let item: TimelineItem
    var onMenuTap: (TimelineItem, CGPoint) -> Void
    var onTagTap: ((String) -> Void)? = nil
    var onImageTap: ((UIImage) -> Void)? = nil
    
    @State private var buttonFrame: CGRect = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部信息
            HStack {
                Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 🔥 显示来源提示 (如果是从时间轴收藏过来的)
                if item.type == "timeline" && item.isHighlight {
                    Text("来自时间轴")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button(action: {
                    let anchor = CGPoint(x: buttonFrame.maxX, y: buttonFrame.maxY)
                    onMenuTap(item, anchor)
                }) {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(.borderless)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { buttonFrame = geo.frame(in: .named("InspirationScrollSpace")) }
                        .onChange(of: geo.frame(in: .named("InspirationScrollSpace"))) { _, newFrame in
                            buttonFrame = newFrame
                        }
                })
            }
            
            // 图片
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFill().frame(height: 180).frame(maxWidth: .infinity)
                    .cornerRadius(8).clipped().contentShape(Rectangle())
                    .onTapGesture {
                        onImageTap?(uiImage)
                    }
            }
            
            // 内容
            if !item.content.isEmpty {
                // 🔥 使用富文本解析
                let segments = parseContent(item)
                
                FlowLayout(spacing: 4) {
                    // 🔥 如果是高亮内容，显示灯泡图标
                    if item.isHighlight {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                            .padding(.trailing, 2)
                    }
                    
                    ForEach(segments) { segment in
                        if segment.isTag {
                            Button(action: { onTagTap?(segment.text) }) {
                                Text(segment.attributedText) // 使用富文本
                                    .font(.body).foregroundColor(.blue)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Color.blue.opacity(0.1)).cornerRadius(4)
                            }
                        } else {
                            Text(segment.attributedText) // 使用富文本
                                .font(.body).foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        // 🔥 增加高亮边框提示
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isHighlight ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
    
    // MARK: - 内容解析逻辑 (同步 TimelineView 的富文本支持)
    struct TextSegment: Identifiable {
        let id = UUID()
        let text: String
        let attributedText: AttributedString // 支持富文本
        let isTag: Bool
    }
    
    func parseContent(_ item: TimelineItem) -> [TextSegment] {
        // 1. 尝试加载富文本
        if let data = item.richContentData,
           let nsAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            return splitRichTextIntoSegments(nsAttr)
        }
        
        // 2. 降级为纯文本
        return splitPlainTextIntoSegments(item.content)
    }
    
    private func splitRichTextIntoSegments(_ nsAttr: NSAttributedString) -> [TextSegment] {
        var segments: [TextSegment] = []
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
                    segments.append(TextSegment(text: wordString, attributedText: swiftUIAttributed, isTag: true))
                } else {
                    segments.append(TextSegment(text: wordString, attributedText: swiftUIAttributed, isTag: false))
                }
            }
            
            if separatorRange.length > 0 {
                let sepSubAttr = nsAttr.attributedSubstring(from: separatorRange)
                let swiftUIAttributed = AttributedString(sepSubAttr)
                segments.append(TextSegment(text: sepSubAttr.string, attributedText: swiftUIAttributed, isTag: false))
            }
            
            currentIndex = segmentRange.upperBound + separatorRange.length
        }
        return segments
    }
    
    private func splitPlainTextIntoSegments(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                let attr = AttributedString(stringWord)
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TextSegment(text: stringWord, attributedText: attr, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TextSegment(text: stringWord, attributedText: attr, isTag: false))
                }
                if wordIndex < words.count - 1 { segments.append(TextSegment(text: " ", attributedText: AttributedString(" "), isTag: false)) }
            }
            if lineIndex < lines.count - 1 { segments.append(TextSegment(text: "\n", attributedText: AttributedString("\n"), isTag: false)) }
        }
        return segments
    }
}

// FlowLayout (保持不变)
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
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
        var currentX: CGFloat = 0; var currentY: CGFloat = 0; var lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth { currentX = 0; currentY += lineHeight + spacing; lineHeight = 0 }
            points.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
        return LayoutResult(size: CGSize(width: maxWidth, height: currentY + lineHeight), points: points)
    }
}
