import SwiftUI
import Foundation
import Combine

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
class SessionListViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var errorMessage: ErrorAlert?
    
    // 加载所有会话
    func loadSessions() async {
        do {
            sessions = try await ChatPersistenceManager.shared.getAllSessions()
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: error.localizedDescription)
        }
    }
    
    // 新建会话
    func createNewSession(title: String) async {
        let session = ChatSession(title: title)
        do {
            try await ChatPersistenceManager.shared.saveSession(session)
            await loadSessions()
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: error.localizedDescription)
        }
    }
    
    // 删除会话
    func deleteSession(_ session: ChatSession) async {
        do {
            try await ChatPersistenceManager.shared.deleteSession(session.id)
            await loadSessions()
            errorMessage = nil
        } catch {
            errorMessage = ErrorAlert(message: "删除会话失败：\(error.localizedDescription)")
        }
    }
}
