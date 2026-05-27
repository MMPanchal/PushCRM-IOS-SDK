import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages user identity and device registration
final class IdentityManager {
    private let networkClient: NetworkClient
    private let storage: StorageManager

    init(networkClient: NetworkClient, storage: StorageManager) {
        self.networkClient = networkClient
        self.storage = storage
        registerDeviceIfNeeded()
    }

    func identify(userId: String, properties: [String: Any]?) {
        storage.userId = userId

        var body: [String: Any] = [
            "deviceId": storage.deviceId,
            "userId": userId
        ]
        if let properties { body["properties"] = properties }

        networkClient.post(endpoint: .identify, body: body) { _ in }
    }

    func reset() {
        storage.userId = nil
    }

    private func registerDeviceIfNeeded() {
        var osVersion = "unknown"
        var model = "unknown"
        #if canImport(UIKit)
        osVersion = UIDevice.current.systemVersion
        model = UIDevice.current.model
        #endif

        let body: [String: Any] = [
            "deviceId": storage.deviceId,
            "platform": "ios",
            "osVersion": osVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "model": model
        ]

        networkClient.post(endpoint: .register, body: body) { _ in }
    }
}
