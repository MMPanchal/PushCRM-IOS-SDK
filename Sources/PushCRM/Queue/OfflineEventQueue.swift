import Foundation

/// Offline-first event queue with batch upload, retry, and persistence.
///
/// Flush triggers:
/// - Queue reaches `batchSize` (default 20)
/// - Timer fires every `flushInterval` (default 30s)
/// - App enters background (persists + attempts flush)
/// - Manual `flush()` call
@available(iOS 13.0, macOS 12.0, *)
public final class OfflineEventQueue {
    // MARK: - Configuration

    public struct Config {
        public let batchSize: Int
        public let flushInterval: TimeInterval
        public let maxRetries: Int
        public let maxQueueSize: Int

        public init(
            batchSize: Int = 20,
            flushInterval: TimeInterval = 30,
            maxRetries: Int = 3,
            maxQueueSize: Int = 1000
        ) {
            self.batchSize = batchSize
            self.flushInterval = flushInterval
            self.maxRetries = maxRetries
            self.maxQueueSize = maxQueueSize
        }
    }

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let store: EventStore
    private let config: Config
    private let deviceId: String

    // MARK: - State (protected by serial DispatchQueue)

    private var inMemoryQueue: [Event] = []
    private var isFlushing = false
    private var flushTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // Serial executor for thread safety
    private let internalQueue = DispatchQueue(label: "com.pushcrm.eventqueue", qos: .utility)

    // MARK: - Init

    public init(apiClient: APIClient, config: Config = Config(), deviceId: String) {
        self.apiClient = apiClient
        self.store = EventStore()
        self.config = config
        self.deviceId = deviceId
    }

    init(apiClient: APIClient, store: EventStore, config: Config = Config(), deviceId: String) {
        self.apiClient = apiClient
        self.store = store
        self.config = config
        self.deviceId = deviceId
    }

    // MARK: - Lifecycle

    /// Call on SDK initialization to restore persisted events and start the flush timer.
    public func start() {
        internalQueue.async { [weak self] in
            guard let self else { return }
            Task {
                let persisted = await self.store.loadAll()
                self.internalQueue.async {
                    self.inMemoryQueue = persisted
                    self.startTimer()
                }
            }
        }
    }

    /// Call when app enters background or SDK is torn down.
    public func stop() {
        internalQueue.async { [weak self] in
            guard let self else { return }
            self.timerTask?.cancel()
            self.timerTask = nil
            Task { await self.store.save(self.inMemoryQueue) }
        }
    }

    // MARK: - Enqueue

    /// Thread-safe event enqueue. Triggers flush if batch size reached.
    public func enqueue(
        name: String,
        properties: [String: Any] = [:],
        userId: String? = nil,
        sessionId: String? = nil
    ) {
        internalQueue.async { [weak self] in
            guard let self else { return }

            guard self.inMemoryQueue.count < self.config.maxQueueSize else { return }

            let event = Event(
                name: name,
                properties: properties,
                deviceId: self.deviceId,
                userId: userId,
                sessionId: sessionId
            )

            self.inMemoryQueue.append(event)

            if self.inMemoryQueue.count >= self.config.batchSize {
                self.triggerFlush()
            }
        }
    }

    // MARK: - Manual Flush

    /// Manually trigger a flush. Safe to call from any thread.
    public func flush() {
        internalQueue.async { [weak self] in
            self?.triggerFlush()
        }
    }

    /// Async flush that completes when the current batch is uploaded (or fails).
    public func flushAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            internalQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.triggerFlush {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.config.flushInterval ?? 30) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                self?.flush()
            }
        }
    }

    // MARK: - Flush Logic

    private func triggerFlush(completion: (() -> Void)? = nil) {
        // Already on internalQueue
        guard !isFlushing, !inMemoryQueue.isEmpty else {
            completion?()
            return
        }

        isFlushing = true
        let batch = Array(inMemoryQueue.prefix(config.batchSize))

        flushTask = Task { [weak self] in
            guard let self else { return }
            await self.uploadBatch(batch)
            self.internalQueue.async {
                self.isFlushing = false
                if self.inMemoryQueue.count >= self.config.batchSize {
                    self.triggerFlush()
                }
                completion?()
            }
        }
    }

    private func uploadBatch(_ batch: [Event]) async {
        let payload = EventBatchPayload(events: batch, deviceId: deviceId)
        let request = APIRequest(
            method: .post,
            path: "/api/sdk/events",
            body: payload
        )

        do {
            try await apiClient.send(request)
            let ids = Set(batch.map(\.id))
            internalQueue.async { [weak self] in
                guard let self else { return }
                self.inMemoryQueue.removeAll { ids.contains($0.id) }
                Task { await self.store.save(self.inMemoryQueue) }
            }
        } catch {
            internalQueue.async { [weak self] in
                guard let self else { return }
                let failedIds = Set(batch.map(\.id))
                for i in self.inMemoryQueue.indices where failedIds.contains(self.inMemoryQueue[i].id) {
                    self.inMemoryQueue[i].retryCount += 1
                }
                self.inMemoryQueue.removeAll { $0.retryCount > self.config.maxRetries }
                Task { await self.store.save(self.inMemoryQueue) }
            }
        }
    }

    // MARK: - Diagnostics

    /// Current number of events pending upload.
    public func pendingCount() -> Int {
        internalQueue.sync { inMemoryQueue.count }
    }
}
