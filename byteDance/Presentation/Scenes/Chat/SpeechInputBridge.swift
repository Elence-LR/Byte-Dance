import Foundation

final class SpeechInputBridge {
    private let asr: SpeechTranscriptionService
    private weak var chatViewModel: ChatViewModel?
    private var listenTask: Task<Void, Never>?
    private var isRunning = false

    // 缓存“聊天模型”的 config
    private var chatConfig: AIModelConfig?

    init(chatViewModel: ChatViewModel, asr: SpeechTranscriptionService = AliyunRealtimeASRAdapter()) {
        self.chatViewModel = chatViewModel
        self.asr = asr
    }

    /// 同时传入：语音识别配置 + 聊天模型配置
    func start(asrConfig: ASRConfig, chatConfig: AIModelConfig) {
        guard !isRunning else { return }
        isRunning = true
        self.chatConfig = chatConfig

        listenTask?.cancel()
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await e in asr.events {
                await MainActor.run {
                    guard let vm = self.chatViewModel else { return }
                    switch e {
                    case .partial(let t):
                        vm.updateDraftFromASR(t)

                    case .final(let t):
                        // 用“聊天模型 config”发给 LLM（不是 ASR）
                        if let cfg = self.chatConfig {
                            vm.commitASRFinalAndStream(t, config: cfg)
                        }

                    default:
                        break
                    }
                }
            }
        }

        Task { [weak self] in
            do {
                try await self?.asr.connect(config: asrConfig) // 只用于 ASR
            } catch {
                print("[ASR] connect failed:", error)
            }
        }
    }

    func pushAudioChunk(_ data: Data) {
        guard isRunning else { return }
        Task {
            do { try await asr.sendAudioChunk(data) }
            catch { print("[ASR] send chunk failed:", error) }
        }
    }

    func stop(needCommit: Bool) {
        guard isRunning else { return }
        isRunning = false

        Task {
            if needCommit { try? await asr.commit() }
            await asr.close()
        }

        listenTask?.cancel()
        listenTask = nil
        chatConfig = nil
    }
}
