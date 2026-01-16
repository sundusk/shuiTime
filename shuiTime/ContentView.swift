//
//  ContentView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    // 获取所有数据 (如果后续红点提示需要，可以保留，否则也可以删掉)
    @Query private var items: [TimelineItem]

    var body: some View {
        // 🔥 移除 ZStack 和 SideMenu，直接返回 TabView
        TabView(selection: $selectedTab) {
            
            // 1. 时间线
            TimeLineView() // 不需要传 showSideMenu 了
                .tabItem {
                    Label("时间线", systemImage: "calendar.day.timeline.left")
                }
                .tag(0)

            // 2. 瞬息
            InspirationView() // 不需要传参了，内部自己管理状态
                .tabItem {
                    Label("瞬息", systemImage: "lightbulb")
                }
                .tag(1)

            // 3. 时光回顾
            LookBackView()
                .tabItem {
                    Label("时光回顾", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
