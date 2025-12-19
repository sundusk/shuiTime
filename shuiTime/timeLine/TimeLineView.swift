//
//  TimeLineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import UIKit // 需要引入 UIKit 来支持 UIScrollView

// MARK: - 1. 全屏图片的数据包装器
struct FullScreenImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - 2. 新增：支持缩放的图片视图 (UIViewRepresentable)
struct ZoomableImageView: UIViewRepresentable {
    var image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        // 配置 ScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0 // 最大放大倍数
        scrollView.minimumZoomScale = 1.0 // 最小缩小倍数
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        
        // 配置 ImageView
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        // 添加布局约束：让 ImageView 初始大小填满 ScrollView
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // 这里不需要频繁更新，因为图片是静态的
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // 代理协调器：处理缩放逻辑
    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        
        // 告诉 ScrollView 哪个视图需要被缩放
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
    }
}

// MARK: - 3. 全屏图片查看容器
struct FullScreenPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black.ignoresSafeArea()
            
            // 🔥 使用支持缩放的图片视图
            ZoomableImageView(image: image)
                .ignoresSafeArea() // 让图片可以全屏展示
            
            // 关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .padding(.top, 40) // 避开刘海屏
                    }
                }
                Spacer()
            }
        }
        // 点击背景也可以关闭（可选，看个人喜好，有时会和缩放手势冲突，这里主要依靠关闭按钮）
    }
}

// MARK: - 4. 主视图
struct TimeLineView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var showSideMenu: Bool
    
    // 日期状态
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    
    // 控制全屏图片的状态
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                // 将点击回调传入 TimelineListView
                TimelineListView(date: selectedDate, onImageTap: { image in
                    // 触发全屏显示
                    fullScreenImage = FullScreenImage(image: image)
                })
                
                InputBarView()
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
            // 全屏图片覆盖层
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(image: wrapper.image)
            }
        }
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        if Calendar.current.isDateInToday(date) {
            return "今日"
        }
        return formatter.string(from: date)
    }
}

// MARK: - 5. 列表视图
struct TimelineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TimelineItem]
    
    // 状态管理
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    
    // 接收点击回调
    var onImageTap: (UIImage) -> Void
    
    init(date: Date, onImageTap: @escaping (UIImage) -> Void) {
        self.onImageTap = onImageTap
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _items = Query(
            filter: #Predicate<TimelineItem> { item in
                item.timestamp >= startOfDay && item.timestamp < endOfDay
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
                        TimelineRowView(
                            item: item,
                            isLast: index == items.count - 1,
                            onImageTap: onImageTap
                        )
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
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                Text("删除后将无法恢复这条记录。")
            }
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

// MARK: - 6. 单行组件
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间轴线
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
            
            // 内容区域
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 图片展示
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            .clipped()
                            // 点击手势
                            .onTapGesture {
                                onImageTap?(uiImage)
                            }
                    }
                    // 文字展示
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
                .contentShape(Rectangle())
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 7. 输入栏 (保持不变)
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

// MARK: - 8. 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            Text("这一天没有记录")
                .font(.title2)
                .foregroundColor(.gray)
            Text("时间流淌，静水流深")
                .font(.footnote)
                .foregroundColor(.gray.opacity(0.6))
        }
        .offset(y: -40)
    }
}

#Preview {
    TimeLineView(showSideMenu: .constant(false))
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
