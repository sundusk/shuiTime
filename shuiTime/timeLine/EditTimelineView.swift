//
//  EditTimelineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import PhotosUI // 引入这个以使用更现代的图片选择器(可选)，但为了兼容先沿用之前的逻辑

struct EditTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    // 接收要修改的那个数据对象
    @Bindable var item: TimelineItem
    
    // 本地编辑状态
    @State private var content: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 文字编辑区
                Section(header: Text("内容")) {
                    TextField("记录当下的想法...", text: $content, axis: .vertical)
                        .lineLimit(3...10)
                }
                
                // 2. 图片编辑区
                Section(header: Text("图片")) {
                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                                .clipped()
                                .listRowInsets(EdgeInsets()) // 让图片撑满
                            
                            // 删除图片按钮
                            Button(action: {
                                withAnimation { selectedImage = nil }
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                    .background(Circle().fill(.white))
                            }
                            .padding(8)
                        }
                    } else {
                        Button(action: {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("添加/更换图片")
                            }
                        }
                    }
                }
                
                // 3. 时间显示 (只读，如果想改时间也可以做成 DatePicker)
                Section(header: Text("时间")) {
                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(content.isEmpty && selectedImage == nil)
                }
            }
        }
        // 初始化数据：把 item 里的旧数据拿出来显示
        .onAppear {
            content = item.content
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        }
        // 图片选择器
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    // 保存修改逻辑
    private func saveChanges() {
        item.content = content
        
        // 处理图片
        if let image = selectedImage {
            item.imageData = image.jpegData(compressionQuality: 0.7)
            item.iconName = "photo"
        } else {
            item.imageData = nil
            item.iconName = "text.bubble"
        }
        
        // SwiftData 会自动感知 Bindable item 的变化并保存，无需手动 insert
    }
}
