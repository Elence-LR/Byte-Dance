import Foundation

public final class OpenAIAdapter: LLMServiceProtocol {
    private let client: HTTPClient
    private let sse: SSEHandler

    public init(client: HTTPClient = HTTPClient(), sse: SSEHandler = SSEHandler()) {
        self.client = client
        self.sse = sse
    }

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        let url = APIEndpoints.chatURL(model: config.modelName)
        let payload = try JSONEncoder().encode(RequestPayload(messages: messages, config: config))
        let data = try await client.request(url: url, headers: headers(config: config), body: payload)
        let text = String(data: data, encoding: .utf8) ?? ""
        return Message(role: .assistant, content: text)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncStream<Message> {
        let url = APIEndpoints.streamURL(model: config.modelName)
        let payload = try? JSONEncoder().encode(RequestPayload(messages: messages, config: config))
        let base = sse.stream(url: url, headers: headers(config: config), body: payload)
        return AsyncStream { continuation in
            Task {
                for await line in base {
                    continuation.yield(Message(role: .assistant, content: line))
                }
                continuation.finish()
            }
        }
    }

    private func headers(config: AIModelConfig) -> [String: String] {
        var h = ["Content-Type": "application/json"]
        if let key = config.apiKey {
            h["Authorization"] = "Bearer \(key)"
        }
        return h
    }

    private struct RequestPayload: Codable {
        let messages: [Message]
        let config: AIModelConfig
    }
}
