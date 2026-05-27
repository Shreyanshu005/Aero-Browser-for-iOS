import SwiftUI

struct BottomBrowserChromeView: View {
    @Bindable var viewModel: BrowserViewModel
    @Namespace private var addressTransition

    private let chromeCornerRadius: CGFloat = 28
    private let addressBarHeight: CGFloat = 46

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.chromeMode == .expanded {
                expandedChrome
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.chromeMode == .compact {
                CompactAddressPillView(viewModel: viewModel)
                    .frame(maxWidth: 260)
                    .padding(.bottom, AeroSpacing.sm)
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
                addressControl
                    .matchedGeometryEffect(id: "address", in: addressTransition)

                if viewModel.isAddressBarFocused {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.dismissSearchPresentation()
                    } label: {
                        Text("Cancel")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(width: 68, height: 44)
                            .background {
                                Capsule()
                                    .fill(Color(UIColor.systemBackground).opacity(0.36))
                                    .browserLiquidGlassBackground(in: Capsule())
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
                            }
                            .contentShape(Capsule())
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
        .padding(.horizontal, AeroSpacing.sm)
        .padding(.top, AeroSpacing.sm)
        .padding(.bottom, AeroSpacing.md)
        .background { chromeBackground }
        .overlay {
            chromeShape
                .strokeBorder(chromeBorder, lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(viewModel.isAddressBarFocused ? 0.10 : 0.18), radius: 22, y: 8)
        .padding(.horizontal, AeroSpacing.sm)
        .padding(.bottom, AeroSpacing.sm)
        .gesture(openTabsDragGesture)
    }

    private var addressControl: some View {
        AddressBar(viewModel: viewModel)
            .frame(height: addressBarHeight)
            .background {
                Capsule()
                    .fill(Color(UIColor.systemBackground).opacity(viewModel.isAddressBarFocused ? 0.82 : 0.40))
                    .browserLiquidGlassBackground(in: Capsule())
            }
            .overlay {
                Capsule()
                    .strokeBorder(addressBorder, lineWidth: 0.7)
            }
            .shadow(color: Color.black.opacity(viewModel.isAddressBarFocused ? 0.06 : 0.12), radius: 10, y: 3)
            .contentShape(Capsule())
    }

    private var chromeBackground: some View {
        chromeShape
            .fill(Color(UIColor.systemBackground).opacity(viewModel.isAddressBarFocused ? 0.74 : 0.30))
            .browserLiquidGlassBackground(in: chromeShape)
    }

    private var chromeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: chromeCornerRadius, style: .continuous)
    }

    private var chromeBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.46),
                Color(UIColor.separator).opacity(0.24),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var addressBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(viewModel.isAddressBarFocused ? 0.50 : 0.38),
                Color(UIColor.separator).opacity(0.28),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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

extension View {
    @ViewBuilder
    func browserLiquidGlassBackground<S: Shape>(in shape: S) -> some View {
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
