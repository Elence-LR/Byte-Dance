import Foundation

public final class MockLLMService: LLMServiceProtocol {
    public init() {}

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        let last = messages.last?.content ?? ""
        return Message(role: .assistant, content: "Echo: \(last)")
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncStream<Message> {
        let last = messages.last?.content ?? ""
        let tokens = ["Echo:", last]
        return AsyncStream { continuation in
            Task {
                for t in tokens {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continuation.yield(Message(role: .assistant, content: t))
                }
                continuation.finish()
            }
        }
    }
}
