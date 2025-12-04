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
                                 message: Message(id: assistantID, role: .assistant, content: ""))
        if let appended = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(appended)
        }
        // 4) 逐 token 合并到占位消息，并更新 repo
        Task {
            var buffer = ""
            for await m in s { // m.content 是 token
                buffer += m.content
                repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: buffer)
                
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

    public func messages() -> [Message] {
        repository.fetchMessages(sessionID: session.id)
    }
}
