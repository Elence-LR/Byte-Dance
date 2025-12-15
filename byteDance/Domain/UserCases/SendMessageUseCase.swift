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

    public func execute(session: Session, userText: String, config: AIModelConfig) async throws -> Message {
        try await execute(session: session, userMessage: Message(role: .user, content: userText), config: config)
    }

    public func stream(session: Session, userMessage: Message, config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        repository.appendMessage(sessionID: session.id, message: userMessage)
        return service.streamMessage(
            sessionID: session.id,
            messages: repository.fetchMessages(sessionID: session.id),
            config: config
        )
    }

    public func stream(session: Session, userText: String, config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        stream(session: session, userMessage: Message(role: .user, content: userText), config: config)
    }

    public func summarize(session: Session, config: AIModelConfig, instruction: String? = nil) async throws -> String {
        let history = repository.fetchMessages(sessionID: session.id)
        var msgs = history
        let prompt = instruction ?? "请总结以上会话的核心要点，200字内"
        msgs.append(Message(role: .user, content: prompt))
        let result = try await service.sendMessage(sessionID: session.id, messages: msgs, config: config)
        return result.content
    }
    
    public func stream(session: Session, messages: [Message], config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        service.streamMessage(
            sessionID: session.id,
            messages: messages,
            config: config
        )
    }
}
