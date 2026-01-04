//
//  TagFilterView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftData
import SwiftUI

struct TagFilterView: View {
    let tagName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    // 查询所有数据
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]

    var filteredItems: [TimelineItem] {
        allItems.filter { item in
            item.content.contains(tagName) && item.type == "inspiration"
        }
    }

    // 状态管理
    @State private var showNewInputSheet = false
    @State private var itemToEdit: TimelineItem?
    @State private var itemToDelete: TimelineItem?
    @State private var showDeleteAlert = false

    // 菜单状态
    @State private var showCustomMenu = false
    @State private var menuPosition: CGPoint = .zero
    @State private var itemForMenu: TimelineItem?

    // 标签跳转
    @State private var selectedTag: String?

    // 全屏图片状态
    @State private var fullScreenImage: FullScreenImage?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("该标签下暂无内容")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredItems) { item in
                                InspirationCardView(
                                    item: item,
                                    onMenuTap: { selectedItem, anchorPoint in
                                        self.itemForMenu = selectedItem
                                        self.menuPosition = anchorPoint
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7))
                                        {
                                            self.showCustomMenu = true
                                        }
                                    },
                                    onTagTap: { tag in
                                        if tag != tagName { self.selectedTag = tag }
                                    },
                                    onImageTap: { item in
                                        self.fullScreenImage = FullScreenImage(
                                            image: UIImage(data: item.imageData!)!,
                                            isLivePhoto: item.isLivePhoto,
                                            videoData: item.livePhotoVideoData
                                        )
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
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

                // 浮层菜单
                if showCustomMenu {
                    Color.black.opacity(0.01).ignoresSafeArea()
                        .onTapGesture { withAnimation { showCustomMenu = false } }

                    VStack(spacing: 0) {
                        Button(action: {
                            showCustomMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                itemToEdit = itemForMenu
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("修改")
                                Spacer()
                            }
                            .padding().foregroundColor(.primary)
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
                            .padding().foregroundColor(.red)
                        }
                    }
                    // 🔥 菜单背景色优化
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12).frame(width: 140)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .position(x: menuPosition.x - 70, y: menuPosition.y + 60)
                    .transition(.scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .navigationTitle(tagName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .padding(8)
                            // 🔥 返回按钮背景色优化
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 3)
                    }
                }
            }
            .navigationDestination(item: $selectedTag) { tag in
                TagFilterView(tagName: tag)
            }
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(imageEntity: wrapper)
            }
            .sheet(isPresented: $showNewInputSheet) {
                InspirationInputView(itemToEdit: nil, initialContent: tagName)
            }
            .sheet(item: $itemToEdit) { item in
                InspirationInputView(itemToEdit: item)
            }
            .alert("确认删除?", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { itemToDelete = nil }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                Text("删除后将无法恢复。")
            }
        }
    }

    // 删除辅助函数
    private func deleteItem(_ item: TimelineItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToDelete = nil
        itemForMenu = nil
    }
}
