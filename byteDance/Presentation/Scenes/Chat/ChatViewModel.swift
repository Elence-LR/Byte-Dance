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
            repository.appendMessage(sessionID: session.id, message: userMessage)
            onNewMessage?(userMessage)
            
            // 模拟助手回复
            repository.appendMessage(sessionID: session.id, message: Message(role: .assistant, content: "Response to: \(text)"))
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
    

    public func stream(text: String, config: AIModelConfig) {
        // 1) 先启动 usecase 的 stream（它会 append user message 到 repo）
        let s = sendUseCase.stream(session: session, userText: text, config: config)

        // 2) 触发一次刷新，让 UI 看到 user message
        if let last = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(last) // 只是为了让 VC reload
        } else {
            onNewMessage?(Message(role: .system, content: "")) // 理论不会走到；你不喜欢就删掉
        }

        // 3) 插入 assistant 占位消息到 repo
        let assistantID = UUID()
        repository.appendMessage(sessionID: session.id,
                                 message: Message(id: assistantID, role: .assistant, content: "", reasoning: nil))
        if let appended = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(appended)
        }
        // 4) 逐 token 合并到占位消息，并更新 repo
        Task {
            var contnetBuffer = ""
            var reasoningBuffer = ""
            for await m in s { // m.content 是 token
                if let r = m.reasoning {
                    print(r)
                    reasoningBuffer += r
                    repository.updateMessageReasoning(sessionID: session.id, messageID: assistantID, reasoning: reasoningBuffer)

                    if let updated = repository.fetchMessages(sessionID: session.id).first(where: { $0.id == assistantID }) {
                        onNewMessage?(updated)
                    }
                }
                else {
                    contnetBuffer += m.content
                    repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: contnetBuffer)
                    
                    // 触发 UI 刷新（把更新后的 message 发给 VC）
                    if let updated = repository.fetchMessages(sessionID: session.id)
                        .first(where: { $0.id == assistantID }) {
                        onNewMessage?(updated)
                    } else {
                        onNewMessage?(m)
                    }
                }
            }
        }
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
