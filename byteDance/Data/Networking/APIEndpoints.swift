import Foundation

public enum APIEndpoints {
    public static func chatURL(model: String) -> URL {
        URL(string: "https://api.example.com/v1/chat/\(model)")!
    }

    // MARK: - OpenAI Style
    public static func openAIStyleStreamURL() -> URL {
        return URL(string: "https://api.deepseek.com/chat/completions")!
    }

    // MARK: - DashScope Native
    public static func dashScopeStreamURL() -> URL {
        let host = "https://dashscope.aliyuncs.com"
        return URL(string: "\(host)/api/v1/services/aigc/text-generation/generation")!
    }

    // MARK: - Headers
    public static func openAIStyleHeaders(apiKey: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        ]
    }

    public static func dashScopeHeaders(apiKey: String, streaming: Bool) -> [String: String] {
        var h: [String: String] = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]
        if streaming {
//          h["Accept"] = "text/event-stream"
            h["X-DashScope-SSE"] = "enable" // DashScope 开启 SSE
        }
        return h
    }
}
