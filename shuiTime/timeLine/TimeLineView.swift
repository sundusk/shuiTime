//
//  TimeLineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import AVKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

// MARK: - 主视图
struct TimeLineView: View {
    @Environment(\.modelContext) private var modelContext

    // 日期与状态管理
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()  // 🔥 日历当前显示的月份
    @State private var showCalendar: Bool = false
    @State private var fullScreenImage: FullScreenImage?
    @State private var isInputExpanded: Bool = false
    @State private var ballOffset: CGSize = .zero

    // 🔥 瞬影功能状态
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var tempImage: UIImage?  // 暂存拍摄/选择的图片
    @State private var showReplaceSheet = false  // 替换弹窗
    @State private var isFabExpanded = false  // 悬浮球菜单展开状态

    // 🔥 Live Photo 支持
    @State private var selectedAsset: LivePhotoAsset?  // 选中的资源
    @State private var tempLivePhotoData: (videoData: Data?, isLive: Bool)?  // 临时存储用于替换流程

    // 🔥 备份功能状态
    @State private var showBackupSheet = false
    @State private var showFilePicker = false
    @State private var showOverwriteFilePicker = false  // 🔥 覆盖导入选择器
    @State private var isExporting = false  // 导出进度状态
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showOverwriteConfirm = false  // 🔥 覆盖确认弹窗
    @State private var pendingOverwriteURL: URL? = nil  // 🔥 待覆盖的文件URL
    @State private var showExportPicker = false  // 🔥 导出选择器开关
    @State private var exportURL: URL? = nil  // 🔥 待导出的文件URL

    // 获取今日数据用于计算额度
    @Query private var allItems: [TimelineItem]

