//
//  AIModelConfig.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public struct AIModelConfig: Codable, Equatable {
    public var modelName: String
    public var temperature: Double
    public var tokenLimit: Int
    public var apiKey: String?

    public init(modelName: String = "gpt-4o-mini", temperature: Double = 0.7, tokenLimit: Int = 4096, apiKey: String? = nil) {
        self.modelName = modelName
        self.temperature = temperature
        self.tokenLimit = tokenLimit
        self.apiKey = apiKey
    }
}
