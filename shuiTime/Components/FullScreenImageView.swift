//
//  FullScreenImageView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import AVKit
import SwiftUI
import UIKit

// MARK: - 1. 数据模型 (用于控制弹窗)
// MARK: - 1. 数据模型 (用于控制弹窗)
struct FullScreenImage: Identifiable {
    let id = UUID()
    let image: UIImage
    // 🔥 新增：Live Photo 数据
    var isLivePhoto: Bool = false
    var videoData: Data? = nil
}

// MARK: - 2. 全屏查看容器 (带关闭按钮)
struct FullScreenPhotoView: View {
    let imageEntity: FullScreenImage  // 改用整个对象以获取视频数据
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            // 黑色背景
            Color.black.ignoresSafeArea()

            // 缩放视图
            ZoomableImageView(image: imageEntity.image)
                .ignoresSafeArea()

            // 3. 关闭按钮 (右上角)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .padding(.top, 40)  // 避开刘海屏
                    }
                }
                Spacer()
            }

            // 4. 实况播放按钮 (左下角)
            if imageEntity.isLivePhoto && imageEntity.videoData != nil {
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { playLivePhoto() }) {
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

            // 🔥 实况播放覆盖层
            if isPlaying, let player = player {
                Color.black.ignoresSafeArea()
                // 使用自定义播放器以隐藏控制条
                SimpleVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onTapGesture { stopPlaying() }  // 点击停止
            }
        }
        .onDisappear { stopPlaying() }
    }

    // 播放逻辑
    private func playLivePhoto() {
        guard let data = imageEntity.videoData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")

        do {
            try data.write(to: tempURL)
            let newPlayer = AVPlayer(url: tempURL)
            // 播放完毕自动恢复
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main
            ) { _ in
                stopPlaying()
            }
            self.player = newPlayer
            self.isPlaying = true
        } catch {
            print("播放失败: \(error)")
        }
    }

    private func stopPlaying() {
        player?.pause()
        player = nil
        isPlaying = false
    }
}

// MARK: - 3. 底层缩放组件 (UIViewRepresentable)
struct ZoomableImageView: UIViewRepresentable {
    var image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
    }
}

// MARK: - 4. 无控件视频播放器 (UIViewRepresentable)
struct SimpleVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // 🔥 关键：隐藏播放控制条
        controller.videoGravity = .resizeAspect  // 保持比例填充
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
