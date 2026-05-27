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
        GeometryReader { geo in
            VStack(spacing: 0) {
                titleBar
                    .frame(height: 46)
                snapshotArea
                    .frame(width: geo.size.width, height: geo.size.height - 46)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(isActive ? 0.15 : 0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            if let favicon = tab.favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 18, height: 18)
            }
            if tab.isPrivate {
                Image(systemName: "eye.slash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(tab.displayTitle.isEmpty ? "New Tab" : tab.displayTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black)
    }

    @ViewBuilder
    private var snapshotArea: some View {
        if let snapshot = tab.snapshot {
            Image(uiImage: snapshot)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else if let webView = tab.webView {
            TabWebViewSnapshot(webView: webView)
                .clipped()
                .allowsHitTesting(false)
        } else {
            ZStack {
                Color.black
                VStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.system(size: 42, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                    Text(tab.displayURL?.host ?? "New Tab")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        }
    }
}
