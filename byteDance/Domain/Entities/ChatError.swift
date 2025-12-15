import Foundation

public enum ChatError: Error, Equatable {
    case cancelled

    case networkUnavailable
    case timedOut
    case connectionLost

    case rateLimited(retryAfter: TimeInterval?)
    case quotaExceeded
    case billingIssue(message: String?)

    case unauthorized                 // 401（不一定是 key 无效）
    case forbidden                    // 403
    case invalidAPIKey                // 401/403
    case serverError(status: Int)     // 5xx
    case badRequest(status: Int)      // 4xx other

    //模型错误检测
    case modelNotFound(model: String?)          // 模型不存在 / 不可用
    case modelAccessDenied(model: String?)      // 有模型名但无权限/未开通（403/404/400 的某些 message）
    case contextLengthExceeded                  // 上下文/输入过长
    case contentFiltered(message: String?)      // 内容安全/策略拦截

    case responseFormatInvalid
    case providerError(code: String?, message: String)

    public var userMessage: String {
        switch self {
        case .cancelled:
            return "已停止生成"
        case .networkUnavailable:
            return "网络不可用，请检查网络连接"
        case .timedOut:
            return "请求超时，请稍后重试"
        case .connectionLost:
            return "网络中断，请重试"

        case .rateLimited(let retryAfter):
            if let t = retryAfter, t > 0 { return "请求过于频繁，请在 \(Int(t)) 秒后重试" }
            return "请求过于频繁（限流），请稍后重试"

        case .quotaExceeded:
            return "额度已用尽（配额不足），请检查用量/套餐/账单"
        case .billingIssue(let msg):
            return msg?.isEmpty == false ? msg! : "账号状态异常（可能欠费/未开通），请检查控制台/账单"

        case .invalidAPIKey:
            return "API Key 无效或已过期，请到设置页更新"
        case .unauthorized:
            return "鉴权失败，请检查 API Key/组织或项目权限"
        case .forbidden:
            return "没有权限访问该模型/接口"

        case .modelNotFound:
            return "模型不存在或不可用，请检查模型名称/版本"
        case .modelAccessDenied:
            return "没有权限使用该模型（可能未开通/无授权）"
        case .contextLengthExceeded:
            return "上下文过长，请减少历史消息或缩短输入"
        case .contentFiltered(let msg):
            return msg?.isEmpty == false ? msg! : "内容被安全策略拦截，请调整输入"

        case .serverError(let s):
            return "服务异常（\(s)），请稍后重试"
        case .badRequest:
            return "请求参数错误，请检查模型/参数设置"
        case .responseFormatInvalid:
            return "响应解析失败（协议不兼容）"
        case .providerError(_, let message):
            return message.isEmpty ? "服务返回错误" : message
        }
    }
}
