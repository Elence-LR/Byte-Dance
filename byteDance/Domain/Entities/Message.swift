//
//  Message.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public enum Role: String, Codable {
    case user
    case assistant
    case system
}

public struct Message: Codable, Equatable, Identifiable {
    public let id: UUID
    public let role: Role
    public var content: String
    public var reasoning: String?
    public let timestamp: Date

    public init(id: UUID = UUID(), role: Role, content: String, reasoning: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.timestamp = timestamp
    }
}
