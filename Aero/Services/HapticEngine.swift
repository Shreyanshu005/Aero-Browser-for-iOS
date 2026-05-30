import UIKit

enum HapticEngine {

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat? = nil) {
        let generator = generator(for: style)
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
    }

    static func selection() {
        selectionGenerator.selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }

    static func prepare(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        generator(for: style).prepare()
    }

    static func prepareSelection() {
        selectionGenerator.prepare()
    }

    static func prepareNotification() {
        notificationGenerator.prepare()
    }

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
