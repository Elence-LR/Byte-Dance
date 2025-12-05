import Foundation

public enum APIEndpoints {
    public static func chatURL(model: String) -> URL {
        URL(string: "https://api.example.com/v1/chat/\(model)")!
    }

    public static func streamURL(model: String) -> URL {
        URL(string: "https://api.deepseek.com/chat/completions")!
    }
    
    public static func headers(apiKey: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        ]
    }
}
