//
//  ChatViewModel.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation
import UIKit


// 桩代码：仅包含初始化和消息获取
public final class ChatViewModel {
    public private(set) var session: Session
    private let sendUseCase: SendMessageUseCase
    private let repository: ChatRepositoryProtocol
    public var onNewMessage: ((Message) -> Void)?
    private var reasoningExpanded: [UUID: Bool] = [:]
    private var currentStreamTask: Task<Void, Never>?
    
    public private(set) var isStreaming: Bool = false {
        didSet { onStreamingStateChanged?(isStreaming) }
    }
    
    public var onStreamingStateChanged: ((Bool) -> Void)?

    public func cancelCurrentStream() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isStreaming = false
        Task { @MainActor in
            self.addSystemTip(ChatError.cancelled.userMessage)
        }
    }


    public init(session: Session, sendUseCase: SendMessageUseCase, repository: ChatRepositoryProtocol) {
        self.session = session
        self.sendUseCase = sendUseCase
        self.repository = repository
    }

    public func send(text: String, config: AIModelConfig) {
        // 仅在本地记录消息，不真正发送
        Task {
            let userMessage = Message(role: .user, content: text, reasoning: nil)
            print("VM send local user length:", text.count)
            repository.appendMessage(sessionID: session.id, message: userMessage)
            onNewMessage?(userMessage)
            
            // 模拟助手回复
            repository.appendMessage(sessionID: session.id, message: Message(role: .assistant, content: "Response to: \(text)"))
            print("VM send local assistant length:", text.count)
            onNewMessage?(Message(role: .assistant, content: "Response to: \(text)"))
        }
    }
    
    /// 李相瑜新增：方法 — 发送图片消息
    public func sendImage(_ image: UIImage) {
        Task {
            //如果你有图片压缩工具，可在这里使用，比如ImageProcessor.jpegData(...)
            // For now, 只是模拟流程

            // 1. 添加用户“图片消息” — content 可以是占位或标记
            let placeholder = "[图片]"  // 或者你定义 Message 支持 image data / url
            let userMsg = Message(role: .user, content: placeholder)
                repository.appendMessage(sessionID: session.id, message: userMsg)
                onNewMessage?(userMsg)

            // 2. 模拟后台返回 — 你可以替换为真实 adapter 调用
            //    例如：let replyText = try await llmService.sendImageMessage(...)
            //    这里先 mock
            let replyText = "👀 我已收到你的图片（模拟回复）"
            let botMsg = Message(role: .assistant, content: replyText)
            repository.appendMessage(sessionID: session.id, message: botMsg)
                onNewMessage?(botMsg)
        }
    }
    
    // MARK: 图片
    // 由于没有服务器，所以我们上传图片选择Base64编码方式上传
    public func sendImage(_ image: UIImage, prompt: String = "图中描绘的是什么景象？", config: AIModelConfig) {
        Task {
            guard let data = ImageProcessor.jpegData(from: image, maxKB: 300) else {
                await MainActor.run { self.addSystemTip("图片压缩失败") }
                return
            }
            let base64 = data.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"

            let userMsg = Message(
                role: .user,
                content: prompt,
                attachments: [.init(kind: .imageDataURL, value: dataURL)]
            )
            self.stream(userMessage: userMsg, config: config)
        }
    }
    
    // MARK: - 统一入口（文本/图片都走这里）
    public func stream(userMessage: Message, config: AIModelConfig) {
        // 如果正在流，先取消旧的（避免并发两个流）
        if isStreaming { cancelCurrentStream() }

        let s = sendUseCase.stream(session: session, userMessage: userMessage, config: config)

        // append 用户消息 & assistant 占位（你们现有逻辑保留）
        // ...（保持你现在 L26-L42 的 append）:contentReference[oaicite:11]{index=11}

        let assistantID = UUID()
        repository.appendMessage(sessionID: session.id,
                                 message: Message(id: assistantID, role: .assistant, content: "", reasoning: nil))
        if let appended = repository.fetchMessages(sessionID: session.id).last {
            onNewMessage?(appended)
        }

        isStreaming = true

        currentStreamTask = Task {
            var contentBuffer = ""
            var reasoningBuffer = ""
            var hasAnyToken = false

            do {
                for try await m in s {
                    if Task.isCancelled { throw CancellationError() }

                    if let r = m.reasoning {
                        reasoningBuffer += r
                        repository.updateMessageReasoning(sessionID: session.id, messageID: assistantID, reasoning: reasoningBuffer)
                        hasAnyToken = true
                    } else {
                        contentBuffer += m.content
                        repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: contentBuffer)
                        if !m.content.isEmpty { hasAnyToken = true }
                    }

                    if let updated = repository.fetchMessages(sessionID: session.id).first(where: { $0.id == assistantID }) {
                        onNewMessage?(updated)
                    }
                }

                // 正常结束
                isStreaming = false
                currentStreamTask = nil

            } catch {
                isStreaming = false
                currentStreamTask = nil

                let mapped = ErrorMapper.map(error)
                await MainActor.run {
                    // ✅ 取消不当作失败（你也可以不提示，只改 UI 状态）
                    if mapped != .cancelled {
                        self.addSystemTip(mapped.userMessage)
                    }
                }
            }
        }
    }
    

    // MARK: - 文本：保持现有行为
    public func stream(text: String, config: AIModelConfig) {
        stream(userMessage: Message(role: .user, content: text), config: config)
    }
    

    
    public func messages() -> [Message] {
        repository.fetchMessages(sessionID: session.id)
    }
    
    
    @MainActor
    public func addSystemTip(_ text: String) {
        let tip = Message(role: .system, content: text)
        repository.appendMessage(sessionID: session.id, message: tip)
        onNewMessage?(tip)
    }
    
    
    public func isReasoningExpanded(messageID: UUID) -> Bool {
        reasoningExpanded[messageID] ?? false
    }

    
    public func toggleReasoningExpanded(messageID: UUID) {
        reasoningExpanded[messageID] = !(reasoningExpanded[messageID] ?? false)
    }
}

