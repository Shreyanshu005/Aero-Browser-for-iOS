import SwiftUI

struct TabGridView: View {
    @Bindable var viewModel: BrowserViewModel

    @State private var appeared = false
    @State private var scrollOffset: CGFloat = 0
    @State private var verticalDrag: CGFloat = 0
    @State private var isDismissing = false
    @State private var dragDirection: DragDirection = .none
    @State private var dragVelocity: CGFloat = 0

    private var tabs: [Tab] { viewModel.tabManager.tabs }

    private let cardWidthRatio: CGFloat = 0.78
    private let cardHeightRatio: CGFloat = 0.85
    private let cardSpacing: CGFloat = 35
    private let depthScale: CGFloat = 0.06
    private let depthOffset: CGFloat = 400
    private let maxVisible = 8

    private enum DragDirection {
        case none, horizontal, vertical
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                deck
                    .opacity(appeared ? 1 : 0)

                Spacer()

                bottomControls
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) { appeared = true }
        }
    }

    // MARK: - Deck

    private var deck: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * cardWidthRatio
            let cardH = geo.size.height * cardHeightRatio
            let maxOffset = max(0, CGFloat(tabs.count - 1) * cardW)

            ZStack {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    let currentIndex = Int(round(scrollOffset / cardW))
                    let depthFromCurrent = index - currentIndex
                    
                    let absDepth = abs(depthFromCurrent)
                    
                    let scale: CGFloat = 1.0 - min(CGFloat(absDepth) * depthScale, 0.35)
                    let xOffset: CGFloat = depthFromCurrent < 0 ? CGFloat(absDepth) * depthOffset : -CGFloat(depthFromCurrent) * 60
                    let opacity: CGFloat = 1.0
                    let zIndex = Double(tabs.count - index)
                    
                    let isCurrentCard = depthFromCurrent == 0
                    
                    if absDepth < maxVisible {
                        TabCardView(tab: tab, isActive: isCurrentCard)
                            .frame(width: cardW, height: cardH)
                            .scaleEffect(scale, anchor: .center)
                            .offset(x: xOffset, y: isCurrentCard ? verticalDrag : 0)
                            .opacity(opacity)
                            .zIndex(zIndex)
                            .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.80), value: scrollOffset)
                            .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.80), value: verticalDrag)
                            .allowsHitTesting(isCurrentCard)
                            .onTapGesture {
                                guard isCurrentCard, abs(verticalDrag) < 10 else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.selectTab(tab)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, geo.size.height * 0.06)
            .contentShape(Rectangle())
            .gesture(deckGesture(geo: geo, maxOffset: maxOffset))
        }
    }

    // MARK: - Gesture

    private func deckGesture(geo: GeometryProxy, maxOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                guard !isDismissing else { return }
                let dx = v.translation.width
                let dy = v.translation.height

                // Lock direction on first significant movement
                if dragDirection == .none {
                    if abs(dy) > abs(dx) * 1.5 {
                        dragDirection = .vertical
                    } else if abs(dx) > 10 {
                        dragDirection = .horizontal
                    }
                }

                switch dragDirection {
                case .horizontal:
                    let newOffset = scrollOffset + dx
                    scrollOffset = max(0, min(maxOffset, newOffset))
                    verticalDrag = 0
                case .vertical:
                    verticalDrag = dy
                case .none:
                    break
                }
            }
            .onEnded { v in
                guard !isDismissing else { return }
                let dy = v.translation.height
                let pdy = v.predictedEndTranslation.height

                defer { dragDirection = .none }

                // Vertical dismiss check
                if dragDirection == .vertical && (dy < -110 || pdy < -220) {
                    triggerDismiss()
                    return
                }

                // Horizontal scroll - stop exactly where released (no momentum)
                if dragDirection == .horizontal {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) {
                        scrollOffset = max(0, min(maxOffset, scrollOffset))
                    }
                }

                // Spring vertical back
                withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.72)) {
                    verticalDrag = 0
                }
            }
    }

    // MARK: - Dismiss

    private func triggerDismiss() {
        guard !tabs.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isDismissing = true

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
            verticalDrag = -900
        }

        let tab = tabs[0]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            viewModel.closeTab(tab)
            isDismissing = false
            verticalDrag = 0

            if viewModel.tabManager.tabs.isEmpty {
                viewModel.hideTabGrid()
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .opacity(0.45)
            RadialGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                center: .top, startRadius: 40, endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }

            Spacer()

            Button { viewModel.hideTabGrid() } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
            }
        }
        .padding(.horizontal, 28)
    }
}