//
//  ChatRepository.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public final class ChatRepository: ChatRepositoryProtocol {
    private var sessions: [Session] = []

    public init() {
        // 添加一个示例会话，确保列表有内容
        sessions.append(Session(title: "Initial Chat", messages: [Message(role: .user, content: "Hello")], archived: false))
    }

    public func fetchSessions() -> [Session] {
        sessions
    }

    public func createSession(title: String) -> Session {
        let session = Session(title: title)
        sessions.append(session)
        return session
    }
    
    // 桩代码，仅用于满足协议
    public func renameSession(id: UUID, title: String) {}
    public func archiveSession(id: UUID) {}
    public func appendMessage(sessionID: UUID, message: Message) {}
    public func fetchMessages(sessionID: UUID) -> [Message] { return [] }
}
