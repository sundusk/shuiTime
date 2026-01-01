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
    
    // 日期与状态管理
    @State private var selectedDate: Date = Date()
    @State private var showCalendar: Bool = false
    @State private var fullScreenImage: FullScreenImage?
    @State private var isInputExpanded: Bool = false
    @State private var ballOffset: CGSize = .zero
    
    // 🔥 瞬影功能状态
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var tempImage: UIImage? // 暂存拍摄/选择的图片
    @State private var showReplaceSheet = false // 替换弹窗
    @State private var isFabExpanded = false // 悬浮球菜单展开状态
    
    // 获取今日数据用于计算额度
    @Query private var allItems: [TimelineItem]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 背景层
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                    .onTapGesture { resetStates() }
                
                // 2. 列表层
                TimelineListView(date: selectedDate, onImageTap: { image in
                    fullScreenImage = FullScreenImage(image: image)
                })
                .onTapGesture { resetStates() }
                
                // 3. 普通输入栏 (底部弹出)
                if isInputExpanded {
                    VStack {
                        Spacer()
                        InputBarView(isExpanded: $isInputExpanded)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .background(
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture { resetStates() }
                    )
                    .zIndex(200)
                }
                
                // 4. 替换确认弹窗 (当瞬影满3张时)
                if showReplaceSheet {
                    ReplaceMomentSheet(
                        items: todayMoments,
                        onReplace: { oldItem in
                            replaceMoment(oldItem: oldItem)
                        },
                        onCancel: {
                            tempImage = nil
                            showReplaceSheet = false
                        }
                    )
                    .zIndex(300)
                }
            }
            // 5. 增强版悬浮球 (带长按菜单 + 呼吸效果 + 🔥绿色新皮肤)
            .overlay(alignment: .bottomTrailing) {
                if !isInputExpanded && Calendar.current.isDateInToday(selectedDate) && !showReplaceSheet {
                    FloatingBallMenu(
                        offset: $ballOffset,
                        isExpanded: $isFabExpanded,
                        onTap: {
                            // 短按：打开普通文字输入
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isInputExpanded = true
                            }
                        },
                        onCameraTap: { showCamera = true },
                        onPhotoTap: { showPhotoLibrary = true }
                    )
                    .padding(.bottom, 100)
                    .padding(.trailing, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            // 相机
            .sheet(isPresented: $showCamera, onDismiss: handleImageSelected) {
                ImagePicker(selectedImage: $tempImage, sourceType: .camera)
            }
            // 相册
            .sheet(isPresented: $showPhotoLibrary, onDismiss: handleImageSelected) {
                ImagePicker(selectedImage: $tempImage, sourceType: .photoLibrary)
            }
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(image: wrapper.image)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                checkAndUpdateDate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                checkAndUpdateDate()
            }
        }
    }
    
    // MARK: - 逻辑处理
    
    private func resetStates() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isInputExpanded = false
            isFabExpanded = false
            hideKeyboard()
        }
    }
    
    private func checkAndUpdateDate() {
        if !Calendar.current.isDateInToday(selectedDate) {
            withAnimation { selectedDate = Date() }
        }
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        if Calendar.current.isDateInToday(date) { return "今日" }
        return formatter.string(from: date)
    }
    
    // --- 瞬影核心逻辑 ---
    
    // 获取今日已有的瞬影
    private var todayMoments: [TimelineItem] {
        allItems.filter { item in
            Calendar.current.isDateInToday(item.timestamp) && item.type == "moment"
        }
    }
    
    private func handleImageSelected() {
        guard tempImage != nil else { return }
        
        // 检查额度
        if todayMoments.count >= 3 {
            withAnimation { showReplaceSheet = true }
        } else {
            saveNewMoment()
        }
    }
    
    private func saveNewMoment() {
        guard let image = tempImage else { return }
        let newItem = TimelineItem(
            content: "", // 瞬影不需要默认文字
            iconName: "camera.aperture",
            timestamp: Date(),
            imageData: image.jpegData(compressionQuality: 0.7),
            type: "moment" // 🔥 关键类型标识
        )
        withAnimation {
            modelContext.insert(newItem)
        }
        tempImage = nil
    }
    
    private func replaceMoment(oldItem: TimelineItem) {
        // 1. 删除旧的
        withAnimation { modelContext.delete(oldItem) }
        // 2. 保存新的
        saveNewMoment()
        // 3. 关闭弹窗
        showReplaceSheet = false
    }
}

