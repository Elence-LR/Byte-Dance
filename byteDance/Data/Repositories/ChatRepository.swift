import Foundation

public final class ChatRepository: ChatRepositoryProtocol {
    private var sessions: [Session] = []
    // 引入文件存储工具（用于持久化）
    private let fileStorage = FileStorage.shared  // 依赖实现的FileStorage
    
    public init() {
        // 启动时从本地加载会话（首次使用时为空）
        sessions = fileStorage.loadSessions() ?? []
    }
    
    public func fetchSessions() -> [Session] {
        return sessions
    }
    
    public func createSession(title: String) -> Session {
        let newSession = Session(
            id: UUID(),
            title: title,
            messages: [],
            archived: false,
            isCurrent: false,
            unreadCount: 0
        )
        sessions.append(newSession)
        saveSessions(sessions)  // 保存到本地
        return newSession
    }
    
    // 重命名会话
    public func renameSession(id: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].title = title
        saveSessions(sessions) // 同步到本地存储
    }
    
    public func archiveSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].archived = true
        saveSessions(sessions)  // 同步到本地
    }
    
    public func appendMessage(sessionID: UUID, message: Message) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].messages.append(message)
        
        saveSessions(sessions)  // 同步到本地
        print("Repo append role:", message.role, "contentLen:", message.content.count)
    }
    
    public func fetchMessages(sessionID: UUID) -> [Message] {
        return sessions.first(where: { $0.id == sessionID })?.messages ?? []
    }
    
    public func updateMessageContent(sessionID: UUID, messageID: UUID, content: String) {
        guard let sIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let mIndex = sessions[sIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        sessions[sIndex].messages[mIndex].content = content
        saveSessions(sessions)  // 同步到本地
        print("Repo update content len:", content.count)
    }
    
    public func updateMessageReasoning(sessionID: UUID, messageID: UUID, reasoning: String) {
        guard let sIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let mIndex = sessions[sIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        sessions[sIndex].messages[mIndex].reasoning = reasoning
        saveSessions(sessions)  // 同步到本地
        print("Repo update reasoning len:", reasoning.count)
    }
    // 新增：删除会话
    public func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions(sessions) // 同步到本地存储
    }
    
    public func updateSession(_ session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        saveSessions(sessions)
    }
       
    // MARK: - 新增：状态管理方法（实现协议）
    
    // 保存会话列表到本地
    public func saveSessions(_ sessions: [Session]) {
        try? fileStorage.saveSessions(sessions)  // 调用FileStorage持久化
    }
    
    //标记当前会话
    public func setCurrentSession(id: UUID) {
        // 遍历所有会话，仅目标会话标记为当前
        for index in sessions.indices {
            sessions[index].isCurrent = (sessions[index].id == id)
        }
        saveSessions(sessions)  // 同步到本地
    }
    
}
