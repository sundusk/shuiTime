//
//  ContentView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 1. 核心导航路径管理
    @State private var path = NavigationPath()
    
    @State private var showSideMenu: Bool = false
    @State private var inspirationSelectedTag: String? = nil
    @Query private var items: [TimelineItem]

    var hasTodayContent: Bool {
        let calendar = Calendar.current
        return items.contains { calendar.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .leading) {
                // 主页面
                TimeLineView(showSideMenu: $showSideMenu)
                    // 1. 处理侧边栏菜单跳转
                    .navigationDestination(for: SideMenuOption.self) { option in
                        switch option {
                        case .inspiration:
                            InspirationView(selectedTag: $inspirationSelectedTag)
                        case .lookBack:
                            LookBackView()
                        }
                    }
                    // 2. 🔥 核心修复：处理标签点击 (String) 跳转
                    // 只有在这里注册了，TimeLineView 里的标签点击才不会报错
                    .navigationDestination(for: String.self) { tag in
                        TagFilterView(tagName: tag)
                    }
                
                // 侧边栏
                SideMenuView(
                    isOpen: $showSideMenu,
                    hasContentToday: hasTodayContent,
                    showTags: true, // 这里虽然传入 true，但 SideMenuView 内部已经修改为始终显示
                    // 🔥 处理标签点击跳转
                    onTagSelected: { tag in
                        withAnimation { showSideMenu = false }
                        // 延迟跳转，保证侧边栏收起动画流畅
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            path.append(tag)
                        }
                    },
                    onMenuSelected: { option in
                        withAnimation { showSideMenu = false }
                        // 延迟跳转，保证侧边栏收起动画流畅
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            path.append(option)
                        }
                    }
                )
            }
        }
    }
}
