//
//  LookBackView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftData
import SwiftUI

// 数据包装器，用于控制 sheet 弹窗
struct LastYearDataWrapper: Identifiable {
    let id = UUID()
    let items: [TimelineItem]
}

struct LookBackView: View {
    @Environment(\.modelContext) private var modelContext

    // 查询所有数据
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]

    // 当前选中的日期
    @State private var selectedDate: Date = Date()
    // 当前显示的月份
    @State private var currentMonth: Date = Date()

    // 全屏图片状态
    @State private var fullScreenImage: FullScreenImage?

    // sheet 弹窗控制
    @State private var lastYearSheetData: LastYearDataWrapper?

    // 时光墙封面：缓存一次，避免 body 重算导致“随机”抖动
    @State private var coverMomentItem: TimelineItem?

    var body: some View {
        NavigationStack {
            ZStack {
                // 🔥 1. 新增：流动的蓝色弥散背景 (替代原本的灰色背景)
                MeshGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {  // 稍微增加间距

                        // 🔥 2. 升级：时光封面卡片 (多层堆叠 + 色差质感)
                        NavigationLink(destination: MomentGalleryView()) {
                            TimeCoverCard(
                                momentItem: coverMomentItem,
                                month: currentMonth
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 10)
                        .shadow(color: .blue.opacity(0.05), radius: 20, x: 0, y: 10)  // 封面增加额外的环境光阴影

                        // 3. 热力图
                        HeatMapCard(items: allItems)

                        // 4. 去年今日
                        if let lastYearItems = itemsLastYear(from: selectedDate),
                            !lastYearItems.isEmpty
                        {
                            LastYearCapsuleCard(
                                items: lastYearItems,
                                onTap: {
                                    self.lastYearSheetData = LastYearDataWrapper(
                                        items: lastYearItems)
                                }
                            )
                        }

                        // 5. 日历视图
                        CalendarCardView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            recordedDates: getRecordedDates()
                        )

                        // 6. 选中日期的详细回顾
                        DayReviewSection(
                            date: selectedDate,
                            items: itemsInDay(date: selectedDate),
                            onImageTap: { item in
                                fullScreenImage = FullScreenImage(
                                    image: UIImage(data: item.imageData!)!,
                                    isLivePhoto: item.isLivePhoto,
                                    videoData: item.livePhotoVideoData
                                )
                            }
                        )
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("时光回顾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        withAnimation {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                    }) {
                        Text("回今天").font(.caption).bold()
                    }
                }
            }
            .fullScreenCover(item: $fullScreenImage) { wrapper in
                FullScreenPhotoView(imageEntity: wrapper)
            }
            .sheet(item: $lastYearSheetData) { wrapper in
                LastYearDetailView(
                    items: wrapper.items,
                    onImageTap: { item in
                        fullScreenImage = FullScreenImage(
                            image: UIImage(data: item.imageData!)!,
                            isLivePhoto: item.isLivePhoto,
                            videoData: item.livePhotoVideoData
                        )
                    })
            }
        }
        .onAppear { refreshCoverMomentItem(forceReshuffleFallback: true) }
        .onChange(of: currentMonth) { _, _ in refreshCoverMomentItem(forceReshuffleFallback: true) }
        .onChange(of: allItems.count) { _, _ in refreshCoverMomentItem(forceReshuffleFallback: false) }
    }

    // MARK: - 数据处理辅助函数

    // 获取指定月份的“瞬影”(有图)列表，按时间倒序
    private func momentsInMonth(_ date: Date) -> [TimelineItem] {
        let calendar = Calendar.current
        return allItems
            .filter {
                calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month)
                    && $0.type == "moment"
                    && $0.imageData != nil
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func fallbackMomentFromPreviousMonth(for date: Date) -> TimelineItem? {
        let calendar = Calendar.current
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) else {
            return nil
        }
        return momentsInMonth(previousMonth).randomElement()
    }

    // 时光墙封面逻辑：
    // - 本月有瞬影：取最新一张
    // - 本月无瞬影：随机展示上个月的一张瞬影作为封面（并缓存，避免抖动）
    private func refreshCoverMomentItem(forceReshuffleFallback: Bool) {
        let thisMonthMoments = momentsInMonth(currentMonth)
        if let latest = thisMonthMoments.first {
            coverMomentItem = latest
            return
        }

        if !forceReshuffleFallback, coverMomentItem != nil {
            return
        }

        coverMomentItem = fallbackMomentFromPreviousMonth(for: currentMonth)
    }

    private func getRecordedDates() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = allItems.map { formatter.string(from: $0.timestamp) }
        return Set(dates)
    }

    private func itemsInDay(date: Date) -> [TimelineItem] {
        let calendar = Calendar.current
        return allItems.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    private func itemsLastYear(from date: Date) -> [TimelineItem]? {
        let calendar = Calendar.current
        guard let lastYearDate = calendar.date(byAdding: .year, value: -1, to: date) else {
            return nil
        }
        let items = allItems.filter { calendar.isDate($0.timestamp, inSameDayAs: lastYearDate) }
        return items.isEmpty ? nil : items
    }
}

