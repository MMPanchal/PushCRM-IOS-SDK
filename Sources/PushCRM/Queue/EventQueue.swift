import Foundation

/// Manages event queue with offline persistence and batch flushing
final class EventQueue {
    private let networkClient: NetworkClient
    private let storage: StorageManager
    private let config: PushCRMConfig
    private var queue: [[String: Any]] = []
    private let lock = NSLock()
    private var flushTimer: Timer?
    private var isFlushing = false

    init(networkClient: NetworkClient, storage: StorageManager, config: PushCRMConfig) {
        self.networkClient = networkClient
        self.storage = storage
        self.config = config
        self.queue = storage.loadPendingEvents()
    }

    func enqueue(event: String, properties: [String: Any]?) {
        lock.lock()
        defer { lock.unlock() }

        let payload: [String: Any] = [
            "event": event,
            "properties": properties ?? [:],
            "deviceId": storage.deviceId,
            "userId": storage.userId ?? "",
            "sessionId": storage.sessionId ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        queue.append(payload)

        if queue.count >= config.maxQueueSize {
            flushInternal()
        }
    }

    func startFlushing() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flushTimer?.invalidate()
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.config.flushInterval, repeats: true) { [weak self] _ in
                self?.flush()
            }
        }
    }

    func flush() {
        lock.lock()
        flushInternal()
        lock.unlock()
    }

    func persistQueue() {
        lock.lock()
        storage.savePendingEvents(queue)
        lock.unlock()
    }

    private func flushInternal() {
        guard !isFlushing, !queue.isEmpty else { return }
        isFlushing = true

        let batch = Array(queue.prefix(50))
        let body: [String: Any] = [
            "events": batch,
            "deviceId": storage.deviceId
        ]

        networkClient.post(endpoint: .events, body: body) { [weak self] result in
            guard let self else { return }
            self.lock.lock()
            switch result {
            case .success:
                self.queue.removeFirst(min(batch.count, self.queue.count))
                self.storage.clearPendingEvents()
                if !self.queue.isEmpty {
                    self.storage.savePendingEvents(self.queue)
                }
            case .failure:
                self.storage.savePendingEvents(self.queue)
            }
            self.isFlushing = false
            self.lock.unlock()
        }
    }
}
