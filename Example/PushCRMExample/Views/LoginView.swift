import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PushCRM

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if viewModel.isSuccess {
                        successSection
                    } else {
                        formSection
                    }
                }
                .padding(24)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("PushCRM Demo")
                .font(.title.bold())
            Text("Login or Register to test SDK integration")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Error banner
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Name
            FormField(icon: "person.fill", placeholder: "Full Name", text: $viewModel.form.name)

            // Email
            FormField(icon: "envelope.fill", placeholder: "Email Address", text: $viewModel.form.email)

            // Mobile
            FormField(icon: "phone.fill", placeholder: "Mobile Number", text: $viewModel.form.mobile)

            // Password
            SecureFormField(icon: "lock.fill", placeholder: "Password", text: $viewModel.form.password)

            // Submit button
            Button(action: viewModel.submit) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Submit")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isLoading ? Color.blue.opacity(0.7) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .padding(.top, 8)

            Text("This will identify the user and track a login event via PushCRM SDK")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Success

    private var successSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("Success!")
                .font(.title2.bold())

            if let message = viewModel.successMessage {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "User ID", value: viewModel.form.email)
                InfoRow(label: "Event", value: "User Login")
                InfoRow(label: "Platform", value: "iOS")
                InfoRow(label: "SDK Version", value: AppConfig.sdkVersion)
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button(action: viewModel.reset) {
                Text("Submit Another")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Reusable Components

struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct SecureFormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            SecureField(placeholder, text: $text)
        }
        .padding(14)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}
