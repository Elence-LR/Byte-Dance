import Foundation

public final class SSEHandler {
    public init() {}

    public func stream(
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AsyncStream<String> {

        AsyncStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                request.httpBody = body

                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        continuation.yield(line)
                    }
                } catch {
                    // 这里可以选择 yield 一个特殊错误行，或者直接结束
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
