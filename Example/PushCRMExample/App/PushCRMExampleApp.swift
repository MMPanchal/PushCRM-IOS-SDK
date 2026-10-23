import SwiftUI
import PushCRM

@main
struct PushCRMExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        PushCRMService.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
