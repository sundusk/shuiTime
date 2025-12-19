//
//  ContentView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 导航路径管理
    @State private var path = NavigationPath()
    
    // 侧边栏状态
    @State private var showSideMenu: Bool = false
    
    // 灵感集页面选中的标签（用于传递状态）
    @State private var inspirationSelectedTag: String? = nil
    
    // 获取所有数据，用于检查状态
    @Query private var items: [TimelineItem]

    // 计算属性：检查今天是否有数据
    var hasTodayContent: Bool {
        let calendar = Calendar.current
        return items.contains { item in
            calendar.isDateInToday(item.timestamp)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .leading) {
                
                // 1. 主页面：时间线 (作为首页)
                TimeLineView(showSideMenu: $showSideMenu)
                    .navigationDestination(for: SideMenuOption.self) { option in
                        switch option {
                        case .inspiration:
                            // 跳转到灵感集
                            InspirationView(selectedTag: $inspirationSelectedTag)
                        case .lookBack:
                            // 跳转到时光回顾
                            LookBackView()
                        }
                    }
                
                // 2. 侧滑栏 (覆盖在最上层)
                SideMenuView(
                    isOpen: $showSideMenu,
                    hasContentToday: hasTodayContent,
                    showTags: false, // 首页侧边栏暂不显示标签列表，避免太杂
                    onTagSelected: { _ in },
                    onMenuSelected: { option in
                        // 关闭侧边栏
                        withAnimation {
                            showSideMenu = false
                        }
                        // 延迟一点点跳转，让动画更顺畅
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            path.append(option)
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimelineItem.self, inMemory: true)
}
