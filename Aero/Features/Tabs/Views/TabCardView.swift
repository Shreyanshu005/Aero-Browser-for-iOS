import SwiftUI
import WebKit

private struct TabWebViewSnapshot: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct TabCardView: View {
    let tab: Tab
    let isActive: Bool
    private let cardRadius: CGFloat = 28

    var body: some View {
        snapshotArea
        .background(Color(uiColor: tab.pageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(isActive ? 0.15 : 0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    @ViewBuilder
    private var snapshotArea: some View {
        if let snapshot = tab.snapshot {
            GeometryReader { geo in
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
            }
        } else if let webView = tab.webView {
            ZStack {
                Color(uiColor: tab.pageBackgroundColor)
                TabWebViewSnapshot(webView: webView)
                    .clipped()
                    .allowsHitTesting(false)
            }
        } else {
            ZStack {
                Color.black
                VStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.system(size: 42, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                    Text(tab.url?.host ?? "New Tab")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        }
    }
}
