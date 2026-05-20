import SwiftUI

enum AeroColor {

    static let backgroundPrimary   = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary  = Color(UIColor.tertiarySystemBackground)
    static let backgroundElevated  = Color(UIColor.secondarySystemGroupedBackground)


    static let surfaceCard         = Color(UIColor.secondarySystemBackground)
    static let surfaceBorder       = Color(UIColor.separator)
    static let surfaceHover        = Color(UIColor.systemFill)


    static let accent              = Color.white
    static let accentSecondary     = Color(UIColor.systemGray)
    static let accentTint          = Color(UIColor.label)


    static let accentCyan          = Color.white
    static let accentBlue          = Color(UIColor.systemGray3)
    static let accentGradient      = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let accentGlow          = Color.clear


    static let textPrimary         = Color(UIColor.label)
    static let textSecondary       = Color(UIColor.secondaryLabel)
    static let textTertiary        = Color(UIColor.tertiaryLabel)
    static let textOnAccent        = Color(UIColor.systemBackground)


    static let success             = Color(UIColor.systemGreen)
    static let warning             = Color(UIColor.systemOrange)
    static let error               = Color(UIColor.systemRed)
    static let secure              = Color(UIColor.systemGreen)


    static let tabColors: [Color] = [
        Color(UIColor.systemGray),
        Color(UIColor.systemGray2),
        Color(UIColor.systemGray3),
        Color(UIColor.systemGray4),
        Color(UIColor.systemGray5),
        Color(UIColor.systemGray6),
    ]
}



enum AeroFont {
    static let urlBar       = Font.system(.body, design: .monospaced, weight: .medium)
    static let urlBarDomain = Font.system(.body, design: .default, weight: .semibold)
    static let title        = Font.system(.title3, design: .rounded, weight: .bold)
    static let headline     = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body         = Font.system(.body, design: .default, weight: .regular)
    static let caption      = Font.system(.caption, design: .default, weight: .medium)
    static let captionSmall = Font.system(.caption2, design: .default, weight: .regular)
    static let tabTitle     = Font.system(.footnote, design: .default, weight: .medium)
    static let badge        = Font.system(size: 11, weight: .bold, design: .rounded)
}



enum AeroSpacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum AeroRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let pill:  CGFloat = 100
    static let card: CGFloat = 14
}



enum AeroShadow {
    static let cardShadowColor  = Color.black.opacity(0.1)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY:      CGFloat = 2

    static let glowRadius: CGFloat = 0
    static let glowOpacity: Double = 0
}



enum AeroAnimation {
    static let snappy   = Animation.spring(duration: 0.3, bounce: 0.15)
    static let smooth   = Animation.spring(duration: 0.4, bounce: 0.1)
    static let bouncy   = Animation.spring(duration: 0.5, bounce: 0.25)
    static let quick    = Animation.easeOut(duration: 0.15)
    static let fade     = Animation.easeInOut(duration: 0.2)
}



enum AeroToolbar {
    static let height:   CGFloat = 44
    static let iconSize: CGFloat = 20
}



extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double( hex        & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}



struct GlassMorphic: ViewModifier {
    var cornerRadius: CGFloat = AeroRadius.lg

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassMorphic(cornerRadius: CGFloat = AeroRadius.lg) -> some View {
        modifier(GlassMorphic(cornerRadius: cornerRadius))
    }
}
