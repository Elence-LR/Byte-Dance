import Foundation

public final class HTTPClient {
    public init() {}

    public func request(url: URL, method: String = "POST", headers: [String: String] = [:], body: Data? = nil) async throws -> Data {
        print("HTTP request:", method, url.absoluteString)
        print("HTTP headers:", headers)
        print("HTTP body bytes:", body?.count ?? 0)
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("HTTP status:", http.statusCode)
            let ct = (http.allHeaderFields["Content-Type"] as? String) ?? "-"
            print("HTTP content-type:", ct)
        }
        print("HTTP response bytes:", data.count)
        return data
    }
}
