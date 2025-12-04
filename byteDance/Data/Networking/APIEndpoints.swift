import Foundation

public enum APIEndpoints {
    public static func chatURL(model: String) -> URL {
        URL(string: "https://api.example.com/v1/chat/\(model)")!
    }

    public static func streamURL(model: String) -> URL {
        URL(string: "https://api.example.com/v1/chat/\(model)/stream")!
    }
}
