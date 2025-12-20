//
//  TimeLineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - 主视图
struct TimeLineView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var showSideMenu: Bool
    
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    
    // 全屏图片状态
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. 背景层
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                    .onTapGesture { hideKeyboard() }
                
                // 2. 列表层
                TimelineListView(date: selectedDate, onImageTap: { image in
                    fullScreenImage = FullScreenImage(image: image)
                })
                .onTapGesture { hideKeyboard() }
                
                // 3. 输入栏层 (仅在今天显示)
                // 使用 overlay 或 ZStack 底部对齐，这里为了避免键盘遮挡问题，InputBarView 内部处理了 padding
                if Calendar.current.isDateInToday(selectedDate) {
                    InputBarView()
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
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(image: wrapper.image)
            }
        }
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        if Calendar.current.isDateInToday(date) { return "今日" }
        return formatter.string(from: date)
    }
}

// MARK: - 列表视图 (TimelineListView)
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
        
        // 🔥 核心修改：移除 type == "timeline" 的限制，查询所有类型的记录
        // 这样“灵感”和“流水账”都会显示在时间轴上
        _items = Query(
            filter: #Predicate<TimelineItem> { item in
                item.timestamp >= startOfDay &&
                item.timestamp < endOfDay
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
                    // 底部留白，防止被输入栏遮挡
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

// MARK: - 单行组件 (TimelineRowView - 升级版)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    // 解析出的标签
    private var tags: [String] {
        item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }
    
    private var isInspiration: Bool {
        item.type == "inspiration"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间轴线
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
                // 灵感类型的节点可以用不同颜色突出
                Circle()
                    .fill(isInspiration ? Color.yellow : Color.blue)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                if !isLast {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                } else { Spacer() }
            }
            .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                // 时间戳
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary).padding(.top, 10)
                
                // 内容气泡
                VStack(alignment: .leading, spacing: 8) {
                    // 图片区域
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 160).frame(maxWidth: .infinity)
                            .cornerRadius(8).clipped()
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    
                    // 文字区域
                    if !item.content.isEmpty {
                        Text(item.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                    }
                    
                    // 🔥 方案 B：页脚信息 (标签 & 灵感标识)
                    if !tags.isEmpty || isInspiration {
                        Divider().opacity(0.3) // 分割线
                        HStack(spacing: 8) {
                            // 灵感标识
                            if isInspiration {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text("灵感")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(4)
                            }
                            
                            // 标签列表
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                // 气泡背景色
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                // 灵感类型可以加一点微弱的金色边框或阴影
                .shadow(color: isInspiration ? Color.yellow.opacity(0.1) : Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isInspiration ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 输入栏 2.0 (InputBarView)
struct InputBarView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 输入状态
    @State private var inputText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    // 焦点控制
    @FocusState private var isInputFocused: Bool
    
    // 🔥 新增：灵感模式开关
    @State private var isInspirationMode: Bool = false
    
    // 获取最近使用的标签 (简单实现：获取所有灵感里的标签)
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var inspirationItems: [TimelineItem]
    
    // 计算前 5 个常用标签
    private var recentTags: [String] {
        var counts: [String: Int] = [:]
        for item in inspirationItems {
            let words = item.content.split(separator: " ")
            for word in words {
                let str = String(word)
                if str.hasPrefix("#") && str.count > 1 {
                    counts[str, default: 0] += 1
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // 🔥 标签联想栏 (Accessory View)
            // 仅当输入框聚焦时显示
            if isInputFocused && !recentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentTags, id: \.self) { tag in
                            Button(action: {
                                inputText += " \(tag) "
                            }) {
                                Text(tag)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 主输入区域
            VStack(alignment: .leading, spacing: 12) {
                // 如果选中了图片，显示图片预览
                if let image = selectedImage {
                    HStack(alignment: .top) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 80)
                            .cornerRadius(10).clipped()
                            .overlay(
                                Button(action: { withAnimation { selectedImage = nil } }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 5, y: -5), alignment: .topTrailing
                            )
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                HStack(alignment: .bottom, spacing: 10) {
                    
                    // 1. 左侧：灵感开关
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation { isInspirationMode.toggle() }
                    }) {
                        Image(systemName: isInspirationMode ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 22))
                            .foregroundColor(isInspirationMode ? .yellow : .secondary)
                            .frame(width: 36, height: 36)
                            .background(isInspirationMode ? Color.yellow.opacity(0.15) : Color.clear)
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 4)
                    
                    // 2. 中间：输入框
                    TextField(isInspirationMode ? "捕捉灵感..." : "现在在想什么...", text: $inputText, axis: .vertical)
                        .focused($isInputFocused)
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemFill))
                        .cornerRadius(18)
                        .lineLimit(1...5)
                        // 如果是灵感模式，输入框边框高亮
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isInspirationMode ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    // 3. 右侧：图片和发送
                    if inputText.isEmpty && selectedImage == nil {
                        Button(action: { sourceType = .photoLibrary; showImagePicker = true }) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                        }
                        .padding(.bottom, 4)
                    } else {
                        Button(action: saveItem) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(isInspirationMode ? .yellow : .blue)
                                .shadow(color: (isInspirationMode ? Color.yellow : Color.blue).opacity(0.3), radius: 4)
                        }
                        .padding(.bottom, 2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.top, 10)
            .background(.ultraThinMaterial) // 毛玻璃背景
            .cornerRadius(25, corners: [.topLeft, .topRight]) // 只圆角上方
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    private func saveItem() {
        guard !inputText.isEmpty || selectedImage != nil else { return }
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let icon = imageData != nil ? "photo" : "text.bubble"
        
        // 🔥 根据模式决定 type
        let type = isInspirationMode ? "inspiration" : "timeline"
        
        let newItem = TimelineItem(
            content: inputText,
            iconName: icon,
            timestamp: Date(),
            imageData: imageData,
            type: type
        )
        modelContext.insert(newItem)
        try? modelContext.save()
        
        // 成功反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            inputText = ""
            selectedImage = nil
            isInputFocused = false
            isInspirationMode = false // 发送后重置为普通模式
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

// MARK: - 扩展：部分圆角 & 隐藏键盘
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    #if canImport(UIKit)
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
