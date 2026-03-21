//
//  MomentGalleryView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2026/01/01.
//

import SwiftData
import SwiftUI
import AVKit
import UIKit

struct MomentMedia: Identifiable {
    let id: UUID
    let imageEntity: FullScreenImage
}

struct MomentGalleryView: View {
    // 筛选所有“瞬影”类型且有图片的记录
    @Query(
        filter: #Predicate<TimelineItem> { $0.type == "moment" && $0.imageData != nil },
        sort: \TimelineItem.timestamp, order: .reverse)
    private var allMoments: [TimelineItem]

    // 全屏浏览状态
    @State private var selectedIndex: Int = 0
    @State private var isFullScreenPresented = false
    @State private var mediaList: [MomentMedia] = []

    // 按月份分组数据
    private var groupedMoments: [(Date, [TimelineItem])] {
        let grouped = Dictionary(grouping: allMoments) { item in
            let components = Calendar.current.dateComponents([.year, .month], from: item.timestamp)
            return Calendar.current.date(from: components)!
        }
        return grouped.sorted { $0.key > $1.key }  // 按月份倒序
    }

    var body: some View {
        ZStack {
            // 和“时光回顾”统一的弥散背景，让时光墙更有回望感
            MeshGradientBackground()

            // 更柔和的梦幻光感：远处的冷暖光晕 + 雾面罩层
            ZStack {
                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.16),
                        Color.blue.opacity(0.08),
                        .clear,
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 380
                )
                .offset(x: -40, y: -80)

                RadialGradient(
                    colors: [
                        Color.indigo.opacity(0.12),
                        Color.pink.opacity(0.05),
                        .clear,
                    ],
                    center: .bottomTrailing,
                    startRadius: 30,
                    endRadius: 420
                )
                .offset(x: 30, y: 120)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color(uiColor: .systemGroupedBackground).opacity(0.16),
                        Color(uiColor: .systemGroupedBackground).opacity(0.34),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 极轻的边缘收束，增强沉浸感但不做明显暗角
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        .clear,
                        .clear,
                        Color.black.opacity(0.10),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.softLight)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 60) {  // 月份之间的大间距
                    ForEach(groupedMoments, id: \.0) { date, items in
                        ScatteredMonthSection(date: date, items: items) { item in
                            guard let index = mediaList.firstIndex(where: { $0.id == item.id }) else {
                                return
                            }
                            selectedIndex = index
                            isFullScreenPresented = true
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("时光墙")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { rebuildMediaList() }
        .onChange(of: allMoments) { _, _ in rebuildMediaList() }
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            MomentFullScreenCarouselView(
                mediaList: mediaList,
                currentIndex: $selectedIndex
            )
        }
    }

    private func rebuildMediaList() {
        mediaList = allMoments.compactMap { item in
            guard let data = item.imageData, let image = UIImage(data: data) else { return nil }
            return MomentMedia(
                id: item.id,
                imageEntity: FullScreenImage(
                    image: image,
                    isLivePhoto: item.isLivePhoto,
                    videoData: item.livePhotoVideoData
                )
            )
        }
    }
}

// MARK: - 散落风格的月份模块
struct ScatteredMonthSection: View {
    let date: Date
    let items: [TimelineItem]
    let onImageTap: (TimelineItem) -> Void

    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"  // 比如 1, 12
        return formatter.string(from: date)
    }

    var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    var monthAnchorLabel: String {
        "\(monthString)月"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(monthAnchorLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.88))

                Text(yearString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .tracking(1.6)

                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 36, height: 1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)

            ZStack(alignment: .topLeading) {
                // 1. 背景大水印：保留氛围，但降低信息职责
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(monthString)
                        .font(.system(size: 104, weight: .black, design: .serif))
                        .foregroundColor(Color.primary.opacity(0.035))
                        .italic()
                    Text("月")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color.primary.opacity(0.02))
                        .padding(.bottom, 16)
                }
                .offset(x: 18, y: -26)
                .allowsHitTesting(false)

                // 2. 散落照片墙
                ScatteredGrid(items: items, onImageTap: onImageTap)
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - 错位瀑布流布局 (核心逻辑)
struct ScatteredGrid: View {
    let items: [TimelineItem]
    let onImageTap: (TimelineItem) -> Void

