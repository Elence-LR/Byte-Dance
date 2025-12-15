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
    private var currentAssistantID: UUID?
    private var regeneratableAssistantIDs: Set<UUID> = []
    private var uiThrottleTimer: Timer?
    private var uiThrottlePendingID: UUID?
    
    private let heightCache = MessageHeightCache()
    
    // 草稿相关属性
    public private(set) var currentDraft: String = "" {
        didSet {
            // 实时保存草稿
            saveDraft()
        }
    }
    private let draftKey: String
    
    public private(set) var isStreaming: Bool = false {
        didSet { onStreamingStateChanged?(isStreaming) }
    }
    
    public var onStreamingStateChanged: ((Bool) -> Void)?
    // 草稿更新回调
    public var onDraftUpdated: ((String) -> Void)?
    
    
    // 终止对话，取消当前流
    public func cancelCurrentStream() {
        if let id = currentAssistantID {
            regeneratableAssistantIDs.insert(id)
        }

        currentStreamTask?.cancel()
        currentStreamTask = nil
        isStreaming = false

        // 刷新被 stop 的 assistant 行，让“重试按钮”立刻出现
        if let id = currentAssistantID {
            notifyAssistantUpdated(id)
        }

        Task { @MainActor in
            self.addSystemTip(ChatError.cancelled.userMessage)
        }
    }




    public init(session: Session, sendUseCase: SendMessageUseCase, repository: ChatRepositoryProtocol) {
        self.session = session
        self.sendUseCase = sendUseCase
        self.repository = repository
        // 初始化草稿存储键（基于会话ID）
        self.draftKey = "draft_\(session.id.uuidString)"
        // 加载已保存的草稿
        loadDraft()
    }
    
    // 加载草稿
    private func loadDraft() {
        if let savedDraft = UserDefaults.standard.string(forKey: draftKey) {
            currentDraft = savedDraft
            onDraftUpdated?(currentDraft)
        }
    }
    
    // 保存草稿
    private func saveDraft() {
        UserDefaults.standard.set(currentDraft, forKey: draftKey)
    }
    
    // 更新草稿内容
    public func updateDraft(_ text: String) {
        currentDraft = text
        onDraftUpdated?(text)
    }
    
    // 清空草稿
    public func clearDraft() {
        currentDraft = ""
        UserDefaults.standard.removeObject(forKey: draftKey)
        onDraftUpdated?("")
    }

    public func send(text: String, config: AIModelConfig) {
        // 发送消息时清空草稿
        clearDraft()
        
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
            guard let data = ImageProcessor.optimizedJpegData(from: image, maxKB: 300) else {
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

        let assistantID = UUID()
        currentAssistantID = assistantID
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
                        heightCache.invalidate(id: assistantID)
                        hasAnyToken = true
                    } else {
                        contentBuffer += m.content
                        repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: contentBuffer)
                        heightCache.invalidate(id: assistantID)
                        if !m.content.isEmpty { hasAnyToken = true }
                    }

                    uiThrottlePendingID = assistantID
                    uiThrottleTimer?.invalidate()
                    uiThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                        guard let self = self, let id = self.uiThrottlePendingID else { return }
                        if let updated = self.repository.fetchMessages(sessionID: self.session.id).first(where: { $0.id == id }) {
                            self.onNewMessage?(updated)
                        }
                    }
                }

                // 正常结束：先结束流，再标记可重试，再刷新一次（让按钮出现）
                isStreaming = false
                currentStreamTask = nil
                regeneratableAssistantIDs.insert(assistantID)
                notifyAssistantUpdated(assistantID)

            } catch {
                isStreaming = false
                currentStreamTask = nil

                // 失败/取消都允许重试，并刷新一次
                regeneratableAssistantIDs.insert(assistantID)
                notifyAssistantUpdated(assistantID)

                let mapped = ErrorMapper.map(error)
                await MainActor.run {
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

    public func summarizeHistory(config: AIModelConfig) async -> String? {
        do {
            return try await sendUseCase.summarize(session: session, config: config)
        } catch {
            return nil
        }
    }
    
    public func streamWithCombined(displayText: String, sendText: String, config: AIModelConfig) {
        if isStreaming { cancelCurrentStream() }
        
        let displayMsg = Message(role: .user, content: displayText)
        repository.appendMessage(sessionID: session.id, message: displayMsg)
        onNewMessage?(displayMsg)
        
        var msgs = repository.fetchMessages(sessionID: session.id)
        if let idx = msgs.lastIndex(where: { $0.role == .user }) {
            let orig = msgs[idx]
            msgs[idx] = Message(id: orig.id, role: .user, content: sendText)
        } else {
            msgs.append(Message(role: .user, content: sendText))
        }
        
        let s = sendUseCase.stream(session: session, messages: msgs, config: config)
        
        let assistantID = UUID()
        currentAssistantID = assistantID
        repository.appendMessage(sessionID: session.id, message: Message(id: assistantID, role: .assistant, content: "", reasoning: nil))
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
                        heightCache.invalidate(id: assistantID)
                        hasAnyToken = true
                    } else {
                        contentBuffer += m.content
                        repository.updateMessageContent(sessionID: session.id, messageID: assistantID, content: contentBuffer)
                        heightCache.invalidate(id: assistantID)
                        if !m.content.isEmpty { hasAnyToken = true }
                    }
                    
                    uiThrottlePendingID = assistantID
                    uiThrottleTimer?.invalidate()
                    uiThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                        guard let self = self, let id = self.uiThrottlePendingID else { return }
                        if let updated = self.repository.fetchMessages(sessionID: self.session.id).first(where: { $0.id == id }) {
                            self.onNewMessage?(updated)
                        }
                    }
                }
                
                isStreaming = false
                currentStreamTask = nil
                regeneratableAssistantIDs.insert(assistantID)
                notifyAssistantUpdated(assistantID)
                
            } catch {
                isStreaming = false
                currentStreamTask = nil
                regeneratableAssistantIDs.insert(assistantID)
                notifyAssistantUpdated(assistantID)
                
                let mapped = ErrorMapper.map(error)
                await MainActor.run {
                    if mapped != .cancelled {
                        self.addSystemTip(mapped.userMessage)
                    }
                }
            }
        }
    }
    
    
    public func canRegenerate(messageID: UUID) -> Bool {
        return regeneratableAssistantIDs.contains(messageID) && !isStreaming
    }

    public func regenerate(assistantMessageID: UUID, config: AIModelConfig) {
        // 若正在流，先停掉当前流（避免并发）
        if isStreaming { cancelCurrentStream() }

        let all = repository.fetchMessages(sessionID: session.id)

        guard let assistantIndex = all.firstIndex(where: { $0.id == assistantMessageID }) else { return }

        // 找到该 assistant 前面最近的一条 user
        guard let userIndex = all[..<assistantIndex].lastIndex(where: { $0.role == .user }) else { return }

        // 关键：上下文只取到那条 user 为止，不把旧 assistant 回复喂回去
        let contextMessages = Array(all[...userIndex])

        // 清空这个 assistant 气泡内容，复用同一个 cell
        repository.updateMessageContent(sessionID: session.id, messageID: assistantMessageID, content: "")
        repository.updateMessageReasoning(sessionID: session.id, messageID: assistantMessageID, reasoning: "")
        heightCache.invalidate(id: assistantMessageID)

        currentAssistantID = assistantMessageID
        isStreaming = true

        let s = sendUseCase.stream(session: session, messages: contextMessages, config: config)

        currentStreamTask = Task {
            var contentBuffer = ""
            var reasoningBuffer = ""

            do {
                for try await m in s {
                    if Task.isCancelled { throw CancellationError() }

                    if let r = m.reasoning {
                        reasoningBuffer += r
                        repository.updateMessageReasoning(sessionID: session.id, messageID: assistantMessageID, reasoning: reasoningBuffer)
                        heightCache.invalidate(id: assistantMessageID)
                    } else {
                        contentBuffer += m.content
                        repository.updateMessageContent(sessionID: session.id, messageID: assistantMessageID, content: contentBuffer)
                        heightCache.invalidate(id: assistantMessageID)
                    }

                    uiThrottlePendingID = assistantMessageID
                    uiThrottleTimer?.invalidate()
                    uiThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                        guard let self = self, let id = self.uiThrottlePendingID else { return }
                        if let updated = self.repository.fetchMessages(sessionID: self.session.id).first(where: { $0.id == id }) {
                            self.onNewMessage?(updated)
                        }
                    }
                }

                isStreaming = false
                currentStreamTask = nil
                regeneratableAssistantIDs.insert(assistantMessageID)

            } catch {
                isStreaming = false
                currentStreamTask = nil
                regeneratableAssistantIDs.insert(assistantMessageID)

                let mapped = ErrorMapper.map(error)
                await MainActor.run {
                    if mapped != .cancelled {
                        self.addSystemTip(mapped.userMessage)
                    }
                }
            }
        }
    }
    
    
    private func notifyAssistantUpdated(_ id: UUID) {
        if let updated = repository.fetchMessages(sessionID: session.id).first(where: { $0.id == id }) {
            onNewMessage?(updated)
        }
    }
    
    
    // 1) ASR partial -> 只更新草稿（不发送）
    @MainActor
    public func updateDraftFromASR(_ text: String) {
        updateDraft(text) // 复用已有草稿逻辑
    }

    // 2) ASR final -> 清草稿 + 走你现有 stream 发送
    @MainActor
    public func commitASRFinalAndStream(_ text: String, config: AIModelConfig) {
        clearDraft()       // 复用已有清草稿逻辑
        stream(text: text, config: config) // 走现有文本入口
    }
    
    
    
    
}
 
extension ChatViewModel {
    public func cachedHeight(messageID: UUID, width: CGFloat) -> CGFloat? {
        heightCache.height(for: messageID, width: width)
    }
    public func setCachedHeight(messageID: UUID, width: CGFloat, height: CGFloat) {
        heightCache.setHeight(height, for: messageID, width: width)
    }
    public func invalidateHeight(messageID: UUID) {
        heightCache.invalidate(id: messageID)
    }
}
