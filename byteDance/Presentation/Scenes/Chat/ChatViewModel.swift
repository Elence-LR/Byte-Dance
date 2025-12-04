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

    public init(session: Session, sendUseCase: SendMessageUseCase, repository: ChatRepositoryProtocol) {
        self.session = session
        self.sendUseCase = sendUseCase
        self.repository = repository
    }

    public func send(text: String, config: AIModelConfig) {
        // 仅在本地记录消息，不真正发送
        Task {
            let userMessage = Message(role: .user, content: text)
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
        // 忽略流式
    }

    public func messages() -> [Message] {
        repository.fetchMessages(sessionID: session.id)
    }
    
    
}
