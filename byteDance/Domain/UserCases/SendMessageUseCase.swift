//
//  SendMessageUseCase.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

// 桩代码：仅实现初始化，依赖于 ChatRepositoryProtocol 和 LLMServiceProtocol
public final class SendMessageUseCase {
    private let repository: ChatRepositoryProtocol
    private let service: LLMServiceProtocol

    public init(repository: ChatRepositoryProtocol, service: LLMServiceProtocol) {
        self.repository = repository
        self.service = service
    }
    
    // 桩方法，仅为满足 ChatViewModel 依赖
    public func execute(session: Session, userText: String, config: AIModelConfig) async throws -> Message {
        // 模拟消息写入，避免崩溃
        repository.appendMessage(sessionID: session.id, message: Message(role: .user, content: userText))
        return try await service.sendMessage(sessionID: session.id, messages: [], config: config)
    }

    public func stream(session: Session, userText: String, config: AIModelConfig) -> AsyncStream<Message> {
        return AsyncStream { continuation in continuation.finish() }
    }
}
