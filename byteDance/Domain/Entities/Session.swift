//
//  Session.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import Foundation

public struct Session: Codable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var messages: [Message]
    public var archived: Bool

    public init(id: UUID = UUID(), title: String, messages: [Message] = [], archived: Bool = false) {
        self.id = id
        self.title = title
        self.messages = messages
        self.archived = archived
    }
}
