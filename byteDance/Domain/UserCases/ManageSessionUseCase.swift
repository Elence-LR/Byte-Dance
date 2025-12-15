//
//  ManageSessionUseCase.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public final class ManageSessionUseCase {
    private let repository: ChatRepositoryProtocol

    public init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }

    public func newSession(title: String) -> Session {
        let newSession = repository.createSession(title: title)
        return newSession
    }

    // 获取会话列表（已排序：置顶在前，按更新时间降序）
    public func sessions() -> [Session] {
        let allSessions = repository.fetchSessions()
        // 过滤未归档的会话并排序
        return allSessions.filter { !$0.archived }
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned
                }
                return $0.updatedAt > $1.updatedAt
            }
    }
    
    // 获取归档会话
    public func archivedSessions() -> [Session] {
        repository.fetchSessions()
            .filter { $0.archived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func deleteSession(id: UUID) {
        repository.deleteSession(id: id)
    }
    
    public func rename(id: UUID, title: String) {
        repository.renameSession(id: id, title: title)
        // 更新时间戳
        updateSessionTimestamp(id: id)
    }
    
    // 归档会话
    public func archive(id: UUID) {
        repository.archiveSession(id: id)
    }
    
    // 取消归档
    public func unarchive(id: UUID) {
        guard let session = repository.fetchSessions().first(where: { $0.id == id }) else { return }
        var updatedSession = session
        updatedSession.archived = false
        repository.updateSession(updatedSession)
    }
    
    // 置顶会话
    public func pin(id: UUID) {
        guard let session = repository.fetchSessions().first(where: { $0.id == id }) else { return }
        var updatedSession = session
        updatedSession.isPinned = true
        updatedSession.updatedAt = Date()
        repository.updateSession(updatedSession)
    }
    
    // 取消置顶
    public func unpin(id: UUID) {
        guard let session = repository.fetchSessions().first(where: { $0.id == id }) else { return }
        var updatedSession = session
        updatedSession.isPinned = false
        updatedSession.updatedAt = Date()
        repository.updateSession(updatedSession)
    }
    
    // 更新会话时间戳
    private func updateSessionTimestamp(id: UUID) {
        guard let session = repository.fetchSessions().first(where: { $0.id == id }) else { return }
        var updatedSession = session
        updatedSession.updatedAt = Date()
        repository.updateSession(updatedSession)
    }
}
