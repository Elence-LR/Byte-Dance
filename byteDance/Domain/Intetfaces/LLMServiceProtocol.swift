//
//  LLMServiceProtocol.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
// Domain/Interfaces/LLMServiceProtocol.swift
import Foundation

public protocol LLMServiceProtocol {
    func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message

    func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig)
      -> AsyncThrowingStream<Message, Error>
}

