import Foundation

public final class SSEHandler {
    public init() {}

    public func stream(url: URL, headers: [String: String] = [:], body: Data? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                request.httpBody = body
                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}
