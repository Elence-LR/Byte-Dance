import Foundation

enum ASRDebugRunner {
    static func runFileTest(apiKey: String) {
        Task {
            let asr = AliyunRealtimeASRAdapter()

            // 订阅事件
            Task {
                for await e in asr.events {
                    print("[ASR]", e)
                }
            }

            try await asr.connect(config: ASRConfig(apiKey: apiKey,
                                                   region: .beijing,
                                                   model: "qwen3-asr-flash-realtime",
                                                   language: "zh",
                                                   inputAudioFormat: "pcm",
                                                   inputSampleRate: 16000,
                                                   enableVAD: true))

            let url = Bundle.main.url(forResource: "output", withExtension: "pcm")!
            let pcm = try Data(contentsOf: url)

            // 40ms 分片：16kHz * 0.04 = 640 samples；PCM16 => 1280 bytes
            let chunkSize = 1280
            var offset = 0
            while offset < pcm.count {
                let end = min(offset + chunkSize, pcm.count)
                let chunk = pcm.subdata(in: offset..<end)
                try await asr.sendAudioChunk(chunk)
                offset = end
                try await Task.sleep(nanoseconds: 40_000_000)
            }

            // 给点时间吐 final
            try await Task.sleep(nanoseconds: 900_000_000)
            await asr.close()
        }
    }
}
