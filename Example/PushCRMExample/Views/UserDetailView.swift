import SwiftUI
import PushCRM

struct UserDetailView: View {
    let name: String
    let email: String
    let mobile: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                Spacer()
            }
            .padding(.top, 16)

            Text("User Detail")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 16) {
                DetailInfoRow(label: "Name", value: name)
                DetailInfoRow(label: "Email", value: email)
                DetailInfoRow(label: "Mobile", value: mobile)
                DetailInfoRow(label: "Platform", value: "iOS")
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()
        }
        .padding(24)
        .onAppear {
            PushCRMService.shared.trackPageLoad(pageName: "User Detail")
        }
    }
}

private struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body.bold())
        }
    }
}