    // 分列
    private var columns: ([TimelineItem], [TimelineItem]) {
        var left: [TimelineItem] = []
        var right: [TimelineItem] = []
        for (index, item) in items.enumerated() {
            if index % 2 == 0 { left.append(item) } else { right.append(item) }
        }
        return (left, right)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // --- 左列 ---
            LazyVStack(spacing: 30) {
                ForEach(columns.0) { item in
                    PhotoPaperCard(item: item, onImageTap: onImageTap)
                        // 左列稍微往右偏一点，制造重叠感
                        .offset(x: 10)
                }
            }
            .frame(maxWidth: .infinity)

            // --- 右列 ---
            LazyVStack(spacing: 30) {
                // 右列整体下沉 60pt，打破水平对齐，形成错落感
                Spacer().frame(height: 60)
                ForEach(columns.1) { item in
                    PhotoPaperCard(item: item, onImageTap: onImageTap)
                        // 右列稍微往左偏
                        .offset(x: -10)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - 拟真照片卡片 (PhotoPaperCard)
struct PhotoPaperCard: View {
    let item: TimelineItem
    let onImageTap: (TimelineItem) -> Void

    // 基于 ID 生成确定性的随机值，防止滚动时抖动
    private var randomRotation: Double {
        return Double(item.id.hashValue % 100) / 100.0 * 8.0 - 4.0  // -4 到 +4 度
    }

    private var randomScale: CGFloat {
        let val = abs(Double(item.id.hashValue % 100)) / 100.0
        return 0.95 + (val * 0.1)  // 0.95 到 1.05 大小浮动
    }

    private var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: item.timestamp)
    }

    var body: some View {
        if let data = item.imageData, let uiImage = UIImage(data: data) {
            Button(action: { onImageTap(item) }) {
                VStack(spacing: 0) {
                    // 图片层
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        // 模拟洗印质感：给图片加一层极淡的内发光/纹理
                        .overlay(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .clear, .black.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(2)  // 图片本身的角不需要太圆，模拟相纸切割
                        .padding(10)  // 白边留白宽度
                        .background(Color.white)  // 相纸底色

                    // 底部文字留白 (类似拍立得，或者只是普通的白边)
                    // 这里我们做成普通的均匀白边，更有生活照的感觉
                }
                // --- 卡片物理质感 ---
                .background(Color.white)
                .cornerRadius(4)  // 相纸整体微圆角 (相纸一般很尖，或者微圆)
                // 0. 环境光：很轻地把照片从背景里托出来
                .background {
                    ZStack {
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.cyan.opacity(0.10),
                                .clear,
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 120
                        )
                        .offset(x: -14, y: -18)
                        .blur(radius: 10)

                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.09),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 24,
                            endRadius: 150
                        )
                        .blur(radius: 18)
                    }
                }
                // 1. 投影：模拟散落在桌面的悬浮感
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 2, y: 4)
                .shadow(color: Color.white.opacity(0.18), radius: 20, x: -6, y: -8)
                .shadow(color: Color.cyan.opacity(0.08), radius: 26, x: 0, y: 10)
                // 2. 内阴影/高光：模拟纸张厚度 (使用 overlay stroke 实现)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                        .blendMode(.screen)  // 混合模式增加透亮感
                )
                // --- 随机变换 ---
                .rotationEffect(.degrees(randomRotation))
                .scaleEffect(randomScale)
                // --- 胶片日期水印 (Optional, 增加复古感) ---
                .overlay(alignment: .bottomTrailing) {
                    Text(dateStamp)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(
                            Color(uiColor: .init(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7))
                        )  // 经典的橙色日期
                        .padding(14)  // 考虑到白边
                        .opacity(0.8)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
            .buttonStyle(SquishButtonStyle())  // 点击时的弹性反馈
        }
    }
}

// MARK: - 辅助组件

