//
//  InspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftData
import SwiftUI
import UIKit

struct InspirationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: AppNavigationState

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

    // 🔥 圈选功能
    @State private var showColorPicker = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // 1. 背景层 - 使用弥散渐变背景（与时间线、时光回顾页面统一）
                MeshGradientBackground()

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
                            Text("点击右下角记录瞬息")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                } else {
                    // --- 列表状态 ---
                    ScrollViewReader { proxy in
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
                                        isFocused: item.id == navigationState.focusedInspirationItemID,
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
                                        onImageTap: { item in
                                            self.fullScreenImage = FullScreenImage(
                                                image: UIImage(data: item.imageData!)!,
                                                isLivePhoto: item.isLivePhoto,
                                                videoData: item.livePhotoVideoData
                                            )
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80)
                        }
                        .coordinateSpace(name: "InspirationScrollSpace")
                        .onAppear {
                            scrollToFocusedItem(using: proxy)
                        }
                        .onChange(of: navigationState.focusedInspirationItemID) { _, _ in
                            scrollToFocusedItem(using: proxy)
                        }
                        .onChange(of: items.map(\.id)) { _, _ in
                            scrollToFocusedItem(using: proxy)
                        }
                    }
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
                        // 🔥 新增：圈选按钮
                        Button(action: {
                            showCustomMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showColorPicker = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "circle.circle")
                                Text("圈选")
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

                // 🔥 彩虹颜色选择器浮层
                if showColorPicker {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showColorPicker = false
                            }
                        }
                    
                    RainbowColorPickerView(
                        onColorSelected: { colorHex in
                            if let item = itemForMenu {
                                item.borderColorHex = colorHex
                                try? modelContext.save()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showColorPicker = false
                            }
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showColorPicker = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
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
            .onAppear {
                openPendingTagIfNeeded()
            }
            .onChange(of: navigationState.pendingInspirationTag) { _, _ in
                openPendingTagIfNeeded()
            }
            .toolbar(.hidden, for: .navigationBar)  // 隐藏系统导航栏
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(imageEntity: wrapper)
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

    private func scrollToFocusedItem(using proxy: ScrollViewProxy) {
        guard
            let focusedID = navigationState.focusedInspirationItemID,
            items.contains(where: { $0.id == focusedID })
        else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(focusedID, anchor: .center)
            }
        }
    }

    private func openPendingTagIfNeeded() {
        guard let tag = navigationState.pendingInspirationTag else { return }
        selectedTag = tag
        navigationState.pendingInspirationTag = nil
    }
}
// CustomHeader, InspirationCardView, FlowLayout 保持不变...

// MARK: - 自定义头部组件
struct CustomHeader: View {
    var onSearch: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("瞬息")
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
    var isFocused: Bool = false

    // 🔥 4. 新增：高亮文字参数 (可选)
    var highlightText: String? = nil

