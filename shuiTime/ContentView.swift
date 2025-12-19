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
    
    // 🔥 新增：用于控制灵感集页面的标签跳转状态
    @State private var inspirationSelectedTag: String? = nil
    
    // 获取所有数据，用于检查状态
    @Query private var items: [TimelineItem]

    // 计算属性：检查今天是否有数据
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
                // TimeLineView (Tab 0)
                TimeLineView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("今日", systemImage: "calendar.day.timeline.left")
                    }
                    .tag(0)

                // InspirationView (Tab 1)
                // 🔥 修改点：将标签选中状态传给子视图
                InspirationView(
                    showSideMenu: $showSideMenu,
                    selectedTag: $inspirationSelectedTag
                )
                    .tabItem {
                        Label("灵感集", systemImage: "lightbulb")
                    }
                    .tag(1)

                // LookBackView (Tab 2)
                LookBackView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("我", systemImage: "person.crop.circle")
                    }
                    .tag(2)
            }
            .tint(.blue)
            
            // 侧滑栏 (覆盖在最上层)
            SideMenuView(
                isOpen: $showSideMenu,
                hasContentToday: hasTodayContent, // 传递今日是否有内容的状态
                showTags: selectedTab == 1,       // 🔥 只有在灵感集页面才显示标签列表
                onTagSelected: { tag in
                    // 🔥 处理点击：
                    // 1. 设置灵感集页面的选中标签
                    inspirationSelectedTag = tag
                    // 2. 关闭侧边栏，用户就能看到跳转后的界面了
                    withAnimation {
                        showSideMenu = false
                    }
                }
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