    var body: some View {
        NavigationStack {
            // 🔥 1. 新增：GeometryReader 用于获取屏幕尺寸和安全区域
            GeometryReader { geo in
                ZStack {
                    // 1. 背景层 - 使用弥散渐变背景
                    MeshGradientBackground()
                        .onTapGesture { resetStates() }

                    // 2. 列表层
                    TimelineListView(
                        date: selectedDate,
                        onImageTap: { imageWrapper in
                            fullScreenImage = imageWrapper
                        }
                    )
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

                    // 🔥 5. 导出进度加载动画
                    if isExporting {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()

                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)

                                Text("正在导出备份...")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("\(allItems.count) 条记录")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(30)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        .zIndex(400)
                        .transition(.opacity)
                    }
                }
                // 5. 增强版悬浮球 (带长按菜单 + 呼吸效果 + 🔥绿色新皮肤)
                .overlay(alignment: .bottomTrailing) {
                    if !isInputExpanded && Calendar.current.isDateInToday(selectedDate)
                        && !showReplaceSheet
                    {
                        FloatingBallMenu(
                            offset: $ballOffset,
                            isExpanded: $isFabExpanded,
                            // 🔥 2. 核心修改：传入容器尺寸和安全区域信息
                            containerSize: geo.size,
                            safeAreaInsets: geo.safeAreaInsets,

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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🔥 左上角备份按钮
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showBackupSheet = true }) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Button(action: { showCalendar = true }) {
                        HStack(spacing: 4) {
                            Text(dateString(selectedDate)).font(.headline).foregroundColor(.primary)
                            Image(systemName: "chevron.down.circle.fill").font(.caption)
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
                // 🔥 使用自定义日历组件，支持蓝点标记
                TimelineCalendarSheet(
                    currentMonth: $currentMonth,
                    selectedDate: $selectedDate,
                    recordedDates: getRecordedDates(),
                    onDismiss: { showCalendar = false }
                )
                .presentationDetents([.medium, .large])
            }
            // 相机
            .sheet(isPresented: $showCamera, onDismiss: handleImageSelected) {
                ImagePicker(selectedImage: $tempImage, sourceType: .camera)
            }
            // 相册 - 使用 PHPickerView 支持 Live Photo
            .sheet(isPresented: $showPhotoLibrary) {
                PHPickerView(selectedAsset: $selectedAsset) {
                    // 选择完成，selectedAsset 有值时会自动触发 fullScreenCover
                }
            }
            // 🔥 Live Photo 预览
            .fullScreenCover(item: $selectedAsset) { asset in
                LivePhotoPreviewSheet(
                    asset: asset,
                    onConfirm: { image, videoData, isLive in
                        handleLivePhotoConfirm(image: image, videoData: videoData, isLive: isLive)
                    },
                    onCancel: {
                        selectedAsset = nil
                    }
                )
            }
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(imageEntity: wrapper)
            }
            // 🔥 备份选项 Sheet
            .sheet(isPresented: $showBackupSheet) {
                BackupOptionsSheet(
                    onExport: { handleExportBackup() },
                    onImport: {
                        // 先关闭当前 sheet，延迟后再打开文件选择器
                        showBackupSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showFilePicker = true
                        }
                    },
                    onImportOverwrite: {
                        showBackupSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showOverwriteFilePicker = true
                        }
                    },
                    onCleanDuplicates: { handleCleanDuplicates() },
                    onDismiss: { showBackupSheet = false }
                )
                .presentationDetents([.height(480)])
            }
            // 🔥 文件选择器（合并导入）
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handleImportBackup(from: url)
                }
            }
            // 🔥 文件选择器（导出备份）
            .sheet(isPresented: $showExportPicker) {
                if let url = exportURL {
                    DocumentExporter(itemURL: url) { success in
                        if success {
                            alertTitle = "导出成功"
                            alertMessage = "备份文件已成功保存到指定位置"
                        } else {
                            alertTitle = "导出取消"
                            alertMessage = "未保存备份文件"
                        }
                        showAlert = true
                        exportURL = nil
                    }
                }
            }
            // 🔥 文件选择器（覆盖导入）
            .sheet(isPresented: $showOverwriteFilePicker) {
                DocumentPicker { url in
                    pendingOverwriteURL = url
                    showOverwriteConfirm = true
                }
            }
            // 🔥 覆盖确认弹窗
            .alert("确认覆盖?", isPresented: $showOverwriteConfirm) {
                Button("取消", role: .cancel) {
                    pendingOverwriteURL = nil
                }
                Button("确认覆盖", role: .destructive) {
                    if let url = pendingOverwriteURL {
                        handleImportOverwrite(from: url)
                    }
                    pendingOverwriteURL = nil
                }
            } message: {
                Text("此操作将删除所有现有数据，并用备份文件中的数据替换。\n\n此操作不可撤销！")
            }
            // 🔥 提示框
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification)
            ) { _ in
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
    
    // 🔥 获取有记录的日期集合，用于日历蓝点标记
    private func getRecordedDates() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = allItems.map { formatter.string(from: $0.timestamp) }
        return Set(dates)
    }

    // --- 瞬影核心逻辑 ---

    // 获取今日已有的瞬影
    private var todayMoments: [TimelineItem] {
        allItems.filter { item in
            Calendar.current.isDateInToday(item.timestamp) && item.type == "moment"
        }
    }

    // 🔥 核心修复：使用直接查询获取准确数量，避免视图刷新延迟导致限额失效
    private func getTodayMomentsCount() -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        // 构造结束时间 (第二天0点)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }

        let descriptor = FetchDescriptor<TimelineItem>(
            predicate: #Predicate { item in
                item.timestamp >= start && item.timestamp < end && item.type == "moment"
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? todayMoments.count
    }

    private func handleImageSelected() {
        guard tempImage != nil else { return }

        // 检查额度
        // 检查额度 (修正版)
        if getTodayMomentsCount() >= 3 {
            withAnimation { showReplaceSheet = true }
        } else {
            saveNewMoment()
        }
    }

    private func saveNewMoment() {
        guard let image = tempImage else { return }

        // 获取 Live Photo 数据（如果有）
        let liveData = tempLivePhotoData

        let newItem = TimelineItem(
            content: "",  // 瞬影不需要默认文字
            iconName: "camera.aperture",
            timestamp: Date(),
            imageData: image.jpegData(compressionQuality: 0.7),
            type: "moment",  // 🔥 关键类型标识
            isLivePhoto: liveData?.isLive ?? false,
            livePhotoVideoData: liveData?.videoData
        )
        withAnimation {
            modelContext.insert(newItem)
        }
        tempImage = nil
        tempLivePhotoData = nil
    }

    private func replaceMoment(oldItem: TimelineItem) {
        // 1. 删除旧的
        withAnimation { modelContext.delete(oldItem) }
        // 2. 保存新的
        saveNewMoment()
        // 3. 关闭弹窗
        showReplaceSheet = false
    }

    // MARK: - Live Photo 处理

    /// 处理 Live Photo 预览确认
    private func handleLivePhotoConfirm(image: UIImage, videoData: Data?, isLive: Bool) {
        selectedAsset = nil

        // 存储图片和 Live 数据
        tempImage = image
        tempLivePhotoData = (videoData, isLive)

        // 检查今天是否已有3张瞬影 (修正版)
        if getTodayMomentsCount() >= 3 {
            // 需要替换
            withAnimation { showReplaceSheet = true }
        } else {
            // 直接保存
            saveNewMoment()
        }
    }

    // MARK: - 备份恢复逻辑

    private func handleExportBackup() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        showBackupSheet = false
        withAnimation { isExporting = true }

        // 导出所有数据
        if let fileURL = BackupManager.shared.exportData(items: allItems) {
            withAnimation { isExporting = false }
            
            // 记录导出的本地 URL 并触发选择器
            self.exportURL = fileURL
            self.showExportPicker = true

            // 成功震动反馈
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            withAnimation { isExporting = false }
            alertTitle = "备份失败"
            alertMessage = "导出数据时发生错误，请稍后重试"
            showAlert = true

            // 失败震动反馈
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }

        showBackupSheet = false
    }

    private func handleImportBackup(from url: URL) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 导入数据
        if let count = BackupManager.shared.importData(from: url, context: modelContext) {
            alertTitle = "恢复成功"
            alertMessage = "成功导入 \(count) 条记录\n\n数据已添加到时间线中"
            showAlert = true

            // 成功震动反馈
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            alertTitle = "恢复失败"
            alertMessage = "导入数据时发生错误\n请确认备份文件格式正确或压缩文件未损坏"
            showAlert = true

            // 失败震动反馈
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }

        showFilePicker = false
    }
    
    // 🔥 清理重复数据
    private func handleCleanDuplicates() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        showBackupSheet = false
        
        let deletedCount = BackupManager.shared.removeDuplicates(context: modelContext)
        
        if deletedCount > 0 {
            alertTitle = "清理完成"
            alertMessage = "已删除 \(deletedCount) 条重复记录"
            showAlert = true
            
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            alertTitle = "无重复数据"
            alertMessage = "当前没有发现重复的记录"
            showAlert = true
            
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.warning)
        }
    }
    
    // 🔥 覆盖导入
    private func handleImportOverwrite(from url: URL) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        showBackupSheet = false
        showOverwriteFilePicker = false
        
        if let count = BackupManager.shared.importDataWithOverwrite(from: url, context: modelContext) {
            alertTitle = "覆盖完成"
            alertMessage = "已删除原有数据，成功导入 \(count) 条记录"
            showAlert = true
            
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            alertTitle = "导入失败"
            alertMessage = "覆盖导入时发生错误\n请确认备份文件格式正确或压缩文件未损坏"
            showAlert = true
            
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
}

