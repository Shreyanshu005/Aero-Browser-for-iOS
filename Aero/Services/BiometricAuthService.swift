import Foundation
import LocalAuthentication
import os.log

@Observable
final class BiometricAuthService {

    var isPrivateBrowsingUnlocked: Bool = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.aero.browser", category: "BiometricAuth")

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error {
            logger.debug("Biometric availability check failed: \(error.localizedDescription)")
        }
        return canEvaluate
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var biometricTypeDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Passcode"
        @unknown default:
            return "Biometrics"
        }
    }

    @MainActor
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.error("Authentication policy not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isPrivateBrowsingUnlocked = true
                logger.info("Biometric authentication succeeded")
            }
            return success
        } catch {
            logger.error("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func lock() {
        isPrivateBrowsingUnlocked = false
        logger.info("Private browsing locked")
    }

    @MainActor
    func unlockIfNeeded() async -> Bool {
        if isPrivateBrowsingUnlocked {
            return true
        }
        return await authenticate(reason: "Unlock private tabs in Aero")
    }
}
