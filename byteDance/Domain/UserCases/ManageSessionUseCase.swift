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
        repository.createSession(title: title)
    }

    public func sessions() -> [Session] {
        repository.fetchSessions()
    }

    public func deleteSession(id: UUID) {    //新增会话删除
        repository.deleteSession(id: id)
    }
    public func rename(id: UUID, title: String) {
        repository.renameSession(id: id, title: title)
    }
    // 桩代码，仅用于满足协议
    public func archive(id: UUID) {}
}
