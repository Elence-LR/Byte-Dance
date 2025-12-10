//
//  DashScopeAdapter.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/8.
//

import Foundation

public final class DashScopeAdapter: LLMServiceProtocol {
    private let client: HTTPClient
    private let sse: SSEHandler

    public init(client: HTTPClient = HTTPClient(), sse: SSEHandler = SSEHandler()) {
        self.client = client
        self.sse = sse
    }

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        // 一个非流式的最小实现（可以只实现 stream）
        let url = APIEndpoints.dashScopeStreamURL()
        let headers = APIEndpoints.dashScopeHeaders(apiKey: config.apiKey ?? "", streaming: false)

        let body = makeDashScopeBody(messages: messages, config: config, incremental: false)
        let data = try await client.request(url: url, headers: headers, body: body)

        // 非流式响应结构也在 output.choices[0].message.content
        let text = extractDashScopeFinalContent(from: data) ?? ""
        return Message(role: .assistant, content: text, reasoning: nil)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncStream<Message> {
        let useIM = needsMultimodal(messages)
        let url = useIM ? APIEndpoints.dashScopeMultimodalURL() : APIEndpoints.dashScopeTextURL()
        
        let headers = APIEndpoints.dashScopeHeaders(apiKey: config.apiKey ?? "", streaming: true)
        let body = makeDashScopeBody(messages: messages, config: config, incremental: true)

        let lines = sse.stream(url: url, headers: headers, body: body)

        return AsyncStream { continuation in
            Task {
                for await line in lines {
                    switch DashScopeSSEParser.parse(line: line) {
                    case .token(let token):
                        continuation.yield(Message(role: .assistant, content: token))
                    case .reasoning(let r):
                        // 你可以选择把思考过程也展示出来，比如用特殊前缀/单独气泡
                        continuation.yield(Message(role: .assistant, content: "", reasoning: r))
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

    // MARK: - Body
    private func makeDashScopeBody(messages: [Message], config: AIModelConfig, incremental: Bool) -> Data? {
        let bodyMessages = messages.map(mapToDashScopeMessage)

        let payload: [String: Any] = [
            "model": config.modelName,
            "input": [
                "messages": bodyMessages
            ],
            "parameters": [
                "result_format": "message",
                "incremental_output": incremental,
                // 常用参数（按需）：temperature / max_tokens
                "enable_thinking": config.thinking,
                "temperature": config.temperature,
                "max_tokens": config.tokenLimit
            ]
        ]
        print("❗️Body: \(payload)")
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func extractDashScopeFinalContent(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let output = json["output"] as? [String: Any],
            let choices = output["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else { return nil }

        return content
    }
    
    private func needsMultimodal(_ messages: [Message]) -> Bool {
        return messages.contains { ($0.attachments?.isEmpty == false) }
    }
    
    private func mapToDashScopeMessage(_ m: Message) -> [String: Any] {
        var obj: [String: Any] = ["role": m.role.rawValue]

        if m.role == .user, let atts = m.attachments, !atts.isEmpty {
            var parts: [[String: Any]] = []
            for a in atts {
                // 目前只做 imageDataURL
                parts.append(["image": a.value])
            }
            if !m.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(["text": m.content])
            }
            obj["content"] = parts
        } else {
            // 非多模态消息保持你现在的方式：纯 string
            obj["content"] = m.content
        }

        return obj
    }

}
