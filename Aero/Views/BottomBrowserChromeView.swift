import SwiftUI

struct BottomBrowserChromeView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.chromeMode == .expanded {
                expandedChrome
                    .transition(.asymmetric(
                        insertion: .scale(scale: 1.04, anchor: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.88, anchor: .bottom).combined(with: .opacity)
                    ))
            }

            if viewModel.chromeMode == .compact {
                CompactAddressPill(viewModel: viewModel)
                    .padding(.horizontal, AeroSpacing.xl)
                    .padding(.bottom, AeroSpacing.sm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 1.08, anchor: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .animation(AeroAnimation.snappy, value: viewModel.chromeMode)
    }

    private var expandedChrome: some View {
        VStack(spacing: AeroSpacing.sm) {
            AddressBar(viewModel: viewModel)
                .padding(.horizontal, AeroSpacing.md)
                .padding(.top, AeroSpacing.md)

            ToolbarView(viewModel: viewModel)
                .padding(.horizontal, AeroSpacing.md)
        }
        .padding(.bottom, AeroSpacing.sm)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct CompactAddressPill: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.expandChromeForInteraction(focusAddressBar: true)
        } label: {
            HStack(spacing: AeroSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(displayText)
                    .font(.system(.callout, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AeroSpacing.lg)
            .frame(height: 44)
            .liquidGlassBackground(in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 16, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var displayText: String {
        if let url = viewModel.activeTab?.url {
            return url.displayHost ?? viewModel.activeTab?.displayTitle ?? url.absoluteString
        }
        return "Search or enter URL"
    }

    private var iconName: String {
        if viewModel.activeTab?.isSecure == true { return "lock.fill" }
        if viewModel.activeTab?.url != nil { return "globe" }
        return "magnifyingglass"
    }

    private var iconColor: Color {
        if viewModel.activeTab?.isSecure == true { return AeroColor.secure }
        return Color(UIColor.secondaryLabel)
    }
}

private extension View {
    @ViewBuilder
    func liquidGlassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(true), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
