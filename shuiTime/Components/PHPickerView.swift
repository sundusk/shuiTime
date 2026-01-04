//
//  PHPickerView.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import AVFoundation
import PhotosUI
import SwiftUI

/// PHPicker 包装器 - 支持 Live Photo
struct PHPickerView: UIViewControllerRepresentable {
    @Binding var selectedAsset: LivePhotoAsset?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView

        init(_ parent: PHPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else {
                parent.onDismiss()
                return
            }

            // 先加载图片
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (object, error) in
                guard let self = self, let image = object as? UIImage else {
                    DispatchQueue.main.async {
                        self?.parent.onDismiss()
                    }
                    return
                }

                // 检查是否为 Live Photo
                guard let assetId = result.assetIdentifier else {
                    // 没有 assetIdentifier，说明是普通图片
                    DispatchQueue.main.async {
                        self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: nil)
                        self.parent.onDismiss()
                    }
                    return
                }

                // 获取 PHAsset
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                guard let asset = fetchResult.firstObject else {
                    DispatchQueue.main.async {
                        self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: nil)
                        self.parent.onDismiss()
                    }
                    return
                }

                // 🔥 关键：检查是否为 Live Photo
                if asset.mediaSubtypes.contains(.photoLive) {
                    print("✅ 检测到 Live Photo")
                    self.extractLivePhotoResources(asset: asset, image: image)
                } else {
                    print("📷 普通静态照片")
                    DispatchQueue.main.async {
                        self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: nil)
                        self.parent.onDismiss()
                    }
                }
            }
        }

        private func extractLivePhotoResources(asset: PHAsset, image: UIImage) {
            // 🔥 直接获取配对视频资源（Live Photo 的关键）
            let resources = PHAssetResource.assetResources(for: asset)

            // 查找配对视频资源
            guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
                print("⚠️ 未找到配对视频资源")
                DispatchQueue.main.async {
                    self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: nil)
                    self.parent.onDismiss()
                }
                return
            }

            print("🎬 找到配对视频资源")

            // 导出视频到临时目录
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(
                for: videoResource,
                toFile: tempURL,
                options: options
            ) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ 导出视频失败: \(error)")
                    DispatchQueue.main.async {
                        self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: nil)
                        self.parent.onDismiss()
                    }
                } else {
                    print("✅ 视频导出成功: \(tempURL)")
                    DispatchQueue.main.async {
                        self.parent.selectedAsset = LivePhotoAsset(image: image, videoURL: tempURL)
                        self.parent.onDismiss()
                    }
                }
            }
        }
    }
}
