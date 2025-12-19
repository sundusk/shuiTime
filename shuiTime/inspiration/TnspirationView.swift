//
//  InspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

struct InspirationView: View {
    @Binding var showSideMenu: Bool
    @Environment(\.modelContext) private var modelContext
    
    // 查询灵感数据
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var items: [TimelineItem]
    
    // MARK: - 状态管理
    @State private var showNewInputSheet = false
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false
    
    // MARK: - 自定义菜单状态
    @State private var showCustomMenu = false
    @State private var menuPosition: CGPoint = .zero // 菜单弹出的位置
    @State private var itemForMenu: TimelineItem?    // 当前操作的条目
    
    var body: some View {
        NavigationStack {
            // 使用 ZStack 确保菜单能浮在最上面
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.min")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("点击右下角记录灵感")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(items) { item in
                                InspirationCardView(
                                    item: item,
                                    // 点击回调：传回 Item 和 按钮的坐标信息
                                    onMenuTap: { selectedItem, anchorPoint in
                                        self.itemForMenu = selectedItem
                                        self.menuPosition = anchorPoint
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            self.showCustomMenu = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                    // 🔥 关键：定义坐标空间，让卡片能算出相对于列表的位置
                    .coordinateSpace(name: "InspirationScrollSpace")
                }
                
                // 悬浮加号按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showNewInputSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                    }
                }
                
                // MARK: - 自定义浮层菜单
                if showCustomMenu {
                    // 1. 透明背景层 (点击空白处关闭)
                    Color.black.opacity(0.01) // 极低透明度用于接收点击
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showCustomMenu = false }
                        }
                    
                    // 2. 菜单本体
                    VStack(spacing: 0) {
                        Button(action: {
                            showCustomMenu = false
                            // 稍微延迟，让菜单消失动画不被卡顿
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                itemToEdit = itemForMenu
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("修改")
                                Spacer()
                            }
                            .padding()
                            .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showCustomMenu = false
                            if let item = itemForMenu {
                                itemToDelete = item
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showDeleteAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("删除")
                                Spacer()
                            }
                            .padding()
                            .foregroundColor(.red)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .frame(width: 140) // 菜单宽度
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    // 🔥 定位逻辑：将菜单的右上角对齐按钮的右下角
                    // position 设置的是视图中心点，所以要做偏移计算
                    .position(
                        x: menuPosition.x - 70, // 向左偏移宽度的一半(140/2)，实现右对齐
                        y: menuPosition.y + 60  // 向下偏移高度的一半(假设高120/2)，实现按钮下方
                    )
                    .transition(.scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .navigationTitle("灵感集")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { withAnimation { showSideMenu = true } }) {
                        Image(systemName: "line.3.horizontal").foregroundColor(.primary)
                    }
                }
            }
            // 弹窗逻辑
            .sheet(isPresented: $showNewInputSheet) {
                InspirationInputView(itemToEdit: nil)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $itemToEdit) { item in
                InspirationInputView(itemToEdit: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete { deleteItem(item) }
                }
            } message: {
                Text("删除后将无法恢复这条灵感。")
            }
        }
    }
    
    private func deleteItem(_ item: TimelineItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
        itemForMenu = nil
    }
}

// MARK: - 灵感卡片视图
struct InspirationCardView: View {
    let item: TimelineItem
    // 回调：传入 Item 和 点击位置的坐标
    var onMenuTap: (TimelineItem, CGPoint) -> Void
    
    // 本地状态：存储按钮的实时位置
    @State private var buttonFrame: CGRect = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.timestamp.formatted(date: .numeric, time: .standard))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                // 按钮区域
                Button(action: {
                    // 点击时，将之前计算好的位置传出去
                    // 这里的坐标是按钮的右下角 (maxX, maxY)
                    let anchor = CGPoint(x: buttonFrame.maxX, y: buttonFrame.maxY)
                    onMenuTap(item, anchor)
                }) {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                // 🔥 核心：使用 GeometryReader 获取按钮在 ScrollView 中的位置
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                // 获取在自定义坐标系中的 frame
                                buttonFrame = geo.frame(in: .named("InspirationScrollSpace"))
                            }
                            .onChange(of: geo.frame(in: .named("InspirationScrollSpace"))) { newFrame in
                                // 当滚动时实时更新坐标
                                buttonFrame = newFrame
                            }
                    }
                )
            }
            
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .clipped()
                    .contentShape(Rectangle())
            }
            
            if !item.content.isEmpty {
                Text(attributedContent(for: item.content))
                    .font(.body)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func attributedContent(for text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .primary
        if text.hasPrefix("#") {
            let separators = CharacterSet.whitespacesAndNewlines
            if let range = text.rangeOfCharacter(from: separators) {
                let tagString = String(text[..<range.lowerBound])
                if let attrRange = attributed.range(of: tagString) {
                    attributed[attrRange].foregroundColor = .blue
                }
            } else {
                attributed.foregroundColor = .blue
            }
        }
        return attributed
    }
}
