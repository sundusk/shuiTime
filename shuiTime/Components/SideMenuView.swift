//
//  SideMenuView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData

// 定义导航选项
enum SideMenuOption {
    case inspiration
    case lookBack
}

struct SideMenuView: View {
    @Binding var isOpen: Bool
    
    // 接收今天是否有内容的状态
    var hasContentToday: Bool
    
    // (已弃用，不再通过此属性控制显示，保留是为了兼容调用)
    var showTags: Bool
    
    // 点击标签的回调
    var onTagSelected: ((String) -> Void)?
    
    // 点击菜单项的回调
    var onMenuSelected: ((SideMenuOption) -> Void)?
    
    // 获取数据库所有数据
    @Query private var allItems: [TimelineItem]
    
    // MARK: - 统计逻辑
    var noteCount: Int { allItems.count }
    
    var tagCount: Int { allTags.count }
    
    // 计算所有唯一的标签
    var allTags: [String] {
        let inspirationItems = allItems // 统计所有类型
        var uniqueTags = Set<String>()
        for item in inspirationItems {
            let lines = item.content.components(separatedBy: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                for word in words {
                    let stringWord = String(word)
                    // 数据本身包含 "#"，例如 "#标签"
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
                    
                    // --- 1. 顶部用户信息 (固定) ---
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
                    }
                    .padding(.top, 60).padding(.horizontal, 24).padding(.bottom, 20)
                    
                    // 使用 ScrollView 包裹剩余内容，防止溢出
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 🔥 交换位置：先显示统计数据
                            // --- 2. 统计数据 ---
                            HStack {
                                StatItemView(number: "\(noteCount)", title: "笔记")
                                Spacer()
                                StatItemView(number: "\(tagCount)", title: "标签")
                                Spacer()
                                StatItemView(number: "\(dayCount)", title: "天")
                            }
                            .padding(.horizontal, 24)
                            
                            // 🔥 交换位置：后显示热力图
                            // --- 3. 热力图 ---
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
                            
                            Divider().padding(.horizontal, 24)
                            
                            // --- 4. 导航菜单区域 ---
                            VStack(spacing: 8) {
                                MenuButton(title: "灵感集", icon: "lightbulb.fill", color: .yellow) {
                                    onMenuSelected?(.inspiration)
                                }
                                
                                MenuButton(title: "时光回顾", icon: "clock.arrow.circlepath", color: .purple) {
                                    onMenuSelected?(.lookBack)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Divider().padding(.horizontal, 24)
                            
                            // --- 5. 全部标签区域 ---
                            VStack(alignment: .leading, spacing: 8) {
                                Text("全部标签")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 24)
                                
                                if allTags.isEmpty {
                                    Text("暂无标签")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 24)
                                } else {
                                    VStack(spacing: 1) {
                                        ForEach(allTags, id: \.self) { tag in
                                            Button(action: { onTagSelected?(tag) }) {
                                                HStack {
                                                    // tag 变量已经包含 #
                                                    Text(tag)
                                                        .font(.body)
                                                        .foregroundColor(.primary)
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundColor(.gray.opacity(0.3))
                                                }
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 16)
                                                // 🔥 修改：移除了背景颜色和圆角，只保留内容
                                                .contentShape(Rectangle()) // 保证整行可点击
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // 底部留白
                            Spacer().frame(height: 40)
                        }
                    }
                    
                    // 底部版本号
                    VStack {
                        Divider()
                        Text("v1.1.0").font(.caption).foregroundColor(.gray.opacity(0.5)).padding()
                    }
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

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
    }
}

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
