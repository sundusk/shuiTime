//
//  TimeLineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

struct TimeLineView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var showSideMenu: Bool
    
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var items: [TimelineItem]
    
    // MARK: - 新增状态管理
    // 用来标记当前正在修改哪个 item
    @State private var itemToEdit: TimelineItem?
    // 用来标记当前准备删除哪个 item
    @State private var itemToDelete: TimelineItem?
    // 控制删除确认弹窗
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if items.isEmpty {
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Spacer().frame(height: 20)
                            
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                TimelineRowView(
                                    item: item,
                                    isLast: index == items.count - 1
                                )
                                // 🔥 核心：在这里添加长按菜单
                                .contextMenu {
                                    // 1. 修改按钮
                                    Button {
                                        itemToEdit = item // 触发 sheet
                                    } label: {
                                        Label("修改", systemImage: "pencil")
                                    }
                                    
                                    // 2. 删除按钮 (红色)
                                    Button(role: .destructive) {
                                        itemToDelete = item // 记录要删谁
                                        showDeleteAlert = true // 触发弹窗
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal)
                    }
                    .scrollClipDisabled(false)
                }
                
                InputBarView()
            }
            .navigationTitle(currentDateString())
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { withAnimation { showSideMenu = true } }) {
                        Image(systemName: "line.3.horizontal").foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "moon.stars").foregroundColor(.secondary)
                }
            }
            // MARK: - 弹窗逻辑
            // 1. 编辑弹窗
            .sheet(item: $itemToEdit) { item in
                EditTimelineView(item: item)
            }
            // 2. 删除确认弹窗
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                Text("删除后将无法恢复这条记录。")
            }
        }
    }
    
    // 删除逻辑
    private func deleteItem(_ item: TimelineItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        return "今日, " + formatter.string(from: Date())
    }
}

// MARK: - 单行时间轴 (保持不变，只是被上面调用时加了 contextMenu)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 2, height: 15)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                if !isLast {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            .clipped()
                    }
                    if !item.content.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: item.iconName)
                                .foregroundColor(.brown)
                            Text(item.content)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                // 增加一个透明背景来增大长按热区，防止点不到
                .contentShape(Rectangle())
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 底部输入栏 (保持不变)
struct InputBarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = selectedImage {
                HStack(alignment: .top) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                        .overlay(
                            Button(action: { withAnimation { selectedImage = nil } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 5, y: -5),
                            alignment: .topTrailing
                        )
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            HStack(alignment: .bottom) {
                TextField("现在在想什么? (记入时间轴)", text: $inputText, axis: .vertical)
                    .focused($isInputFocused)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemFill))
                    .cornerRadius(15)
                    .lineLimit(1...4)
                
                Button(action: {
                    sourceType = .photoLibrary
                    showImagePicker = true
                }) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                if !inputText.isEmpty || selectedImage != nil {
                    Button(action: saveItem) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(.bottom, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(25)
        .padding()
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    private func saveItem() {
        guard !inputText.isEmpty || selectedImage != nil else { return }
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let icon = imageData != nil ? "photo" : "text.bubble"
        let newItem = TimelineItem(
            content: inputText,
            iconName: icon,
            timestamp: Date(),
            imageData: imageData
        )
        modelContext.insert(newItem)
        try? modelContext.save()
        withAnimation {
            inputText = ""
            selectedImage = nil
            isInputFocused = false
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            Text("今日无时间线")
                .font(.title2)
                .foregroundColor(.gray)
            Text("点击下方记录当下的美好瞬间")
                .font(.footnote)
                .foregroundColor(.gray.opacity(0.6))
        }
        .offset(y: -100)
    }
}

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
