import Foundation

// 草稿存储服务
final class DraftStorage {
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "chat_draft_"
    
    func save(draft: ChatDraft) {
        let key = keyPrefix + draft.sessionID.uuidString
        if let data = try? JSONEncoder().encode(draft) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func load(for sessionID: UUID) -> ChatDraft? {
        let key = keyPrefix + sessionID.uuidString
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ChatDraft.self, from: data)
    }
    
    func clear(for sessionID: UUID) {
        let key = keyPrefix + sessionID.uuidString
        userDefaults.removeObject(forKey: key)
    }
}
