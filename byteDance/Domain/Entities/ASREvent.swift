//
//  ASREvent.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public enum ASREvent: Sendable, Equatable {
    case opened(sessionID: String?)
    case vadSpeechStarted
    case vadSpeechStopped
    case partial(text: String)
    case final(text: String)
    case closed(code: Int, reason: String)
}
