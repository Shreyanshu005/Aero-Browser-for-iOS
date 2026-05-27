
import Foundation
import LocalAuthentication
import os.log

// MARK: - BiometricAuthService

/// Manages biometric authentication for unlocking private browsing mode.
///
/// Uses Face ID or Touch ID via `LAContext` to gate access to private tabs.
/// While locked, the UI should present a blur overlay to prevent content leakage.
@Observable
final class BiometricAuthService {

    // MARK: - Public State

    /// Whether the user has successfully authenticated for this session.
    var isPrivateBrowsingUnlocked: Bool = false

    // MARK: - Private

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.aero.browser", category: "BiometricAuth")

    // MARK: - Computed Properties

    /// Returns `true` when the device supports any form of biometric authentication.
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error {
            logger.debug("Biometric availability check failed: \(error.localizedDescription)")
        }
        return canEvaluate
    }

    /// The type of biometric hardware available on this device.
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    /// A user-facing label describing the biometric type (e.g. "Face ID").
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

    // MARK: - Authentication

    /// Authenticates the user via biometrics or device passcode.
    ///
    /// - Parameter reason: A localized string explaining why authentication is required.
    /// - Returns: `true` if the user authenticated successfully, `false` otherwise.
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

    /// Locks private browsing, requiring re-authentication to view private tabs.
    @MainActor
    func lock() {
        isPrivateBrowsingUnlocked = false
        logger.info("Private browsing locked")
    }

    /// Convenience method that attempts unlock only if currently locked.
    ///
    /// - Returns: `true` if already unlocked or authentication succeeded.
    @MainActor
    func unlockIfNeeded() async -> Bool {
        if isPrivateBrowsingUnlocked {
            return true
        }
        return await authenticate(reason: "Unlock private tabs in Aero")
    }
}
