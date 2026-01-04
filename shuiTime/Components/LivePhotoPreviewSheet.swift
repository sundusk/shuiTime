//
//  LivePhotoPreviewSheet.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import AVKit
import SwiftUI

/// Live Photo 预览和选择页面 - 简化版
struct LivePhotoPreviewSheet: View {
    let asset: LivePhotoAsset
    var onConfirm: (UIImage, Data?, Bool) -> Void
    var onCancel: () -> Void

    @State private var isLiveEnabled: Bool = false  // 🔥 默认不勾选实况
    @State private var player: AVPlayer?

    init(
        asset: LivePhotoAsset, onConfirm: @escaping (UIImage, Data?, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.asset = asset
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // 背景色 - 深色
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 🔥 顶部导航栏 - 只保留返回按钮
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // 主图片/视频
                if let videoURL = asset.videoURL, isLiveEnabled {
                    // Live Photo 视频预览
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            setupPlayer(url: videoURL)
                        }
                } else {
                    // 静态图片
                    Image(uiImage: asset.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // 🔥 底部区域
                VStack(spacing: 16) {
                    // 实况标签 + 缩略图预览
                    HStack(spacing: 12) {
                        // 左侧：实况标签（仅当有 Live Photo 时显示）
                        if asset.isLivePhoto {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()

                                withAnimation(.spring()) {
                                    isLiveEnabled.toggle()
                                }

                                // 开启时播放预览
                                if isLiveEnabled {
                                    playPreview()
                                } else {
                                    player?.pause()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    // 🔥 移除勾选图标，仅保留实况图标和文字
                                    Image(systemName: "livephoto")
                                        .font(.system(size: 16))
                                    Text("实况")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(isLiveEnabled ? Color.green : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            isLiveEnabled ? Color.green : Color.white,  // 未选中时也用白色描边，或灰色，保持一致
                                            lineWidth: 1)
                                )
                            }
                        }

                        Spacer()

                        // 缩略图预览
                        ZStack(alignment: .bottomLeading) {
                            Image(uiImage: asset.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.green, lineWidth: 2)
                                )

                            // Live Photo 图标
                            if asset.isLivePhoto && isLiveEnabled {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .padding(4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // 🔥 只保留发送按钮
                    HStack {
                        Spacer()

                        Button(action: handleConfirm) {
                            Text("发送 (1)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
        }
    }

    private func setupPlayer(url: URL) {
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = false
        self.player = newPlayer

        // 🔥 监听播放结束
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            // 播放结束后重置到开头
            newPlayer.seek(to: .zero)
        }
    }

    private func playPreview() {
        guard let player = player else { return }

        // 🔥 播放完整视频
        player.seek(to: .zero)
        player.play()
    }

    private func handleConfirm() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 读取视频数据（如果启用）
        var videoData: Data? = nil
        if isLiveEnabled, let videoURL = asset.videoURL {
            videoData = try? Data(contentsOf: videoURL)
        }

        onConfirm(asset.image, videoData, isLiveEnabled)
    }
}
