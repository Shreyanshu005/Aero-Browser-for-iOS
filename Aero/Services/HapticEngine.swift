import UIKit

/// Centralized haptic feedback manager to avoid creating and discarding generator instances.
///
/// Haptic generators have a warm-up time; reusing instances reduces latency. This enum
/// provides a shared set of generators and convenience methods for all feedback types
/// used throughout the app.
///
/// ## Usage
/// ```swift
/// // Simple feedback
/// HapticEngine.impact(.light)
/// HapticEngine.selection()
/// HapticEngine.notification(.success)
///
/// // Prepare before a known interaction for minimal latency
/// HapticEngine.prepare(.medium)
/// // ... user performs action ...
/// HapticEngine.impact(.medium)
/// ```
enum HapticEngine {

    // MARK: - Shared Generators

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Impact Feedback

    /// Triggers an impact haptic feedback with the specified style.
    ///
    /// - Parameters:
    ///   - style: The feedback style determining intensity (light, medium, heavy, soft, rigid).
    ///   - intensity: Optional custom intensity from 0.0 to 1.0. Defaults to the style's default.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat? = nil) {
        let generator = generator(for: style)
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
    }

    // MARK: - Selection Feedback

    /// Triggers a selection change haptic, used for picker scrolls and toggle changes.
    static func selection() {
        selectionGenerator.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Triggers a notification haptic feedback.
    ///
    /// - Parameter type: The notification type (`.success`, `.warning`, `.error`).
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }

    // MARK: - Preparation

    /// Prepares the impact generator for the given style to reduce latency on the next trigger.
    ///
    /// Call this just before a user interaction that you know will produce haptic feedback,
    /// such as when a drag gesture begins or a button enters its highlighted state.
    ///
    /// - Parameter style: The feedback style to prepare.
    static func prepare(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        generator(for: style).prepare()
    }

    /// Prepares the selection generator for immediate use.
    static func prepareSelection() {
        selectionGenerator.prepare()
    }

    /// Prepares the notification generator for immediate use.
    static func prepareNotification() {
        notificationGenerator.prepare()
    }

    // MARK: - Private Helpers

    /// Returns the shared generator instance for the given feedback style.
    private static func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightGenerator
        case .medium:
            return mediumGenerator
        case .heavy:
            return heavyGenerator
        case .soft:
            return softGenerator
        case .rigid:
            return rigidGenerator
        @unknown default:
            return mediumGenerator
        }
    }
}
