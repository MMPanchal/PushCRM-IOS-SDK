import SwiftUI

@main
struct PushCRMExampleApp: App {
    init() {
        PushCRMService.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
