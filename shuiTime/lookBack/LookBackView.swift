//
//  LookBackView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import UIKit

struct LookBackView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有数据，用于统计和日历标记
    @Query(sort: \TimelineItem.timestamp, order: .reverse)
    private var allItems: [TimelineItem]
    
    // 当前选中的日期
    @State private var selectedDate: Date = Date()
    // 当前显示的月份（用于日历翻页）
    @State private var currentMonth: Date = Date()
    
    // 全屏图片状态
    @State private var fullScreenImage: FullScreenImage?
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. 顶部统计卡片 (本月概览)
                    StatsHeaderView(items: itemsInMonth(date: currentMonth))
                        .padding(.top, 10)
                    
                    // 2. 自定义日历视图
                    CalendarCardView(
                        currentMonth: $currentMonth,
                        selectedDate: $selectedDate,
                        recordedDates: getRecordedDates()
                    )
                    
                    // 3. 选中日期的详细回顾
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
        // 图片全屏浏览
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenPhotoView(image: wrapper.image)
        }
    }
    
    // MARK: - 数据处理辅助函数
    
    private func getRecordedDates() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = allItems.map { formatter.string(from: $0.timestamp) }
        return Set(dates)
    }
    
    private func itemsInMonth(date: Date) -> [TimelineItem] {
        let calendar = Calendar.current
        return allItems.filter { calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
    }
    
    private func itemsInDay(date: Date) -> [TimelineItem] {
        let calendar = Calendar.current
        return allItems.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
}

// MARK: - 1. 顶部统计组件
struct StatsHeaderView: View {
    let items: [TimelineItem]
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "本月记录", value: "\(items.count)", unit: "条", icon: "doc.text.fill", color: .blue)
            
            // 🔥 修复数据逻辑：统计 (类型为灵感 OR 标记为高亮) 的数量，与灵感集保持一致
            StatCard(
                title: "灵感捕捉",
                value: "\(items.filter { $0.type == "inspiration" || $0.isHighlight }.count)",
                unit: "个",
                icon: "lightbulb.fill",
                color: .yellow
            )
            
            StatCard(title: "影像瞬间", value: "\(items.filter { $0.imageData != nil }.count)", unit: "张", icon: "photo.fill", color: .purple)
        }
    }
}

struct StatCard: View {
    let title: String, value: String, unit: String, icon: String, color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Spacer()
            }
            .font(.caption)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title2).bold().foregroundColor(.primary)
                Text(unit).font(.caption2).foregroundColor(.secondary)
            }
            
            Text(title).font(.caption2).foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 2. 日历卡片组件 (保持不变)
struct CalendarCardView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let recordedDates: Set<String>
    
    private let calendar = Calendar.current
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(monthYearString(currentMonth))
                    .font(.title3).bold()
                    .foregroundColor(.primary)
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
                    } else { Text("").frame(height: 36) }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) { withAnimation { currentMonth = newMonth } }
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
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) { days.append(date) }
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
    let date: Date, isSelected: Bool, isToday: Bool, hasData: Bool
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                .frame(width: 32, height: 32)
                .background(isSelected ? Circle().fill(Color.blue) : nil)
                .overlay(isToday && !isSelected ? Circle().stroke(Color.blue, lineWidth: 1) : nil)
            Circle().fill(hasData ? (isSelected ? .white.opacity(0.8) : Color.blue) : Color.clear).frame(width: 4, height: 4)
        }
        .frame(height: 40)
    }
}

// MARK: - 3. 选中日期详情组件
struct DayReviewSection: View {
    let date: Date
    let items: [TimelineItem]
    var onImageTap: ((UIImage) -> Void)?
    
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
                        .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
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
                .frame(maxWidth: .infinity).padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5)).cornerRadius(12)
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

// MARK: - 紧凑型列表行
struct CompactTimelineRow: View {
    let item: TimelineItem
    var onImageTap: ((UIImage) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间
            Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
                .padding(.top, 4)
            
            // 内容卡片
            HStack(alignment: .top, spacing: 8) {
                // 图片
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { onImageTap?(uiImage) }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 🔥 内容富文本（标签变蓝 + 灯泡）
                    if !item.content.isEmpty {
                        Text(getAttributedContent(item))
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    } else {
                        Text("一张图片")
                            .font(.italic(.caption)())
                            .foregroundColor(.secondary)
                    }
                    
                    // 🔥 灵感标签 (如果是灵感类型，显示黄色标签)
                    if item.type == "inspiration" {
                        Text("灵感")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // 🔥 解析内容：标签变蓝 + 插入灯泡图标
    private func getAttributedContent(_ item: TimelineItem) -> AttributedString {
        var fullString = AttributedString("")
        
        // 如果有高亮，添加灯泡图标
        if item.isHighlight {
            var imageAttr = AttributedString(String(localized: "💡 ")) // 使用 emoji
            imageAttr.font = .system(size: 14)
            fullString.append(imageAttr)
        }
        
        let content = item.content
        var attrContent = AttributedString(content)
        
        // 匹配 #标签 并设为蓝色
        if let regex = try? NSRegularExpression(pattern: "#[^\\s]*", options: []) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if let range = Range(match.range, in: content) {
                    if let attrRange = attrContent.range(of: String(content[range])) {
                         attrContent[attrRange].foregroundColor = .blue
                    }
                }
            }
        }
        
        fullString.append(attrContent)
        return fullString
    }
}
