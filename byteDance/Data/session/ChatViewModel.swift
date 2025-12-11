import SwiftUI
import Foundation
import Combine
import UIKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draftContent: String = ""
    @Published var errorMessage: ErrorAlert?
    
    private let sessionId: String
    
    init(sessionId: String) {
        self.sessionId = sessionId
        Task { await loadData() }
    }
    
    // 加载历史消息和草稿
    func loadData() async {
        do {
            messages = try await ChatPersistenceManager.shared.getMessages(for: sessionId)
            let session = try await ChatPersistenceManager.shared.getSession(sessionId)
            draftContent = session.draftContent ?? ""
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: error.localizedDescription)
        }
    }
    
    // 发送用户文本消息
    func sendUserMessage() async {
        guard !draftContent.isEmpty else { return }
        let message = ChatMessage(userContent: draftContent, sessionId: sessionId)
        do {
            try await ChatPersistenceManager.shared.saveMessage(message)
            messages.append(message)
            draftContent = ""
            try await ChatPersistenceManager.shared.saveDraft(for: sessionId, draft: nil)
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: error.localizedDescription)
        }
    }
    
    // 保存草稿
    func saveDraft() async {
        do {
            var session = try await ChatPersistenceManager.shared.getSession(sessionId)
            session.draftContent = draftContent
            try await ChatPersistenceManager.shared.saveSession(session)
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: error.localizedDescription)
        }
    }
    
    // 修复：将发送图片消息方法移入类内
    func sendImageMessage(_ imageData: Data, textContent: String = "") async {
        let message = ChatMessage(imageData: imageData, sessionId: sessionId, textContent: textContent)
        do {
            try await ChatPersistenceManager.shared.saveMessage(message)
            messages.append(message)
            errorMessage = nil
            draftContent = "" // 发送后清空输入框
        } catch {
            errorMessage = ErrorAlert(message: "发送图片失败：\(error.localizedDescription)")
        }
    }
}

// 保存草稿
extension ChatPersistenceManager {
    func saveDraft(for sessionId: String, draft: String?) async throws {
        var session = try await getSession(sessionId)
        session.draftContent = draft
        try await saveSession(session)
    }
}
