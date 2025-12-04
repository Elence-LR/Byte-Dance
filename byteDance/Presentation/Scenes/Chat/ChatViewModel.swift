//
//  ChatViewModel.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

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

    public func stream(text: String, config: AIModelConfig) {
        // 忽略流式
    }

    public func messages() -> [Message] {
        repository.fetchMessages(sessionID: session.id)
    }
}
