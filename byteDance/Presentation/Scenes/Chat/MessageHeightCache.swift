import UIKit

public final class MessageHeightCache {
    private struct Key: Hashable {
        let id: UUID
        let width: Int
    }
    private var store: [Key: CGFloat] = [:]
    private let queue = DispatchQueue(label: "message.height.cache.queue", attributes: .concurrent)
    public init() {}
    private func k(_ id: UUID, _ width: CGFloat) -> Key {
        Key(id: id, width: Int(width.rounded(.down)))
    }
    public func height(for id: UUID, width: CGFloat) -> CGFloat? {
        var v: CGFloat?
        queue.sync { v = store[k(id, width)] }
        return v
    }
    public func setHeight(_ h: CGFloat, for id: UUID, width: CGFloat) {
        queue.async(flags: .barrier) { self.store[self.k(id, width)] = h }
    }
    public func invalidate(id: UUID) {
        queue.async(flags: .barrier) {
            self.store = self.store.filter { $0.key.id != id }
        }
    }
    public func invalidateAll() {
        queue.async(flags: .barrier) { self.store.removeAll() }
    }
}
