import Foundation

public struct HTTPError: Error {
    public let statusCode: Int
    public let headers: [AnyHashable: Any]
    public let body: Data?
}

public final class SSEHandler {
    public init() {}

    public func stream(
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AsyncThrowingStream<String, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                request.httpBody = body

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ChatError.responseFormatInvalid
                    }

                    // ✅ 先判断 HTTP code，不是 2xx 直接抛
                    if !(200...299).contains(http.statusCode) {
                        // 尝试读取少量 body（避免读太久）
                        var collected = Data()
                        var count = 0
                        for try await b in bytes {
                            collected.append(b)
                            count += 1
                            if count > 64 * 1024 { break }
                        }
                        throw HTTPError(statusCode: http.statusCode,
                                       headers: http.allHeaderFields,
                                       body: collected.isEmpty ? nil : collected)
                    }

                    // ✅ 正常：按行读 SSE
                    for try await line in bytes.lines {
                        if Task.isCancelled { throw CancellationError() }
                        continuation.yield(line)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ChatError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
