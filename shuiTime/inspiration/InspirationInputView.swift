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
    
    // 接收初始内容
    var initialContent: String = ""
    
    // 指定创建时的类型
    var createType: String = "inspiration"
    
    // 输入状态
    @State private var attributedText = NSMutableAttributedString(string: "")
    @State private var isBold: Bool = false
    @State private var isStrikethrough: Bool = false
    @State private var showKeyboard: Bool = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    // 🔥 闪光点状态
    @State private var isHighlight: Bool = false
    
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
                RichTextEditor(text: $attributedText, isBold: $isBold, isStrikethrough: $isStrikethrough, showKeyboard: $showKeyboard)
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
                
                HStack(spacing: 20) {
                    Button(action: insertHashTag) { Image(systemName: "number").font(.title3).foregroundColor(.primary) }
                    Button(action: {
                        showKeyboard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showImagePicker = true }
                    }) { Image(systemName: "photo").font(.title3).foregroundColor(.primary) }
                    
                    // 🔥 修改：闪光点开关按钮 (星星 -> 灯泡)
                    Button(action: { withAnimation { isHighlight.toggle() } }) {
                        Image(systemName: isHighlight ? "lightbulb.fill" : "lightbulb")
                            .font(.title3)
                            .foregroundColor(isHighlight ? .yellow : .primary)
                    }
                    
                    Button(action: { isBold.toggle() }) {
                        Image(systemName: "bold").font(.title3)
                            .foregroundColor(isBold ? .blue : .primary)
                            .padding(4).background(isBold ? Color.blue.opacity(0.1) : Color.clear).cornerRadius(4)
                    }
                    
                    Button(action: { isStrikethrough.toggle() }) {
                        Image(systemName: "strikethrough").font(.title3)
                            .foregroundColor(isStrikethrough ? .blue : .primary)
                            .padding(4).background(isStrikethrough ? Color.blue.opacity(0.1) : Color.clear).cornerRadius(4)
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
            isHighlight = item.isHighlight
            
            if let richData = item.richContentData,
               let nsAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: richData) {
                attributedText = NSMutableAttributedString(attributedString: nsAttr)
            } else {
                applyStyle(to: item.content)
            }
        } else if !initialContent.isEmpty {
            let textToFill = initialContent.hasSuffix(" ") ? initialContent : initialContent + " "
            applyStyle(to: textToFill)
        }
    }
    
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
    
    private func insertHashTag() {
        let current = NSMutableAttributedString(attributedString: attributedText)
        let hashString = NSAttributedString(string: "#", attributes: [
            .font: isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.systemBlue,
            .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0
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
            .foregroundColor: UIColor.label,
            .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0
        ])
        current.append(bullet)
        attributedText = current
        showKeyboard = true
    }
    
    private func saveInspiration() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        let plainText = attributedText.string
        let richData = try? NSKeyedArchiver.archivedData(withRootObject: attributedText, requiringSecureCoding: false)
        
        if let existingItem = itemToEdit {
            existingItem.content = plainText
            existingItem.richContentData = richData
            existingItem.imageData = imageData
            existingItem.isHighlight = isHighlight
        } else {
            var icon = "lightbulb.fill"
            if createType == "timeline" {
                icon = imageData != nil ? "photo" : "text.bubble"
            }
            
            let newItem = TimelineItem(
                content: plainText,
                iconName: icon,
                timestamp: Date(),
                imageData: imageData,
                type: createType,
                isHighlight: isHighlight,
                richContentData: richData
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
    @Binding var isStrikethrough: Bool
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
        if uiView.attributedText.string != text.string || uiView.attributedText != text {
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
            attributes[.font] = parent.isBold ? UIFont.boldSystemFont(ofSize: 17) : UIFont.systemFont(ofSize: 17)
            
            if parent.isStrikethrough {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attributes[.strikethroughStyle] = 0
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
