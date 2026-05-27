import Foundation

/// Thread-safe persistent storage for SDK data
final class StorageManager {
    private let defaults = UserDefaults(suiteName: "com.pushcrm.sdk")!
    private let fileQueue = DispatchQueue(label: "com.pushcrm.storage")

    private enum Keys {
        static let deviceId = "pushcrm_device_id"
        static let userId = "pushcrm_user_id"
        static let pushToken = "pushcrm_push_token"
        static let sessionId = "pushcrm_session_id"
        static let lastActiveAt = "pushcrm_last_active"
        static let pendingEvents = "pushcrm_pending_events"
    }

    // MARK: - Device ID

    var deviceId: String {
        if let id = defaults.string(forKey: Keys.deviceId) {
            return id
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: Keys.deviceId)
        return id
    }

    // MARK: - User ID

    var userId: String? {
        get { defaults.string(forKey: Keys.userId) }
        set { defaults.set(newValue, forKey: Keys.userId) }
    }

    // MARK: - Push Token

    var pushToken: String? {
        get { defaults.string(forKey: Keys.pushToken) }
        set { defaults.set(newValue, forKey: Keys.pushToken) }
    }

    // MARK: - Session

    var sessionId: String? {
        get { defaults.string(forKey: Keys.sessionId) }
        set { defaults.set(newValue, forKey: Keys.sessionId) }
    }

    var lastActiveAt: Date? {
        get { defaults.object(forKey: Keys.lastActiveAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastActiveAt) }
    }

    // MARK: - Event Queue Persistence

    func savePendingEvents(_ events: [[String: Any]]) {
        fileQueue.sync {
            guard let data = try? JSONSerialization.data(withJSONObject: events) else { return }
            defaults.set(data, forKey: Keys.pendingEvents)
        }
    }

    func loadPendingEvents() -> [[String: Any]] {
        fileQueue.sync {
            guard let data = defaults.data(forKey: Keys.pendingEvents),
                  let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return [] }
            return events
        }
    }

    func clearPendingEvents() {
        fileQueue.sync {
            defaults.removeObject(forKey: Keys.pendingEvents)
        }
    }

    // MARK: - Reset

    func clearAll() {
        defaults.removePersistentDomain(forName: "com.pushcrm.sdk")
    }
}
