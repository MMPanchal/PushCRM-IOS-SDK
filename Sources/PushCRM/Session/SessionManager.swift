import Foundation

/// Manages user session lifecycle with timeout-based rotation
final class SessionManager {
    private let config: PushCRMConfig
    private let eventQueue: EventQueue
    private var storage: StorageManager { PushCRM.shared.storage! }

    init(config: PushCRMConfig, eventQueue: EventQueue) {
        self.config = config
        self.eventQueue = eventQueue
    }

    func startSession() {
        let sessionId = UUID().uuidString
        storage.sessionId = sessionId
        storage.lastActiveAt = Date()
        eventQueue.enqueue(event: "__session_start", properties: ["sessionId": sessionId])
    }

    func pauseSession() {
        storage.lastActiveAt = Date()
    }

    func resumeSession() {
        guard let lastActive = storage.lastActiveAt else {
            startSession()
            return
        }

        let elapsed = Date().timeIntervalSince(lastActive)
        if elapsed > config.sessionTimeout {
            endSession()
            startSession()
        } else {
            storage.lastActiveAt = Date()
        }
    }

    func endSession() {
        if let sessionId = storage.sessionId {
            eventQueue.enqueue(event: "__session_end", properties: ["sessionId": sessionId])
        }
        storage.sessionId = nil
    }
}
