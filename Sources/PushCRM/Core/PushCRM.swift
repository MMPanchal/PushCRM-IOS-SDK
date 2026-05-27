import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PushCRM Public SDK

/// The main entry point for the PushCRM iOS SDK.
///
/// `PushCRM` provides a simple, developer-friendly API for push notification management,
/// user identification, and event tracking. All public methods are thread-safe.
///
/// ## Quick Start
/// ```swift
/// // 1. Initialize (in AppDelegate.didFinishLaunchingWithOptions)
/// let config = PushCRMConfig(
///     appKey: "your-app-key",
///     baseURL: "https://your-pushcrm-server.com"
/// )
/// PushCRM.shared.initialize(config: config)
///
/// // 2. Identify user after login
/// PushCRM.shared.identify(userId: "user_123", properties: ["plan": "pro"])
///
/// // 3. Track events
/// PushCRM.shared.track(event: "purchase", properties: ["amount": 29.99])
///
/// // 4. Register push token
/// PushCRM.shared.registerPushToken(deviceToken)
///
/// // 5. Reset on logout
/// PushCRM.shared.resetUser()
/// ```
public final class PushCRM {

    // MARK: - Singleton

    /// Shared SDK instance. Always use this to interact with PushCRM.
    public static let shared = PushCRM()

    // MARK: - State

    /// Whether the SDK has been initialized.
    public private(set) var isInitialized: Bool = false

    /// The current identified user ID, or `nil` if anonymous.
    public var currentUserId: String? { storage?.userId }

    /// The current device ID assigned by the SDK.
    public var deviceId: String? { storage?.deviceId }

    // MARK: - Internal Dependencies

    private var config: PushCRMConfig?
    private let serialQueue = DispatchQueue(label: "com.pushcrm.sdk", qos: .utility)

    private(set) var networkClient: NetworkClient?
    private(set) var apiClient: Any? // APIClient (requires iOS 13+)
    private(set) var storage: StorageManager?
    private(set) var eventQueue: EventQueue?
    private(set) var offlineQueue: Any? // OfflineEventQueue (requires iOS 13+)
    private(set) var sessionManager: SessionManager?
    private(set) var identityManager: IdentityManager?
    private(set) var pushManager: PushTokenManager?

    private init() {}

    // MARK: - Initialize

