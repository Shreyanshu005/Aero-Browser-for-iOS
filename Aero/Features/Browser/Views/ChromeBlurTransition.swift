import SwiftUI

private struct ChromeBlurModifier: ViewModifier {
    let radius: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .scaleEffect(scale, anchor: .bottom)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var chromeBlurReplace: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ChromeBlurModifier(radius: 10, scale: 0.92, opacity: 0),
                identity: ChromeBlurModifier(radius: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: ChromeBlurModifier(radius: 12, scale: 1.08, opacity: 0),
                identity: ChromeBlurModifier(radius: 0, scale: 1, opacity: 1)
            )
        )
    }
}
