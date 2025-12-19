//
//  SideMenuView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

struct SideMenuView: View {
    @Binding var isOpen: Bool
    // 🔥 1. 点击标签的回调闭包
    var onTagSelected: ((String) -> Void)?
    
    // 获取数据库所有数据
    @Query private var allItems: [TimelineItem]
    
    // MARK: - 统计逻辑
    var noteCount: Int { allItems.count }
    
    var tagCount: Int { allTags.count }
    
    // 计算所有唯一的标签
    var allTags: [String] {
        let inspirationItems = allItems.filter { $0.type == "inspiration" }
        var uniqueTags = Set<String>()
        for item in inspirationItems {
            let lines = item.content.components(separatedBy: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                for word in words {
                    let stringWord = String(word)
                    if stringWord.hasPrefix("#") && stringWord.count > 1 {
                        uniqueTags.insert(stringWord)
                    }
                }
            }
        }
        return Array(uniqueTags).sorted()
    }
    
    var dayCount: Int {
        let timelineItems = allItems.filter { $0.type == "timeline" }
        let uniqueDays = Set(timelineItems.map { Calendar.current.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
    }
    
    // MARK: - 热力图数据
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
        
        let notesByDay = Dictionary(grouping: allItems) { item in
            calendar.startOfDay(for: item.timestamp)
        }.mapValues { $0.count }
        
        for weekOffset in (0..<17).reversed() {
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
        ZStack(alignment: .leading) {
            
            // 遮罩
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { isOpen = false } }
            }
            
            // 侧滑栏主体
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // --- 顶部用户信息 ---
                    HStack {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(Text("M").foregroundColor(.blue).bold())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Momo").font(.headline).foregroundColor(.primary)
                                    Text("PRO").font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15)).foregroundColor(.orange).cornerRadius(4)
                                }
                            }
                        }
                        Spacer()
                        HStack(spacing: 20) {
                            Image(systemName: "bell")
                            Image(systemName: "hexagon")
                        }
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    }
                    .padding(.top, 60).padding(.horizontal, 24).padding(.bottom, 30)
                    
                    // --- 统计数据 ---
                    HStack {
                        StatItemView(number: "\(noteCount)", title: "笔记")
                        Spacer()
                        StatItemView(number: "\(tagCount)", title: "标签")
                        Spacer()
                        StatItemView(number: "\(dayCount)", title: "天")
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                    
                    // --- 热力图 ---
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 3) {
                            ForEach(heatMapData.indices, id: \.self) { weekIndex in
                                let week = heatMapData[weekIndex]
                                VStack(spacing: 3) {
                                    ForEach(week) { day in
                                        HeatMapCell(day: day)
                                    }
                                }
                            }
                        }
                        
                        // 底部说明
                        HStack {
                            Text("Less").font(.caption2).foregroundColor(.secondary)
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.1)).frame(width: 8, height: 8)
                                RoundedRectangle(cornerRadius: 1).fill(Color.green.opacity(0.4)).frame(width: 8, height: 8)
                                RoundedRectangle(cornerRadius: 1).fill(Color.green).frame(width: 8, height: 8)
                            }
                            Text("More").font(.caption2).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    
                    // --- 🔥 全部标签区域 ---
                    VStack(alignment: .leading, spacing: 12) {
                        // 标题栏
                        HStack {
                            Text("全部标签")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Spacer()
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if allTags.isEmpty {
                            Text("暂无标签").font(.caption).foregroundColor(.gray)
                                .padding(.top, 10)
                        } else {
                            // 🔥 修改点：添加 showsIndicators: false 隐藏滚动条
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(allTags, id: \.self) { tag in
                                        Button(action: {
                                            // 触发跳转回调
                                            onTagSelected?(tag)
                                        }) {
                                            HStack {
                                                // 左侧 # 号
                                                Text("#")
                                                    .font(.system(size: 22, weight: .bold))
                                                    .foregroundColor(.secondary.opacity(0.7))
                                                
                                                // 标签文字
                                                Text(tag.replacingOccurrences(of: "#", with: ""))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                // 右侧 ... 图标
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 8)
                                            .contentShape(Rectangle()) // 确保点击区域铺满整行
                                        }
                                    }
                                }
                                .padding(.bottom, 20)
                            }
                            .frame(maxHeight: 220) // 限制高度
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Text("v1.0.1").font(.caption).foregroundColor(.gray.opacity(0.5)).padding()
                }
                .frame(width: 300)
                .background(Color(uiColor: .systemBackground))
                .offset(x: isOpen ? 0 : -300)
                
                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
    }
}

// MARK: - 辅助组件
struct HeatMapCell: View {
    let day: SideMenuView.HeatMapDay
    var body: some View {
        var color: Color {
            if day.count == 0 { return Color.secondary.opacity(0.1) }
            if day.count <= 2 { return Color.green.opacity(0.4) }
            return Color.green
        }
        return ZStack {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            if day.isToday {
                RoundedRectangle(cornerRadius: 2).stroke(Color.primary.opacity(0.5), lineWidth: 1).frame(width: 12, height: 12)
            }
        }
    }
}

struct StatItemView: View {
    let number: String
    let title: String
    var body: some View {
        VStack(spacing: 4) {
            Text(number).font(.title2).fontWeight(.bold).foregroundColor(.primary)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
    }
}
