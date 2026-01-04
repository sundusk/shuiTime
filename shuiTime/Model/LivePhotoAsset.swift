//
//  LivePhotoAsset.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import Foundation
import Photos
import UIKit

/// Live Photo 资源包装
struct LivePhotoAsset: Identifiable {
    let id = UUID()
    let image: UIImage
    let videoURL: URL?
    let isLivePhoto: Bool

    init(image: UIImage, videoURL: URL? = nil) {
        self.image = image
        self.videoURL = videoURL
        self.isLivePhoto = videoURL != nil
    }
}
