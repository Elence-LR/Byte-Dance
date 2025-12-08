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
        let url = APIEndpoints.openAIStyleStreamURL()
        let headers = APIEndpoints.openAIStyleHeaders(apiKey: config.apiKey ?? "")
//        print(url, headers)

        let bodyMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let payload: [String: Any] = [
            "model": config.modelName,
            "messages": bodyMessages,
            "stream": true
        ]
        let body = try? JSONSerialization.data(withJSONObject: payload)

        let lines = sse.stream(url: url, headers: headers, body: body)

        return AsyncStream { continuation in
            Task {
                for await line in lines {
                    switch OpenAIStyleSSEParser.parse(line: line) {
                    case .token(let token):
                        continuation.yield(Message(role: .assistant, content: token))
                    case .done:
                        continuation.finish()
                        return
                    case .ignore:
                        continue
                    }
                }
                continuation.finish()
            }
        }
    }

    
    
    private func makeBody(session: Session, config: AIModelConfig) -> Data {
        let messagesArr = session.messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        let payload: [String: Any] = [
            "model": config.modelName,
            "messages": messagesArr,
            "stream": true
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
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