// 简单的弹性按钮样式
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)  // 点击时稍微变亮
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct MomentFullScreenCarouselView: View {
    let mediaList: [MomentMedia]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var dragOffset: CGFloat = 0
    @State private var currentZoomScale: CGFloat = 1
    @State private var isTransitioning = false
    @State private var viewportWidth: CGFloat = 0
    @State private var showPhotoActions = false
    @State private var saveResultMessage = ""
    @State private var showSaveResult = false
    @State private var photoLibrarySaver: PhotoLibrarySaver?
    private let slideSpacing: CGFloat = 28

    private var hasContent: Bool { !mediaList.isEmpty }

    private var safeIndex: Int {
        guard hasContent else { return 0 }
        return min(max(currentIndex, 0), mediaList.count - 1)
    }

    private var imageEntity: FullScreenImage? {
        guard hasContent else { return nil }
        return mediaList[safeIndex].imageEntity
    }

    private var adjacentIndex: Int? {
        guard hasContent else { return nil }
        if dragOffset < 0, safeIndex < mediaList.count - 1 { return safeIndex + 1 }
        if dragOffset > 0, safeIndex > 0 { return safeIndex - 1 }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let imageEntity {
                GeometryReader { geometry in
                    ZStack {
                        if let adjacentIndex {
                            ZoomableImageView(image: mediaList[adjacentIndex].imageEntity.image)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                                .offset(x: adjacentImageOffset(width: geometry.size.width))
                        }

                        ZoomableImageView(
                            image: imageEntity.image,
                            onZoomScaleChange: { scale in
                                currentZoomScale = scale
                            }
                        )
                            .id(mediaList[safeIndex].id)
                            .ignoresSafeArea()
                            .offset(x: dragOffset)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        guard !isPlaying else { return }
                                        showPhotoActions = true
                                    }
                            )
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 16)
                            .onChanged { value in
                                guard !isTransitioning else { return }
                                guard currentZoomScale <= 1.02 else { return }
                                guard abs(value.translation.width) > abs(value.translation.height) else {
                                    return
                                }
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                guard !isTransitioning else { return }
                                guard currentZoomScale <= 1.02 else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        dragOffset = 0
                                    }
                                    return
                                }
                                handleSwipeEnd(value: value, width: geometry.size.width)
                            }
                    )
                    .onAppear { viewportWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newValue in
                        viewportWidth = newValue
                    }
                }
                .transition(.identity)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .padding(.top, 40)
                    }
                }
                Spacer()
            }

            if let imageEntity, imageEntity.isLivePhoto && imageEntity.videoData != nil {
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { playLivePhoto(videoData: imageEntity.videoData) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "livephoto.play")
                                    .font(.system(size: 14))
                                Text("实况")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 50)
                        Spacer()
                    }
                }
            }

            if isPlaying, let player = player {
                Color.black.ignoresSafeArea()
                SimpleVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onTapGesture { stopPlaying() }
            }

            ArrowKeyCatcher(
                onLeft: showPrevious,
                onRight: showNext,
                onEscape: { dismiss() }
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .onAppear {
            if currentIndex >= mediaList.count { currentIndex = max(0, mediaList.count - 1) }
        }
        .onChange(of: safeIndex) { _, _ in
            stopPlaying()
            dragOffset = 0
            currentZoomScale = 1
        }
        .onDisappear { stopPlaying() }
        .confirmationDialog("", isPresented: $showPhotoActions, titleVisibility: .hidden) {
            Button("保存到相册") {
                saveCurrentPhotoToLibrary()
            }
            Button("取消", role: .cancel) {}
        }
        .alert("保存结果", isPresented: $showSaveResult) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    private func showPrevious() {
        guard !isTransitioning else { return }
        guard hasContent, safeIndex > 0 else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { dragOffset = 0 }
            return
        }
        animateSlide(to: safeIndex - 1, direction: .toPrevious)
    }

    private func showNext() {
        guard !isTransitioning else { return }
        guard hasContent, safeIndex < mediaList.count - 1 else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { dragOffset = 0 }
            return
        }
        animateSlide(to: safeIndex + 1, direction: .toNext)
    }

    private func handleSwipeEnd(value: DragGesture.Value, width: CGFloat) {
        let threshold = max(60, width * 0.18)
        let translation = value.translation.width

        if translation <= -threshold, safeIndex < mediaList.count - 1 {
            animateSlide(to: safeIndex + 1, direction: .toNext, width: width)
        } else if translation >= threshold, safeIndex > 0 {
            animateSlide(to: safeIndex - 1, direction: .toPrevious, width: width)
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                dragOffset = 0
            }
        }
    }

    private enum SlideDirection {
        case toNext
        case toPrevious
    }

    private func adjacentImageOffset(width: CGFloat) -> CGFloat {
        if dragOffset < 0 {
            return dragOffset + width + slideSpacing
        }
        return dragOffset - width - slideSpacing
    }

    private func animateSlide(to targetIndex: Int, direction: SlideDirection, width: CGFloat? = nil) {
        guard !isTransitioning else { return }
        let screenWidth = max(1, width ?? viewportWidth)
        isTransitioning = true
        stopPlaying()

        let travel = screenWidth + slideSpacing
        let targetOffset = direction == .toNext ? -travel : travel

        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentIndex = targetIndex
            dragOffset = 0
            isTransitioning = false
        }
    }

    private func playLivePhoto(videoData: Data?) {
        guard let data = videoData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")

        do {
            try data.write(to: tempURL)
            let newPlayer = AVPlayer(url: tempURL)
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main
            ) { _ in
                stopPlaying()
            }
            player = newPlayer
            isPlaying = true
        } catch {
            print("播放失败: \(error)")
        }
    }

    private func stopPlaying() {
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func saveCurrentPhotoToLibrary() {
        guard let imageEntity else { return }
        let saver = PhotoLibrarySaver()
        saver.completion = { success, error in
            saveResultMessage = success ? "已保存到相册" : "保存失败\(error.map { "：\($0.localizedDescription)" } ?? "")"
            showSaveResult = true
            photoLibrarySaver = nil
        }
        photoLibrarySaver = saver
        saver.writeToPhotoAlbum(image: imageEntity.image)
    }
}

private struct ArrowKeyCatcher: UIViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onEscape: () -> Void

    func makeUIView(context: Context) -> ArrowKeyResponderView {
        let view = ArrowKeyResponderView()
        view.onLeft = onLeft
        view.onRight = onRight
        view.onEscape = onEscape
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateUIView(_ uiView: ArrowKeyResponderView, context: Context) {
        uiView.onLeft = onLeft
        uiView.onRight = onRight
        uiView.onEscape = onEscape
        DispatchQueue.main.async { uiView.becomeFirstResponder() }
    }
}

private final class ArrowKeyResponderView: UIView {
    var onLeft: () -> Void = {}
    var onRight: () -> Void = {}
    var onEscape: () -> Void = {}

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(left)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(right)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escape)),
        ]
    }

    @objc private func left() { onLeft() }
    @objc private func right() { onRight() }
    @objc private func escape() { onEscape() }
}
