// ChatPersistenceManager.swift
import Foundation
import UIKit

final class ChatPersistenceManager {
    // 单例模式
    static let shared = ChatPersistenceManager()
    private init() {}
    
    // 内存缓存
    private var sessionCache: [String: ChatSession] = [:]
    private var messageCache: [String: [ChatMessage]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - 路径工具方法
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func getSessionsDirectory() -> URL {
        let dir = getDocumentsDirectory().appendingPathComponent("Sessions")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func getMessagesDirectory() -> URL {
        let dir = getDocumentsDirectory().appendingPathComponent("Messages")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func getSessionFileURL(_ sessionId: String) -> URL {
        getSessionsDirectory().appendingPathComponent("\(sessionId).json")
    }
    
    private func getMessageFileURL(_ messageId: String) -> URL {
        getMessagesDirectory().appendingPathComponent("\(messageId).json")
    }
    
    // MARK: - 核心会话操作
    // 保存会话
    func saveSession(_ session: ChatSession) async throws {
        let url = getSessionFileURL(session.id)
        let data = try JSONEncoder().encode(session)
        try data.write(to: url)
        cacheLock.withLock { sessionCache[session.id] = session }
    }
    
    // 删除会话
    func deleteSession(_ sessionId: String) async throws {
        // 1.删除会话文件
            let messages = try await getMessages(for: sessionId)
            for msg in messages where msg.imageLocalPath != nil {
                try deleteImage(at: msg.imageLocalPath!)
            }
        let sessionUrl = getSessionFileURL(sessionId)
        if FileManager.default.fileExists(atPath: sessionUrl.path) {
            try FileManager.default.removeItem(at: sessionUrl)
        }
        
        // 2. 删除关联消息文件
        let messageUrls = try getMessageFiles(for: sessionId)
        for url in messageUrls {
            try FileManager.default.removeItem(at: url)
        }
        
        // 3. 清空缓存
        cacheLock.withLock {
            sessionCache.removeValue(forKey: sessionId)
            messageCache.removeValue(forKey: sessionId)
        }
    }
    
    // 获取单个会话
    func getSession(_ sessionId: String) async throws -> ChatSession {
        if let cached = cacheLock.withLock({ sessionCache[sessionId] }) {
            return cached
        }
        let url = getSessionFileURL(sessionId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.sessionNotFound
        }
        let data = try Data(contentsOf: url)
        let session = try JSONDecoder().decode(ChatSession.self, from: data)
        cacheLock.withLock { sessionCache[session.id] = session }
        return session
    }
    
    // 获取所有会话
    func getAllSessions() async throws -> [ChatSession] {
        // 优先读缓存
        let cached = cacheLock.withLock {
            sessionCache.values.sorted { $0.updateTime > $1.updateTime }
        }
        if let latest = cached.first, Date().timeIntervalSince1970 - latest.updateTime < 300 {
            return cached
        }
        
        // 读文件
        let urls = try FileManager.default.contentsOfDirectory(at: getSessionsDirectory(), includingPropertiesForKeys: nil)
        var sessions = [ChatSession]()
        for url in urls {
            let data = try Data(contentsOf: url)
            let session = try JSONDecoder().decode(ChatSession.self, from: data)
            sessions.append(session)
        }
        
        let sorted = sessions.sorted { $0.updateTime > $1.updateTime }
        cacheLock.withLock {
            sessionCache = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        }
        return sorted
    }
    
    // MARK: - 消息操作
    func saveMessage(_ message: ChatMessage) async throws {
        let url = getMessageFileURL(message.id)
        let data = try JSONEncoder().encode(message)
        try data.write(to: url)
        cacheLock.withLock {
            var messages = messageCache[message.sessionId] ?? []
            messages.append(message)
            messageCache[message.sessionId] = messages.sorted { $0.createTime < $1.createTime }
        }
    }
    
    func getMessages(for sessionId: String) async throws -> [ChatMessage] {
        if let cached = cacheLock.withLock({ messageCache[sessionId] }) {
            return cached
        }
        let urls = try getMessageFiles(for: sessionId)
        var messages = [ChatMessage]()
        for url in urls {
            let data = try Data(contentsOf: url)
            let msg = try JSONDecoder().decode(ChatMessage.self, from: data)
            messages.append(msg)
        }
        let sorted = messages.sorted { $0.createTime < $1.createTime }
        cacheLock.withLock { messageCache[sessionId] = sorted }
        return sorted
    }
    
    // 私有辅助方法
    private func getMessageFiles(for sessionId: String) throws -> [URL] {
        let allUrls = try FileManager.default.contentsOfDirectory(at: getMessagesDirectory(), includingPropertiesForKeys: nil)
        var sessionUrls = [URL]()
        for url in allUrls {
            let data = try Data(contentsOf: url)
            let msg = try JSONDecoder().decode(ChatMessage.self, from: data)
            if msg.sessionId == sessionId {
                sessionUrls.append(url)
            }
        }
        return sessionUrls
    }
}
// MARK: - 图片文件操作
extension ChatPersistenceManager {
    func saveImage(_ imageData: Data) throws -> (localPath: String, width: CGFloat, height: CGFloat) {
        let fileName = "\(UUID().uuidString).png"
        let imageUrl = getImagesDirectory().appendingPathComponent(fileName)
        try imageData.write(to: imageUrl)
        
        if let image = UIImage(data: imageData) {
            return (imageUrl.path, image.size.width, image.size.height)
        } else {
            throw PersistenceError.fileWriteFailed
        }
    }
    
    func loadImage(from localPath: String) -> UIImage? {
        guard FileManager.default.fileExists(atPath: localPath) else { return nil }
        return UIImage(contentsOfFile: localPath)
    }
    
    func deleteImage(at localPath: String) throws {
        guard FileManager.default.fileExists(atPath: localPath) else { return }
        try FileManager.default.removeItem(atPath: localPath)
    }
    
    private func getImagesDirectory() -> URL {
        let dir = getDocumentsDirectory().appendingPathComponent("Images")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
