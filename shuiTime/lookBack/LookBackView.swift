//
//  LookBackView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) { // 稍微增加间距
                        
                        // 🔥 1. 新增：时光封面卡片 (替换了原本的统计卡片)
                        NavigationLink(destination: MomentGalleryView()) {
                                                    TimeCoverCard(
                                                        momentItem: latestMomentInMonth(date: currentMonth),
                                                        month: currentMonth
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle()) // 去掉默认的按钮点击置灰效果，保持卡片原样
                                                .padding(.top, 10)
                        
                        // 2. 热力图
                        HeatMapCard(items: allItems)
                        
                        // 3. 去年今日
                        if let lastYearItems = itemsLastYear(from: selectedDate), !lastYearItems.isEmpty {
                            LastYearCapsuleCard(
                                items: lastYearItems,
                                onTap: {
                                    self.lastYearSheetData = LastYearDataWrapper(items: lastYearItems)
                                }
                            )
                        }
                        
                        // 4. 日历视图
                        CalendarCardView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            recordedDates: getRecordedDates()
                        )
                        
                        // 5. 选中日期的详细回顾
                        DayReviewSection(
                            date: selectedDate,
                            items: itemsInDay(date: selectedDate),
                            onImageTap: { image in
                                fullScreenImage = FullScreenImage(image: image)
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
                FullScreenPhotoView(image: wrapper.image)
            }
            .sheet(item: $lastYearSheetData) { wrapper in
                LastYearDetailView(items: wrapper.items, onImageTap: { image in
                    fullScreenImage = FullScreenImage(image: image)
                })
            }
        }
    }
    
    // MARK: - 数据处理辅助函数
    
    // 获取本月最新的一张瞬影
    private func latestMomentInMonth(date: Date) -> TimelineItem? {
        let calendar = Calendar.current
        return allItems
            .filter {
                calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month) &&
                $0.type == "moment" && // 必须是瞬影
                $0.imageData != nil    // 必须有图
            }
            .sorted { $0.timestamp > $1.timestamp } // 按时间倒序
            .first
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
        guard let lastYearDate = calendar.date(byAdding: .year, value: -1, to: date) else { return nil }
        let items = allItems.filter { calendar.isDate($0.timestamp, inSameDayAs: lastYearDate) }
        return items.isEmpty ? nil : items
    }
}

// MARK: - 🔥 新增：时光封面卡片组件
struct TimeCoverCard: View {
    let momentItem: TimelineItem?
    let month: Date
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM" // 例如: January
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
            // 1. 底层叠放装饰 (模拟堆叠感)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .frame(height: 240)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                .rotationEffect(.degrees(-4)) // 向左歪一点
                .padding(.horizontal, 20)
                .opacity(0.6)
            
            // 2. 主封面卡片
            VStack(spacing: 0) {
                if let item = momentItem, let data = item.imageData, let uiImage = UIImage(data: data) {
                    // --- 有照片的状态 ---
                    HStack(spacing: 0) {
                        // 左侧齿孔
                        SprocketColumn()
                        
                        // 照片区域
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180) // 固定高度
                            .clipped()
                            // 🔥 核心需求：2px 蓝色细边框
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                        
                        // 右侧齿孔
                        SprocketColumn()
                    }
                    .background(Color.black.opacity(0.9)) // 胶片底色
                    
                    // 底部月份信息
                    HStack {
                        Text(monthString)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(.black.opacity(0.8))
                        Spacer()
                        Text(yearString)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    
                } else {
                    // --- 空状态 (本月无瞬影) ---
                    // 🔥 修正点：去掉了错误的 mainAxisAlignment 参数
                    // 使用 spacing 来控制垂直间距，效果更好
                    VStack(spacing: 8) {
                        Image(systemName: "camera.shutter.button")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("本月暂无瞬影")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(height: 240)
                    .frame(maxWidth: .infinity) // 这里的 frame 会自动让 VStack 居中显示
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray.opacity(0.2))
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // 卡片整体阴影
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            // 🔥 核心需求：随机旋转角度 (3度)
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

// MARK: - 热力图卡片 (保持不变)
struct HeatMapCard: View {
    let items: [TimelineItem]
    
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
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: startOfCurrentWeek) {
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
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(heatMapData.indices, id: \.self) { weekIndex in
                        let week = heatMapData[weekIndex]
                        VStack(spacing: 4) {
                            ForEach(week) { day in
                                HeatMapCell(day: day)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            HStack {
                Text("Less").font(.caption2).foregroundColor(.secondary)
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.1)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.4)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 10, height: 10)
                }
                Text("More").font(.caption2).foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    struct HeatMapCell: View {
        let day: HeatMapDay
        var body: some View {
            var color: Color {
                if day.count == 0 { return Color.secondary.opacity(0.1) }
                if day.count <= 2 { return Color.green.opacity(0.4) }
                return Color.green
            }
            return ZStack {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 14)
                if day.isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.primary.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
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
                    Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left").foregroundColor(.secondary) }
                    Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right").foregroundColor(.secondary) }
                }
            }
            .padding(.horizontal, 4)
            
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day).font(.caption).bold().foregroundColor(.gray).frame(maxWidth: .infinity)
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
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedDate = date } }
                    } else {
                        Text("").frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return [] }
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
    var onImageTap: (UIImage) -> Void
    
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
                        Image(systemName: "hourglass.bottomhalf.filled").font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                        Text("时光未至").font(.subheadline).foregroundColor(.gray.opacity(0.5))
                    } else {
                        Image(systemName: "wind").font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                        Text("这天没有留下痕迹").font(.subheadline).foregroundColor(.gray.opacity(0.5))
                    }
                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
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

// 列表行组件
struct CompactTimelineRow: View {
    let item: TimelineItem
    var onImageTap: ((UIImage) -> Void)?
    
    private var tags: [String] {
        item.content.split(separator: " ")
            .map { String($0) }
            .filter { $0.hasPrefix("#") && $0.count > 1 }
    }
    
    private var cleanContent: String {
        let pattern = "#[^\\s]+"
        let range = NSRange(location: 0, length: item.content.utf16.count)
        let regex = try? NSRegularExpression(pattern: pattern)
        let cleaned = regex?.stringByReplacingMatches(in: item.content, options: [], range: range, withTemplate: "") ?? item.content
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
                }
            }
            .frame(width: 50, alignment: .trailing)
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { onImageTap?(uiImage) }
                    }
                    
                    if !cleanContent.isEmpty {
                        Text(cleanContent)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if item.imageData != nil {
                        Text("分享了一张图片")
                            .font(.italic(.subheadline)())
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                if !tags.isEmpty || item.type == "inspiration" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if item.type == "inspiration" {
                                HStack(spacing: 2) {
                                    Image(systemName: "lightbulb.fill").font(.system(size: 8))
                                    Text("灵感")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(Color.yellow.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
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
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        }
    }
}
