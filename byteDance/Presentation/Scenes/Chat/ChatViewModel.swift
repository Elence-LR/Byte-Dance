//
//  ChatViewModel.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation
import UIKit


// 桩代码：仅包含初始化和消息获取
public final class ChatViewModel {
    public private(set) var session: Session
    private let sendUseCase: SendMessageUseCase
    private let repository: ChatRepositoryProtocol
    public var onNewMessage: ((Message) -> Void)?
    private var reasoningExpanded: [UUID: Bool] = [:]

    public init(session: Session, sendUseCase: SendMessageUseCase, repository: ChatRepositoryProtocol) {
        self.session = session
        self.sendUseCase = sendUseCase
        self.repository = repository
    }

    public func send(text: String, config: AIModelConfig) {
        // 仅在本地记录消息，不真正发送
        Task {
            let userMessage = Message(role: .user, content: text, reasoning: nil)
            print("VM send local user length:", text.count)
            repository.appendMessage(sessionID: session.id, message: userMessage)
            onNewMessage?(userMessage)
            
            // 模拟助手回复
            repository.appendMessage(sessionID: session.id, message: Message(role: .assistant, content: "Response to: \(text)"))
            print("VM send local assistant length:", text.count)
            onNewMessage?(Message(role: .assistant, content: "Response to: \(text)"))
        }
    }
    
    /// 李相瑜新增：方法 — 发送图片消息
    public func sendImage(_ image: UIImage) {
        Task {
            //如果你有图片压缩工具，可在这里使用，比如ImageProcessor.jpegData(...)
            // For now, 只是模拟流程

            // 1. 添加用户“图片消息” — content 可以是占位或标记
            let placeholder = "[图片]"  // 或者你定义 Message 支持 image data / url
            let userMsg = Message(role: .user, content: placeholder)
                repository.appendMessage(sessionID: session.id, message: userMsg)
                onNewMessage?(userMsg)

            // 2. 模拟后台返回 — 你可以替换为真实 adapter 调用
            //    例如：let replyText = try await llmService.sendImageMessage(...)
            //    这里先 mock
            let replyText = "👀 我已收到你的图片（模拟回复）"
            let botMsg = Message(role: .assistant, content: replyText)
            repository.appendMessage(sessionID: session.id, message: botMsg)
                onNewMessage?(botMsg)
        }
    }
    
    // MARK: 图片
    // 由于没有服务器，所以我们上传图片选择Base64编码方式上传
    public func sendImage(_ image: UIImage, prompt: String = "图中描绘的是什么景象？", config: AIModelConfig) {
        Task {
            guard let data = ImageProcessor.jpegData(from: image, maxKB: 300) else {
                await MainActor.run { self.addSystemTip("图片压缩失败") }
                return
            }
            let base64 = data.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"

            let userMsg = Message(
                role: .user,
                content: prompt,
                attachments: [.init(kind: .imageDataURL, value: dataURL)]
            )
            self.stream(userMessage: userMsg, config: config)
        }
    }
    
    // MARK: - 统一入口（文本/图片都走这里）
    public func stream(userMessage: Message, config: AIModelConfig) {
        // 原始 append 用户消息
        let s = sendUseCase.stream(session: session, userMessage: userMessage, config: config)

        if let last = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(last)
        } else {
            onNewMessage?(Message(role: .system, content: ""))
        }

        let assistantID = UUID()
        repository.appendMessage(sessionID: session.id,
                                 message: Message(id: assistantID, role: .assistant, content: "", reasoning: nil))
        if let appended = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(appended)
        }

        // 逐 token 更新 assistant 占位消息
        Task {
            var contentBuffer = ""
            var reasoningBuffer = ""
            for await m in s {
                if let r = m.reasoning {
                    reasoningBuffer += r
                    repository.updateMessageReasoning(sessionID: session.id, messageID: assistantID, reasoning: reasoningBuffer)
                } else {
                    contentBuffer += m.content
                    repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: contentBuffer)
                }

                if let updated = repository.fetchMessages(sessionID: session.id).first(where: { $0.id == assistantID }) {
                    onNewMessage?(updated)
                } else {
                    onNewMessage?(m)
                }
            }
        }
    }
    

    // MARK: - 文本：保持现有行为
    public func stream(text: String, config: AIModelConfig) {
        stream(userMessage: Message(role: .user, content: text), config: config)
    }
    

    
    public func messages() -> [Message] {
        repository.fetchMessages(sessionID: session.id)
    }
    
    
    @MainActor
    public func addSystemTip(_ text: String) {
        let tip = Message(role: .system, content: text)
        repository.appendMessage(sessionID: session.id, message: tip)
        onNewMessage?(tip)
    }
    
    
    public func isReasoningExpanded(messageID: UUID) -> Bool {
        reasoningExpanded[messageID] ?? false
    }

    
    public func toggleReasoningExpanded(messageID: UUID) {
        reasoningExpanded[messageID] = !(reasoningExpanded[messageID] ?? false)
    }
}

