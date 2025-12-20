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
    // 🔥 已移除 showSideMenu Binding
    
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    @State private var fullScreenImage: FullScreenImage?
    
    // 控制输入框展开
    @State private var isInputExpanded: Bool = false
    
    // 拖拽偏移量
    @State private var ballOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 背景层
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isInputExpanded = false
                            hideKeyboard()
                        }
                    }
                
                // 2. 列表层
                TimelineListView(date: selectedDate, onImageTap: { image in
                    fullScreenImage = FullScreenImage(image: image)
                })
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isInputExpanded = false
                        hideKeyboard()
                    }
                }
                
                // 3. 输入栏层 (Expanded Input Bar)
                if isInputExpanded {
                    VStack {
                        Spacer()
                        InputBarView(isExpanded: $isInputExpanded)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .background(
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { isInputExpanded = false; hideKeyboard() }
                            }
                    )
                    .zIndex(200)
                }
            }
            // 4. 悬浮球
            .overlay(alignment: .bottomTrailing) {
                if !isInputExpanded && Calendar.current.isDateInToday(selectedDate) {
                    FloatingBallView(
                        offset: $ballOffset,
                        onTap: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isInputExpanded = true
                            }
                        }
                    )
                    .padding(.bottom, 100)
                    .padding(.trailing, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🔥 左上角菜单按钮已删除
                
                ToolbarItem(placement: .principal) {
                    Button(action: { showCalendar = true }) {
                        HStack(spacing: 4) {
                            Text(dateString(selectedDate)).font(.headline).foregroundColor(.primary)
                            Image(systemName: "chevron.down.circle.fill").font(.caption).foregroundColor(.secondary)
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

// MARK: - 🔥 纯净版悬浮球 (FloatingBallView)
struct FloatingBallView: View {
    @Binding var offset: CGSize
    var onTap: () -> Void
    
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        Button(action: onTap) {
            // 纯粹的渐变球体
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue,               // 核心：深蓝 (Inner)
                            Color.cyan.opacity(0.8)   // 边缘：浅蓝/青色 (Outer)
                        ]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 30
                    )
                )
                .frame(width: 56, height: 56)
                // 增加一点高光边框，增加立体感
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                // 柔和的投影
                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 5)
        }
        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
                }
        )
    }
}

// MARK: - 列表视图 (TimelineListView - 保持不变)
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
                item.timestamp >= startOfDay && item.timestamp < endOfDay
            },
            sort: \.timestamp, order: .reverse
        )
    }
    
    var body: some View {
        if items.isEmpty {
            EmptyStateView().frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 80)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TimelineRowView(item: item, isLast: index == items.count - 1, onImageTap: onImageTap)
                            .contextMenu {
                                Button { itemToEdit = item } label: { Label("修改", systemImage: "pencil") }
                                Button(role: .destructive) { itemToDelete = item; showDeleteAlert = true } label: { Label("删除", systemImage: "trash") }
                            }
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled(false)
            .sheet(item: $itemToEdit) { item in EditTimelineView(item: item) }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) { if let item = itemToDelete { deleteItem(item) } }
            } message: { Text("删除后将无法恢复这条记录。") }
        }
    }
    
    private func deleteItem(_ item: TimelineItem) {
        withAnimation { modelContext.delete(item); try? modelContext.save() }
        itemToDelete = nil
    }
}

// MARK: - 单行组件 (TimelineRowView - 保持不变)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    private var isInspiration: Bool {
        item.type == "inspiration"
    }
    
    private var tags: [String] {
        guard isInspiration else { return [] }
        return item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }
    
    private var cleanContent: String {
        guard isInspiration else { return item.content }
        let pattern = "#[^\\s]+"
        let range = NSRange(location: 0, length: item.content.utf16.count)
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned = regex?.stringByReplacingMatches(in: item.content, options: [], range: range, withTemplate: "") ?? item.content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
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
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundColor(.secondary).padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(height: 160).frame(maxWidth: .infinity)
                            .cornerRadius(8).clipped()
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    
                    if !cleanContent.isEmpty {
                        Text(cleanContent).font(.body).foregroundColor(.primary).lineLimit(nil)
                    }
                    
                    if !tags.isEmpty || isInspiration {
                        if (!cleanContent.isEmpty || item.imageData != nil) { Divider().opacity(0.3) }
                        HStack(spacing: 8) {
                            if isInspiration {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill").font(.caption2).foregroundColor(.yellow)
                                    Text("灵感").font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2).padding(.horizontal, 6)
                                .background(Color.yellow.opacity(0.1)).cornerRadius(4)
                            }
                            ForEach(tags, id: \.self) { tag in
                                Text(tag).font(.caption2).foregroundColor(.blue)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Color.blue.opacity(0.05)).cornerRadius(4)
                            }
                        }
                        .padding(.top, (cleanContent.isEmpty && item.imageData == nil) ? 0 : 4)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
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

// MARK: - 输入栏 (展开后逻辑 - 保持不变)
struct InputBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isExpanded: Bool
    
    @State private var inputText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @FocusState private var isInputFocused: Bool
    @State private var isInspirationMode: Bool = false
    
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var inspirationItems: [TimelineItem]
    
    private var recentTags: [String] {
        var counts: [String: Int] = [:]
        for item in inspirationItems {
            let words = item.content.split(separator: " ")
            for word in words {
                let str = String(word)
                if str.hasPrefix("#") && str.count > 1 { counts[str, default: 0] += 1 }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签联想栏
            if isInputFocused && isInspirationMode && !recentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentTags, id: \.self) { tag in
                            Button(action: { inputText += " \(tag) " }) {
                                Text(tag).font(.caption).foregroundColor(.blue)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground)).cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 主输入区域
            VStack(alignment: .leading, spacing: 0) {
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 80, height: 80).cornerRadius(10).clipped()
                            .overlay(
                                Button(action: { withAnimation { selectedImage = nil } }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 5, y: -5), alignment: .topTrailing
                            )
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                }
                
                HStack(alignment: .bottom, spacing: 12) {
                    HStack(spacing: 8) {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                            withAnimation { isInspirationMode.toggle() }
                        }) {
                            Image(systemName: isInspirationMode ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 24))
                                .foregroundColor(isInspirationMode ? .yellow : .secondary)
                                .frame(width: 32, height: 32)
                        }
                        
                        Button(action: { sourceType = .photoLibrary; showImagePicker = true }) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(selectedImage == nil ? .secondary : .blue)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.bottom, 6)
                    
                    TextField(isInspirationMode ? "捕捉灵感..." : "记录此刻...", text: $inputText, axis: .vertical)
                        .focused($isInputFocused)
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemFill))
                        .cornerRadius(18)
                        .lineLimit(1...5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isInspirationMode ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    // 按钮组
                    if !inputText.isEmpty || selectedImage != nil {
                        Button(action: saveItem) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(isInspirationMode ? .yellow : .blue)
                                .shadow(color: (isInspirationMode ? Color.yellow : Color.blue).opacity(0.3), radius: 4)
                        }
                        .padding(.bottom, 2)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded = false
                                isInputFocused = false
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(25, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    private func saveItem() {
        guard !inputText.isEmpty || selectedImage != nil else { return }
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let icon = imageData != nil ? "photo" : "text.bubble"
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
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            inputText = ""
            selectedImage = nil
            isInputFocused = false
            isInspirationMode = false
            isExpanded = false
        }
    }
}

// 辅助 View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock").font(.system(size: 80)).foregroundColor(.gray.opacity(0.3))
            Text("这一天没有记录").font(.title2).foregroundColor(.gray)
        }
        .offset(y: -40)
    }
}
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
