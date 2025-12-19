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
    
    // 接收要修改的条目
    var itemToEdit: TimelineItem?
    
    // 🔥 新增：接收初始内容 (用于新建时预填标签)
    var initialContent: String = ""
    
    // 输入状态
    @State private var attributedText = NSMutableAttributedString(string: "")
    @State private var isBold: Bool = false
    @State private var showKeyboard: Bool = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部拖拽条
            HStack { Spacer() }.padding(.top, 10)
            
            // 2. 输入区域
            ZStack(alignment: .topLeading) {
                if attributedText.string.isEmpty {
                    Text("现在的想法是...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
                RichTextEditor(text: $attributedText, isBold: $isBold, showKeyboard: $showKeyboard)
                    .padding(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 3. 底部区域
            VStack(spacing: 0) {
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(6).clipped()
                            .overlay(
                                Button(action: { withAnimation { selectedImage = nil } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                }
                                .offset(x: 5, y: -5), alignment: .topTrailing
                            )
                        Spacer()
                    }
                    .padding(.horizontal).padding(.bottom, 8)
                }
                
                Divider()
                
                HStack(spacing: 24) {
                    Button(action: insertHashTag) { Image(systemName: "number").font(.title3).foregroundColor(.primary) }
                    Button(action: {
                        showKeyboard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showImagePicker = true }
                    }) { Image(systemName: "photo").font(.title3).foregroundColor(.primary) }
                    
                    Button(action: { isBold.toggle() }) {
                        Image(systemName: "bold").font(.title3)
                            .foregroundColor(isBold ? .blue : .primary)
                            .padding(4).background(isBold ? Color.blue.opacity(0.1) : Color.clear).cornerRadius(4)
                    }
                    
                    Button(action: insertBulletPoint) { Image(systemName: "list.bullet").font(.title3).foregroundColor(.primary) }
                    
                    Spacer()
                    
                    Button(action: saveInspiration) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            .frame(width: 44, height: 34)
                            .background(Color.green.opacity(attributedText.string.isEmpty && selectedImage == nil ? 0.3 : 1.0))
                            .cornerRadius(17)
                    }
                    .disabled(attributedText.string.isEmpty && selectedImage == nil)
                }
                .padding(.vertical, 12).padding(.horizontal, 20)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .onAppear {
            setupInitialContent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showKeyboard = true }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showKeyboard = true }
        }) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
    }
    
    // 初始化内容逻辑
    private func setupInitialContent() {
        if let item = itemToEdit {
            // 修改模式：回填旧数据
            if let data = item.imageData { selectedImage = UIImage(data: data) }
            applyStyle(to: item.content)
        } else if !initialContent.isEmpty {
            // 🔥 新建模式：如果有预填内容（如标签），填入并应用样式
            // 自动在标签后加个空格，方便用户接着输入
            let textToFill = initialContent.hasSuffix(" ") ? initialContent : initialContent + " "
            applyStyle(to: textToFill)
        }
    }
    
    // 统一的样式应用逻辑
    private func applyStyle(to content: String) {
        let attr = NSMutableAttributedString(string: content)
        let fullRange = NSRange(location: 0, length: attr.length)
        
        // 1. 基础字体
        attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: fullRange)
        attr.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // 2. 简单的标签高亮 (蓝色)
        let regexPattern = "#[^\\s]*"
        if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
            let matches = regex.matches(in: content, options: [], range: fullRange)
            for match in matches {
                attr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            }
        }
        attributedText = attr
    }
    
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
    
    private func saveInspiration() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let plainText = attributedText.string
        
        if let existingItem = itemToEdit {
            existingItem.content = plainText
            existingItem.imageData = imageData
        } else {
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

// MARK: - RichTextEditor (保持不变)
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
            if !uiView.isFirstResponder { DispatchQueue.main.async { uiView.becomeFirstResponder() } }
        } else {
            if uiView.isFirstResponder { DispatchQueue.main.async { uiView.resignFirstResponder() } }
        }
        if uiView.attributedText.string != text.string { uiView.attributedText = text }
        context.coordinator.updateTypingAttributes(textView: uiView)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        init(_ parent: RichTextEditor) { self.parent = parent }
        
        func updateTypingAttributes(textView: UITextView) {
            var attributes: [NSAttributedString.Key: Any] = [:]
            attributes[.font] = parent.isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17)
            
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
                        if text.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: checkRange).location == NSNotFound {
                            isInTag = true
                        }
                    } else { isInTag = true }
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
            
            if let regex = try? NSRegularExpression(pattern: "#[^\\s]*", options: []) {
                let matches = regex.matches(in: textStorage.string, options: [], range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                }
            }
            textView.selectedRange = selectedRange
            parent.text = NSMutableAttributedString(attributedString: textStorage)
            updateTypingAttributes(textView: textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            updateTypingAttributes(textView: textView)
        }
    }
}
