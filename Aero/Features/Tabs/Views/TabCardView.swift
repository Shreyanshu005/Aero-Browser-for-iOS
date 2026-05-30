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
    private let titleBarHeight: CGFloat = 58

    private var accentColor: Color {
        tab.isPrivate
            ? Color(red: 0.80, green: 0.50, blue: 1.0)
            : Color(red: 0.34, green: 0.82, blue: 0.92)
    }

    private var title: String {
        tab.displayTitle.isEmpty ? "New Tab" : tab.displayTitle
    }

    private var subtitle: String {
        if let host = tab.displayURL?.displayHost {
            return host
        }
        return tab.isPrivate ? "Private Tab" : "New Tab"
    }

    var body: some View {
        snapshotArea
        .background(Color(uiColor: tab.pageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(
                    isActive ? accentColor.opacity(0.68) : Color.white.opacity(tab.isPrivate ? 0.18 : 0.10),
                    lineWidth: isActive ? 1.2 : 0.7
                )
        )
        .shadow(color: accentColor.opacity(isActive ? 0.18 : 0), radius: 24, y: 10)
        .shadow(color: .black.opacity(isActive ? 0.56 : 0.44), radius: isActive ? 30 : 22, y: 14)
    }

    private var snapshotArea: some View {
        ZStack {
            snapshotContent

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            if tab.isLoading {
                loadingBar
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(Color.black.opacity(0.88))
        .clipped()
    }


    @ViewBuilder
    private var snapshotContent: some View {
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
                LinearGradient(
                    colors: [
                        Color(UIColor.secondarySystemBackground).opacity(0.55),
                        Color.black.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.13))
                            .frame(width: 66, height: 66)
                        Image(systemName: tab.isPrivate ? "eye.slash" : "safari")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.white.opacity(0.44))
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.44))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    private var faviconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if let favicon = tab.favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .frame(width: 32, height: 32)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.7)
        }
    }

    private func statusBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(Color.black.opacity(0.30))
            }
            .overlay {
                Circle()
                    .strokeBorder(accentColor.opacity(0.30), lineWidth: 0.7)
            }
    }

    private var loadingBar: some View {
        GeometryReader { geo in
            let progress = CGFloat(min(max(tab.estimatedProgress, 0), 1))

            Rectangle()
                .fill(accentColor)
                .frame(width: max(18, geo.size.width * progress), height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: accentColor.opacity(0.45), radius: 6)
        }
        .frame(height: 2)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(Color.black.opacity(tab.isPrivate ? 0.44 : 0.30))
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(tab.isPrivate ? 0.18 : 0.10),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
