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

    // 支持传入完整 userMessage（可携带 attachments）
    public func execute(session: Session, userMessage: Message, config: AIModelConfig) async throws -> Message {
        repository.appendMessage(sessionID: session.id, message: userMessage)
        let response = try await service.sendMessage(
            sessionID: session.id,
            messages: repository.fetchMessages(sessionID: session.id),
            config: config
        )
        repository.appendMessage(sessionID: session.id, message: response)
        return response
    }

    // 旧的文本入口（不破坏现有调用方）
    public func execute(session: Session, userText: String, config: AIModelConfig) async throws -> Message {
        try await execute(session: session, userMessage: Message(role: .user, content: userText), config: config)
    }

    // 支持传入完整 userMessage（可携带 attachments）
    public func stream(session: Session, userMessage: Message, config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        repository.appendMessage(sessionID: session.id, message: userMessage)
        return service.streamMessage(
            sessionID: session.id,
            messages: repository.fetchMessages(sessionID: session.id),
            config: config
        )
    }

    // 旧的文本入口
    public func stream(session: Session, userText: String, config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        stream(session: session, userMessage: Message(role: .user, content: userText), config: config)
    }
}

