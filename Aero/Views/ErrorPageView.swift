import SwiftUI

struct ErrorPageView: View {
    let error: BrowserError
    let retryAction: () -> Void
    let newTabAction: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AeroSpacing.xl) {
                    Spacer()
                        .frame(height: 80)

                    Image(systemName: iconName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 78, height: 78)
                        .background(
                            Circle()
                                .fill(iconColor.opacity(0.12))
                        )
                        .accessibilityHidden(true)

                    VStack(spacing: AeroSpacing.sm) {
                        Text(error.title)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AeroColor.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(error.displayHost)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AeroColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)

                        Text(error.message)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, AeroSpacing.xs)
                    }
                    .frame(maxWidth: 360)

                    VStack(spacing: AeroSpacing.md) {
                        Button(action: retryAction) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.system(.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(AeroColor.textPrimary)
                        .accessibilityIdentifier("navigationErrorRetryButton")

                        Button(action: newTabAction) {
                            Label("New Tab", systemImage: "plus")
                                .font(.system(.body, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(AeroColor.textPrimary)
                        .accessibilityIdentifier("navigationErrorNewTabButton")
                    }
                    .frame(maxWidth: 280)

                    Text(error.displayURL)
                        .font(AeroFont.captionSmall)
                        .foregroundStyle(AeroColor.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)

                    Spacer()
                        .frame(height: BrowserChromeLayout.expandedBottomInset + 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AeroSpacing.xl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .accessibilityIdentifier("navigationErrorPage")
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                appeared = true
            }
        }
    }

    private var iconName: String {
        switch error.kind {
        case .offline:
            return "wifi.slash"
        case .connectionLost, .timedOut:
            return "clock.badge.exclamationmark"
        case .cannotFindServer, .cannotConnect:
            return "network.slash"
        case .secureConnectionFailed:
            return "lock.trianglebadge.exclamationmark"
        case .unsupportedAddress:
            return "link.badge.plus"
        case .cancelled, .unknown:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch error.kind {
        case .secureConnectionFailed:
            return AeroColor.error
        case .offline, .connectionLost, .timedOut, .cannotFindServer, .cannotConnect, .unsupportedAddress, .cancelled, .unknown:
            return AeroColor.warning
        }
    }
}
