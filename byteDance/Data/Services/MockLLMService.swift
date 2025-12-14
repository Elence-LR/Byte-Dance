//
//  MockLLMService.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//

import Foundation

// 桩代码：仅实现初始化，方法体为空或返回简单值
public final class MockLLMService: LLMServiceProtocol {
    public init() {}

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        // 静态返回一个消息
        return Message(role: .assistant, content: "Static Echo: \(messages.last?.content ?? "")")
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

}
