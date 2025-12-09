//
//  ChatRepositoryProtocol.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public protocol ChatRepositoryProtocol {
    func fetchSessions() -> [Session]
    func createSession(title: String) -> Session
    func renameSession(id: UUID, title: String)
    func archiveSession(id: UUID)
    func appendMessage(sessionID: UUID, message: Message)
    func fetchMessages(sessionID: UUID) -> [Message]
    func updateMessageContent(sessionID: UUID, messageID: UUID, content: String)
    func updateMessageReasoning(sessionID: UUID, messageID: UUID, reasoning: String)
}
