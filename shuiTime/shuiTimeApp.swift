//
//  shuiTimeApp.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import SwiftUI
import SwiftData

@main
struct shuiTimeApp: App {
    // 定义我们 app 的数据容器
    var sharedModelContainer: ModelContainer = {
        // 🔥 核心点：这里必须把 TimelineItem.self 加进去
        let schema = Schema([
            TimelineItem.self,
        ])
        
        // 纯本地配置：不依赖 iCloud
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("数据库初始化失败: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 将数据容器注入到 App 中
        .modelContainer(sharedModelContainer)
    }
}
