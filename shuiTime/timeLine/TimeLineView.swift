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
    
    // 控制新建输入的弹窗
    @State private var showInputSheet: Bool = false
    
    // 全屏图片
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            // 背景层
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            // 列表层
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
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        // 使用 InspirationInputView 替换旧的输入弹窗，并指定类型为 timeline
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
        if Calendar.current.isDateInToday(date) { return "今日" }
        return formatter.string(from: date)
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
                EditTimelineView(item: item)
            }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete { deleteItem(item) }
                }
            } message: { Text("删除后将无法恢复这条记录。") }
        }
    }
    
    private func deleteItem(_ item: TimelineItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
    }
}

// MARK: - 单行组件
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间线轴
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
                Circle().fill(Color.blue).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                if !isLast {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                } else { Spacer() }
            }
            .frame(width: 20)
            
            // 右侧内容卡片
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary).padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 图片显示
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 160).frame(maxWidth: .infinity)
                            .cornerRadius(8).clipped()
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    
                    // 文字内容显示 (支持标签高亮)
                    if !item.content.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: item.iconName)
                                .foregroundColor(.brown)
                                .padding(.top, 2)
                            
                            // 解析内容并布局
                            let segments = parseContent(item.content)
                            FlowLayout(spacing: 4) {
                                ForEach(segments.indices, id: \.self) { index in
                                    let segment = segments[index]
                                    if segment.isTag {
                                        Text(segment.text)
                                            .font(.body).foregroundColor(.blue)
                                            .padding(.vertical, 2).padding(.horizontal, 6)
                                            .background(Color.blue.opacity(0.1)).cornerRadius(4)
                                    } else {
                                        Text(segment.text).font(.body).foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12).background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
    
    // 解析逻辑 (返回值改为了 TimelineTextSegment)
    func parseContent(_ text: String) -> [TimelineTextSegment] {
        var segments: [TimelineTextSegment] = []
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wordIndex, word) in words.enumerated() {
                let stringWord = String(word)
                if stringWord.hasPrefix("#") && stringWord.count > 1 {
                    segments.append(TimelineTextSegment(text: stringWord, isTag: true))
                } else if !stringWord.isEmpty {
                    segments.append(TimelineTextSegment(text: stringWord, isTag: false))
                }
                if wordIndex < words.count - 1 { segments.append(TimelineTextSegment(text: " ", isTag: false)) }
            }
            if lineIndex < lines.count - 1 { segments.append(TimelineTextSegment(text: "\n", isTag: false)) }
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

// 🔥 重命名为 TimelineTextSegment，避免和 InspirationView 的 TextSegment 冲突
// 🔥 去掉了 private，因为 TimelineRowView (internal) 使用了它
struct TimelineTextSegment: Identifiable {
    let id = UUID()
    let text: String
    let isTag: Bool
}

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
