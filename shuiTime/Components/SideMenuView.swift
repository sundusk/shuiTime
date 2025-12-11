//
//  SideMenuView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

// SideMenuView.swift
import SwiftUI

struct SideMenuView: View {
    // 这是一个绑定属性，用于在侧滑栏内部关闭自己
    @Binding var isOpen: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 1. 半透明遮罩 (点击空白处关闭)
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isOpen = false
                        }
                    }
            }
            
            // 2. 侧滑内容区域
            HStack {
                VStack(alignment: .leading) {
                    // 这里预留给你的 UI 代码 (如：头像、统计图、菜单列表)
                    // 参考图中的 "全部笔记"、"微信输入" 等
                    Text("侧滑栏功能区域")
                        .font(.title2)
                        .padding(.top, 60)
                        .padding(.leading, 20)
                    
                    Spacer()
                }
                .frame(width: 280) // 侧滑栏通常不是全屏宽度
                .background(Color.white) // 或者是 Color(UIColor.systemBackground)
                .offset(x: isOpen ? 0 : -280) // 核心动画逻辑：移进/移出
                
                Spacer()
            }
        }
        // 确保动画平滑
        .animation(.easeInOut(duration: 0.3), value: isOpen)
    }
}