// MARK: - 🔥 新增：流动的蓝色弥散背景组件
// MARK: - 🔥 修复：流动的蓝色弥散背景组件（已适配深色模式）
struct MeshGradientBackground: View {
    @State private var animate = false
    @Environment(\.colorScheme) var colorScheme  // 获取当前颜色模式

    var body: some View {
        ZStack {
            // 1. 基底色：使用系统自适应背景色
            // Light: 浅灰白 / Dark: 纯黑或深灰
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            // 2. 弥散光球组
            GeometryReader { geo in
                ZStack {
                    // 左上：深邃蓝
                    Circle()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.08))  // 深色模式下稍微加深透明度
                        .frame(width: geo.size.width * 0.8)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
                        .offset(x: animate ? 20 : -20, y: animate ? 10 : -10)

                    // 右中：清透青
                    Circle()
                        .fill(Color.cyan.opacity(colorScheme == .dark ? 0.15 : 0.06))
                        .frame(width: geo.size.width * 0.6)
                        .blur(radius: 50)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.2)
                        .offset(x: animate ? -15 : 15, y: animate ? -15 : 15)

                    // 左下：极淡紫 (增加层次)
                    Circle()
                        .fill(Color.indigo.opacity(colorScheme == .dark ? 0.15 : 0.05))
                        .frame(width: geo.size.width * 0.7)
                        .blur(radius: 70)
                        .offset(x: -geo.size.width * 0.1, y: geo.size.height * 0.4)
                        .scaleEffect(animate ? 1.1 : 1.0)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // 极慢的呼吸动画
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - 时光封面卡片组件 (优化引导版 - 已适配深色模式)
struct TimeCoverCard: View {
    let momentItem: TimelineItem?
    let month: Date
    @Environment(\.colorScheme) var colorScheme  // 获取当前颜色模式

    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"  // 例如: January
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: month).uppercased()
    }

    var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: month)
    }

    var body: some View {
        ZStack {
            // --- 装饰层 1 (最底层) ---
            RoundedRectangle(cornerRadius: 12)
                // 🔥 适配：使用自适应背景色
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(height: 250)
                .shadow(color: .black.opacity(0.05), radius: 4, x: -2, y: 2)
                .rotationEffect(.degrees(-6))
                .offset(x: -12, y: 8)
                .opacity(0.8)

            // --- 装饰层 2 (中间层) ---
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .frame(height: 250)
                .shadow(color: .black.opacity(0.08), radius: 5, x: 2, y: 3)
                .rotationEffect(.degrees(-3))
                .offset(x: -4, y: 4)
                .padding(.horizontal, 20)

            // --- 主封面卡片 (顶层) ---
            VStack(spacing: 0) {
                if let item = momentItem, let data = item.imageData,
                    let uiImage = UIImage(data: data)
                {
                    // --- 有照片的状态 ---
                    HStack(spacing: 0) {
                        SprocketColumn()  // 胶卷齿孔

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                            )
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)

                        SprocketColumn()
                    }
                    // 胶卷背景保持深色（模拟胶卷）
                    .background(Color.black.opacity(0.9))

                    // 底部区域
                    VStack(spacing: 4) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(monthString)
                                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                                // 🔥 适配：改为 primary，深色模式下变白
                                .foregroundColor(.primary)

                            Spacer()

                            Text(yearString)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray.opacity(0.6))
                        }

                        // 中文副标题
                        Text("— 点击进入时光墙 —")
                            .font(.caption2)
                            .fontWeight(.light)
                            .kerning(4)
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    // 🔥 适配：改为自适应背景
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                } else {
                    // --- 空状态 ---
                    VStack(spacing: 8) {
                        Image(systemName: "camera.shutter.button")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("本月暂无瞬影").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    // 🔥 适配：使用自适应背景
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray.opacity(0.2))
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 深色模式下阴影稍微加重一点点，或者保持不变
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 8, x: 0, y: 4)
            .rotationEffect(.degrees(2))
        }
        .padding(.vertical, 10)
    }
}

