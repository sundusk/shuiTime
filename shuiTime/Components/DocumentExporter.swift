//
//  DocumentExporter.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/11.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 文件导出器 (用于将备份文件保存到用户选择的文件夹)
struct DocumentExporter: UIViewControllerRepresentable {
    let itemURL: URL
    var onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 使用 .exporting 模式
        let picker = UIDocumentPickerViewController(forExporting: [itemURL])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // 导出成功
            onFinish(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // 用户取消导出
            onFinish(false)
        }
    }
}
