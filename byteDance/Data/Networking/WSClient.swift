//
//  WSClient.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public final class WSClient {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(_ request: URLRequest) {
        let t = session.webSocketTask(with: request)
        self.task = t
        t.resume()
    }

    public func send(text: String) async throws {
        guard let task else { throw URLError(.notConnectedToInternet) }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            task.send(.string(text)) { err in
                if let err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }


    public func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { cont in
            task?.receive { result in cont.resume(with: result) }
        }
    }

    public func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}
