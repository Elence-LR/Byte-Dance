//
//  OpenAIStyleSSEParser.swift
//  Byte-Dance-AIChat
//
//  Created by Huhuhu on 2025/12/4.
//

import Foundation

enum OpenAIStyleSSEEvent {
    case token(String)
    case reasoning(String)
    case done
    case ignore
}

struct OpenAIStyleSSEParser {
    static func parse(line: String) -> OpenAIStyleSSEEvent {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignore }

        // 收到形如 "data: {...}" 或者单独的 "[DONE]"
        let payload: String
        if trimmed.hasPrefix("data:") {
            payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        } else {
            payload = trimmed
        }
        print("✅ Raw: \(payload)")

        if payload == "[DONE]" { return .done }
        guard payload.hasPrefix("{") else { return .ignore }

        // choices[0].delta.content
        guard
            let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first
        else { return .ignore }

        // delta.content
        if let delta = first["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return .token(content)
        }
        
        if let delta = first["delta"] as? [String: Any],
           let reasoning = delta["reasoning_content"] as? String,
           !reasoning.isEmpty {
            return .reasoning(reasoning)
        }

        // 有的实现可能把 content 放在 message 里（非严格流式），这里做个兜底
        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String,
           !content.isEmpty {
            return .token(content)
        }

        return .ignore
    }
}
