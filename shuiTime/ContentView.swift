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
    @State private var showSideMenu: Bool = false
    
    // 🔥 1. 获取所有数据，用于检查状态
    @Query private var items: [TimelineItem]

    // 🔥 2. 计算属性：检查今天是否有数据
    var hasTodayContent: Bool {
        let calendar = Calendar.current
        // 遍历所有 items，只要有一个 item 的日期是今天，就返回 true
        return items.contains { item in
            calendar.isDateInToday(item.timestamp)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            
            TabView(selection: $selectedTab) {
                // TimeLineView
                TimeLineView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("今日", systemImage: "calendar.day.timeline.left")
                    }
                    .tag(0)

                InspirationView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("灵感集", systemImage: "lightbulb")
                    }
                    .tag(1)

                LookBackView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("我", systemImage: "person.crop.circle")
                    }
                    .tag(2)
            }
            .tint(.blue)
            
            // 侧滑栏 (覆盖在最上层)
            // 🔥 3. 将计算出的状态传递给 SideMenuView
            SideMenuView(isOpen: $showSideMenu, hasContentToday: hasTodayContent)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
