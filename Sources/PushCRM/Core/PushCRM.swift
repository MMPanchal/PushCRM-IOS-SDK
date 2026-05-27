import Foundation
import UIKit

/// Main entry point for PushCRM SDK
public final class PushCRM {
    public static let shared = PushCRM()

    private var config: PushCRMConfig?
    private let serialQueue = DispatchQueue(label: "com.pushcrm.sdk", qos: .utility)

    private(set) var networkClient: NetworkClient?
    private(set) var storage: StorageManager?
    private(set) var eventQueue: EventQueue?
    private(set) var sessionManager: SessionManager?
    private(set) var identityManager: IdentityManager?
    private(set) var pushManager: PushTokenManager?

    private init() {}

    /// Initialize SDK with configuration
    public func initialize(config: PushCRMConfig) {
        serialQueue.sync {
            self.config = config
            self.networkClient = NetworkClient(config: config)
            self.storage = StorageManager()
            self.eventQueue = EventQueue(
                networkClient: self.networkClient!,
                storage: self.storage!,
                config: config
            )
            self.sessionManager = SessionManager(
                config: config,
                eventQueue: self.eventQueue!
            )
            self.identityManager = IdentityManager(
                networkClient: self.networkClient!,
                storage: self.storage!
            )
            self.pushManager = PushTokenManager(
                networkClient: self.networkClient!,
                storage: self.storage!
            )

            self.sessionManager?.startSession()
            self.eventQueue?.startFlushing()
        }

        observeAppLifecycle()
    }

    // MARK: - Public API

    /// Identify a user
    public func identify(userId: String, properties: [String: Any]? = nil) {
        serialQueue.async {
            self.identityManager?.identify(userId: userId, properties: properties)
        }
    }

    /// Track a custom event
    public func track(event: String, properties: [String: Any]? = nil) {
        serialQueue.async {
            self.eventQueue?.enqueue(event: event, properties: properties)
        }
    }

    /// Register push token
    public func registerPushToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        serialQueue.async {
            self.pushManager?.register(token: tokenString)
        }
    }

    /// Notify SDK that a push notification was received (delivered)
    public func pushDelivered(campaignId: String) {
        serialQueue.async {
            self.eventQueue?.enqueue(event: "__push_delivered", properties: ["campaignId": campaignId])
        }
    }

    /// Notify SDK that a push notification was opened
    public func pushOpened(campaignId: String) {
        serialQueue.async {
            self.eventQueue?.enqueue(event: "__push_opened", properties: ["campaignId": campaignId])
        }
    }

    /// Flush all pending events
    public func flush() {
        serialQueue.async {
            self.eventQueue?.flush()
        }
    }

    /// Reset user identity (logout)
    public func reset() {
        serialQueue.async {
            self.identityManager?.reset()
            self.sessionManager?.endSession()
        }
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification, object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        serialQueue.async {
            self.sessionManager?.pauseSession()
            self.eventQueue?.flush()
        }
    }

    @objc private func appWillEnterForeground() {
        serialQueue.async {
            self.sessionManager?.resumeSession()
        }
    }

    @objc private func appWillTerminate() {
        serialQueue.sync {
            self.eventQueue?.persistQueue()
            self.sessionManager?.endSession()
        }
    }
}
