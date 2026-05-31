import Foundation
import PushCRM

/// SDK integration layer — wraps PushCRM SDK calls with logging and error handling
final class PushCRMService {
    static let shared = PushCRMService()
    private init() {}

    func initialize() {
        let config = PushCRMConfig(
            appKey: AppConfig.pushCRMAppKey,
            baseURL: AppConfig.pushCRMBaseURL
        )
        PushCRM.shared.initialize(config: config)
        print("[PushCRMService] ✅ SDK initialized with baseURL: \(AppConfig.pushCRMBaseURL)")
    }

    func identifyUser(email: String, name: String, mobile: String) {
        PushCRM.shared.identify(userId: email, properties: [
            "name": name,
            "email": email,
            "mobile": mobile,
            "platform": "iOS"
        ])
        print("[PushCRMService] 👤 Identified user: \(email)")
    }

    func trackLogin(email: String) {
        PushCRM.shared.track(event: "User Login", properties: [
            "platform": "iOS",
            "screen": "Login",
            "login_method": "email",
            "sdk_version": AppConfig.sdkVersion,
            "email": email
        ])
        print("[PushCRMService] 📊 Tracked 'User Login' for: \(email)")
    }

    func trackSignup(email: String) {
        PushCRM.shared.track(event: "User Signup", properties: [
            "platform": "iOS",
            "screen": "Login",
            "signup_method": "email",
            "sdk_version": AppConfig.sdkVersion,
            "email": email
        ])
        print("[PushCRMService] 📊 Tracked 'User Signup' for: \(email)")
    }

    func flush() {
        PushCRM.shared.flush()
        print("[PushCRMService] 🔄 Flushed event queue")
    }
}
