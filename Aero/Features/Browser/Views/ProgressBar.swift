






import SwiftUI

struct ProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var animateGradient = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isLoading && progress > 0 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.5),
                                    Color.blue,
                                    Color.blue.opacity(0.5),
                                ],
                                startPoint: animateGradient ? .leading : UnitPoint(x: -0.5, y: 0.5),
                                endPoint: animateGradient ? UnitPoint(x: 1.5, y: 0.5) : .leading
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .animation(.easeInOut(duration: 0.3), value: progress)
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
