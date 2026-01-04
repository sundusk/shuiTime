//
//  BackupOptionsSheet.swift
//  shuiTime
//
//  Created by Antigravity on 2026/01/04.
//

import SwiftUI
import UIKit

/// 备份选项弹窗
struct BackupOptionsSheet: View {
    var onExport: () -> Void
    var onImport: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)

                Text("数据备份与恢复")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("保护你的时间线数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            // 按钮组
            VStack(spacing: 12) {
                // 导出按钮
                Button(action: {
                    onExport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                        Text("导出备份")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }

                // 导入按钮
                Button(action: {
                    onImport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                        Text("导入备份")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
