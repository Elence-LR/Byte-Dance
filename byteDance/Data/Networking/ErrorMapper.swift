//
//  ErrorMapper.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

enum ErrorMapper {
    static func map(_ error: Error) -> ChatError {
        if let e = error as? ChatError { return e }

        if error is CancellationError { return .cancelled }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timedOut
            default:
                return .connectionLost
            }
        }

        if let http = error as? HTTPError {
            let retryAfter = parseRetryAfter(headers: http.headers)
            // 先尝试从 body 里解析 provider 风格错误
            if let body = http.body,
               let pe = parseProviderError(body: body) {
                // 401/403 且 message/code 指向 key 问题
                if http.statusCode == 401 || http.statusCode == 403 {
                    return .invalidAPIKey
                }
                return .providerError(code: pe.code, message: pe.message)
            }

            switch http.statusCode {
            case 401: return .unauthorized
            case 403: return .forbidden
            case 429: return .rateLimited(retryAfter: retryAfter)
            case 500...599: return .serverError(status: http.statusCode)
            default:
                return .badRequest(status: http.statusCode)
            }
        }

        return .providerError(code: nil, message: error.localizedDescription)
    }

    private static func parseRetryAfter(headers: [AnyHashable: Any]) -> TimeInterval? {
        // Retry-After: seconds
        if let v = headers["Retry-After"] as? String, let s = TimeInterval(v) { return s }
        if let v = headers["retry-after"] as? String, let s = TimeInterval(v) { return s }
        return nil
    }

    // 兼容常见 OpenAI 风格：{ "error": { "message": "...", "code": "...", "type": "..." } }
    // 也可以按需加 DashScope 的结构（你们后面接更多第三方就继续扩展这里）
    private static func parseProviderError(body: Data) -> (code: String?, message: String)? {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        if let e = obj["error"] as? [String: Any] {
            let msg = (e["message"] as? String) ?? ""
            let code = (e["code"] as? String)
            if !msg.isEmpty { return (code, msg) }
        }
        // DashScope 常见：{ "message": "...", "code": "..." }（示例化，按你们真实返回再补）
        if let msg = obj["message"] as? String, !msg.isEmpty {
            return (obj["code"] as? String, msg)
        }
        return nil
    }
}
