//
//  MockImageLLMService.swift
//  byteDance
//
//  Created by da A on 2025/12/4.
//

import UIKit

class MockImageLLMService {
    func analyzeImage(_ data: Data) async throws -> String {
        // 模拟延迟
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "👀 我收到了你的图片！（这是模拟结果）"
    }
}
