//
//  InspirationSearchView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2026/01/03.
//

import SwiftData
import SwiftUI

struct InspirationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Query(
        filter: #Predicate<TimelineItem> { $0.type == "inspiration" },
        sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]

    // 搜索状态
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @FocusState private var isFocused: Bool

    // 筛选类型枚举
    enum SearchFilter: String, CaseIterable {
        case all = "全部"
        case hasImage = "有图的"
        case textOnly = "纯灵感"
        case recent = "最近一周"
    }

    // MARK: - 数据处理

    // 1. 计算热门标签 (前 10 个)
    private var topTags: [String] {
        var counts: [String: Int] = [:]
        for item in allItems {
            let lines = item.content.components(separatedBy: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                for word in words {
                    let str = String(word)
                    if str.hasPrefix("#") && str.count > 1 {
                        counts[str, default: 0] += 1
                    }
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }

    // 2. 实时筛选结果
    private var filteredItems: [TimelineItem] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 基础过滤：匹配内容
        let itemsMatchingText: [TimelineItem]
        if text.isEmpty {
            itemsMatchingText = allItems
        } else {
            itemsMatchingText = allItems.filter { item in
                item.content.localizedCaseInsensitiveContains(text)
            }
        }

        // 二次过滤：应用分类筛选
        switch selectedFilter {
        case .all:
            return itemsMatchingText
        case .hasImage:
            return itemsMatchingText.filter { $0.imageData != nil }
        case .textOnly:
            return itemsMatchingText.filter { $0.imageData == nil }
        case .recent:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return itemsMatchingText.filter { $0.timestamp >= weekAgo }
        }
    }

    // MARK: - 视图主体
    var body: some View {
        ZStack {
            // 1. 底层：复用流动的弥散背景
            // 如果这个背景组件导致性能问题，可以先注释掉测试
            MeshGradientBackground()

            VStack(spacing: 0) {
                // 2. 顶部：自定义毛玻璃搜索栏
                CustomSearchBar(
                    text: $searchText, isFocused: $isFocused,
                    onCancel: {
                        dismiss()
                    }
                )
                .padding(.top, 10)
                .padding(.horizontal)
                .padding(.bottom, 10)

                // 3. 内容区域
                ScrollView {
                    VStack(spacing: 24) {
                        if searchText.isEmpty && selectedFilter == .all {
                            // --- 状态 A: 搜索着陆页 (Landing Page) ---
                            LandingContentView(
                                tags: topTags,
                                onTagSelect: { tag in
                                    searchText = tag
                                    // 点击标签后也可以收起键盘
                                    isFocused = false
                                },
                                selectedFilter: $selectedFilter
                            )
                        } else {
                            // --- 状态 B: 搜索结果页 (Results) ---
                            ResultsContentView(
                                items: filteredItems,
                                highlightText: searchText,
                                currentFilter: $selectedFilter
                            )
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

// MARK: - 子组件：自定义搜索栏
struct CustomSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 输入框主体
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))

                TextField("搜索记忆、标签...", text: $text)
                    .focused(isFocused)  // 绑定焦点状态
                    .font(.system(size: 17))
                    .submitLabel(.search)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)  // 毛玻璃效果
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)

            // 取消按钮
            Button("取消") {
                // 取消时先收键盘，再退页面，体验更流畅
                isFocused.wrappedValue = false
                onCancel()
            }
            .foregroundColor(.primary)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

// MARK: - 子组件：着陆页内容 (标签 + 筛选入口)
struct LandingContentView: View {
    let tags: [String]
    var onTagSelect: (String) -> Void
    @Binding var selectedFilter: InspirationSearchView.SearchFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {

            // 1. 常用标签
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("常用标签")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // 复用 FlowLayout
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button(action: { onTagSelect(tag) }) {
                                Text(tag)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // 2. 快速筛选
            VStack(alignment: .leading, spacing: 12) {
                Text("快速筛选")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    QuickFilterCard(
                        icon: "photo.on.rectangle",
                        title: "有图",
                        color: .purple,
                        isSelected: selectedFilter == .hasImage
                    ) { selectedFilter = .hasImage }

                    QuickFilterCard(
                        icon: "text.bubble",
                        title: "纯灵感",
                        color: .orange,
                        isSelected: selectedFilter == .textOnly
                    ) { selectedFilter = .textOnly }

                    QuickFilterCard(
                        icon: "clock",
                        title: "最近一周",
                        color: .green,
                        isSelected: selectedFilter == .recent
                    ) { selectedFilter = .recent }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
    }
}

// 快速筛选卡片按钮
struct QuickFilterCard: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                ZStack {
                    if isSelected {
                        Rectangle().fill(color.gradient)
                    } else {
                        Color(uiColor: .secondarySystemGroupedBackground).opacity(0.7)
                    }
                }
            )
            .cornerRadius(16)
            .shadow(
                color: isSelected ? color.opacity(0.4) : .black.opacity(0.05), radius: 8, x: 0, y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - 子组件：搜索结果页
struct ResultsContentView: View {
    let items: [TimelineItem]
    let highlightText: String
    @Binding var currentFilter: InspirationSearchView.SearchFilter

    var body: some View {
        VStack(spacing: 16) {
            // 顶部筛选条
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InspirationSearchView.SearchFilter.allCases, id: \.self) { filter in
                        FilterChip(title: filter.rawValue, isSelected: currentFilter == filter) {
                            withAnimation { currentFilter = filter }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // 结果列表
            if items.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("未找到相关灵感")
                        .foregroundColor(.gray)
                    Text("换个关键词试试？")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(items) { item in
                        InspirationCardView(
                            item: item,
                            highlightText: highlightText,
                            onMenuTap: { _, _ in },
                            onTagTap: nil,
                            onImageTap: nil
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    isSelected ? Color.blue : Color(uiColor: .tertiarySystemGroupedBackground)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
