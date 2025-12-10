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


public enum MessageAttachmentKind: String, Codable {
    case imageDataURL   // "data:image/jpeg;base64,...."
}

public struct MessageAttachment: Codable, Equatable {
    public let kind: MessageAttachmentKind
    public let value: String

    public init(kind: MessageAttachmentKind, value: String) {
        self.kind = kind
        self.value = value
    }
}


public struct Message: Codable, Equatable, Identifiable {
    public let id: UUID
    public let role: Role
    public var content: String
    public var reasoning: String?
    public var attachments: [MessageAttachment]?   // 新增
    public let timestamp: Date

    public init(id: UUID = UUID(), role: Role, content: String, reasoning: String? = nil, attachments: [MessageAttachment]? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.attachments = attachments
        self.timestamp = timestamp
    }
}
