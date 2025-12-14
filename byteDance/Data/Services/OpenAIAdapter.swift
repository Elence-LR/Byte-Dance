import Foundation

public final class OpenAIAdapter: LLMServiceProtocol {
    private let client: HTTPClient
    private let sse: SSEHandler

    public init(client: HTTPClient = HTTPClient(), sse: SSEHandler = SSEHandler()) {
        self.client = client
        self.sse = sse
    }

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        let url = normalizedOpenAIURL(config: config)
        print("OpenAI send URL:", url.absoluteString)
        let payload = try JSONEncoder().encode(RequestPayload(messages: messages, config: config))
        let data = try await client.request(url: url, headers: headers(config: config), body: payload)
        let text = String(data: data, encoding: .utf8) ?? ""
        return Message(role: .assistant, content: text)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig)
      -> AsyncThrowingStream<Message, Error> {

        let url = normalizedOpenAIURL(config: config)
        let headers = APIEndpoints.openAIStyleHeaders(apiKey: config.apiKey ?? "")
        let body = makeBody(messages: messages, config: config)

        let lines = sse.stream(url: url, headers: headers, body: body)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in lines {
                        switch OpenAIStyleSSEParser.parse(line: line) { // 你们现有解析器保留
                        case .token(let token):
                            continuation.yield(Message(role: .assistant, content: token))
                        case .reasoning(let r):
                            continuation.yield(Message(role: .assistant, content: "", reasoning: r))
                        case .done:
                            continuation.finish()
                            return
                        case .ignore:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }


    
    
    private func makeBody(messages: [Message], config: AIModelConfig) -> Data? {
        let messagesArr = messages.map { ["role": $0.role.rawValue, "content": $0.content] }

        let modelName: String = {
            if let base = config.baseURL, base.contains("deepseek.com") {
                let allowed = ["deepseek-chat", "deepseek-reasoner"]
                if allowed.contains(config.modelName) { return config.modelName }
                return config.thinking ? "deepseek-reasoner" : "deepseek-chat"
            }
            return config.modelName
        }()

        var payload: [String: Any] = [
            "model": modelName,
            "messages": messagesArr,
            "stream": true
        ]

        
        payload["thinking"] = ["type": config.thinking ? "enabled" : "disabled"]
        

        return try? JSONSerialization.data(withJSONObject: payload)
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
    private func normalizedOpenAIURL(config: AIModelConfig) -> URL {
        if let base = config.baseURL, !base.isEmpty {
            if base.hasSuffix("/chat/completions") { return URL(string: base)! }
            if base.contains("deepseek.com") { return URL(string: base + "/chat/completions")! }
            return URL(string: base)!
        }
        return APIEndpoints.openAIStyleStreamURL()
    }
