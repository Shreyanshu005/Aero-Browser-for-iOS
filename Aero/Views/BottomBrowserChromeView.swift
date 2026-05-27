import SwiftUI

struct BottomBrowserChromeView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.chromeMode == .expanded {
                expandedChrome
                    .transition(.chromeBlurReplace)
            }

            if viewModel.chromeMode == .compact {
                CompactAddressPill(viewModel: viewModel)
                    .padding(.horizontal, AeroSpacing.xl)
                    .padding(.bottom, AeroSpacing.sm)
                    .transition(.chromeBlurReplace)
            }
        }
        .animation(AeroAnimation.smooth, value: viewModel.chromeMode)
    }

    private var expandedChrome: some View {
        VStack(spacing: AeroSpacing.sm) {
            if viewModel.isAddressBarFocused && !viewModel.suggestions.isEmpty {
                SuggestionsDropdown(suggestions: viewModel.suggestions) { suggestion in
                    viewModel.selectSuggestion(suggestion)
                }
                .padding(.horizontal, AeroSpacing.md)
                .transition(.chromeBlurReplace)
            }

            HStack(spacing: AeroSpacing.sm) {
                AddressBar(viewModel: viewModel)

                if viewModel.isAddressBarFocused {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.dismissSearchPresentation()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 38, height: 38)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel Address Entry")
                    .accessibilityIdentifier("browser.addressBar.cancel")
                    .transition(.chromeBlurReplace)
                }
            }
            .padding(.horizontal, AeroSpacing.md)
            .padding(.top, viewModel.isAddressBarFocused && !viewModel.suggestions.isEmpty ? 0 : AeroSpacing.md)

            if !viewModel.isAddressBarFocused {
                ToolbarView(viewModel: viewModel)
                    .padding(.horizontal, AeroSpacing.md)
                    .transition(.chromeBlurReplace)
            }
        }
        .padding(.bottom, AeroSpacing.sm)
        .gesture(openTabsDragGesture)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(AeroAnimation.smooth, value: viewModel.isAddressBarFocused)
        .animation(AeroAnimation.smooth, value: viewModel.suggestions.isEmpty)
    }

    private var openTabsDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard value.translation.height < -56,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showTabGrid()
            }
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
        .accessibilityLabel("Address Bar")
        .accessibilityValue(Text(displayText))
        .accessibilityIdentifier("browser.compactAddressBar")
        .gesture(openTabsDragGesture)
    }

    private var openTabsDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard value.translation.height < -56,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showTabGrid()
            }
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
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(true), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
#else
        self.background(.ultraThinMaterial, in: shape)
#endif
    }
}
