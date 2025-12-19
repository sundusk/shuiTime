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
        ZStack(alignment: .bottomTrailing) { // 修改对齐方式，为了放置 FAB
            
            // 背景层
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            // 列表层
            TimelineListView(date: selectedDate, onImageTap: { image in
                fullScreenImage = FullScreenImage(image: image)
            })
            
            // 🔥 新增：悬浮加号按钮 (仿 InspirationView 样式)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue) // 时间线用蓝色主题
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
        // 🔥 新增：输入弹窗
        .sheet(isPresented: $showInputSheet) {
            TimelineInputSheet()
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

// MARK: - 新增：TimelineInputSheet (用于替代 InputBarView)
struct TimelineInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var content: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("内容")) {
                    TextField("记录当下的想法...", text: $content, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section(header: Text("图片")) {
                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                                .clipped()
                                .listRowInsets(EdgeInsets())
                            
                            Button(action: {
                                withAnimation { selectedImage = nil }
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                    .background(Circle().fill(.white))
                            }
                            .padding(8)
                        }
                    } else {
                        Button(action: {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("添加图片")
                            }
                        }
                    }
                }
            }
            .navigationTitle("新记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(content.isEmpty && selectedImage == nil)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
            }
        }
    }
    
    private func saveItem() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let icon = imageData != nil ? "photo" : "text.bubble"
        
        let newItem = TimelineItem(
            content: content,
            iconName: icon,
            timestamp: Date(),
            imageData: imageData,
            type: "timeline"
        )
        modelContext.insert(newItem)
        try? modelContext.save()
    }
}

// MARK: - 列表视图 (保持基本不变，只删除了 showSideMenu 绑定)
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

// MARK: - 单行组件 (保持不变)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
                Circle().fill(Color.blue).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                if !isLast {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                } else { Spacer() }
            }
            .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary).padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 160).frame(maxWidth: .infinity)
                            .cornerRadius(8).clipped()
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    if !item.content.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: item.iconName).foregroundColor(.brown)
                            Text(item.content).font(.body).foregroundColor(.primary).lineLimit(nil)
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

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
