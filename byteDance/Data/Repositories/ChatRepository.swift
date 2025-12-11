import Foundation

public final class ChatRepository: ChatRepositoryProtocol {
    private var sessions: [Session] = []

    public init() {}

    public func fetchSessions() -> [Session] {
        sessions
    }

    public func createSession(title: String) -> Session {
        let session = Session(title: title)
        sessions.append(session)
        return session
    }

    public func renameSession(id: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].title = title
    }

    public func archiveSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].archived = true
    }

    public func appendMessage(sessionID: UUID, message: Message) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        print("Repo append role:", message.role.rawValue, "contentLen:", message.content.count)
        sessions[index].messages.append(message)
    }

    public func fetchMessages(sessionID: UUID) -> [Message] {
        sessions.first(where: { $0.id == sessionID })?.messages ?? []
    }
    
    public func updateMessageContent(sessionID: UUID, messageID: UUID, content: String) {
        guard let sIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let mIndex = sessions[sIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        sessions[sIndex].messages[mIndex].content = content
        print("Repo update content len:", content.count)
    }
    
    public func updateMessageReasoning(sessionID: UUID, messageID: UUID, reasoning: String) {
        guard let sIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let mIndex = sessions[sIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        sessions[sIndex].messages[mIndex].reasoning = reasoning
        print("Repo update reasoning len:", reasoning.count)
    }
}
