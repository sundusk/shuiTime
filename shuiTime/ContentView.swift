import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showSideMenu: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            
            TabView(selection: $selectedTab) {
                // 1. 传给 TimeLineView (保持不变)
                TimeLineView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("今日", systemImage: "calendar.day.timeline.left")
                    }
                    .tag(0)

                // 2. 修改：传给 InspirationView
                InspirationView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("灵感集", systemImage: "lightbulb")
                    }
                    .tag(1)

                // 3. 修改：传给 LookBackView
                LookBackView(showSideMenu: $showSideMenu)
                    .tabItem {
                        Label("我", systemImage: "person.crop.circle")
                    }
                    .tag(2)
            }
            .tint(.blue)
            
            // 侧滑栏组件
            SideMenuView(isOpen: $showSideMenu)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
