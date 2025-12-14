import Foundation

// 继承NSObject（确保兼容性）
public final class HTTPClient: NSObject {
    public override init() {}

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
    
    // upload
    public func upload(for request: URLRequest, from data: Data, progress: @escaping (Progress) -> Void) async throws -> (Data, URLResponse) {
        // 创建上传任务
        let task = URLSession.shared.uploadTask(with: request, from: data)
        
        // 监听进度（原生Progress的回调）
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            progress(progressObj)
        }
        
        // 执行任务并等待结果（用async/await原生语法）
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: data)
            observation.invalidate() // 任务完成后销毁监听
            return (data, response)
        } catch {
            observation.invalidate() // 出错也销毁监听
            throw error
        }
    }
}
