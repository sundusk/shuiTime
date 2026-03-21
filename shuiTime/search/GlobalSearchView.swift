//
//  GlobalSearchView.swift
//  shuiTime
//
//  Created by Codex on 2026/03/21.
//

import SwiftData
import SwiftUI
import UIKit

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query(sort: \TimelineItem.timestamp, order: .reverse) private var allItems: [TimelineItem]

    @State private var searchText = ""
    @State private var selectedScope: SearchScope = .all
    @FocusState private var isFocused: Bool

    private enum SearchScope: String, CaseIterable {
        case all = "全部"
        case timeline = "时间线"
        case inspiration = "瞬息"
        case moment = "瞬影"

        var matchedType: String? {
            switch self {
            case .all:
                return nil
            case .timeline:
                return "timeline"
            case .inspiration:
                return "inspiration"
            case .moment:
                return "moment"
            }
        }
    }

    private var topTags: [String] {
        var counts: [String: Int] = [:]
        for item in allItems {
            for tag in tags(in: item.content) {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        .prefix(8)
        .map(\.key)
    }

    private var filteredItems: [TimelineItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return allItems.filter { item in
            let matchesScope = selectedScope.matchedType == nil || item.type == selectedScope.matchedType
            guard matchesScope else { return false }

            guard !trimmed.isEmpty else { return true }

            let normalizedQuery = trimmed.lowercased()
            let contentMatches = item.content.localizedCaseInsensitiveContains(trimmed)
            let typeMatches = displayType(for: item).lowercased().contains(normalizedQuery)
            let dateMatches = shortDate(for: item.timestamp).lowercased().contains(normalizedQuery)

            return contentMatches || typeMatches || dateMatches
        }
    }

    private var recentItems: [TimelineItem] {
        Array(allItems.prefix(6))
    }

    private var showsLanding: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedScope == .all
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                VStack(spacing: 18) {
                    searchBar

                    scopeBar

                    ScrollView(showsIndicators: false) {
                        if showsLanding {
                            landingContent
                        } else {
                            resultContent
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索记录、标签、瞬影...", text: $searchText)
                    .focused($isFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            Button("取消") {
                dismiss()
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
    }

    private var scopeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    SearchTypeChip(
                        title: scope.rawValue,
                        isSelected: selectedScope == scope
                    ) {
                        selectedScope = scope
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var landingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !topTags.isEmpty {
                sectionCard(title: "热门标签", subtitle: "点一下直接开始搜索") {
                    FlowLayout(spacing: 8) {
                        ForEach(topTags, id: \.self) { tag in
                            Button(action: {
                                searchText = tag
                                isFocused = false
                            }) {
                                Text(tag)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(18)
                            }
                        }
                    }
                }
            }

            sectionCard(title: "最近记录", subtitle: "先从最近几条开始找回记忆") {
                VStack(spacing: 12) {
                    ForEach(recentItems) { item in
                        SearchResultRow(item: item, action: {
                            handleSelection(for: item)
                        })
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(filteredItems.count) 条结果")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if !searchText.isEmpty {
                    Text("关键词：\(searchText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 42))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("没有找到相关记录")
                        .font(.headline)
                    Text("换个关键词，或者切到其他筛选看看。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        SearchResultRow(item: item, action: {
                            handleSelection(for: item)
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 30)
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }

    private func tags(in content: String) -> [String] {
        content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }

    private func displayType(for item: TimelineItem) -> String {
        switch item.type {
        case "timeline":
            return "时间线"
        case "inspiration":
            return "瞬息"
        case "moment":
            return "瞬影"
        default:
            return item.type
        }
    }

    private func shortDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func handleSelection(for item: TimelineItem) {
        switch item.type {
        case "inspiration":
            navigationState.selectedTab = 1
            navigationState.focusedInspirationItemID = item.id
            navigationState.focusedTimelineItemID = nil
            navigationState.presentedMomentItemID = nil
        case "timeline", "moment":
            navigationState.selectedTab = 0
            navigationState.selectedTimelineDate = item.timestamp
            navigationState.focusedTimelineItemID = item.id
            navigationState.focusedInspirationItemID = nil
            navigationState.presentedMomentItemID = item.type == "moment" ? item.id : nil
        default:
            navigationState.selectedTab = 0
            navigationState.selectedTimelineDate = item.timestamp
            navigationState.focusedTimelineItemID = item.id
            navigationState.focusedInspirationItemID = nil
            navigationState.presentedMomentItemID = nil
        }

        dismiss()
    }
}

private struct SearchTypeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.12))
                .foregroundColor(isSelected ? .white : .blue)
                .cornerRadius(18)
        }
    }
}

private struct SearchResultRow: View {
    let item: TimelineItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipped()
                        .cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 54, height: 54)
                        .overlay {
                            Image(systemName: iconName)
                                .foregroundColor(.blue)
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(typeTitle)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(typeColor.opacity(0.14))
                            .foregroundColor(typeColor)
                            .cornerRadius(12)

                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(summaryText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return item.type == "moment" ? "图片记录" : "无文字内容"
    }

    private var iconName: String {
        switch item.type {
        case "timeline":
            return "text.bubble"
        case "inspiration":
            return "lightbulb"
        case "moment":
            return "photo"
        default:
            return "doc.text"
        }
    }

    private var typeTitle: String {
        switch item.type {
        case "timeline":
            return "时间线"
        case "inspiration":
            return "瞬息"
        case "moment":
            return "瞬影"
        default:
            return item.type
        }
    }

    private var typeColor: Color {
        switch item.type {
        case "timeline":
            return .blue
        case "inspiration":
            return .orange
        case "moment":
            return .green
        default:
            return .gray
        }
    }
}
