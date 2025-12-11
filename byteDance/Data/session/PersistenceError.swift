import Foundation

enum PersistenceError: Error, LocalizedError {
    case sessionNotFound
    case messageNotFound
    case fileWriteFailed
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound: return "会话不存在"
        case .messageNotFound: return "消息不存在"
        case .fileWriteFailed: return "文件写入失败"
        case .fileReadFailed: return "文件读取失败"
        }
    }
}
