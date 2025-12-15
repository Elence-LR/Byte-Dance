import Foundation

enum ErrorMapper {

    static func map(_ error: Error) -> ChatError {
        if let e = error as? ChatError { return e }

        if error is CancellationError { return .cancelled }
        if let ue = error as? URLError, ue.code == .cancelled { return .cancelled }

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
            let pe = http.body.flatMap(parseProviderError(body:))

            switch http.statusCode {
            case 401:
                if isClearlyInvalidAPIKey(pe) { return .invalidAPIKey }
                return .unauthorized

            case 403:
                if isClearlyInvalidAPIKey(pe) { return .invalidAPIKey }
                if let mapped = mapSemanticProviderError(pe, statusCode: 403) { return mapped }
                return .forbidden

            case 404:
                if let mapped = mapSemanticProviderError(pe, statusCode: 404) { return mapped }
                return .badRequest(status: 404)

            case 429:
                if let mapped = mapSemanticProviderError(pe, statusCode: 429) { return mapped }
                return .rateLimited(retryAfter: retryAfter)

            case 500...599:
                return .serverError(status: http.statusCode)

            default:
                if let mapped = mapSemanticProviderError(pe, statusCode: http.statusCode) { return mapped }
                if (400...499).contains(http.statusCode) { return .badRequest(status: http.statusCode) }
                return .providerError(code: pe?.code, message: pe?.message ?? "服务返回错误")
            }
        }

        return .providerError(code: nil, message: error.localizedDescription)
    }

    // MARK: - Provider error parsing (OpenAI + DashScope)

    private struct ProviderError {
        let code: String?
        let type: String?
        let param: String?
        let message: String
    }

    /// OpenAI: { "error": { "message": "...", "type": "...", "code": "...", "param": ... } }
    /// DashScope: top-level { "code": "...", "message": "...", "type": "...", "param": ... }
    private static func parseProviderError(body: Data) -> ProviderError? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: body),
            let dict = obj as? [String: Any]
        else { return nil }

        // OpenAI-style wrapper
        if let e = dict["error"] as? [String: Any] {
            let msg = (e["message"] as? String) ?? ""
            if msg.isEmpty { return nil }
            return ProviderError(
                code: e["code"] as? String,
                type: e["type"] as? String,
                param: (e["param"] as? String) ?? ((e["param"] as? NSNull) == nil ? nil : nil),
                message: msg
            )
        }

        // DashScope-style
        if let msg = dict["message"] as? String, !msg.isEmpty {
            return ProviderError(
                code: dict["code"] as? String,
                type: dict["type"] as? String,
                param: dict["param"] as? String,
                message: msg
            )
        }

        return nil
    }

    // MARK: - Semantic mapping (model/quota/context/etc.)

    private static func mapSemanticProviderError(_ pe: ProviderError?, statusCode: Int) -> ChatError? {
        guard let pe else { return nil }
        let msg = pe.message.lowercased()
        let code = pe.code?.lowercased() ?? ""
        let type = pe.type?.lowercased() ?? ""

        if code == "arrearage" || type == "arrearage" || msg.contains("account is in good standing") {
            return .billingIssue(message: pe.message)
        }

        // 配额不足
        if msg.contains("exceeded your current quota") || msg.contains("billing details") || code.contains("insufficient_quota") {
            return .quotaExceeded
        }

        // 模型不存在 / 不可用
        if code.contains("model_not_found") || msg.contains("model not exist") || msg.contains("does not exist") {
            return .modelNotFound(model: extractModelName(from: pe.message))
        }

        // 模型无权限/未开通
        if statusCode == 403 || msg.contains("do not have access") || msg.contains("permission") || msg.contains("access denied") {
            return .modelAccessDenied(model: extractModelName(from: pe.message))
        }

        // 上下文/长度超限
        if code.contains("context_length_exceeded")
            || msg.contains("maximum context length")
            || msg.contains("input length")
            || msg.contains("range of input length")
        {
            return .contextLengthExceeded
        }

        // 内容策略/安全
        if code.contains("content_policy") || msg.contains("content policy") || msg.contains("safety") {
            return .contentFiltered(message: pe.message)
        }

        // response_format/协议不兼容
        if pe.param?.lowercased() == "response_format" || msg.contains("response_format") {
            return .responseFormatInvalid
        }

        return nil
    }

    private static func isClearlyInvalidAPIKey(_ pe: ProviderError?) -> Bool {
        guard let pe else { return false }
        let msg = pe.message.lowercased()
        let code = pe.code?.lowercased() ?? ""
        let type = pe.type?.lowercased() ?? ""

        if msg.contains("incorrect api key") || msg.contains("invalid api key") { return true }
        if code.contains("invalid_api_key") || type.contains("authentication") { return true }

        return false
    }

    // MARK: - Retry-After parsing

    private static func parseRetryAfter(headers: [AnyHashable: Any]) -> TimeInterval? {
        let normalized = normalizeHeaders(headers)

        guard let raw = normalized["retry-after"] else { return nil }

        // seconds
        if let s = TimeInterval(raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return s }

        // HTTP-date
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        if let date = df.date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }

        return nil
    }

    private static func normalizeHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in headers {
            let key = String(describing: k).lowercased()
            if let s = v as? String {
                out[key] = s
            } else {
                out[key] = String(describing: v)
            }
        }
        return out
    }

    private static func extractModelName(from message: String) -> String? {
        let patterns = [
            #"`([^`]+)`"#,
            #"'([^']+)'"#,
            #"model\\s+([A-Za-z0-9._:-]+)"#
        ]
        for p in patterns {
            if let r = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                let ns = message as NSString
                if let m = r.firstMatch(in: message, range: NSRange(location: 0, length: ns.length)),
                   m.numberOfRanges >= 2 {
                    return ns.substring(with: m.range(at: 1))
                }
            }
        }
        return nil
    }
}
