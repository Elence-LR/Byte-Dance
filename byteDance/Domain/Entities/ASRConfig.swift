//
//  ASRConfig.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public struct ASRConfig: Sendable, Equatable {
    public enum Region: String, Sendable, Equatable { case beijing, singaporeIntl }

    public var apiKey: String
    public var region: Region
    public var model: String              // "qwen3-asr-flash-realtime"
    public var language: String?          // "zh"
    public var inputAudioFormat: String   // "pcm" / "opus"
    public var inputSampleRate: Int       // 8000 / 16000
    public var enableVAD: Bool

    public init(
        apiKey: String,
        region: Region = .singaporeIntl,
        model: String = "qwen3-asr-flash-realtime",
        language: String? = "zh",
        inputAudioFormat: String = "pcm",
        inputSampleRate: Int = 16000,
        enableVAD: Bool = true
    ) {
        self.apiKey = apiKey
        self.region = region
        self.model = model
        self.language = language
        self.inputAudioFormat = inputAudioFormat
        self.inputSampleRate = inputSampleRate
        self.enableVAD = enableVAD
    }
}
