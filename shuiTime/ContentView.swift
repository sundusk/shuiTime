//
//  ContentView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var navigationState = AppNavigationState()
    @State private var showSideMenu = false
    @State private var showBackupSheet = false
    @State private var showFilePicker = false
    @State private var showOverwriteFilePicker = false
    @State private var isExporting = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showOverwriteConfirm = false
    @State private var pendingOverwriteURL: URL? = nil
    @State private var showExportPicker = false
    @State private var exportURL: URL? = nil
    
    // 获取所有数据 (如果后续红点提示需要，可以保留，否则也可以删掉)
    @Query private var items: [TimelineItem]

    var body: some View {
        ZStack(alignment: .leading) {
            TabView(selection: selectedTab) {
                
                // 1. 时间线
                TimeLineView {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSideMenu = true
                    }
                }
                .tabItem {
                    Label("时间线", systemImage: "calendar.day.timeline.left")
                }
                .tag(0)

                // 2. 瞬息
                InspirationView()
                    .tabItem {
                        Label("瞬息", systemImage: "lightbulb")
                    }
                    .tag(1)

                // 3. 时光回顾
                LookBackView()
                    .tabItem {
                        Label("时光回顾", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(2)
            }
            .tint(.blue)
            .environmentObject(navigationState)

            SideMenuView(
                isOpen: $showSideMenu,
                onTagSelected: { tag in
                    navigationState.pendingInspirationTag = nil

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        navigationState.selectedTab = 1
                        showSideMenu = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationState.pendingInspirationTag = tag
                    }
                },
                onBackupTap: openBackupPanel
            )
            .environmentObject(navigationState)

            if isExporting {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)

                        Text("正在导出备份...")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(items.count) 条记录")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .zIndex(500)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showBackupSheet) {
            BackupOptionsSheet(
                onExport: { handleExportBackup() },
                onImport: {
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
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { url in
                handleImportBackup(from: url)
            }
        }
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
        .sheet(isPresented: $showOverwriteFilePicker) {
            DocumentPicker { url in
                pendingOverwriteURL = url
                showOverwriteConfirm = true
            }
        }
        .alert("确认覆盖?", isPresented: $showOverwriteConfirm) {
            Button("取消", role: .cancel) {
                pendingOverwriteURL = nil
            }
            Button("覆盖", role: .destructive) {
                if let url = pendingOverwriteURL {
                    handleImportOverwrite(from: url)
                }
                pendingOverwriteURL = nil
            }
        } message: {
            Text("此操作将删除所有现有数据，并用备份文件中的数据替换。\n\n此操作不可撤销！")
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var selectedTab: Binding<Int> {
        Binding(
            get: { navigationState.selectedTab },
            set: { navigationState.selectedTab = $0 }
        )
    }

    private func openBackupPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showSideMenu = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showBackupSheet = true
        }
    }

    private func handleExportBackup() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        showBackupSheet = false
        withAnimation { isExporting = true }

        if let fileURL = BackupManager.shared.exportData(items: items) {
            withAnimation { isExporting = false }
            exportURL = fileURL
            showExportPicker = true

            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            withAnimation { isExporting = false }
            alertTitle = "备份失败"
            alertMessage = "导出数据时发生错误，请稍后重试"
            showAlert = true

            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }

    private func handleImportBackup(from url: URL) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if let count = BackupManager.shared.importData(from: url, context: modelContext) {
            alertTitle = "恢复成功"
            alertMessage = "成功导入 \(count) 条记录\n\n数据已添加到时间线中"
            showAlert = true

            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            alertTitle = "恢复失败"
            alertMessage = "导入数据时发生错误\n请确认备份文件格式正确或压缩文件未损坏"
            showAlert = true

            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }

        showFilePicker = false
    }

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

#Preview {
    ContentView()
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
