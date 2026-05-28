import SwiftUI

enum AeroGlassStyle {
    case panel
    case toolbar
    case control
    case prominentControl
    case scrim

    var fallbackMaterial: Material {
        switch self {
        case .panel:
            return .regularMaterial
        case .toolbar, .control, .prominentControl, .scrim:
            return .ultraThinMaterial
        }
    }

    var tint: Color {
        switch self {
        case .panel:
            return Color(UIColor.secondarySystemBackground).opacity(0.28)
        case .toolbar:
            return Color(UIColor.systemBackground).opacity(0.20)
        case .control:
            return Color(UIColor.systemBackground).opacity(0.18)
        case .prominentControl:
            return Color(UIColor.label).opacity(0.08)
        case .scrim:
            return Color(UIColor.systemBackground).opacity(0.18)
        }
    }

    var stroke: Color {
        switch self {
        case .panel:
            return Color.white.opacity(0.18)
        case .toolbar, .control, .prominentControl, .scrim:
            return Color.white.opacity(0.14)
        }
    }

    var separator: Color {
        Color(UIColor.separator).opacity(0.28)
    }

    var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch self {
        case .panel:
            return (Color.black.opacity(0.10), 12, 4)
        case .toolbar:
            return (Color.black.opacity(0.08), 10, -2)
        case .control, .prominentControl:
            return (Color.black.opacity(0.08), 6, 1)
        case .scrim:
            return (Color.black.opacity(0.06), 8, 0)
        }
    }
}

enum AeroGlassButtonShape {
    case circle
    case pill
}

struct AeroGlassPanel<Content: View>: View {
    private let style: AeroGlassStyle
    private let cornerRadius: CGFloat
    private let interactive: Bool
    private let content: Content

    init(
        style: AeroGlassStyle = .panel,
        cornerRadius: CGFloat = AeroRadius.lg,
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        content
            .aeroGlassPanel(
                style: style,
                cornerRadius: cornerRadius,
                interactive: interactive
            )
    }
}

struct AeroToolbarGlassBackground: View {
    var showsTopSeparator: Bool
    var showsBottomSeparator: Bool

    init(showsTopSeparator: Bool = true, showsBottomSeparator: Bool = false) {
        self.showsTopSeparator = showsTopSeparator
        self.showsBottomSeparator = showsBottomSeparator
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .aeroGlassSurface(style: .toolbar, in: Rectangle())
            .overlay(alignment: .top) {
                if showsTopSeparator {
                    AeroGlassSeparator()
                }
            }
            .overlay(alignment: .bottom) {
                if showsBottomSeparator {
                    AeroGlassSeparator()
                }
            }
    }
}

struct AeroSafeAreaGlass: View {
    var edge: VerticalEdge
    var length: CGFloat
    var showsSeparator: Bool

    init(edge: VerticalEdge, length: CGFloat = 72, showsSeparator: Bool = true) {
        self.edge = edge
        self.length = length
        self.showsSeparator = showsSeparator
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: length)
            .aeroGlassSurface(style: .scrim, in: Rectangle())
            .overlay(alignment: separatorAlignment) {
                if showsSeparator {
                    AeroGlassSeparator()
                }
            }
            .ignoresSafeArea(edges: edge.edgeSet)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var separatorAlignment: Alignment {
        switch edge {
        case .top:
            return .bottom
        case .bottom:
            return .top
        }
    }
}

struct AeroGlassIconButton<Label: View>: View {
    private let action: () -> Void
    private let shape: AeroGlassButtonShape
    private let size: CGFloat
    private let isProminent: Bool
    private let label: Label

    init(
        shape: AeroGlassButtonShape = .circle,
        size: CGFloat = 38,
        isProminent: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.shape = shape
        self.size = size
        self.isProminent = isProminent
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(
            AeroGlassIconButtonStyle(
                shape: shape,
                size: size,
                isProminent: isProminent
            )
        )
    }
}

struct AeroGlassIconButtonStyle: ButtonStyle {
    var shape: AeroGlassButtonShape = .circle
    var size: CGFloat = 38
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        AeroGlassIconButtonStyleBody(
            label: configuration.label,
            shape: shape,
            size: size,
            isProminent: isProminent,
            isPressed: configuration.isPressed
        )
    }
}

