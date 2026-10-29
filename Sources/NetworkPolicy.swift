import Foundation
final class NetworkPolicy {
    static let shared = NetworkPolicy()
    private let lock = NSLock()
    private var epoch = 0
    private var cancellations: [UUID:()->Void] = [:]
    var generation: Int { lock.lock(); defer { lock.unlock() }; return epoch }
    func begin(expected: Int, start: () throws -> Void, cancel: @escaping ()->Void) throws -> UUID {
        lock.lock(); defer { lock.unlock() }
        guard expected == epoch else { throw RadioError.message("网络设置已更改，请重试") }
        let id = UUID(); try start(); cancellations[id] = cancel; return id
    }
    func finish(_ id: UUID) { lock.lock(); cancellations.removeValue(forKey:id); lock.unlock() }
    func cancelAll() {
        lock.lock(); epoch += 1; let actions = Array(cancellations.values); cancellations.removeAll(); lock.unlock()
        actions.forEach { $0() }
    }
}