// MARK: - 增强版悬浮球 (逻辑重构 + 🔥绿色新皮肤)
struct FloatingBallMenu: View {
    @Binding var offset: CGSize
    @Binding var isExpanded: Bool

    // 接收尺寸参数
    var containerSize: CGSize
    var safeAreaInsets: EdgeInsets

    var onTap: () -> Void
    var onCameraTap: () -> Void
    var onPhotoTap: () -> Void

    @State private var dragStartOffset: CGSize = .zero
    @State private var activeSelection: Int? = nil
    @State private var isBreathing = false
    @State private var isFloating = false  // 🌊 上下浮动动画
    @State private var isAlive = false      // 💓 微微呼吸缩放

    // 🔥 1. 计算属性：判断当前球是否在屏幕右侧
    private var isOnRightSide: Bool {
        // 初始位置在右下角 (trailing: 20)，球心大概在 width - 48
        // 加上当前的偏移量 offset.width
        let initialCenterX = containerSize.width - 20 - 28  // 20是padding, 28是半径
        let currentCenterX = initialCenterX + offset.width
        return currentCenterX > containerSize.width / 2
    }

    // 🔥 2. 动态偏移量：根据位置自动翻转 X 轴
    private var cameraOffset: CGSize {
        // 如果在右边，往左弹(-60)；如果在左边，往右弹(60)
        CGSize(width: isOnRightSide ? -65 : 65, height: -65)
    }

