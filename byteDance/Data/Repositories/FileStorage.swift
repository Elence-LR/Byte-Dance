import Foundation

/// 本地文件存储工具，负责将数据序列化到沙盒路径
public final class FileStorage {
    // 单例实例（全局共享）
    public static let shared = FileStorage()
    
    // 沙盒中用于存储数据的目录（Documents/byteDanceData）
    private let baseURL: URL
    
    // 初始化：创建存储目录（若不存在）
    private init() {
        // 获取Documents目录
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("无法获取Documents目录")
        }
        // 创建自定义子目录（避免与其他文件冲突）
        baseURL = documentsURL.appendingPathComponent("byteDanceData")
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
    
    // MARK: - 通用存储方法（支持Codable类型）
    
    /// 保存数据到本地文件
    /// - Parameters:
    ///   - data: 要保存的数据（需遵循Codable）
    ///   - fileName: 文件名（如"session_123"、"all_sessions"）
    public func save<T: Codable>(_ data: T, fileName: String) throws {
        let fileURL = baseURL.appendingPathComponent(fileName)
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: fileURL)
    }
    
    /// 从本地文件加载数据
    /// - Parameter fileName: 文件名
    /// - Returns: 解码后的数据（若文件不存在或解码失败，返回nil）
    public func load<T: Codable>(fileName: String) -> T? {
        let fileURL = baseURL.appendingPathComponent(fileName)
        guard let jsonData = try? Data(contentsOf: fileURL) else {
            return nil // 文件不存在
        }
        return try? JSONDecoder().decode(T.self, from: jsonData)
    }
    
    /// 删除本地文件
    /// - Parameter fileName: 文件名
    public func delete(fileName: String) throws {
        let fileURL = baseURL.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - 会话相关便捷方法（供ChatRepository调用）
    
    /// 保存所有会话列表
    public func saveSessions(_ sessions: [Session]) throws {
        try save(sessions, fileName: "all_sessions.json")
    }
    
    /// 加载所有会话列表
    public func loadSessions() -> [Session]? {
        load(fileName: "all_sessions.json")
    }
    
    /// 保存单个会话的消息
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - sessionId: 会话ID（作为文件名，确保唯一）
    public func saveMessages(_ messages: [Message], for sessionId: UUID) throws {
        try save(messages, fileName: "messages_\(sessionId).json")
    }
    
    /// 加载单个会话的消息
    public func loadMessages(for sessionId: UUID) -> [Message]? {
        load(fileName: "messages_\(sessionId).json")
    }
}
