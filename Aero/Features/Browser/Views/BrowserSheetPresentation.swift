import SwiftUI
import UIKit

struct BrowserSheetPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(30)
    }
}

struct BrowserSheetListBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color(UIColor.systemBackground).opacity(0.22)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func browserSheetPresentation() -> some View {
        modifier(BrowserSheetPresentation())
    }

    func browserSheetListBackground() -> some View {
        modifier(BrowserSheetListBackground())
    }
}
