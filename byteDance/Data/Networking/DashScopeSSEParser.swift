//
//  DashScopeSSEParser.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/8.
//

import Foundation

enum DashScopeSSEEvent {
    case token(String)          // content
    case reasoning(String)      // reasoning_content（可选）
    case done
    case ignore
}

struct DashScopeSSEParser {

    static func parse(line: String) -> DashScopeSSEEvent {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignore }

        // DashScope SSE 有 id/event/:HTTP_STATUS/data: 多行，这里只处理 data:
        guard trimmed.hasPrefix("data:") else { return .ignore }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)

        if payload == "[DONE]" { return .done } // 兼容一些实现

        guard payload.hasPrefix("{"),
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .ignore }
        
        // 打印完整信息，便于debug
        print("RAW:", payload.prefix(300))


        // data: {"output":{"choices":[{"message":{"content":"xxx","reasoning_content":"...","role":"assistant"}}]}}
        if let output = json["output"] as? [String: Any],
           let choices = output["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any] {

            if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
                return .reasoning(reasoning)
            }

            if let content = message["content"] as? String, !content.isEmpty {
                return .token(content)
            }
        }

        return .ignore
    }
}