    /// Initializes the PushCRM SDK with the given configuration.
    ///
    /// Call this once during app launch, typically in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    /// Calling this multiple times is safe — subsequent calls are ignored.
    ///
    /// - Parameter config: The SDK configuration containing your app key and server URL.
    ///
    /// ## Example
    /// ```swift
    /// let config = PushCRMConfig(
    ///     appKey: "pk_live_abc123",
    ///     baseURL: "https://api.pushcrm.io",
    ///     flushInterval: 30,
    ///     maxRetries: 3
    /// )
    /// PushCRM.shared.initialize(config: config)
    /// ```
    public func initialize(config: PushCRMConfig) {
        serialQueue.sync {
            guard !isInitialized else { return }

            self.config = config
            self.storage = StorageManager()
            self.networkClient = NetworkClient(config: config)
            if #available(iOS 13.0, macOS 12.0, *) {
                let client = APIClient(pushCRMConfig: config)
                self.apiClient = client
                self.offlineQueue = OfflineEventQueue(
                    apiClient: client,
                    config: .init(
                        batchSize: 20,
                        flushInterval: config.flushInterval,
                        maxRetries: config.maxRetries,
                        maxQueueSize: config.maxQueueSize
                    ),
                    deviceId: self.storage!.deviceId
                )
            }

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

            self.isInitialized = true
            self.sessionManager?.startSession()
            self.eventQueue?.startFlushing()
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.start()
            }
        }

        observeAppLifecycle()
    }

    // MARK: - Identify

    /// Identifies the current user with a unique ID and optional properties.
    ///
    /// Call this after user login or when user identity becomes known.
    /// The SDK associates all subsequent events with this user until `resetUser()` is called.
    ///
    /// - Parameters:
    ///   - userId: A unique, stable identifier for the user (e.g., database ID, email hash).
    ///   - properties: Optional dictionary of user attributes (e.g., name, plan, company).
    ///
    /// ## Example
    /// ```swift
    /// PushCRM.shared.identify(
    ///     userId: "user_42",
    ///     properties: [
    ///         "name": "Jane Smith",
    ///         "plan": "enterprise",
    ///         "signupDate": "2024-01-15"
    ///     ]
    /// )
    /// ```
    public func identify(userId: String, properties: [String: Any]? = nil) {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.identityManager?.identify(userId: userId, properties: properties)
        }
    }

    // MARK: - Track

    /// Tracks a custom event with optional properties.
    ///
    /// Events are queued locally and uploaded in batches. They persist across app restarts
    /// and are retried automatically on network failure.
    ///
    /// - Parameters:
    ///   - event: The event name (e.g., "purchase", "screen_view", "button_tap").
    ///   - properties: Optional dictionary of event metadata.
    ///
    /// ## Example
    /// ```swift
    /// PushCRM.shared.track(event: "purchase", properties: [
    ///     "amount": 29.99,
    ///     "currency": "USD",
    ///     "item_id": "sku_001"
    /// ])
    ///
    /// // Simple event with no properties
    /// PushCRM.shared.track(event: "app_opened")
    /// ```
    public func track(event: String, properties: [String: Any]? = nil) {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.eventQueue?.enqueue(event: event, properties: properties)
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.enqueue(
                    name: event,
                    properties: properties ?? [:],
                    userId: self.storage?.userId,
                    sessionId: self.storage?.sessionId
                )
            }
        }
    }

    // MARK: - Push Token

    /// Registers the APNs device token with the PushCRM backend.
    ///
    /// Call this in `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// The SDK deduplicates tokens — re-registering the same token is a no-op.
    ///
    /// - Parameter token: The raw APNs device token `Data` provided by iOS.
    ///
    /// ## Example
    /// ```swift
    /// func application(_ app: UIApplication,
    ///     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    ///     PushCRM.shared.registerPushToken(deviceToken)
    /// }
    /// ```
    public func registerPushToken(_ token: Data) {
        guard ensureInitialized() else { return }
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        serialQueue.async {
            self.pushManager?.register(token: tokenString)
        }
    }

    /// Registers a push token string directly (useful for testing or Firebase FCM tokens).
    ///
    /// - Parameter tokenString: The hex-encoded push token string.
    public func registerPushToken(string tokenString: String) {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.pushManager?.register(token: tokenString)
        }
    }

    // MARK: - Reset User

    /// Resets the current user identity and ends the active session.
    ///
    /// Call this on user logout. After reset:
    /// - User ID is cleared
    /// - Session is ended
    /// - Subsequent events are tracked as anonymous until `identify()` is called again
    /// - Device ID and push token are preserved
    ///
    /// ## Example
    /// ```swift
    /// func logout() {
    ///     // Your logout logic...
    ///     PushCRM.shared.resetUser()
    /// }
    /// ```
    public func resetUser() {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.identityManager?.reset()
            self.sessionManager?.endSession()
            self.sessionManager?.startSession()
        }
    }

    // MARK: - Push Tracking

    /// Tracks that a push notification was delivered to the device.
    ///
    /// Call this in your Notification Service Extension's `didReceive(_:withContentHandler:)`.
    ///
    /// - Parameter campaignId: The campaign identifier from the push payload.
    public func pushDelivered(campaignId: String) {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.eventQueue?.enqueue(event: "__push_delivered", properties: ["campaignId": campaignId])
        }
    }

    /// Tracks that a push notification was opened by the user.
    ///
    /// Call this in `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    ///
    /// - Parameter campaignId: The campaign identifier from the push payload.
    public func pushOpened(campaignId: String) {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.eventQueue?.enqueue(event: "__push_opened", properties: ["campaignId": campaignId])
        }
    }

    // MARK: - Flush

    /// Manually triggers an upload of all queued events.
    ///
    /// Normally the SDK flushes automatically on a timer and at batch thresholds.
    /// Use this for critical moments (e.g., before a paywall, after a purchase).
    public func flush() {
        guard ensureInitialized() else { return }
        serialQueue.async {
            self.eventQueue?.flush()
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.flush()
            }
        }
    }

    // MARK: - Private Helpers

    private func ensureInitialized() -> Bool {
        if !isInitialized {
            #if DEBUG
            print("[PushCRM] ⚠️ SDK not initialized. Call PushCRM.shared.initialize(config:) first.")
            #endif
        }
        return isInitialized
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        #if canImport(UIKit)
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
        #endif
    }

    @objc private func appDidEnterBackground() {
        serialQueue.async {
            self.sessionManager?.pauseSession()
            self.eventQueue?.flush()
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.stop()
            }
        }
    }

    @objc private func appWillEnterForeground() {
        serialQueue.async {
            self.sessionManager?.resumeSession()
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.start()
            }
        }
    }

    @objc private func appWillTerminate() {
        serialQueue.sync {
            self.eventQueue?.persistQueue()
            if #available(iOS 13.0, macOS 12.0, *) {
                (self.offlineQueue as? OfflineEventQueue)?.stop()
            }
            self.sessionManager?.endSession()
        }
    }
}