extension ButtonStyle where Self == AeroGlassIconButtonStyle {
    static func aeroGlassIcon(
        shape: AeroGlassButtonShape = .circle,
        size: CGFloat = 38,
        isProminent: Bool = false
    ) -> AeroGlassIconButtonStyle {
        AeroGlassIconButtonStyle(
            shape: shape,
            size: size,
            isProminent: isProminent
        )
    }
}

extension View {
    func aeroGlassPanel(
        style: AeroGlassStyle = .panel,
        cornerRadius: CGFloat = AeroRadius.lg,
        interactive: Bool = false
    ) -> some View {
        aeroGlassSurface(
            style: style,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            interactive: interactive
        )
    }

    func aeroToolbarGlassBackground(
        showsTopSeparator: Bool = true,
        showsBottomSeparator: Bool = false
    ) -> some View {
        background {
            AeroToolbarGlassBackground(
                showsTopSeparator: showsTopSeparator,
                showsBottomSeparator: showsBottomSeparator
            )
        }
    }

    @ViewBuilder
    func aeroGlassIconButton(
        shape: AeroGlassButtonShape = .circle,
        size: CGFloat = 38,
        isProminent: Bool = false
    ) -> some View {
        switch shape {
        case .circle:
            self
                .aeroGlassIconButtonChrome(
                    size: size,
                    width: size,
                    shape: Circle(),
                    style: isProminent ? .prominentControl : .control
                )
        case .pill:
            self
                .padding(.horizontal, AeroSpacing.sm)
                .aeroGlassIconButtonChrome(
                    size: size,
                    width: max(size, 52),
                    shape: Capsule(),
                    style: isProminent ? .prominentControl : .control
                )
        }
    }

    @ViewBuilder
    func aeroSafeAreaGlass(
        edge: VerticalEdge,
        length: CGFloat = 72,
        showsSeparator: Bool = true
    ) -> some View {
        switch edge {
        case .top:
            overlay(alignment: .top) {
                AeroSafeAreaGlass(
                    edge: edge,
                    length: length,
                    showsSeparator: showsSeparator
                )
            }
        case .bottom:
            overlay(alignment: .bottom) {
                AeroSafeAreaGlass(
                    edge: edge,
                    length: length,
                    showsSeparator: showsSeparator
                )
            }
        }
    }

    func aeroGlassSurface<S: InsettableShape>(
        style: AeroGlassStyle = .panel,
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        modifier(
            AeroGlassSurfaceModifier(
                style: style,
                shape: shape,
                interactive: interactive
            )
        )
    }
}

private struct AeroGlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let style: AeroGlassStyle
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        let shadow = style.shadow

        content
            .aeroPlatformGlass(style: style, in: shape, interactive: interactive)
            .background(style.tint, in: shape)
            .overlay {
                shape
                    .strokeBorder(style.stroke, lineWidth: 0.7)
            }
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

private struct AeroGlassIconButtonStyleBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled

    let label: Label
    let shape: AeroGlassButtonShape
    let size: CGFloat
    let isProminent: Bool
    let isPressed: Bool

    var body: some View {
        label
            .font(.system(size: AeroToolbar.iconSize, weight: .semibold))
            .foregroundStyle(Color(UIColor.label).opacity(isEnabled ? 0.92 : 0.32))
            .aeroGlassIconButton(
                shape: shape,
                size: size,
                isProminent: isProminent
            )
            .scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(AeroAnimation.quick, value: isPressed)
    }
}

private struct AeroGlassSeparator: View {
    var body: some View {
        Rectangle()
            .fill(AeroGlassStyle.toolbar.separator)
            .frame(height: 0.5)
    }
}

private extension View {
    @ViewBuilder
    func aeroGlassIconButtonChrome<S: InsettableShape>(
        size: CGFloat,
        width: CGFloat,
        shape: S,
        style: AeroGlassStyle
    ) -> some View {
        self
            .frame(minWidth: width, minHeight: size)
            .contentShape(shape)
            .aeroGlassSurface(style: style, in: shape, interactive: true)
    }

    @ViewBuilder
    func aeroPlatformGlass<S: InsettableShape>(
        style: AeroGlassStyle,
        in shape: S,
        interactive: Bool
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            self.background(style.fallbackMaterial, in: shape)
        }
#else
        self.background(style.fallbackMaterial, in: shape)
#endif
    }
}

private extension VerticalEdge {
    var edgeSet: Edge.Set {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}
