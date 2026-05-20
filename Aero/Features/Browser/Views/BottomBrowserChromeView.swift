import SwiftUI

struct BottomBrowserChromeView: View {
    @Bindable var viewModel: BrowserViewModel
    @Namespace private var addressTransition

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.chromeMode == .expanded {
                expandedChrome
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.chromeMode == .compact {
                CompactAddressPillView(viewModel: viewModel)
                    .frame(maxWidth: 260)
                    .matchedGeometryEffect(id: "address", in: addressTransition)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AeroAnimation.smooth, value: viewModel.chromeMode)
    }

    private var expandedChrome: some View {
        VStack(spacing: AeroSpacing.sm) {
            bottomBar
                .transition(.chromeBlurReplace)
        }
        .animation(AeroAnimation.smooth, value: viewModel.isAddressBarFocused)
        .animation(AeroAnimation.smooth, value: viewModel.searchSuggestions.isEmpty)
    }

    private var bottomBar: some View {
        VStack(spacing: AeroSpacing.sm) {
            if let tab = viewModel.activeTab {
                ProgressBar(progress: tab.estimatedProgress, isLoading: tab.isLoading)
            }

            HStack(spacing: AeroSpacing.sm) {
                AddressBar(viewModel: viewModel)
                    .matchedGeometryEffect(id: "address", in: addressTransition)

                if viewModel.isAddressBarFocused {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.dismissSearchPresentation()
                    } label: {
                        Text("Cancel")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(height: 38)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AeroSpacing.md)
        .padding(.top, AeroSpacing.sm)
        .padding(.bottom, AeroSpacing.xl)
        .background {
            if viewModel.isAddressBarFocused {
                Color(UIColor.systemGray6)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.35)
        }
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
