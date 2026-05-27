import Foundation

/// Configuration for PushCRM SDK initialization
public struct PushCRMConfig {
    public let appKey: String
    public let baseURL: String
    public let flushInterval: TimeInterval
    public let maxQueueSize: Int
    public let maxRetries: Int
    public let sessionTimeout: TimeInterval

    public init(
        appKey: String,
        baseURL: String,
        flushInterval: TimeInterval = 30,
        maxQueueSize: Int = 1000,
        maxRetries: Int = 3,
        sessionTimeout: TimeInterval = 300
    ) {
        self.appKey = appKey
        self.baseURL = baseURL
        self.flushInterval = flushInterval
        self.maxQueueSize = maxQueueSize
        self.maxRetries = maxRetries
        self.sessionTimeout = sessionTimeout
    }
}
