import Foundation
import SwiftUI
import PushCRM

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var form = UserFormData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    @Published var successMessage: String?

    func submit() {
        errorMessage = nil
        successMessage = nil

        // Validate
        if let error = FormValidator.validate(form) {
            errorMessage = error
            return
        }

        isLoading = true

        Task {
            await performSubmit()
        }
    }

    private func performSubmit() async {
        let email = form.email.trimmingCharacters(in: .whitespaces).lowercased()
        let name = form.name.trimmingCharacters(in: .whitespaces)
        let mobile = form.mobile.trimmingCharacters(in: .whitespaces)

        print("[LoginViewModel] 🚀 Submitting for: \(email)")

        // 1. Identify user via SDK (creates/updates user profile in backend)
        PushCRMService.shared.identifyUser(email: email, name: name, mobile: mobile)

        // 2. Track login event
        PushCRMService.shared.trackLogin(email: email)

        // 3. Force flush to send immediately
        PushCRMService.shared.flush()

        // Small delay to allow network request to complete
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        isLoading = false
        isSuccess = true
        successMessage = "Welcome, \(name)! Your profile and event have been recorded."
        print("[LoginViewModel] ✅ Submit complete for: \(email)")
    }

    func reset() {
        form = UserFormData()
        isSuccess = false
        successMessage = nil
        errorMessage = nil
    }
}
