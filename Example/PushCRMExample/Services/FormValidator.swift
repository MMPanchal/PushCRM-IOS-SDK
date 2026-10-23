import Foundation

enum FormValidator {
    static func validate(_ form: UserFormData) -> String? {
        if form.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Name is required"
        }
        if form.name.count < 2 {
            return "Name must be at least 2 characters"
        }
        if form.email.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Email is required"
        }
        if !isValidEmail(form.email) {
            return "Please enter a valid email address"
        }
        if form.mobile.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Mobile number is required"
        }
        if !isValidMobile(form.mobile) {
            return "Please enter a valid mobile number (10+ digits)"
        }
        if form.password.isEmpty {
            return "Password is required"
        }
        if form.password.count < 6 {
            return "Password must be at least 6 characters"
        }
        return nil
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isValidMobile(_ mobile: String) -> Bool {
        let digits = mobile.filter(\.isNumber)
        return digits.count >= 10
    }
}
