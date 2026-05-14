import SwiftUI

struct BottomBrowserChromeView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        Group {
            switch viewModel.chromeMode {
            case .expanded:
                expandedChrome
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .compact:
                CompactAddressPill(viewModel: viewModel)
                    .padding(.horizontal, AeroSpacing.xl)
                    .padding(.bottom, AeroSpacing.sm)
                    .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
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
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(UIColor.separator).opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
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
