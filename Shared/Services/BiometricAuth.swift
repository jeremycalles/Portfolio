import Foundation
import LocalAuthentication

// MARK: - Shared Biometric Authentication
/// Evaluates device owner authentication (Face ID / Touch ID or device password).
/// Use from macOS or iOS lock managers to avoid duplicating LAContext policy logic.
enum BiometricAuth {
    /// Evaluates biometrics or device password. Returns `true` if the user authenticated successfully.
    /// Throws if policy cannot be evaluated (e.g. biometry not available); does not throw on user cancel.
    static func evaluate(localizedReason: String) async throws -> Bool {
        let context = LAContext()
        var authError: NSError?

        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : (context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics)

        guard context.canEvaluatePolicy(policy, error: &authError) else {
            if let e = authError { throw e }
            return false
        }

        do {
            return try await context.evaluatePolicy(policy, localizedReason: localizedReason)
        } catch {
            if (error as NSError).code == LAError.userCancel.rawValue {
                return false
            }
            throw error
        }
    }
}
