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
                print("SSE start:", url.absoluteString)
                print("SSE headers:", headers)
                print("SSE body bytes:", body?.count ?? 0)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse {
                        print("SSE status:", http.statusCode)
                        let ct = (http.allHeaderFields["Content-Type"] as? String) ?? "-"
                        print("SSE content-type:", ct)
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        print("SSE line:", String(line.prefix(200)))
                        continuation.yield(line)
                    }
                } catch {
                    print("SSE error:", String(describing: error))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
