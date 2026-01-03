//
//  InspirationInputView.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/19.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - 数据交互模型
struct TagPopupData: Equatable {
    var rect: CGRect       // #号光标在 TextEditor 中的位置
    var range: NSRange     // 当前正在输入的标签范围（用于替换）
    var searchText: String // 当前输入的关键词（不含#）
}

struct InspirationInputView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 接收要修改的条目
    var itemToEdit: TimelineItem?
    
    // 接收初始内容 (用于新建时预填标签)
    var initialContent: String = ""
    
    // 输入状态
    @State private var attributedText = NSMutableAttributedString(string: "")
    @State private var isBold: Bool = false
    @State private var showKeyboard: Bool = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    // 🔥 标签联想状态
    @State private var tagPopupData: TagPopupData?
    
    // 获取历史标签数据
    @Query(filter: #Predicate<TimelineItem> { $0.type == "inspiration" }, sort: \TimelineItem.timestamp, order: .reverse)
    private var allInspirations: [TimelineItem]
    
    // 计算常用标签
    private var availableTags: [String] {
        var counts: [String: Int] = [:]
        for item in allInspirations {
            let lines = item.content.components(separatedBy: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                for word in words {
                    let str = String(word)
                    if str.hasPrefix("#") && str.count > 1 {
                        counts[str, default: 0] += 1
                    }
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }
    
    // 根据输入筛选标签
    private var filteredTags: [String] {
        guard let data = tagPopupData else { return [] }
        let all = availableTags
        if data.searchText.isEmpty {
            return Array(all.prefix(20)) // 无搜索词时显示前20个
        } else {
            return all.filter { $0.localizedCaseInsensitiveContains(data.searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部拖拽条
            HStack { Spacer() }.padding(.top, 10)
            
            // 2. 输入区域 (ZStack 用于放置悬浮层)
            ZStack(alignment: .topLeading) {
                if attributedText.string.isEmpty {
                    Text("现在的想法是...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
                
                // 文本编辑器
                RichTextEditor(
                    text: $attributedText,
                    isBold: $isBold,
                    showKeyboard: $showKeyboard,
                    tagPopupData: $tagPopupData // 🔥 绑定弹窗数据
                )
                .padding(4)
                
                // 🔥 3. 跟随光标的标签选择列表
                if let data = tagPopupData, !filteredTags.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredTags, id: \.self) { tag in
                                    Button(action: { insertExistingTag(tag, range: data.range) }) {
                                        HStack {
                                            Text(tag)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain) // 移除点击高亮背景，改用 hover 效果或自定义
                                    
                                    if tag != filteredTags.last {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 180)
                    .frame(maxHeight: 200)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    // 🔥 核心定位逻辑：基于光标位置偏移
                    .offset(x: max(10, data.rect.minX), y: data.rect.maxY + 8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    .zIndex(100) // 确保在最上层
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 4. 底部工具栏
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
                    // # 按钮：仅负责插入字符，触发逻辑交给 RichTextEditor
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
            if let data = item.imageData { selectedImage = UIImage(data: data) }
            applyStyle(to: item.content)
        } else if !initialContent.isEmpty {
            let textToFill = initialContent.hasSuffix(" ") ? initialContent : initialContent + " "
            applyStyle(to: textToFill)
        }
    }
    
    // 统一的样式应用逻辑
    private func applyStyle(to content: String) {
        let attr = NSMutableAttributedString(string: content)
        let fullRange = NSRange(location: 0, length: attr.length)
        
        attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: fullRange)
        attr.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        let regexPattern = "#[^\\s]*"
        if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
            let matches = regex.matches(in: content, options: [], range: fullRange)
            for match in matches {
                attr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            }
        }
        attributedText = attr
    }
    
    // 插入 # (触发联想)
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
    
    // 🔥 点击列表中的标签，替换当前输入
    private func insertExistingTag(_ tag: String, range: NSRange) {
        let current = NSMutableAttributedString(attributedString: attributedText)
        
        // 构造完整的标签字符串 (带颜色 + 空格)
        let tagString = NSMutableAttributedString(string: tag + " ", attributes: [
            .font: isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.systemBlue
        ])
        // 恢复空格后的颜色为默认
        tagString.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: tag.count, length: 1))
        
        // 替换原来正在输入的 "#xx"
        if range.location + range.length <= current.length {
            current.replaceCharacters(in: range, with: tagString)
        } else {
            current.append(tagString)
        }
        
        attributedText = current
        tagPopupData = nil // 关闭弹窗
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

// MARK: - RichTextEditor (核心修改：增加标签检测与坐标反馈)
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSMutableAttributedString
    @Binding var isBold: Bool
    @Binding var showKeyboard: Bool
    
    // 🔥 双向绑定弹窗数据
    @Binding var tagPopupData: TagPopupData?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.allowsEditingTextAttributes = true
        // 禁用智能引号等，防止干扰标签解析
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
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
        
        // 避免死循环：只有当内容真正改变时才设置
        if uiView.attributedText.string != text.string {
            // 记录当前光标，尝试恢复（可选，但在输入标签时通常不需要）
            uiView.attributedText = text
        }
        context.coordinator.updateTypingAttributes(textView: uiView)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        init(_ parent: RichTextEditor) { self.parent = parent }
        
        // 🔥 核心逻辑：检测光标位置是否在标签中
        func checkTagInput(textView: UITextView) {
            let selectedRange = textView.selectedRange
            guard selectedRange.length == 0 else {
                parent.tagPopupData = nil
                return
            }
            
            let cursorIndex = selectedRange.location
            let text = textView.text as NSString
            
            // 1. 找到光标所在的单词范围
            // 向前寻找空格或换行符或字符串开头
            var start = cursorIndex
            while start > 0 {
                let charRange = NSRange(location: start - 1, length: 1)
                if text.substring(with: charRange).rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                    break
                }
                start -= 1
            }
            
            let length = cursorIndex - start
            if length > 0 {
                let wordRange = NSRange(location: start, length: length)
                let word = text.substring(with: wordRange)
                
                // 2. 如果单词以 # 开头
                if word.hasPrefix("#") {
                    // 3. 计算 # 号的屏幕坐标
                    // 获取 # 字符的结束位置（即 TextPosition）
                    // 注意：UITextView 的坐标系是滚动的，所以要减去 contentOffset
                    if let startPos = textView.position(from: textView.beginningOfDocument, offset: wordRange.location),
                       let endPos = textView.position(from: startPos, offset: 1), // 获取 # 的位置
                       let _ = textView.textRange(from: startPos, to: endPos) {
                        
                        let caretRect = textView.caretRect(for: endPos)
                        
                        // 转换为相对于 UITextView bounds 的坐标 (减去滚动偏移)
                        let relativeRect = caretRect.offsetBy(dx: 0, dy: -textView.contentOffset.y)
                        
                        // 提取搜索词 (去掉 #)
                        let searchText = String(word.dropFirst())
                        
                        DispatchQueue.main.async {
                            self.parent.tagPopupData = TagPopupData(
                                rect: relativeRect,
                                range: wordRange,
                                searchText: searchText
                            )
                        }
                        return
                    }
                }
            }
            
            // 如果不满足条件，清空弹窗
            if parent.tagPopupData != nil {
                DispatchQueue.main.async { self.parent.tagPopupData = nil }
            }
        }
        
        func updateTypingAttributes(textView: UITextView) {
            var attributes: [NSAttributedString.Key: Any] = [:]
            attributes[.font] = parent.isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17)
            
            // 简单的输入时颜色判断
            // 如果正在输入的内容属于一个 Tag 范围，就变蓝
            if let _ = parent.tagPopupData {
                attributes[.foregroundColor] = UIColor.systemBlue
            } else {
                attributes[.foregroundColor] = UIColor.label
            }
            textView.typingAttributes = attributes
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let textStorage = textView.textStorage
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let selectedRange = textView.selectedRange
            
            // 全文扫描高亮标签
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
            
            // 🔥 每次文字改变，检查是否触发标签联想
            checkTagInput(textView: textView)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            updateTypingAttributes(textView: textView)
            // 🔥 光标移动也要检查 (比如用户点击回 # 位置)
            checkTagInput(textView: textView)
        }
    }
}