// 胶卷齿孔装饰组件
struct SprocketColumn: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<8) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 8, height: 12)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
    }
}

// MARK: - 增强交互版热力图卡片
struct HeatMapCard: View {
    let items: [TimelineItem]

    // 🔥 新增：选中的热力图日期
    @State private var selectedHeatMapDate: Date? = nil

    struct HeatMapDay: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        let isToday: Bool
    }

    var heatMapData: [[HeatMapDay]] {
        var weeks: [[HeatMapDay]] = []
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2

        guard let startOfCurrentWeek = calendar.date(from: components) else { return [] }

        let notesByDay = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.timestamp)
        }.mapValues { $0.count }

        for weekOffset in (0..<16).reversed() {
            var weekDays: [HeatMapDay] = []
            if let weekStart = calendar.date(
                byAdding: .weekOfYear, value: -weekOffset, to: startOfCurrentWeek)
            {
                for dayOffset in 0..<7 {
                    if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                        let startOfDay = calendar.startOfDay(for: date)
                        let count = notesByDay[startOfDay] ?? 0
                        let isToday = calendar.isDateInToday(date)
                        weekDays.append(HeatMapDay(date: date, count: count, isToday: isToday))
                    }
                }
            }
            weeks.append(weekDays)
        }
        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录热力")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack {
                Spacer(minLength: 0)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(heatMapData.indices, id: \.self) { weekIndex in
                            let week = heatMapData[weekIndex]
                            VStack(spacing: 4) {
                                ForEach(week) { day in
                                    // 🔥 修改：传入选中状态和点击事件
                                    HeatMapCell(
                                        day: day,
                                        isSelected: Calendar.current.isDate(
                                            day.date,
                                            inSameDayAs: selectedHeatMapDate ?? Date.distantPast),
                                        onTap: {
                                            withAnimation(.spring(response: 0.3)) {
                                                if let current = selectedHeatMapDate,
                                                    Calendar.current.isDate(
                                                        current, inSameDayAs: day.date)
                                                {
                                                    selectedHeatMapDate = nil  // 再次点击取消选中
                                                } else {
                                                    selectedHeatMapDate = day.date
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            HStack {
                // 左侧图例
                Text("Less").font(.caption2).foregroundColor(.secondary)
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.1)).frame(
                        width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.4)).frame(
                        width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 10, height: 10)
                }
                Text("More").font(.caption2).foregroundColor(.secondary)

                Spacer()

                // 🔥 蓝色标记区域：显示选中的日期
                if let date = selectedHeatMapDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(formatDate(date))
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .transition(
                        .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // 日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }

    struct HeatMapCell: View {
        let day: HeatMapDay
        let isSelected: Bool  // 新增：选中状态
        let onTap: () -> Void  // 新增：点击回调

        var body: some View {
            let color: Color = {
                if day.count == 0 { return Color.secondary.opacity(0.1) }
                if day.count <= 2 { return Color.green.opacity(0.4) }
                return Color.green
            }()

            return ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 14, height: 14)

                // 今日标记
                if day.isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.primary.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }

                // 🔥 选中后的视觉反馈 (蓝色外边框)
                if isSelected {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }  // 触发点击
        }
    }
}

// MARK: - 日历卡片组件 (保持不变)
struct CalendarCardView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let recordedDates: Set<String>

    private let calendar = Calendar.current
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(monthYearString(currentMonth)).font(.title3).bold().foregroundColor(.primary)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left").foregroundColor(.secondary)
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)

            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day).font(.caption).bold().foregroundColor(.gray).frame(
                        maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasData: hasData(on: date)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { selectedDate = date }
                        }
                    } else {
                        Text("").frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        // 🔥 适配新背景
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation { currentMonth = newMonth }
        }
    }
    func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 MM月"
        return formatter.string(from: date)
    }
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
            let firstDayOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let paddingDays = firstWeekday - 1
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    func hasData(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return recordedDates.contains(formatter.string(from: date))
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasData: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                .frame(width: 32, height: 32)
                .background(isSelected ? Circle().fill(Color.blue) : nil)
                .overlay(isToday && !isSelected ? Circle().stroke(Color.blue, lineWidth: 1) : nil)

            Circle()
                .fill(hasData ? (isSelected ? .white.opacity(0.8) : Color.blue) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(height: 40)
    }
}

