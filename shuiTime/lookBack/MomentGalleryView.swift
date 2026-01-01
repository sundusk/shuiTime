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
        ZStack {
            // 背景：深色桌面纹理感 (使用极深的灰/黑，避免纯黑死板)
            Color(uiColor: .systemGroupedBackground) // 或者使用自定义的深灰色
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 60) { // 月份之间的大间距
                    ForEach(groupedMoments, id: \.0) { date, items in
                        ScatteredMonthSection(date: date, items: items) { image in
                            self.fullScreenImage = FullScreenImage(image: image)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("时光长廊")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
    }
}

// MARK: - 散落风格的月份模块
struct ScatteredMonthSection: View {
    let date: Date
    let items: [TimelineItem]
    let onImageTap: (UIImage) -> Void
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M" // 比如 1, 12
        return formatter.string(from: date)
    }
    
    var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. 背景大水印 (月份) - 增加一点艺术感
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(monthString)
                    .font(.system(size: 120, weight: .black, design: .serif))
                    .foregroundColor(Color.primary.opacity(0.05))
                    .italic()
                Text("月")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color.primary.opacity(0.03))
                    .padding(.bottom, 20)
            }
            .offset(x: 20, y: -50)
            .allowsHitTesting(false)
            
            // 2. 散落照片墙
            ScatteredGrid(items: items, onImageTap: onImageTap)
        }
    }
}

// MARK: - 错位瀑布流布局 (核心逻辑)
struct ScatteredGrid: View {
    let items: [TimelineItem]
    let onImageTap: (UIImage) -> Void
    
    // 分列
    private var columns: ([TimelineItem], [TimelineItem]) {
        var left: [TimelineItem] = []
        var right: [TimelineItem] = []
        for (index, item) in items.enumerated() {
            if index % 2 == 0 { left.append(item) } else { right.append(item) }
        }
        return (left, right)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // --- 左列 ---
            LazyVStack(spacing: 30) {
                ForEach(columns.0) { item in
                    PhotoPaperCard(item: item, onImageTap: onImageTap)
                        // 左列稍微往右偏一点，制造重叠感
                        .offset(x: 10)
                }
            }
            .frame(maxWidth: .infinity)
            
            // --- 右列 ---
            LazyVStack(spacing: 30) {
                // 右列整体下沉 60pt，打破水平对齐，形成错落感
                Spacer().frame(height: 60)
                ForEach(columns.1) { item in
                    PhotoPaperCard(item: item, onImageTap: onImageTap)
                        // 右列稍微往左偏
                        .offset(x: -10)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - 拟真照片卡片 (PhotoPaperCard)
struct PhotoPaperCard: View {
    let item: TimelineItem
    let onImageTap: (UIImage) -> Void
    
    // 基于 ID 生成确定性的随机值，防止滚动时抖动
    private var randomRotation: Double {
        return Double(item.id.hashValue % 100) / 100.0 * 8.0 - 4.0 // -4 到 +4 度
    }
    
    private var randomScale: CGFloat {
        let val = abs(Double(item.id.hashValue % 100)) / 100.0
        return 0.95 + (val * 0.1) // 0.95 到 1.05 大小浮动
    }
    
    private var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: item.timestamp)
    }
    
    var body: some View {
        if let data = item.imageData, let uiImage = UIImage(data: data) {
            Button(action: { onImageTap(uiImage) }) {
                VStack(spacing: 0) {
                    // 图片层
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        // 模拟洗印质感：给图片加一层极淡的内发光/纹理
                        .overlay(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .clear, .black.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(2) // 图片本身的角不需要太圆，模拟相纸切割
                        .padding(10)     // 白边留白宽度
                        .background(Color.white) // 相纸底色
                    
                    // 底部文字留白 (类似拍立得，或者只是普通的白边)
                    // 这里我们做成普通的均匀白边，更有生活照的感觉
                }
                // --- 卡片物理质感 ---
                .background(Color.white)
                .cornerRadius(4) // 相纸整体微圆角 (相纸一般很尖，或者微圆)
                // 1. 投影：模拟散落在桌面的悬浮感
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 2, y: 4)
                // 2. 内阴影/高光：模拟纸张厚度 (使用 overlay stroke 实现)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                        .blendMode(.screen) // 混合模式增加透亮感
                )
                // --- 随机变换 ---
                .rotationEffect(.degrees(randomRotation))
                .scaleEffect(randomScale)
                // --- 胶片日期水印 (Optional, 增加复古感) ---
                .overlay(alignment: .bottomTrailing) {
                    Text(dateStamp)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(uiColor: .init(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7))) // 经典的橙色日期
                        .padding(14) // 考虑到白边
                        .opacity(0.8)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
            .buttonStyle(SquishButtonStyle()) // 点击时的弹性反馈
        }
    }
}

// MARK: - 辅助组件

// 简单的弹性按钮样式
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0) // 点击时稍微变亮
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
