//
//  AliyunRealtimeASRAdapter.swift
//  byteDance
//
//  Created by Huhuhu on 2025/12/14.
//

import Foundation

public final class AliyunRealtimeASRAdapter: SpeechTranscriptionService {
    public var events: AsyncStream<ASREvent> { _events }
    private let _events: AsyncStream<ASREvent>
    private let cont: AsyncStream<ASREvent>.Continuation

    private let ws: WSClient
    private var receiveTask: Task<Void, Never>?

    public init(ws: WSClient = WSClient()) {
        self.ws = ws
        var c: AsyncStream<ASREvent>.Continuation!
        self._events = AsyncStream<ASREvent> { c = $0 }
        self.cont = c
    }

    public func connect(config: ASRConfig) async throws {
        let base: String = (config.region == .beijing)
            ? "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
            : "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime"
        let url = URL(string: "\(base)?model=\(config.model)")!

        var req = URLRequest(url: url)
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        ws.connect(req)
        cont.yield(.opened(sessionID: nil))

        // 1) session.update
        var transcription: [String: Any] = [:]
        if let lang = config.language { transcription["language"] = lang }

        var sessionObj: [String: Any] = [
            "modalities": ["text"],
            "input_audio_format": config.inputAudioFormat,
            "sample_rate": config.inputSampleRate,
            "input_audio_transcription": transcription
        ]

        // 可选：VAD（server_vad）
        if config.enableVAD {
            sessionObj["turn_detection"] = [
                "type": "server_vad",
                "threshold": 0.2,
                "silence_duration_ms": 800
            ]
        } else {
            sessionObj["turn_detection"] = NSNull()
        }

        try await sendJSON(["type": "session.update", "session": sessionObj])

        // 2) receive loop
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
    }

    public func sendAudioChunk(_ data: Data) async throws {
        let b64 = data.base64EncodedString()
        try await sendJSON(["type": "input_audio_buffer.append", "audio": b64])
    }

    public func commit() async throws {
        try await sendJSON(["type": "input_audio_buffer.commit"])
    }

    public func close() async {
        receiveTask?.cancel()
        receiveTask = nil
        ws.close()
        cont.yield(.closed(code: 0, reason: "closed"))
    }

    // MARK: - Private

    private func sendJSON(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj)
        let text = String(data: data, encoding: .utf8) ?? "{}"
        try await ws.send(text: text)
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                let msg = try await ws.receive()
                let text: String?
                switch msg {
                case .string(let s): text = s
                case .data(let d):   text = String(data: d, encoding: .utf8)
                @unknown default:    text = nil
                }
                if let t = text { handleServerEvent(t) }
            } catch {
                cont.yield(.closed(code: -1, reason: error.localizedDescription))
                return
            }
        }
    }

    private func handleServerEvent(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let type = json["type"] as? String
        else { return }

        switch type {
        case "session.created":
            let sid = (json["session"] as? [String: Any])?["id"] as? String
            cont.yield(.opened(sessionID: sid))

        case "input_audio_buffer.speech_started":
            cont.yield(.vadSpeechStarted)

        case "input_audio_buffer.speech_stopped":
            cont.yield(.vadSpeechStopped)

        case "conversation.item.input_audio_transcription.text":
            if let t = json["text"] as? String, !t.isEmpty {
                cont.yield(.partial(text: t))
            }

        case "conversation.item.input_audio_transcription.completed":
            if let t = json["transcript"] as? String, !t.isEmpty {
                cont.yield(.final(text: t))
            }

        default:
            break
        }
    }
}
