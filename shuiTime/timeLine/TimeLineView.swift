//
//  TimeLineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

// MARK: - 主视图
struct TimeLineView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var showSideMenu: Bool
    
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    @State private var showInputSheet: Bool = false
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 背景
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            // 列表内容
            TimelineListView(date: selectedDate, onImageTap: { image in
                fullScreenImage = FullScreenImage(image: image)
            })
            
            // 悬浮加号按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { withAnimation { showSideMenu = true } }) {
                    Image(systemName: "line.3.horizontal").foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .principal) {
                Button(action: { showCalendar = true }) {
                    HStack(spacing: 4) {
                        Text(dateString(selectedDate))
                            .font(.headline).foregroundColor(.primary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { withAnimation { selectedDate = Date() } }) {
                    Text("今天").font(.subheadline)
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
        .sheet(isPresented: $showCalendar) {
            VStack {
                DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showInputSheet) {
            InspirationInputView(itemToEdit: nil, createType: "timeline")
        }
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        return Calendar.current.isDateInToday(date) ? "今日" : formatter.string(from: date)
    }
}

// MARK: - 列表视图
struct TimelineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TimelineItem]
    
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    var onImageTap: (UIImage) -> Void
    
    init(date: Date, onImageTap: @escaping (UIImage) -> Void) {
        self.onImageTap = onImageTap
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _items = Query(
            filter: #Predicate<TimelineItem> { item in
                item.timestamp >= startOfDay &&
                item.timestamp < endOfDay &&
                item.type == "timeline"
            },
            sort: \.timestamp,
            order: .reverse
        )
    }
    
    var body: some View {
        if items.isEmpty {
            EmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 80)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TimelineRowView(item: item, isLast: index == items.count - 1, onImageTap: onImageTap)
                            .contextMenu {
                                Button { itemToEdit = item } label: { Label("修改", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showDeleteAlert = true
                                } label: { Label("删除", systemImage: "trash") }
                            }
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled(false)
            .sheet(item: $itemToEdit) { item in
                InspirationInputView(itemToEdit: item, createType: "timeline")
            }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete {
                        withAnimation { modelContext.delete(item); try? modelContext.save() }
                    }
                    itemToDelete = nil
                }
            } message: { Text("删除后将无法恢复这条记录。") }
        }
    }
}

// MARK: - 单行组件
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间轴
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
                Circle().fill(Color.blue).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                if !isLast {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                } else { Spacer() }
            }
            .frame(width: 20)
            
            // 右侧卡片内容
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary).padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 图片
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 160).frame(maxWidth: .infinity)
                            .cornerRadius(8).clipped()
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    
                    // 文字混排 (支持富文本)
                    if !item.content.isEmpty {
                        TimelineTagLayout(spacing: 6) {
                            // 🔥 修改：闪光点图标 (星星 -> 灯泡)
                            if item.isHighlight {
                                Image(systemName: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                                    .padding(.top, 2)
                            }
                            
                            let segments = parseContent(item)
                            ForEach(segments) { segment in
                                if segment.isTag {
                                    NavigationLink(destination: TagFilterView(tagName: segment.text)) {
                                        Text(segment.attributedText)
                                            .font(.subheadline)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text(segment.attributedText)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                .padding(12).background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                // 🔥 修改：高亮边框颜色
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.isHighlight ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
    
    func parseContent(_ item: TimelineItem) -> [TimelineContentSegment] {
        if let data = item.richContentData,
           let nsAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            return splitRichTextIntoSegments(nsAttr)
        }
        return splitPlainTextIntoSegments(item.content)
    }
    
    private func splitRichTextIntoSegments(_ nsAttr: NSAttributedString) -> [TimelineContentSegment] {
        var segments: [TimelineContentSegment] = []
        let string = nsAttr.string
        let nsString = string as NSString
        var currentIndex = 0
        
        while currentIndex < nsString.length {
            let remainingRange = NSRange(location: currentIndex, length: nsString.length - currentIndex)
            let rangeOfSpace = nsString.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: remainingRange)
            
            let segmentRange: NSRange
            let separatorRange: NSRange
            
            if rangeOfSpace.location == NSNotFound {
                segmentRange = remainingRange
                separatorRange = NSRange(location: nsString.length, length: 0)
            } else {
                segmentRange = NSRange(location: currentIndex, length: rangeOfSpace.location - currentIndex)
                separatorRange = rangeOfSpace
            }
            
            if segmentRange.length > 0 {
                let wordSubAttr = nsAttr.attributedSubstring(from: segmentRange)
                let wordString = wordSubAttr.string
                let swiftUIAttributed = AttributedString(wordSubAttr)
                
                if wordString.hasPrefix("#") && wordString.count > 1 {
                    segments.append(TimelineContentSegment(text: wordString, attributedText: swiftUIAttributed, isTag: true))
                } else {
                    segments.append(TimelineContentSegment(text: wordString, attributedText: swiftUIAttributed, isTag: false))
                }
            }
            
            if separatorRange.length > 0 {
                let sepSubAttr = nsAttr.attributedSubstring(from: separatorRange)
                let swiftUIAttributed = AttributedString(sepSubAttr)
                segments.append(TimelineContentSegment(text: sepSubAttr.string, attributedText: swiftUIAttributed, isTag: false))
            }
            
            currentIndex = segmentRange.upperBound + separatorRange.length
        }
        return segments
    }
    
    private func splitPlainTextIntoSegments(_ text: String) -> [TimelineContentSegment] {
        var segments: [TimelineContentSegment] = []
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                let attr = AttributedString(stringWord)
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TimelineContentSegment(text: stringWord, attributedText: attr, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TimelineContentSegment(text: stringWord, attributedText: attr, isTag: false))
                }
                if wordIndex < words.count - 1 {
                    segments.append(TimelineContentSegment(text: " ", attributedText: AttributedString(" "), isTag: false))
                }
            }
            if lineIndex < lines.count - 1 {
                segments.append(TimelineContentSegment(text: "\n", attributedText: AttributedString("\n"), isTag: false))
            }
        }
        return segments
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock").font(.system(size: 80)).foregroundColor(.gray.opacity(0.3))
            Text("这一天没有记录").font(.title2).foregroundColor(.gray)
            Text("时间流淌，静水流深").font(.footnote).foregroundColor(.gray.opacity(0.6))
        }
        .offset(y: -40)
    }
}

struct TimelineContentSegment: Identifiable {
    let id = UUID()
    let text: String
    let attributedText: AttributedString
    let isTag: Bool
}

struct TimelineTagLayout: Layout {
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

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
