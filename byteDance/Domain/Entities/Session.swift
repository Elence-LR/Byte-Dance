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
    // 新增状态字段
    public var isCurrent: Bool = false // 是否为当前活跃会话
    
     public init(
         id: UUID = UUID(),
         title: String,
         messages: [Message] = [],
         archived: Bool = false,
         isCurrent: Bool = false,
         unreadCount: Int = 0
     ) {
         self.id = id
         self.title = title
         self.messages = messages
         self.archived = archived
         self.isCurrent = isCurrent

     }
}
