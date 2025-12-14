import Foundation

// 定义草稿模型
struct ChatDraft: Codable {
    let sessionID: UUID  // 关联会话
    var text: String     // 文本草稿
    var imageData: Data? // 图片草稿
    let updatedAt: Date  // 最后更新时间
}
