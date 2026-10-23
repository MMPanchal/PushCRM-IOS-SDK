import Foundation

struct UserFormData {
    var name: String = ""
    var email: String = ""
    var mobile: String = ""
    var password: String = ""
}

struct FormValidationError: Identifiable {
    let id = UUID()
    let message: String
}
