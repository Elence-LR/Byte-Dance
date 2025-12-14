//
//  SpeechErrorMapper.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

enum SpeechErrorMapper {
    static func map(_ error: Error) -> ChatError {
        if error is CancellationError { return .cancelled }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost: return .networkUnavailable
            case .timedOut: return .timedOut
            default: return .connectionLost
            }
        }
        return .providerError(code: nil, message: error.localizedDescription)
    }
}