// MARK: - 增强版悬浮球 (逻辑重构 + 🔥绿色新皮肤)
struct FloatingBallMenu: View {
    @Binding var offset: CGSize
    @Binding var isExpanded: Bool
    
    // 回调
    var onTap: () -> Void
    var onCameraTap: () -> Void
    var onPhotoTap: () -> Void
    
    // 内部状态
    @State private var dragStartOffset: CGSize = .zero // 拖拽开始时的小球位置
    @State private var activeSelection: Int? = nil // 0: None, 1: Camera, 2: Photo
    @State private var isBreathing = false // 呼吸动画状态
    
    // 布局常量 (相对于球心的偏移)
    private let cameraOffset = CGSize(width: -60, height: -70)
    private let photoOffset  = CGSize(width: 10, height: -90)
    private let triggerDistance: CGFloat = 40.0 // 吸附/触发距离
    
    var body: some View {
        ZStack {
            // 1. 径向菜单项 (展开时显示)
            if isExpanded {
                // 相机气泡 (保持蓝色，代表生成蓝色的瞬影)
                MenuBubble(icon: "camera.fill", color: .blue, label: "拍摄", isHighlighted: activeSelection == 1)
                    .offset(cameraOffset)
                    .transition(.scale.combined(with: .opacity))
                
                // 相册气泡 (保持绿色，代表资源库)
                MenuBubble(icon: "photo.on.rectangle", color: .green, label: "相册", isHighlighted: activeSelection == 2)
                    .offset(photoOffset)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // 2. 主球体
            ZStack {
                // 🔥 新增：呼吸光晕层 (改为绿色)
                if !isExpanded {
                    Circle()
                        .fill(Color.green) // 🔥 绿色呼吸
                        .frame(width: 56, height: 56)
                        .scaleEffect(isBreathing ? 1.3 : 1.0) // 缩放范围 1.0 -> 1.3
                        .opacity(isBreathing ? 0.0 : 0.3)     // 透明度范围 0.3 -> 0.0 (消散)
                }
                
                // 球体本体 (纯视觉组件，无 Button 干扰，无 "+" 号)
                Circle()
                    .fill(
                        RadialGradient(
                            // 🔥 核心修改：改为绿色系渐变
                            gradient: Gradient(colors: [
                                Color.green,              // 核心：鲜绿
                                Color.mint.opacity(0.8)   // 边缘：薄荷绿 (带一点青色，过渡自然)
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 30
                        )
                    )
                    .frame(width: 56, height: 56)
                    // 高光立体边框
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
                    // 柔和的投影 (改为绿色阴影)
                    .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 5) // 🔥 绿色阴影
            }
            .scaleEffect(isExpanded ? 0.9 : 1.0) // 展开时轻微缩小，增加锁定感
        }
        .offset(offset)
        // 🔥 核心手势逻辑 🔥
        .gesture(
            DragGesture(minimumDistance: 0) // minimumDistance: 0 确保按下即开始追踪
                .onChanged { value in
                    // [状态 A] 菜单已展开：进入“选择模式”
                    if isExpanded {
                        let currentDrag = value.translation
                        
                        // 计算到 Camera 的距离
                        let distToCamera = hypot(currentDrag.width - cameraOffset.width, currentDrag.height - cameraOffset.height)
                        // 计算到 Photo 的距离
                        let distToPhoto = hypot(currentDrag.width - photoOffset.width, currentDrag.height - photoOffset.height)
                        
                        // 判定高亮
                        if distToCamera < triggerDistance {
                            if activeSelection != 1 {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring()) { activeSelection = 1 }
                            }
                        } else if distToPhoto < triggerDistance {
                            if activeSelection != 2 {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring()) { activeSelection = 2 }
                            }
                        } else {
                            if activeSelection != nil {
                                withAnimation(.spring()) { activeSelection = nil }
                            }
                        }
                    }
                    // [状态 B] 菜单未展开：进入“移动模式”
                    else {
                        // 只有当位移足够大时，才更新位置 (防止点击时的抖动)
                        offset = CGSize(
                            width: dragStartOffset.width + value.translation.width,
                            height: dragStartOffset.height + value.translation.height
                        )
                    }
                }
                .onEnded { value in
                    // 1. 如果是展开状态：触发选择
                    if isExpanded {
                        if activeSelection == 1 {
                            onCameraTap()
                        } else if activeSelection == 2 {
                            onPhotoTap()
                        }
                        // 无论如何，松手后收起菜单
                        withAnimation(.spring()) {
                            isExpanded = false
                            activeSelection = nil
                        }
                    }
                    // 2. 如果是未展开状态
                    else {
                        // 判断是“点击”还是“拖拽”
                        // 如果位移非常小，视为点击
                        if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                            onTap()
                        }
                        // 否则视为拖拽结束，保存当前位置
                        dragStartOffset = offset
                    }
                }
        )
        // 长按手势：独立于拖拽，专门用于触发“展开”
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    // 触发展开
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isExpanded = true
                        // 展开时，记录当前的偏移量，防止位置跳变
                        dragStartOffset = offset
                    }
                }
        )
        .onAppear {
            dragStartOffset = offset
            // 🔥 启动呼吸动画：无限循环，自动往复
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isBreathing = true
            }
        }
    }
    
    // 子菜单气泡组件 (增加高亮状态)
    struct MenuBubble: View {
        let icon: String
        let color: Color
        let label: String
        let isHighlighted: Bool // 高亮状态
        
        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: isHighlighted ? 60 : 48, height: isHighlighted ? 60 : 48) // 高亮放大
                    .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                            .font(isHighlighted ? .title2 : .headline)
                    )
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .opacity(isHighlighted ? 1.0 : 0.8)
            }
            .animation(.spring(), value: isHighlighted) // 增加弹性动画
        }
    }
}

