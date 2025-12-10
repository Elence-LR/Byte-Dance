//
//  Message.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//  合并本地/网络图片和API attachments支持
//

import Foundation

// 角色类型
public enum Role: String, Codable {
    case user
    case assistant
    case system
}

// API 图片类型
public enum MessageAttachmentKind: String, Codable {
    case imageDataURL   // "data:image/jpeg;base64,..."
}

// API 附件结构
public struct MessageAttachment: Codable, Equatable {
    public let kind: MessageAttachmentKind
    public let value: String

    public init(kind: MessageAttachmentKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

// 消息结构体
public struct Message: Codable, Equatable, Identifiable {
    public let id: UUID
    public let role: Role
    public var content: String
    public var reasoning: String?

    // ✅ 本地/网络图片支持
    public var imageData: Data?      // 本地图片
    public var imageURL: URL?        // 网络图片（可选）

    // ✅ API attachments 支持
    public var attachments: [MessageAttachment]?

    public let timestamp: Date

    // 合并初始化器
    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoning: String? = nil,
        imageData: Data? = nil,
        imageURL: URL? = nil,
        attachments: [MessageAttachment]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.imageData = imageData
        self.imageURL = imageURL
        self.attachments = attachments
        self.timestamp = timestamp
    }
}

// ✅ 辅助扩展，可将本地/网络图片转为 attachments
public extension Message {
    mutating func convertImagesToAttachments() {
        var newAttachments: [MessageAttachment] = attachments ?? []

        if let data = imageData {
            let base64Str = data.base64EncodedString()
            let value = "data:image/jpeg;base64,\(base64Str)"
            let att = MessageAttachment(kind: .imageDataURL, value: value)
            newAttachments.append(att)
        }

        if let url = imageURL {
            let att = MessageAttachment(kind: .imageDataURL, value: url.absoluteString)
            newAttachments.append(att)
        }

        attachments = newAttachments
        // 清空原来的 imageData / imageURL 避免重复
        imageData = nil
        imageURL = nil
    }
}
