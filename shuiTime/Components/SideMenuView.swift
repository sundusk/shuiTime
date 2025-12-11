//
//  SideMenuView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var isOpen: Bool
    
    // 🔥 新增：接收今天是否有内容的状态
    var hasContentToday: Bool
    
    // 计算“今天”在网格中的位置 (假设最后一列是本周)
    var todayGridPosition: (col: Int, row: Int) {
        let weekday = Calendar.current.component(.weekday, from: Date()) // Sun=1...Sat=7
        // 转换：Mon=0 ... Sun=6
        let row = (weekday + 5) % 7
        return (col: 11, row: row)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            // 1. 半透明遮罩
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isOpen = false
                        }
                    }
            }
            
            // 2. 侧滑栏主体
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // --- 顶部用户信息 (保持不变) ---
                    HStack {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(Text("承").foregroundColor(.blue).bold())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("承曦")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("⚡️升级PRO")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
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
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    
                    // --- 统计数据栏 (保持不变) ---
                    HStack {
                        StatItemView(number: "2", title: "笔记")
                        Spacer()
                        StatItemView(number: "2", title: "标签")
                        Spacer()
                        StatItemView(number: "47", title: "天")
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)
                    
                    // --- 热力图 (7行 x 12列) ---
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            ForEach(0..<12, id: \.self) { col in
                                VStack(spacing: 4) {
                                    ForEach(0..<7, id: \.self) { row in
                                        
                                        // 判断格子是否是“今天”
                                        let isToday = (col == todayGridPosition.col && row == todayGridPosition.row)
                                        
                                        if isToday {
                                            // 🔥 核心逻辑修改：
                                            // 1. 始终显示绿色描边 (代表这是今天)
                                            // 2. 如果 hasContentToday 为 true，填充浅绿色；否则透明
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.green, lineWidth: 1.5)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(hasContentToday ? Color.green.opacity(0.5) : Color.clear)
                                                )
                                                .frame(width: 12, height: 12)
                                        } else {
                                            // 其他日期的样式 (保持原样或随机模拟)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(heatMapColor(col: col, row: row))
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                }
                                if col < 11 { Spacer() }
                            }
                        }
                        
                        // 月份标签 (保持不变)
                        HStack(spacing: 0) {
                            Text("10月").font(.caption2).frame(width: 50, alignment: .leading)
                            Spacer()
                            Text("11月").font(.caption2).frame(width: 50, alignment: .leading)
                            Spacer()
                            Text("12月").font(.caption2).frame(width: 50, alignment: .leading)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    
                    Spacer()
                }
                .frame(width: 300)
                .background(Color(uiColor: .systemBackground))
                .offset(x: isOpen ? 0 : -300)
                
                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
    }
    
    func heatMapColor(col: Int, row: Int) -> Color {
        let randomSeed = (col * 7 + row) * 13
        let hasData = (randomSeed % 7 == 0) || (col > 9 && row % 2 != 0)
        return hasData ? Color.green.opacity(0.7) : Color.secondary.opacity(0.15)
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

// 预览时需传入假数据
#Preview {
    SideMenuView(isOpen: .constant(true), hasContentToday: true)
}
