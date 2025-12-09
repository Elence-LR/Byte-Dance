//
//  SendMessageUseCase.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public final class SendMessageUseCase {
    private let repository: ChatRepositoryProtocol
    private let service: LLMServiceProtocol

    public init(repository: ChatRepositoryProtocol, service: LLMServiceProtocol) {
        self.repository = repository
        self.service = service
    }

    public func execute(session: Session, userText: String, config: AIModelConfig) async throws -> Message {
        let userMessage = Message(role: .user, content: userText)
        repository.appendMessage(sessionID: session.id, message: userMessage)
        let response = try await service.sendMessage(sessionID: session.id, messages: repository.fetchMessages(sessionID: session.id), config: config)
        repository.appendMessage(sessionID: session.id, message: response)
        return response
    }

    public func stream(session: Session, userText: String, config: AIModelConfig) -> AsyncStream<Message> {
        // 目前发送出去的内容只包含content，不会包含reasoning
        let userMessage = Message(role: .user, content: userText)
        repository.appendMessage(sessionID: session.id, message: userMessage)
        return service.streamMessage(sessionID: session.id, messages: repository.fetchMessages(sessionID: session.id), config: config)
    }
}
