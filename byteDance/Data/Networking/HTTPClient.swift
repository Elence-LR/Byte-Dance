import Foundation

public final class HTTPClient {
    public init() {}

    public func request(url: URL, method: String = "POST", headers: [String: String] = [:], body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
