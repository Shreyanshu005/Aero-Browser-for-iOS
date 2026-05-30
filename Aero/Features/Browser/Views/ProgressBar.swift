import SwiftUI

struct ProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var animateGradient = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isLoading && progress > 0 {
                    let gradient = LinearGradient(
                        colors: [
                            Color.orange,
                            Color.red,
                            Color.pink,
                            Color.orange,
                        ],
                        startPoint: animateGradient ? .leading : UnitPoint(x: -0.5, y: 0.5),
                        endPoint: animateGradient ? UnitPoint(x: 1.5, y: 0.5) : .leading
                    )

                    RoundedRectangle(cornerRadius: 1)
                        .fill(gradient)
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                        .shadow(color: Color.pink.opacity(0.55), radius: 6, y: 0)
                        .shadow(color: Color.orange.opacity(0.35), radius: 10, y: 0)
                }
            }
        }
        .frame(height: 2.5)
        .opacity(isLoading && progress > 0 && progress < 1.0 ? 1.0 : 0.0)
        .animation(AeroAnimation.fade, value: isLoading)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}
