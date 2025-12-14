//
//  SpeechTranscriptionProtocol.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public protocol SpeechTranscriptionService: AnyObject {
    var events: AsyncStream<ASREvent> { get }

    func connect(config: ASRConfig) async throws
    func sendAudioChunk(_ data: Data) async throws
    func commit() async throws
    func close() async
}