// MARK: - 选中日期详情组件 (保持不变)
struct DayReviewSection: View {
    let date: Date
    let items: [TimelineItem]
    var onImageTap: (TimelineItem) -> Void

    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(dateFormatted(date)).font(.headline).foregroundColor(.secondary)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count) 条记忆")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 4)

            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 20)
                    if isFuture {
                        Image(systemName: "hourglass.bottomhalf.filled").font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("时光未至").font(.subheadline).foregroundColor(.gray.opacity(0.5))
                    } else {
                        Image(systemName: "wind").font(.system(size: 40)).foregroundColor(
                            .gray.opacity(0.3))
                        Text("这天没有留下痕迹").font(.subheadline).foregroundColor(.gray.opacity(0.5))
                    }
                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity)
                .padding()
                // 🔥 适配新背景：增加透明度
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        CompactTimelineRow(item: item, onImageTap: onImageTap)
                    }
                }
            }
        }
    }

    func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 优化后的列表行组件 (支持瞬影标记)
struct CompactTimelineRow: View {
    let item: TimelineItem
    var onImageTap: ((TimelineItem) -> Void)?

    // 判断是否为瞬影类型
    private var isMoment: Bool {
        item.type == "moment"
    }

    private var tags: [String] {
        item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }

    private var cleanContent: String {
        let pattern = "#[^\\s]+"
        let range = NSRange(location: 0, length: item.content.utf16.count)
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned =
            regex?.stringByReplacingMatches(
                in: item.content, options: [], range: range, withTemplate: "") ?? item.content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左侧时间与标记
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                if item.type == "inspiration" {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                } else if isMoment {
                    // 🔥 瞬影专属标记小圆点
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 50, alignment: .trailing)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: isMoment ? 80 : 60, height: isMoment ? 80 : 60)  // 瞬影图片略大
                                .cornerRadius(8)
                                .clipped()
                                // 🔥 瞬影蓝色边框识别
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isMoment ? Color.blue.opacity(0.5) : Color.clear,
                                            lineWidth: 1.5)
                                )

                            if isMoment {
                                // 🔥 蓝色“瞬影”标签
                                Text("瞬影")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                    .offset(x: 5, y: -5)
                            }
                        }
                        .onTapGesture { onImageTap?(item) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if !cleanContent.isEmpty {
                            Text(cleanContent)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(4)
                        } else if isMoment {
                            Text("捕捉了一个瞬影")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                        } else if item.imageData != nil {
                            Text("分享了一张图片")
                                .font(.italic(.subheadline)())
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 标签展示
                if !tags.isEmpty || item.type == "inspiration" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if item.type == "inspiration" {
                                TagLabel(text: "灵感", color: .orange, icon: "lightbulb.fill")
                            }
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .background(Color.blue.opacity(0.08))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isMoment
                    ? Color.blue.opacity(0.03) : Color(uiColor: .secondarySystemGroupedBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isMoment ? Color.blue.opacity(0.1) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// 辅助子组件：统一标签样式
struct TagLabel: View {
    let text: String
    let color: Color
    let icon: String?

    var body: some View {
        HStack(spacing: 2) {
            if let icon = icon {
                Image(systemName: icon).font(.system(size: 8))
            }
            Text(text)
        }
        .font(.system(size: 10, weight: .bold))
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}