    private var photoOffset: CGSize {
        // 如果在右边，往左弹(-15)；如果在左边，往右弹(15)
        // 稍微错开高度，形成扇形
        CGSize(width: isOnRightSide ? -15 : 15, height: -100)
    }

    private let triggerDistance: CGFloat = 45.0  // 稍微增大触发区域

    // 🔥 "瞬影"标签的偏移位置
    private var labelOffset: CGSize {
        // 标签位置在相册按钮的左上方，避免被图标遮挡
        CGSize(width: isOnRightSide ? -55 : 55, height: -130)
    }

    var body: some View {
        ZStack {
            // 菜单项
            if isExpanded {
                // 🔥 "瞬影"功能提示标签
                Text("瞬影")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    .rotationEffect(.degrees(isOnRightSide ? -35 : 35))  // 🔥 与按钮连线平行的角度
                    .offset(labelOffset)
                    .transition(.scale.combined(with: .opacity))

                // 相机
                MenuBubble(
                    icon: "camera.fill", color: .blue, label: "拍摄",
                    isHighlighted: activeSelection == 1
                )
                .offset(cameraOffset)
                .transition(.scale.combined(with: .opacity))

                // 相册
                MenuBubble(
                    icon: "photo.on.rectangle", color: .green, label: "相册",
                    isHighlighted: activeSelection == 2
                )
                .offset(photoOffset)
                .transition(.scale.combined(with: .opacity))
            }

            // 主球体 - 使用 xiaoshui.png 图片
            ZStack {
                if !isExpanded {
                    Image("xiaoshui")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .scaleEffect(isBreathing ? 1.3 : 1.0)
                        .opacity(isBreathing ? 0.0 : 0.3)
                }

                Image("xiaoshui")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .scaleEffect(isAlive ? 1.05 : 1.0)  // 💓 微微呼吸
                    .offset(y: isFloating ? -3 : 3)     // 🌊 上下浮动
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 5)
            }
            .scaleEffect(isExpanded ? 0.9 : 1.0)
        }
        .offset(offset)
        // 手势逻辑
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isExpanded {
                        // [选择模式] 使用动态的 offset 进行距离判断
                        let currentDrag = value.translation

                        // 获取当前的动态位置
                        let camOff = self.cameraOffset
                        let phoOff = self.photoOffset

                        let distToCamera = hypot(
                            currentDrag.width - camOff.width, currentDrag.height - camOff.height)
                        let distToPhoto = hypot(
                            currentDrag.width - phoOff.width, currentDrag.height - phoOff.height)

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
                    } else {
                        // [拖拽模式] 保持之前的边界限制逻辑
                        let proposedHeight = dragStartOffset.height + value.translation.height

                        let bottomPadding: CGFloat = 100
                        let ballHeight: CGFloat = 56
                        let navBarHeight: CGFloat = 44
                        let tabBarHeight: CGFloat = 60

                        let initialTopY = containerSize.height - bottomPadding - ballHeight
                        let targetTopY = safeAreaInsets.top + navBarHeight
                        let topLimit = targetTopY - initialTopY

                        let initialBottomY = containerSize.height - bottomPadding
                        let targetBottomY =
                            containerSize.height - safeAreaInsets.bottom - tabBarHeight
                        let bottomLimit = max(0, targetBottomY - initialBottomY)

                        let constrainedHeight = min(max(proposedHeight, topLimit), bottomLimit)

                        offset = CGSize(
                            width: dragStartOffset.width + value.translation.width,
                            height: constrainedHeight
                        )
                    }
                }
                .onEnded { value in
                    if isExpanded {
                        if activeSelection == 1 {
                            onCameraTap()
                        } else if activeSelection == 2 {
                            onPhotoTap()
                        }
                        withAnimation(.spring()) {
                            isExpanded = false
                            activeSelection = nil
                        }
                    } else {
                        if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                            onTap()
                        }
                        dragStartOffset = offset
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isExpanded = true
                        dragStartOffset = offset
                    }
                }
        )
        .onAppear {
            dragStartOffset = offset
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isBreathing = true
            }
            // 🌊 启动浮动动画（上下轻柔飘动）
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            // 💓 启动呼吸动画（微微缩放）
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAlive = true
            }
        }
    }

    struct MenuBubble: View {
        let icon: String
        let color: Color
        let label: String
        let isHighlighted: Bool

        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: isHighlighted ? 60 : 48, height: isHighlighted ? 60 : 48)
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
            .animation(.spring(), value: isHighlighted)
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
    var onImageTap: (FullScreenImage) -> Void

    init(date: Date, onImageTap: @escaping (FullScreenImage) -> Void) {
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
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineRowView(
                        item: item, isLast: index == items.count - 1, onImageTap: onImageTap
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)  // 🔥 清除行背景，显示弥散渐变
                    .swipeActions(edge: .trailing) {
                        // 删除功能
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteAlert = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        // 修改功能 (非瞬影)
                        if item.type != "moment" {
                            Button {
                                itemToEdit = item
                            } label: {
                                Label("修改", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }

                // 底部占位
                Color.clear.frame(height: 100)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)  // 🔥 清除底部占位行背景
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)  // 适配 iOS 16+ 背景
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
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
    }
}

