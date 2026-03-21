//
//  SideMenuView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

struct SideMenuView: View {
    @Binding var isOpen: Bool

    // 点击标签的回调
    var onTagSelected: ((String) -> Void)?

    // 点击备份入口的回调
    var onBackupTap: (() -> Void)?

    // 获取数据库所有数据
    @Query private var allItems: [TimelineItem]

    // MARK: - 统计逻辑
    var noteCount: Int { allItems.count }

    var tagCount: Int { allTags.count }

    // 计算所有唯一的标签
    var allTags: [String] {
        let inspirationItems = allItems // 统计所有类型
        var uniqueTags = Set<String>()
        for item in inspirationItems {
            let lines = item.content.components(separatedBy: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                for word in words {
                    let stringWord = String(word)
                    // 数据本身包含 "#"，例如 "#标签"
                    if stringWord.hasPrefix("#") && stringWord.count > 1 {
                        uniqueTags.insert(stringWord)
                    }
                }
            }
        }
        return Array(uniqueTags).sorted()
    }
    
    var dayCount: Int {
        let timelineItems = allItems.filter { $0.type == "timeline" }
        let uniqueDays = Set(timelineItems.map { Calendar.current.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
    }

    private var latestEntryDate: Date? {
        allItems.map(\.timestamp).max()
    }

    private var tagPreview: [String] {
        Array(allTags.prefix(6))
    }

    var appVersionText: String {
        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
        let buildNumber =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(shortVersion) (\(buildNumber))"
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { isOpen = false } }
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("记录抽屉")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("这里保留真正有用的事情: 看数据、管备份、按标签翻找。")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 60)
                            .padding(.horizontal, 24)

                            OverviewCard(
                                noteCount: noteCount,
                                tagCount: tagCount,
                                dayCount: dayCount,
                                latestEntryDate: latestEntryDate
                            )
                            .padding(.horizontal, 16)

                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "数据管理", subtitle: "导出、恢复和整理记录")
                                    .padding(.horizontal, 24)

                                MenuButton(
                                    title: "数据备份与恢复",
                                    subtitle: "保存一份副本，或从备份恢复",
                                    icon: "arrow.up.arrow.down.circle.fill",
                                    color: .blue
                                ) {
                                    onBackupTap?()
                                }
                            }
                            .padding(.horizontal, 16)

                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "标签导航", subtitle: allTags.isEmpty ? "还没有可筛选的标签" : "按标签快速回看内容")
                                    .padding(.horizontal, 24)

                                if allTags.isEmpty {
                                    EmptyTagsCard()
                                        .padding(.horizontal, 16)
                                } else {
                                    TagPreviewCard(
                                        tags: tagPreview,
                                        onTagTap: { tag in onTagSelected?(tag) }
                                    )
                                        .padding(.horizontal, 16)

                                    VStack(spacing: 8) {
                                        ForEach(allTags, id: \.self) { tag in
                                            Button(action: { onTagSelected?(tag) }) {
                                                HStack(spacing: 12) {
                                                    Text(tag)
                                                        .font(.body.weight(.medium))
                                                        .foregroundColor(.primary)

                                                    Spacer()

                                                    Image(systemName: "arrow.up.right")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundColor(.blue.opacity(0.7))
                                                }
                                                .padding(.vertical, 14)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            Spacer().frame(height: 32)
                        }
                    }

                    Text(appVersionText)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.65))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                .frame(width: 300)
                .background(
                    ZStack {
                        Color(uiColor: .systemGroupedBackground)

                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.08))
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 22)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    .ignoresSafeArea()
                )
                .offset(x: isOpen ? 0 : -300)

                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
    }
}

// MARK: - 辅助组件

struct MenuButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatItemView: View {
    let number: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OverviewCard: View {
    let noteCount: Int
    let tagCount: Int
    let dayCount: Int
    let latestEntryDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据总览")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(latestEntryDate.map { "最近记录于 \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "还没有记录，先写下今天吧")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 12) {
                StatItemView(number: "\(noteCount)", title: "全部笔记")
                StatItemView(number: "\(tagCount)", title: "标签")
                StatItemView(number: "\(dayCount)", title: "记录天数")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TagPreviewCard: View {
    let tags: [String]
    let onTagTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用标签")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            FlexibleTagWrap(tags: tags, onTagTap: onTagTap)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.9))
        )
    }
}

struct EmptyTagsCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            Text("写记录时加上 `#标签`，这里就会变成你的快速入口。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.9))
        )
    }
}

struct FlexibleTagWrap: View {
    let tags: [String]
    let onTagTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        Button(action: { onTagTap(tag) }) {
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rows: [[String]] {
        var rows: [[String]] = [[]]
        var currentWidth = 0
        let maxWidth = 24

        for tag in tags {
            let tagWidth = tag.count + 4
            if currentWidth + tagWidth > maxWidth {
                rows.append([tag])
                currentWidth = tagWidth
            } else {
                rows[rows.count - 1].append(tag)
                currentWidth += tagWidth
            }
        }

        return rows.filter { !$0.isEmpty }
    }
}