    var onMenuTap: (TimelineItem, CGPoint) -> Void
    var onTagTap: ((String) -> Void)? = nil
    var onImageTap: ((TimelineItem) -> Void)? = nil

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
                        onImageTap?(item)
                    }
            }

            // 内容
            if !item.content.isEmpty {
                // 提取标签和纯文本
                let (tags, plainText) = extractTagsAndText(item.content)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 标签行 - 使用 FlowLayout 横向排列
                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                let isHighlighted = shouldHighlight(tag)
                                Button(action: { onTagTap?(tag) }) {
                                    Text(tag)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .fontWeight(isHighlighted ? .black : .regular)
                                        .padding(.vertical, 2).padding(.horizontal, 6)
                                        .background(
                                            isHighlighted
                                                ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // 纯文本 - 使用普通 Text，自动换行
                    if !plainText.isEmpty {
                        let isHighlighted = shouldHighlight(plainText)
                        ExpandableInspirationText(
                            text: plainText,
                            isHighlighted: isHighlighted
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        // 🔥 圈选颜色边框
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused
                        ? Color.blue.opacity(0.95)
                        : item.borderColorHex.flatMap { Color(hex: $0) } ?? Color.clear,
                    lineWidth: isFocused ? 2 : (item.borderColorHex != nil ? 3 : 0)
                )
        )
        .shadow(
            color: isFocused ? Color.blue.opacity(0.22) : Color.black.opacity(0.05),
            radius: isFocused ? 12 : 5,
            x: 0,
            y: isFocused ? 6 : 2
        )
    }

    // 🔥 6. 判断是否高亮的辅助函数
    private func shouldHighlight(_ text: String) -> Bool {
        guard let query = highlightText, !query.isEmpty else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }
    
    // 🔥 7. 提取标签和纯文本
    private func extractTagsAndText(_ content: String) -> (tags: [String], plainText: String) {
        var tags: [String] = []
        var plainTextParts: [String] = []
        
        // 按空格和换行分割
        let components = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        for component in components {
            if component.hasPrefix("#") && component.count > 1 {
                tags.append(component)
            } else if !component.isEmpty {
                plainTextParts.append(component)
            }
        }
        
        // 纯文本重新用空格连接
        let plainText = plainTextParts.joined(separator: " ")
        
        return (tags, plainText)
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

private struct ExpandableInspirationText: View {
    let text: String
    let isHighlighted: Bool

    @State private var isExpanded = false
    @State private var measuredWidth: CGFloat = 0
    @State private var shouldShowToggle = false

    private let collapsedLineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            contentText(lineLimit: isExpanded ? nil : collapsedLineLimit)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            updateToggleVisibility(for: geo.size.width)
                        }
                        .onChange(of: geo.size.width) { _, newWidth in
                            updateToggleVisibility(for: newWidth)
                        }
                }
            )

            if shouldShowToggle {
                Button(action: {
                    isExpanded.toggle()
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起" : "展开")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func contentText(lineLimit: Int?) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(isHighlighted ? .blue : .primary)
            .fontWeight(isHighlighted ? .bold : .regular)
            .background(isHighlighted ? Color.yellow.opacity(0.2) : Color.clear)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func updateToggleVisibility(for width: CGFloat) {
        let roundedWidth = floor(width)
        guard roundedWidth > 0 else { return }

        if abs(roundedWidth - measuredWidth) > 0.5 {
            measuredWidth = roundedWidth
        }

        let nextShouldShowToggle = requiresExpansionButton(for: roundedWidth)
        if shouldShowToggle != nextShouldShowToggle {
            shouldShowToggle = nextShouldShowToggle
        }

        if !nextShouldShowToggle && isExpanded {
            isExpanded = false
        }
    }

    private func requiresExpansionButton(for width: CGFloat) -> Bool {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )

        let collapsedHeight = ceil(font.lineHeight * CGFloat(collapsedLineLimit))
        return ceil(boundingRect.height) > collapsedHeight + 1
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
        let defaultMaxWidth: CGFloat = 600 // 适用于大多数设备的保守默认值
        let maxWidth = proposal.width ?? defaultMaxWidth
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

// MARK: - 🔥 彩虹颜色选择器视图
struct RainbowColorPickerView: View {
    var onColorSelected: (String?) -> Void
    var onDismiss: () -> Void
    
    // 彩虹七色
    private let rainbowColors: [(name: String, hex: String, color: Color)] = [
        ("红", "#FF0000", .red),
        ("橙", "#FF7F00", .orange),
        ("黄", "#FFFF00", .yellow),
        ("绿", "#00FF00", .green),
        ("蓝", "#0000FF", .blue),
        ("靛", "#4B0082", Color(red: 0.29, green: 0, blue: 0.51)),
        ("紫", "#8B00FF", .purple)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择圈选颜色")
                .font(.headline)
                .foregroundColor(.white)
            
            // 颜色圆圈 - 上3下4排列
            VStack(spacing: 16) {
                // 第一行：红、橙、黄
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { index in
                        colorButton(for: rainbowColors[index])
                    }
                }
                // 第二行：绿、蓝、靛、紫
                HStack(spacing: 20) {
                    ForEach(3..<7, id: \.self) { index in
                        colorButton(for: rainbowColors[index])
                    }
                }
            }
            
            // 清除按钮
            Button(action: {
                onColorSelected(nil)
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("清除颜色")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 🔥 居中显示
    }
    
    // 🔥 颜色按钮抽取为辅助函数
    @ViewBuilder
    private func colorButton(for colorInfo: (name: String, hex: String, color: Color)) -> some View {
        Button(action: {
            onColorSelected(colorInfo.hex)
        }) {
            Circle()
                .fill(colorInfo.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: colorInfo.color.opacity(0.5), radius: 5)
        }
    }
}

// MARK: - Color 扩展：十六进制转换
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
