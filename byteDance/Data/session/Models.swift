// Models.swift
import Foundation

// 会话模型
struct ChatSession: Codable, Identifiable {
    let id: String
    var title: String
    var createTime: TimeInterval
    var updateTime: TimeInterval
    var draftContent: String?
    var modelConfig: ModelConfig?
    
    init(title: String) {
        self.id = UUID().uuidString
        self.title = title
        self.createTime = Date().timeIntervalSince1970
        self.updateTime = self.createTime
        self.draftContent = nil
        self.modelConfig = nil
    }
}


// 消息模型
struct ChatMessage: Codable, Identifiable {
    let id: String
    let sessionId: String
    let content: String
    let role: MessageRole
    let createTime: TimeInterval
    var isStreaming: Bool
    var streamingContent: String?
// 新增图片属性
    var imageLocalPath: String?  // 图片本地存储路径
    var imageWidth: CGFloat?     // 图片宽度
    var imageHeight: CGFloat?    // 图片高度
    // 用户消息初始化
    init(userContent: String, sessionId: String) {
        self.id = UUID().uuidString
        self.sessionId = sessionId
        self.content = userContent
        self.role = .user
        self.createTime = Date().timeIntervalSince1970
        self.isStreaming = false
        self.streamingContent = nil
    }
    // 图片消息初始化
        init(imageData: Data, sessionId: String, textContent: String = "") {
            self.id = UUID().uuidString
            self.sessionId = sessionId
            self.content = textContent
            self.role = .user
            self.createTime = Date().timeIntervalSince1970
            self.isStreaming = false
            self.streamingContent = nil
            
            // 保存图片到本地并记录路径/尺寸
            do {
                let (localPath, width, height) = try ChatPersistenceManager.shared.saveImage(imageData)
                self.imageLocalPath = localPath
                self.imageWidth = width
                self.imageHeight = height
            } catch {
                self.imageLocalPath = nil
                self.imageWidth = nil
                self.imageHeight = nil
                print("图片保存失败：\(error)")
            }
        }
    // 助手流式消息初始化
    init(assistantStreamingContent: String, sessionId: String) {
        self.id = UUID().uuidString
        self.sessionId = sessionId
        self.content = ""
        self.role = .assistant
        self.createTime = Date().timeIntervalSince1970
        self.isStreaming = true
        self.streamingContent = assistantStreamingContent
    }
}

// 消息角色枚举
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// 模型参数配置
struct ModelConfig: Codable {
    let modelName: String
    let temperature: Double
    let maxTokens: Int
    let isStreaming: Bool
}