// MARK: - 替换确认弹窗 (Sheet)
struct ReplaceMomentSheet: View {
    let items: [TimelineItem]
    let onReplace: (TimelineItem) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("今日瞬影已满 (3/3)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("选择一张旧的瞬间来替换")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items) { item in
                            if let data = item.imageData, let uiImage = UIImage(data: data) {
                                Button(action: { onReplace(item) }) {
                                    ZStack {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 110, height: 160)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .shadow(radius: 5)
                                        
                                        // 替换图标
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.4))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button("取消") { onCancel() }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding()
        }
    }
}

// MARK: - 列表视图 (TimelineListView - 仅瞬影不可修改)
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
                                // 🔥 核心修改：只有“非瞬影”类型才允许修改
                                if item.type != "moment" {
                                    Button {
                                        itemToEdit = item
                                    } label: {
                                        Label("修改", systemImage: "pencil")
                                    }
                                }
                                // 删除功能对所有类型开放
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showDeleteAlert = true
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
            .sheet(item: $itemToEdit) { item in EditTimelineView(item: item) }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete { deleteItem(item) }
                }
            } message: {
                if let item = itemToDelete, item.type == "moment" {
                    Text("删除这张瞬影后，将自动恢复今日的一个拍摄额度。")
                } else {
                    Text("删除后将无法恢复这条记录。")
                }
            }
        }
    }
    
    private func deleteItem(_ item: TimelineItem) {
        withAnimation { modelContext.delete(item); try? modelContext.save() }
        itemToDelete = nil
    }
}

