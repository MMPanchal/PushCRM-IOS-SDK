import Foundation

/// Manages push notification token registration with backend
final class PushTokenManager {
    private let networkClient: NetworkClient
    private let storage: StorageManager

    init(networkClient: NetworkClient, storage: StorageManager) {
        self.networkClient = networkClient
        self.storage = storage
    }

    func register(token: String) {
        guard token != storage.pushToken else { return }
        storage.pushToken = token

        let body: [String: Any] = [
            "deviceId": storage.deviceId,
            "token": token,
            "platform": "ios",
            "userId": storage.userId ?? ""
        ]

        networkClient.post(endpoint: .pushToken, body: body) { _ in }
    }
}
