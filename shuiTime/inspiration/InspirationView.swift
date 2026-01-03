//
//  InspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftData
import SwiftUI

struct InspirationView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TimelineItem> { $0.type == "inspiration" },
        sort: \TimelineItem.timestamp, order: .reverse)
    private var items: [TimelineItem]

    @State private var showNewInputSheet = false
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    @State private var showCustomMenu = false
    @State private var menuPosition: CGPoint = .zero
    @State private var itemForMenu: TimelineItem?

    @State private var selectedTag: String?
    @State private var fullScreenImage: FullScreenImage?

    // 控制搜索页面的显示
    @State private var showSearchPage = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // 1. 背景层 (移除这里的 navigationDestination)
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if items.isEmpty {
                    // --- 空状态 ---
                    VStack(spacing: 0) {
                        CustomHeader(onSearch: {
                            print("DEBUG: 点击了搜索按钮")
                            DispatchQueue.main.async {
                                showSearchPage = true
                            }
                        })
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "lightbulb.min")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.3))
                            Text("点击右下角记录灵感")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                } else {
                    // --- 列表状态 ---
                    ScrollView {
                        CustomHeader(onSearch: {
                            print("DEBUG: 点击了搜索按钮")
                            DispatchQueue.main.async {
                                showSearchPage = true
                            }
                        })
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                        LazyVStack(spacing: 16) {
                            ForEach(items) { item in
                                InspirationCardView(
                                    item: item,
                                    onMenuTap: { selectedItem, anchorPoint in
                                        self.itemForMenu = selectedItem
                                        self.menuPosition = anchorPoint
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7))
                                        {
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
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                    .coordinateSpace(name: "InspirationScrollSpace")
                }

                // 悬浮加号按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showNewInputSheet = true }) {
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

                // 浮层菜单
                if showCustomMenu {
                    Color.black.opacity(0.01).ignoresSafeArea().onTapGesture {
                        withAnimation { showCustomMenu = false }
                    }
                    VStack(spacing: 0) {
                        Button(action: {
                            showCustomMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                itemToEdit = itemForMenu
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("修改")
                                Spacer()
                            }
                            .padding().foregroundColor(.primary)
                        }
                        Divider()
                        Button(action: {
                            showCustomMenu = false
                            if let item = itemForMenu {
                                itemToDelete = item
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showDeleteAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("删除")
                                Spacer()
                            }
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
            // 🔥🔥🔥 修复方案：改用 fullScreenCover 而不是 navigationDestination 🔥🔥🔥
            // 原因：搜索页面本身隐藏了导航栏，使用 fullScreenCover 更合适，避免 NavigationStack 冲突
            .onChange(of: showSearchPage) { oldValue, newValue in
                print("DEBUG: showSearchPage 状态变化 - 旧值: \(oldValue), 新值: \(newValue)")
            }
            .fullScreenCover(isPresented: $showSearchPage) {
                InspirationSearchView()
            }
            // 处理标签点击的跳转
            .navigationDestination(item: $selectedTag) { tag in
                TagFilterView(tagName: tag)
            }
            .toolbar(.hidden, for: .navigationBar)  // 隐藏系统导航栏
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(image: wrapper.image)
            }
            .sheet(isPresented: $showNewInputSheet) {
                InspirationInputView(itemToEdit: nil)
            }
            .sheet(item: $itemToEdit) { item in
                InspirationInputView(itemToEdit: item)
            }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) { if let item = itemToDelete { deleteItem(item) } }
            } message: {
                Text("删除后将无法恢复。")
            }
        }
    }

    private func deleteItem(_ item: TimelineItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
        itemForMenu = nil
    }
}
// CustomHeader, InspirationCardView, FlowLayout 保持不变...

// MARK: - 自定义头部组件
struct CustomHeader: View {
    var onSearch: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("灵感集")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            // 搜索按钮
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    // 🔥 增加点击热区，确保容易点中
                    .contentShape(Circle())
            }
        }
    }
}

// MARK: - 灵感卡片视图 (UI 优化版 - 支持高亮)
struct InspirationCardView: View {
    let item: TimelineItem

    // 🔥 4. 新增：高亮文字参数 (可选)
    var highlightText: String? = nil

    var onMenuTap: (TimelineItem, CGPoint) -> Void
    var onTagTap: ((String) -> Void)? = nil
    var onImageTap: ((UIImage) -> Void)? = nil

    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部
            HStack {
                Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                buttonFrame = geo.frame(in: .named("InspirationScrollSpace"))
                            }
                            .onChange(of: geo.frame(in: .named("InspirationScrollSpace"))) {
                                _, newFrame in
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
                let segments = parseContent(item.content)
                FlowLayout(spacing: 4) {
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]

                        // 🔥 5. 核心逻辑：判断是否高亮
                        let isHighlighted = shouldHighlight(segment.text)

                        if segment.isTag {
                            Button(action: { onTagTap?(segment.text) }) {
                                Text(segment.text)
                                    .font(.body)
                                    // 高亮时加粗，否则普通蓝
                                    .foregroundColor(isHighlighted ? .blue : .blue)
                                    .fontWeight(isHighlighted ? .black : .regular)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    // 高亮时背景变深
                                    .background(
                                        isHighlighted
                                            ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.1)
                                    )
                                    .cornerRadius(4)
                            }
                        } else {
                            Text(segment.text)
                                .font(.body)
                                // 高亮时变蓝，否则普通色
                                .foregroundColor(isHighlighted ? .blue : .primary)
                                .fontWeight(isHighlighted ? .bold : .regular)
                                .background(isHighlighted ? Color.yellow.opacity(0.2) : Color.clear)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // 🔥 6. 判断是否高亮的辅助函数
    private func shouldHighlight(_ text: String) -> Bool {
        guard let query = highlightText, !query.isEmpty else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }

    // 解析和布局逻辑
    struct TextSegment: Identifiable {
        let id = UUID()
        let text: String
        let isTag: Bool
    }

    func parseContent(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TextSegment(text: stringWord, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TextSegment(text: stringWord, isTag: false))
                }
                if wordIndex < words.count - 1 {
                    segments.append(TextSegment(text: " ", isTag: false))
                }
            }
            if lineIndex < lines.count - 1 {
                segments.append(TextSegment(text: "\n", isTag: false))
            }
        }
        return segments
    }
}

// FlowLayout (保持不变，确保此类是 public 或 internal，以便 InspirationSearchView 调用)
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified)
        }
    }
    struct LayoutResult {
        var size: CGSize
        var points: [CGPoint]
    }
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
        return LayoutResult(
            size: CGSize(width: maxWidth, height: currentY + lineHeight), points: points)
    }
}
