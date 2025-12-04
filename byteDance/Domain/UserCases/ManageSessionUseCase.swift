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
    
    // 桩代码，仅用于满足协议
    public func rename(id: UUID, title: String) {}
    public func archive(id: UUID) {}
}
