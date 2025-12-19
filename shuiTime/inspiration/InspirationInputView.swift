//
//  InspirationInputView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftUI
import SwiftData
import UIKit

struct InspirationInputView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 🔥 新增：接收要修改的条目 (如果是新建则为 nil)
    var itemToEdit: TimelineItem?
    
    // 输入状态
    @State private var attributedText = NSMutableAttributedString(string: "")
    @State private var isBold: Bool = false
    
    // 键盘控制状态
    @State private var showKeyboard: Bool = false
    
    // 图片选择状态
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部拖拽条区域
            HStack { Spacer() }
                .padding(.top, 10)
            
            // 2. 富文本输入区域
            ZStack(alignment: .topLeading) {
                if attributedText.string.isEmpty {
                    Text("现在的想法是...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
                
                // 自定义输入框
                RichTextEditor(text: $attributedText, isBold: $isBold, showKeyboard: $showKeyboard)
                    .padding(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 3. 底部区域 (图片预览 + 工具栏)
            VStack(spacing: 0) {
                // 图片预览
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
                
                // 工具栏
                HStack(spacing: 24) {
                    // 插入标签 #
                    Button(action: insertHashTag) {
                        Image(systemName: "number")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    // 插入图片
                    Button(action: {
                        showKeyboard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showImagePicker = true
                        }
                    }) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    // 加粗开关
                    Button(action: { isBold.toggle() }) {
                        Image(systemName: "bold")
                            .font(.title3)
                            .foregroundColor(isBold ? .blue : .primary)
                            .padding(4)
                            .background(isBold ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                    }
                    
                    // 插入列表符
                    Button(action: insertBulletPoint) {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // 发送/保存按钮
                    Button(action: saveInspiration) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 34)
                            .background(Color.green.opacity(attributedText.string.isEmpty && selectedImage == nil ? 0.3 : 1.0))
                            .cornerRadius(17)
                    }
                    .disabled(attributedText.string.isEmpty && selectedImage == nil)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(uiColor: .systemBackground))
            }
        }
        // 🔥 初始化逻辑：如果是修改模式，回填数据
        .onAppear {
            if let item = itemToEdit {
                // 1. 回填图片
                if let data = item.imageData {
                    selectedImage = UIImage(data: data)
                }
                // 2. 回填文字并进行第一次染色 (让旧内容的标签也是蓝色的)
                let initialAttr = NSMutableAttributedString(string: item.content)
                initialAttr.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 0, length: initialAttr.length))
                initialAttr.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: initialAttr.length))
                
                let regexPattern = "#[^\\s]*"
                if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
                    let matches = regex.matches(in: initialAttr.string, options: [], range: NSRange(location: 0, length: initialAttr.length))
                    for match in matches {
                        initialAttr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                    }
                }
                attributedText = initialAttr
            }
            
            // 弹出键盘
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showKeyboard = true
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showKeyboard = true
            }
        }) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
    }
    
    // 插入 #
    private func insertHashTag() {
        let current = NSMutableAttributedString(attributedString: attributedText)
        let hashString = NSAttributedString(string: "#", attributes: [
            .font: isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.systemBlue
        ])
        current.append(hashString)
        attributedText = current
        showKeyboard = true
    }
    
    // 插入列表符
    private func insertBulletPoint() {
        let current = NSMutableAttributedString(attributedString: attributedText)
        let prefix = current.string.hasSuffix("\n") || current.string.isEmpty ? "" : "\n"
        let bullet = NSAttributedString(string: "\(prefix)- ", attributes: [
            .font: isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label
        ])
        current.append(bullet)
        attributedText = current
        showKeyboard = true
    }
    
    // 🔥 保存逻辑：区分新建和修改
    private func saveInspiration() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let plainText = attributedText.string
        
        if let existingItem = itemToEdit {
            // --- 修改模式 ---
            existingItem.content = plainText
            existingItem.imageData = imageData
            // SwiftData 对象是类的引用，直接修改属性即可，不需要再次 insert
        } else {
            // --- 新建模式 ---
            let newItem = TimelineItem(
                content: plainText,
                iconName: "lightbulb.fill",
                timestamp: Date(),
                imageData: imageData,
                type: "inspiration"
            )
            modelContext.insert(newItem)
        }
        
        try? modelContext.save()
        
        showKeyboard = false
        dismiss()
    }
}

// MARK: - 核心组件：RichTextEditor (保持不变)
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSMutableAttributedString
    @Binding var isBold: Bool
    @Binding var showKeyboard: Bool
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.allowsEditingTextAttributes = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        
        if showKeyboard {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            }
        } else {
            if uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.resignFirstResponder() }
            }
        }
        
        if uiView.attributedText.string != text.string {
            uiView.attributedText = text
        }
        
        context.coordinator.updateTypingAttributes(textView: uiView)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) { self.parent = parent }
        
        func updateTypingAttributes(textView: UITextView) {
            var attributes: [NSAttributedString.Key: Any] = [:]
            
            if parent.isBold {
                attributes[.font] = UIFont.boldSystemFont(ofSize: 17)
            } else {
                attributes[.font] = UIFont.systemFont(ofSize: 17)
            }
            
            let selectedRange = textView.selectedRange
            let cursorIndex = selectedRange.location
            let text = textView.text as NSString
            
            var isInTag = false
            
            if cursorIndex > 0 {
                let searchRange = NSRange(location: 0, length: cursorIndex)
                let hashRange = text.range(of: "#", options: .backwards, range: searchRange)
                
                if hashRange.location != NSNotFound {
                    let contentStart = hashRange.location + 1
                    let length = cursorIndex - contentStart
                    
                    if length > 0 {
                        let checkRange = NSRange(location: contentStart, length: length)
                        let whitespaceRange = text.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: checkRange)
                        if whitespaceRange.location == NSNotFound {
                            isInTag = true
                        }
                    } else {
                        isInTag = true
                    }
                }
            }
            
            attributes[.foregroundColor] = isInTag ? UIColor.systemBlue : UIColor.label
            textView.typingAttributes = attributes
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let textStorage = textView.textStorage
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let selectedRange = textView.selectedRange
            
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
            
            let regexPattern = "#[^\\s]*"
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
                let matches = regex.matches(in: textStorage.string, options: [], range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                }
            }
            
            textView.selectedRange = selectedRange
            let copy = NSMutableAttributedString(attributedString: textStorage)
            parent.text = copy
            updateTypingAttributes(textView: textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            updateTypingAttributes(textView: textView)
        }
    }
}
