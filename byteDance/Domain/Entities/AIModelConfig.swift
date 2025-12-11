//
//  AIModelConfig.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation


public enum LLMProvider: String, Codable {
    case openAIStyle   // OpenAI协议下DeepSeek
    case dashscope     // DashScope 原生协议
}

public struct AIModelConfig: Codable, Equatable {
    public var provider: LLMProvider
    public var modelName: String
    public var temperature: Double
    public var tokenLimit: Int
    public var apiKey: String?
    public var thinking: Bool
    public var baseURL: String?
    

    public init(provider: LLMProvider = .openAIStyle, modelName: String = "deepseek-chat", temperature: Double = 0.7, tokenLimit: Int = 4096, thinking: Bool = false, apiKey: String? = nil, baseURL: String? = nil) {
        self.provider = provider
        self.modelName = modelName
        self.thinking = thinking
        self.temperature = temperature
        self.tokenLimit = tokenLimit
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}