// MARK: - 单行组件 (TimelineRowView - 修复删除崩溃版)
struct TimelineRowView: View {
    let item: TimelineItem
    let isLast: Bool
    var onImageTap: ((FullScreenImage) -> Void)?

    // 🔥 修复核心：缓存所有需要访问的属性，防止删除动画时访问已销毁的数据库对象
    @State private var cachedImage: UIImage?
    @State private var cachedTimestamp: Date = Date()
    @State private var cachedType: String = ""
    @State private var cachedContent: String = ""
    @State private var cachedIsLivePhoto: Bool = false
    @State private var cachedVideoData: Data?
    @State private var isDataLoaded: Bool = false

    // 实况播放相关
    @State private var player: AVPlayer?
    @State private var isPlayingLivePhoto = false
    @State private var gradientRotation: Double = 0  // 流光动画旋转角度

    // 🔥 使用缓存的类型判断
    private var isMoment: Bool { cachedType == "moment" }
    private var isInspiration: Bool { cachedType == "inspiration" }

    private var tags: [String] {
        guard isInspiration else { return [] }
        return cachedContent.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }

    private var cleanContent: String {
        if isMoment { return "" }
        guard isInspiration else { return cachedContent }
        let pattern = "#[^\\s]+"
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned =
            regex?.stringByReplacingMatches(
                in: cachedContent, options: [],
                range: NSRange(location: 0, length: cachedContent.utf16.count), withTemplate: "")
            ?? cachedContent
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        // 🔥 安全检查：如果对象已删除且数据未加载，直接返回空视图，避免崩溃
        if item.isDeleted && !isDataLoaded {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(alignment: .top, spacing: 12) {
                // 1. 左侧时间轴线条和节点
                VStack(spacing: 0) {
                    // 上半截线
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2, height: 15)

                    // 节点
                    if isMoment {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.2)).frame(width: 18, height: 18)
                            Circle().stroke(Color.blue, lineWidth: 1.5).frame(width: 18, height: 18)
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                        }
                    } else {
                        Circle()
                            .fill(isInspiration ? Color.yellow : Color.blue)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(
                                    Color(uiColor: .systemGroupedBackground), lineWidth: 2))
                    }

                    // 下半截线
                    if !isLast {
                        Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 2).frame(
                            maxHeight: .infinity)
                    } else {
                        Spacer()
                    }
                }
                .frame(width: 20)

                // 2. 右侧内容卡片
                VStack(alignment: .leading, spacing: 6) {
                    // 时间戳
                    HStack {
                        Text(cachedTimestamp.formatted(date: .omitted, time: .shortened))
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

                        // (A) 🔥 瞬影样式：使用 GeometryReader 确保边框尺寸固定一致
                        if isMoment, let uiImage = cachedImage {
                            GeometryReader { geo in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                            .frame(height: 220)  // 🔥 固定高度
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            // 实况播放覆盖层 (显示在图片之上，图标之下)
                            .overlay {
                                if isPlayingLivePhoto, let player = player {
                                    VideoPlayer(player: player)
                                        .disabled(true)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        isPlayingLivePhoto
                                            ?  // 播放时：流光渐变边框
                                            AnyShapeStyle(
                                                AngularGradient(
                                                    gradient: Gradient(colors: [
                                                        .cyan, .blue, .purple, .cyan,
                                                    ]),
                                                    center: .center,
                                                    startAngle: .degrees(gradientRotation),
                                                    endAngle: .degrees(gradientRotation + 360)
                                                )
                                            )
                                            :  // 静态时：蓝色实线
                                            AnyShapeStyle(Color.blue.opacity(0.8)),
                                        lineWidth: isPlayingLivePhoto ? 4 : 2  // 播放时加粗
                                    )
                            )
                            // 动画触发 logic
                            .onChange(of: isPlayingLivePhoto) { oldValue, newValue in
                                if newValue {
                                    withAnimation(
                                        .linear(duration: 2).repeatForever(autoreverses: false)
                                    ) {
                                        gradientRotation = 360
                                    }
                                } else {
                                    withAnimation(.default) {
                                        gradientRotation = 0
                                    }
                                }
                            }
                            // 右下角图标
                            .overlay(alignment: .bottomTrailing) {
                                Image(
                                    systemName: cachedIsLivePhoto
                                        ? "livephoto" : "camera.aperture"
                                )
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                                .shadow(radius: 2)
                            }
                            // 手势逻辑
                            .onLongPressGesture(
                                minimumDuration: 60.0,
                                pressing: { isPressing in
                                    if isPressing {
                                        startPlayingLivePhoto()
                                    } else {
                                        stopPlayingLivePhoto()
                                    }
                                }, perform: {}
                            )
                            .onTapGesture {
                                if !isPlayingLivePhoto {
                                    onImageTap?(
                                        FullScreenImage(
                                            image: uiImage,
                                            isLivePhoto: cachedIsLivePhoto,
                                            videoData: cachedVideoData
                                        )
                                    )
                                }
                            }
                        }
                        // (B) 普通样式
                        else {
                            // 普通记录的图片也使用 cachedImage
                            if let uiImage = cachedImage {
                                Image(uiImage: uiImage)
                                    .resizable().scaledToFill().frame(height: 160).frame(
                                        maxWidth: .infinity
                                    )
                                    .cornerRadius(8).clipped()
                                    .onTapGesture {
                                        onImageTap?(
                                            FullScreenImage(
                                                image: uiImage,
                                                isLivePhoto: cachedIsLivePhoto,
                                                videoData: cachedVideoData
                                            )
                                        )
                                    }
                            }

                            if !cleanContent.isEmpty {
                                Text(cleanContent).font(.body).foregroundColor(.primary).lineLimit(
                                    nil)
                            }

                            if !tags.isEmpty || isInspiration {
                                if !cleanContent.isEmpty || cachedImage != nil {
                                    Divider().opacity(0.3)
                                }
                                HStack(spacing: 8) {
                                    if isInspiration {
                                        HStack(spacing: 4) {
                                            Image(systemName: "lightbulb.fill").font(.caption2)
                                                .foregroundColor(.yellow)
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
                    .padding(isMoment ? 0 : 12)
                    .background(
                        isMoment ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground)
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(isMoment ? 0 : 0.05), radius: 2, x: 0, y: 1)
                    .contentShape(Rectangle())
                    .padding(.bottom, 20)
                }
                Spacer()
            }
            // 🔥 核心逻辑：加载数据
            .onAppear { loadImage() }
            // 监听数据变更（针对编辑操作）
            // 🔥 修复: 在 onChange 回调中也需检查 isDeleted，防止删除动画时访问已分离数据
            .onChange(of: item.imageData) { _, _ in
                if !item.isDeleted { loadImage() }
            }
        )
    }

    // 🔥 安全加载所有属性方法
    private func loadImage() {
        // 如果对象已经被删除，不要去访问它的属性，直接退出
        if item.isDeleted { return }

        // 缓存所有必要属性
        cachedTimestamp = item.timestamp
        cachedType = item.type
        cachedContent = item.content
        cachedIsLivePhoto = item.isLivePhoto
        cachedVideoData = item.livePhotoVideoData
        
        // 安全读取图片 data
        if let data = item.imageData, let image = UIImage(data: data) {
            self.cachedImage = image
        } else {
            self.cachedImage = nil
        }
        
        isDataLoaded = true
    }

    // 开始播放实况
    private func startPlayingLivePhoto() {
        guard cachedIsLivePhoto, !isPlayingLivePhoto else { return }
        guard let videoData = cachedVideoData else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")

        do {
            try videoData.write(to: tempURL)
            let newPlayer = AVPlayer(url: tempURL)
            newPlayer.isMuted = false
            newPlayer.actionAtItemEnd = .none

            // 循环播放逻辑
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }

            self.player = newPlayer
            self.isPlayingLivePhoto = true

            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            newPlayer.play()
        } catch {
            print("播放实况失败: \(error)")
        }
    }

    // 停止播放实况
    private func stopPlayingLivePhoto() {
        player?.pause()
        player = nil
        isPlayingLivePhoto = false
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

    @Query(
        filter: #Predicate<TimelineItem> { $0.type == "inspiration" },
        sort: \TimelineItem.timestamp, order: .reverse)
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
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .cornerRadius(12)
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
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation { isInspirationMode.toggle() }
                        }) {
                            Image(systemName: isInspirationMode ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 24))
                                .foregroundColor(isInspirationMode ? .yellow : .secondary)
                                .frame(width: 32, height: 32)
                        }

                        Button(action: {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(selectedImage == nil ? .secondary : .blue)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.bottom, 6)

                    TextField(
                        isInspirationMode ? "捕捉灵感..." : "记录此刻...", text: $inputText, axis: .vertical
                    )
                    .focused($isInputFocused)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemFill))
                    .cornerRadius(18)
                    .lineLimit(1...5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18).stroke(
                            isInspirationMode ? Color.yellow.opacity(0.5) : Color.clear,
                            lineWidth: 1))

                    if !inputText.isEmpty || selectedImage != nil {
                        Button(action: saveItem) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(isInspirationMode ? .yellow : .blue)
                        }
                        .padding(.bottom, 2)
                    } else {
                        Button(action: {
                            withAnimation {
                                isExpanded = false
                                isInputFocused = false
                            }
                        }) {
                            Image(systemName: "chevron.down").font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32).background(
                                    Color.secondary.opacity(0.1)
                                ).clipShape(Circle())
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

        let newItem = TimelineItem(
            content: inputText, iconName: icon, timestamp: Date(), imageData: imageData, type: type)
        modelContext.insert(newItem)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation {
            inputText = ""
            selectedImage = nil
            isInputFocused = false
            isInspirationMode = false
            isExpanded = false
        }
    }
}

