//
//  LLMServiceRouter.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/8.
//

import Foundation

public final class LLMServiceRouter: LLMServiceProtocol {
    private let openAIStyle: LLMServiceProtocol
    private let dashscope: LLMServiceProtocol
    private let templateMock: LLMServiceProtocol

    public init(
        openAIStyle: LLMServiceProtocol = OpenAIAdapter(),
        dashscope: LLMServiceProtocol = DashScopeAdapter(),
        templateMock: LLMServiceProtocol = TemplateMockAdapter()
    ) {
        self.openAIStyle = openAIStyle
        self.dashscope = dashscope
        self.templateMock = templateMock
    }

    private func service(for config: AIModelConfig) -> LLMServiceProtocol {
        if UserDefaults.standard.bool(forKey: "test_mode_enabled") { return templateMock }
        switch config.provider {
        case .openAIStyle: return openAIStyle
        case .dashscope:   return dashscope
        }
    }

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        try await service(for: config).sendMessage(sessionID: sessionID, messages: messages, config: config)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncStream<Message> {
        service(for: config).streamMessage(sessionID: sessionID, messages: messages, config: config)
    }
}