// MARK: - 单行组件 (TimelineRowView - 无呼吸灯，仅精致边框 - 保持蓝色)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((UIImage) -> Void)?
    
    // 判断类型
    private var isMoment: Bool { item.type == "moment" }
    private var isInspiration: Bool { item.type == "inspiration" }
    
    private var tags: [String] {
        guard isInspiration else { return [] }
        return item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }
    
    private var cleanContent: String {
        if isMoment { return "" }
        guard isInspiration else { return item.content }
        let pattern = "#[^\\s]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned = regex?.stringByReplacingMatches(in: item.content, options: [], range: NSRange(location: 0, length: item.content.utf16.count), withTemplate: "") ?? item.content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 1. 左侧时间轴线条和节点
            VStack(spacing: 0) {
                // 上半截线
                Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)
                
                // 节点
                if isMoment {
                    // 左侧节点：纯静态，与右侧呼应
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.2)).frame(width: 18, height: 18)
                        Circle().stroke(Color.blue, lineWidth: 1.5).frame(width: 18, height: 18)
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                    }
                } else {
                    Circle()
                        .fill(isInspiration ? Color.yellow : Color.blue)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                }
                
                // 下半截线
                if !isLast {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                } else { Spacer() }
            }
            .frame(width: 20)
            
            // 2. 右侧内容卡片
            VStack(alignment: .leading, spacing: 6) {
                // 时间戳
                HStack {
                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundColor(.secondary)
                    
                    if isMoment {
                        Text("瞬影")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.blue)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1)).cornerRadius(4)
                    }
                }
                .padding(.top, 10)
                
                // 内容容器
                VStack(alignment: .leading, spacing: 8) {
                    
                    // (A) 🔥 瞬影样式：只有静态边框
                    if isMoment, let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            // 裁剪图片圆角
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            // 前景边框层 (静态)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        Color.blue.opacity(0.8), // 固定透明度
                                        lineWidth: 2             // 固定线宽
                                    )
                            )
                            // 点击交互
                            .onTapGesture { onImageTap?(uiImage) }
                            // 底部小图标
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.aperture")
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .shadow(radius: 2)
                            }
                    }
                    // (B) 普通样式 (无变化)
                    else {
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
                        }
                    }
                }
                .padding(isMoment ? 0 : 12) // 瞬影卡片无内边距
                // 瞬影卡片背景透明；普通卡片保持灰色背景
                .background(isMoment ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                // 瞬影去掉默认阴影；普通卡片保留阴影
                .shadow(color: Color.black.opacity(isMoment ? 0 : 0.05), radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
                .padding(.bottom, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 输入栏 (InputBarView - 保持不变)
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
            // 标签栏
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
            }
            
            // 输入区
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
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isInspirationMode ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1))
                    
                    if !inputText.isEmpty || selectedImage != nil {
                        Button(action: saveItem) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(isInspirationMode ? .yellow : .blue)
                        }
                        .padding(.bottom, 2)
                    } else {
                        Button(action: { withAnimation { isExpanded = false; isInputFocused = false } }) {
                            Image(systemName: "chevron.down").font(.system(size: 20, weight: .bold)).foregroundColor(.secondary)
                                .frame(width: 32, height: 32).background(Color.secondary.opacity(0.1)).clipShape(Circle())
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isInputFocused = true }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    private func saveItem() {
        guard !inputText.isEmpty || selectedImage != nil else { return }
        let type = isInspirationMode ? "inspiration" : "timeline"
        let icon = selectedImage != nil ? "photo" : "text.bubble"
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        
        let newItem = TimelineItem(content: inputText, iconName: icon, timestamp: Date(), imageData: imageData, type: type)
        modelContext.insert(newItem)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            inputText = ""; selectedImage = nil; isInputFocused = false; isInspirationMode = false; isExpanded = false
        }
    }
}

// 辅助组件
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
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