// 辅助组件
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.day.timeline.left").font(.system(size: 80)).foregroundColor(
                .gray.opacity(0.3))
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
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 🔥 时间线日历组件（带蓝点标记）
struct TimelineCalendarSheet: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let recordedDates: Set<String>
    var onDismiss: () -> Void
    
    private let calendar = Calendar.current
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 月份导航
                HStack {
                    Text(monthYearString(currentMonth))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    HStack(spacing: 20) {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.secondary)
                        }
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
                
                // 星期标题
                HStack {
                    ForEach(weekDays, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // 日期网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            TimelineDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                hasData: hasData(on: date)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDate = date
                                }
                                // 选择日期后自动关闭
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            }
                        } else {
                            Text("").frame(height: 40)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        withAnimation {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { onDismiss() }
                }
            }
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation { currentMonth = newMonth }
        }
    }
    
    func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 MM月"
        return formatter.string(from: date)
    }
    
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let paddingDays = firstWeekday - 1
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    func hasData(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return recordedDates.contains(formatter.string(from: date))
    }
}

// MARK: - 日历日期单元格（带蓝点标记）
struct TimelineDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasData: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                .frame(width: 32, height: 32)
                .background(isSelected ? Circle().fill(Color.blue) : nil)
                .overlay(isToday && !isSelected ? Circle().stroke(Color.blue, lineWidth: 1) : nil)
            
            // 🔥 蓝点标记：有数据的日期显示蓝点
            Circle()
                .fill(hasData ? (isSelected ? .white.opacity(0.8) : Color.blue) : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 44)
    }
}
