//
//  MomentGalleryView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2026/01/01.
//

import SwiftUI
import SwiftData

struct MomentGalleryView: View {
    // 筛选所有“瞬影”类型且有图片的记录
    @Query(filter: #Predicate<TimelineItem> { $0.type == "moment" && $0.imageData != nil }, sort: \TimelineItem.timestamp, order: .reverse)
    private var allMoments: [TimelineItem]
    
    // 全屏浏览状态
    @State private var fullScreenImage: FullScreenImage?
    
    // 按月份分组数据
    private var groupedMoments: [(Date, [TimelineItem])] {
        let grouped = Dictionary(grouping: allMoments) { item in
            let components = Calendar.current.dateComponents([.year, .month], from: item.timestamp)
            return Calendar.current.date(from: components)!
        }
        return grouped.sorted { $0.key > $1.key } // 按月份倒序
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 40) { // 月份之间的大呼吸间距
                ForEach(groupedMoments, id: \.0) { date, items in
                    MonthSectionGallery(date: date, items: items) { image in
                        self.fullScreenImage = FullScreenImage(image: image)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 80)
        }
        .background(Color(uiColor: .systemGroupedBackground)) // 保持应用统一底色
        .navigationTitle("时光长廊")
        .navigationBarTitleDisplayMode(.inline)
        // 全屏浏览复用已有的组件
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
    }
}

// MARK: - 单月模块 (含隐形分割)
struct MonthSectionGallery: View {
    let date: Date
    let items: [TimelineItem]
    let onImageTap: (UIImage) -> Void
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 🔥 3. 时间索引：隐形分割 (背景巨型数字)
            Text(monthString)
                .font(.system(size: 160, weight: .black))
                .foregroundColor(Color.gray.opacity(0.06)) // 极淡的纹理感
                .offset(x: -10, y: -70) // 错位放置在左上角背景
                .allowsHitTesting(false)
                .zIndex(0)
            
            // 1. 整体布局：错落瀑布流
            WaterfallGrid(items: items, onImageTap: onImageTap)
                .padding(.horizontal, 16)
                .zIndex(1)
        }
    }
}

// MARK: - 瀑布流网格实现 (双列错落)
struct WaterfallGrid: View {
    let items: [TimelineItem]
    let onImageTap: (UIImage) -> Void
    
    // 简单的左右分列逻辑
    private var columns: ([TimelineItem], [TimelineItem]) {
        var left: [TimelineItem] = []
        var right: [TimelineItem] = []
        for (index, item) in items.enumerated() {
            if index % 2 == 0 {
                left.append(item)
            } else {
                right.append(item)
            }
        }
        return (left, right)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) { // 列间距 12pt
            // 左列
            LazyVStack(spacing: 12) { // 行间距 12pt
                ForEach(columns.0) { item in
                    GalleryPhotoCard(item: item, onImageTap: onImageTap)
                }
            }
            
            // 右列
            LazyVStack(spacing: 12) {
                ForEach(columns.1) { item in
                    GalleryPhotoCard(item: item, onImageTap: onImageTap)
                }
            }
        }
    }
}

// MARK: - 单图质感组件
struct GalleryPhotoCard: View {
    let item: TimelineItem
    let onImageTap: (UIImage) -> Void
    
    var body: some View {
        if let data = item.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit() // 🔥 核心：保持原图比例，不裁剪
                .clipShape(RoundedRectangle(cornerRadius: 12)) // 圆角 12px
                // 🔥 2. 单图质感：身份识别描边
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1.5) // 1.5px 半透明蓝
                )
                // 光影：微弱蓝调弥散阴影
                .shadow(color: Color.blue.opacity(0.12), radius: 8, x: 0, y: 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    onImageTap(uiImage)
                }
        }
    }
}
