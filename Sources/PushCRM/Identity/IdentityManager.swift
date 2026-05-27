import Foundation
import UIKit

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
        let body: [String: Any] = [
            "deviceId": storage.deviceId,
            "platform": "ios",
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "model": UIDevice.current.model
        ]

        networkClient.post(endpoint: .register, body: body) { _ in }
    }
}
