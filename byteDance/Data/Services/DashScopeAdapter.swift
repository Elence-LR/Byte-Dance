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
        let fallback = APIEndpoints.dashScopeStreamURL()
        let url = URL(string: config.baseURL ?? fallback.absoluteString)!
        print("DashScope send URL:", url.absoluteString)
        let headers = APIEndpoints.dashScopeHeaders(apiKey: config.apiKey ?? "", streaming: false)

        let body = makeDashScopeBody(messages: messages, config: config, incremental: false)
        let data = try await client.request(url: url, headers: headers, body: body)

        let text = extractDashScopeFinalContent(from: data) ?? ""
        return Message(role: .assistant, content: text, reasoning: nil)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        let useIM = needsMultimodal(messages)
        let fallback = useIM ? APIEndpoints.dashScopeMultimodalURL() : APIEndpoints.dashScopeTextURL()
        let url = URL(string: config.baseURL ?? fallback.absoluteString)!
        print("DashScope stream URL:", url.absoluteString)

        let headers = APIEndpoints.dashScopeHeaders(apiKey: config.apiKey ?? "", streaming: true)
        let body = makeDashScopeBody(messages: messages, config: config, incremental: true)

        let lines = sse.stream(url: url, headers: headers, body: body)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in lines {
                        switch DashScopeSSEParser.parse(line: line) {
                        case .token(let token):
                            print("DashScope token:", token.prefix(80))
                            continuation.yield(Message(role: .assistant, content: token))
                        case .reasoning(let r):
                            print("DashScope reasoning:", r.prefix(80))
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

            continuation.onTermination = { @Sendable _ in
                // 这里不需要显式 cancel：外层 Task 会随着 continuation 结束而退出
                // 如果你想更强硬一些，也可以把 Task 存起来然后 cancel
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
