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
    var onImportOverwrite: () -> Void  // 🔥 覆盖导入
    var onCleanDuplicates: () -> Void
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

                // 导入按钮（合并模式）
                Button(action: {
                    onImport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("导入备份")
                                .font(.headline)
                            Text("合并到现有数据")
                                .font(.caption2)
                                .opacity(0.7)
                        }
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
                
                // 🔥 覆盖导入按钮（危险操作）
                Button(action: {
                    onImportOverwrite()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("覆盖导入")
                                .font(.headline)
                            Text("删除现有数据后导入")
                                .font(.caption2)
                                .opacity(0.7)
                        }
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                
                // 清理重复数据按钮
                Button(action: {
                    onCleanDuplicates()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("清理重复数据")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
