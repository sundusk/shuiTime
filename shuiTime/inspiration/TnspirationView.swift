//
//  inspirationView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI

struct InspirationView: View {
    // 1. 接收侧滑栏开关状态
    @Binding var showSideMenu: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "lightbulb")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding()
                Text("这里是灵感集")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("灵感集")
            // 2. 添加左上角菜单按钮
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation {
                            showSideMenu = true
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// 预览时需提供模拟数据
#Preview {
    InspirationView(showSideMenu: .constant(false))
}
