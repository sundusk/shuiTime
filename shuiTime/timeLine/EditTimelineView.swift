//
//  EditTimelineView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/11.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 接收要修改的那个数据对象
    @Bindable var item: TimelineItem
    
    // 本地编辑状态
    @State private var content: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    // 灵感模式状态
    @State private var isInspiration: Bool = false
    
    // 🔥 新增：获取最近使用的标签 (用于联想)
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var inspirationItems: [TimelineItem]
    
    private var recentTags: [String] {
        var counts: [String: Int] = [:]
        for item in inspirationItems {
            let words = item.content.split(separator: " ")
            for word in words {
                let str = String(word)
                if str.hasPrefix("#") && str.count > 1 {
                    counts[str, default: 0] += 1
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { $0.key } // 取前10个
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 记录属性 (灵感开关)
                Section {
                    Toggle(isOn: $isInspiration) {
                        HStack(spacing: 12) {
                            Image(systemName: isInspiration ? "lightbulb.fill" : "lightbulb")
                                .font(.title3)
                                .foregroundColor(isInspiration ? .yellow : .secondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("灵感模式")
                                    .font(.headline)
                                Text(isInspiration ? "已标记为灵感，支持标签提取" : "普通流水账，内容原样显示")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.yellow)
                } header: {
                    Text("属性")
                }
                
                // 2. 🔥 核心编辑区 (标签 + 图片 + 文字)
                Section {
                    // (A) 标签联想栏 (仅灵感模式显示)
                    if isInspiration && !recentTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentTags, id: \.self) { tag in
                                    Button(action: {
                                        // 在文字末尾追加标签
                                        if !content.hasSuffix(" ") && !content.isEmpty {
                                            content += " "
                                        }
                                        content += "\(tag) "
                                    }) {
                                        Text(tag)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain) // 防止点击整行触发
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) // 让滚动条顶格
                    }
                    
                    // (B) 图片预览区 (放在文字上方，方便对照修改)
                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                                .clipped()
                                .padding(.vertical, 8)
                            
                            // 删除图片按钮
                            Button(action: {
                                withAnimation { selectedImage = nil }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .padding(16)
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) // 图片撑满宽度
                    }
                    
                    // (C) 文字编辑区
                    TextField("记录当下的想法...", text: $content, axis: .vertical)
                        .lineLimit(5...15) // 增加高度
                        .font(.body)
                        .padding(.vertical, 4)
                    
                    // (D) 添加/更换图片按钮 (如果没有图片，或者想换图)
                    if selectedImage == nil {
                        Button(action: {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("添加图片")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("内容编辑")
                }
                
                // 3. 信息区
                Section {
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
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
        .onAppear {
            content = item.content
            isInspiration = (item.type == "inspiration")
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: sourceType)
        }
    }
    
    // 保存修改逻辑
    private func saveChanges() {
        item.content = content
        
        // 保存类型变更
        item.type = isInspiration ? "inspiration" : "timeline"
        
        // 处理图片
        if let image = selectedImage {
            item.imageData = image.jpegData(compressionQuality: 0.7)
            item.iconName = "photo"
        } else {
            item.imageData = nil
            item.iconName = isInspiration ? "lightbulb.fill" : "text.bubble"
        }
        
        // SwiftData 自动保存
    }
}
