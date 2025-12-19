//
//  InspirationInputView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftUI
import SwiftData

struct InspirationInputView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 输入状态
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    // 图片选择状态
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽条区域（视觉提示）
            HStack { Spacer() }
                .padding(.top, 10)
            
            // 文本输入区域
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("现在的想法是...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 5)
                }
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity) // 让输入框占据剩余空间
            
            // 选中的图片预览
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                        .clipped()
                        .overlay(
                            Button(action: { withAnimation { selectedImage = nil } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .offset(x: 5, y: -5),
                            alignment: .topTrailing
                        )
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Divider()
            
            // 底部工具栏
            HStack(spacing: 24) {
                // 这里方便你以后扩展更多功能
                Button(action: { text += "#" }) {
                    Image(systemName: "number").font(.title3).foregroundColor(.primary)
                }
                
                Button(action: { showImagePicker = true }) {
                    Image(systemName: "photo").font(.title3).foregroundColor(.primary)
                }
                
                // 预留功能位：加粗
                Button(action: {}) {
                    Image(systemName: "bold").font(.title3).foregroundColor(.primary)
                }
                
                Button(action: { text += "\n- " }) {
                    Image(systemName: "list.bullet").font(.title3).foregroundColor(.primary)
                }
                
                // 预留功能位：更多
                Button(action: {}) {
                    Image(systemName: "ellipsis").font(.title3).foregroundColor(.primary)
                }
                
                Spacer()
                
                // 发送按钮
                Button(action: saveInspiration) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 34)
                        .background(Color.green.opacity(text.isEmpty && selectedImage == nil ? 0.3 : 1.0))
                        .cornerRadius(17)
                }
                .disabled(text.isEmpty && selectedImage == nil)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(uiColor: .systemBackground))
        }
        .onAppear {
            // 延迟一点点弹出键盘，体验更好
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
    }
    
    // 保存逻辑
    private func saveInspiration() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        
        let newItem = TimelineItem(
            content: text,
            iconName: "lightbulb.fill",
            timestamp: Date(),
            imageData: imageData,
            type: "inspiration" // 标记为灵感
        )
        modelContext.insert(newItem)
        try? modelContext.save()
        
        isFocused = false
        dismiss()
    }
}

// 预览
#Preview {
    InspirationInputView()
}
