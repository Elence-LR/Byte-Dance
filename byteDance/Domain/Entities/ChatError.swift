//
//  ChatError.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public enum ChatError: Error, Equatable {
    case cancelled

    case networkUnavailable
    case timedOut
    case connectionLost

    case rateLimited(retryAfter: TimeInterval?)
    case unauthorized            // 401
    case forbidden               // 403
    case invalidAPIKey           // 401/403 + 解析出来的明确错误
    case serverError(status: Int) // 5xx
    case badRequest(status: Int)  // 4xx other

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
        case .unauthorized, .invalidAPIKey:
            return "API Key 无效或已过期，请到设置页更新"
        case .forbidden:
            return "没有权限访问该模型/接口"
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
