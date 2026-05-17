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
                    .frame(maxWidth: 260)
                    .padding(.bottom, 2)
                    .transition(.chromeBlurReplace)
            }
        }
        .animation(AeroAnimation.smooth, value: viewModel.chromeMode)
    }

    private var expandedChrome: some View {
        VStack(spacing: AeroSpacing.sm) {
            if viewModel.isAddressBarFocused && !viewModel.wikiSuggestions.isEmpty {
                WikiSuggestionsDropdown(suggestions: viewModel.wikiSuggestions) { suggestion in
                    viewModel.navigateToWikiSuggestion(suggestion)
                }
                .padding(.horizontal, AeroSpacing.md)
                .transition(.chromeBlurReplace)
            }

            dockContent
                .transition(.chromeBlurReplace)
        }
        .padding(.bottom, 2)
        .animation(AeroAnimation.smooth, value: viewModel.isAddressBarFocused)
        .animation(AeroAnimation.smooth, value: viewModel.wikiSuggestions.isEmpty)
    }

    private var dockContent: some View {
        VStack(spacing: AeroSpacing.sm) {
            if let tab = viewModel.activeTab {
                ProgressBar(progress: tab.estimatedProgress, isLoading: tab.isLoading)
                    .padding(.horizontal, 18)
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
                            .liquidGlassBackground(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.chromeBlurReplace)
                }
            }

            if !viewModel.isAddressBarFocused {
                ToolbarView(viewModel: viewModel)
                    .transition(.chromeBlurReplace)
            }
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.vertical, AeroSpacing.md)
        .dockGlassContainer()
        .padding(.horizontal, AeroSpacing.md)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(displayText)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(1)
            }
            .padding(.horizontal, AeroSpacing.md)
            .frame(height: 36)
            .liquidGlassBackground(in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 12, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    func dockGlassContainer() -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        self
            .padding(.bottom, 0)
            .background {
                Color.clear.liquidGlassBackground(in: shape)
                    .overlay(shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7))
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}
