import SwiftUI

struct TabGridView: View {
    @Bindable var viewModel: BrowserViewModel

    @State private var appeared     = false
    @State private var offset: CGFloat  = 0
    @State private var dragStart: CGFloat = 0
    @State private var dragDir: DragAxis  = .undecided
    @State private var verticalDrag: CGFloat = 0
    @State private var isDismissing = false

    // Physics momentum
    @State private var momentumVelocity: CGFloat = 0
    @State private var momentumTimer: Timer? = nil

    private enum DragAxis { case undecided, horizontal, vertical }

    private var tabs: [Tab] { viewModel.tabManager.tabs }

    private let cardStep: CGFloat   = 265
    private let stackPeek: CGFloat  = 22
    private let depthScale: CGFloat = 0.055
    private let maxCards            = 3
    // Physics constants
    private let friction: CGFloat   = 0.88   // velocity multiplied each frame (0-1, lower = more friction)
    private let snapThreshold: CGFloat = 80  // velocity below this → snap to nearest

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer()
                deck.opacity(appeared ? 1 : 0)
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
            let cardW  = geo.size.width * 0.78
            let cardH  = geo.size.height * 0.85
            let maxOff = max(0, CGFloat(tabs.count - 1) * cardStep)
            let fraction = (offset / cardStep) - floor(offset / cardStep)

            ZStack {
                ForEach(Array(tabs.enumerated().reversed()), id: \.element.id) { (index: Int, tab: Tab) in
                    let depth = CGFloat(index) - offset / cardStep

                    // Wide visibility window so cards never pop out mid-scroll
                    guard depth > -3.0 && depth < CGFloat(maxCards) else { return AnyView(EmptyView()) }

                    let isFront = depth > -0.5 && depth < 0.5

                    let xOffset: CGFloat = {
                        if depth < 0 {
                            // Passed: slide right off screen — stays fully rendered
                            return -depth * cardStep
                        }
                        let basePeek = -depth * stackPeek
                        // 75% cascade: next card starts sliding when current is 75% revealed
                        if depth > 0 && fraction > 0.75 {
                            let distToNextFront = depth - (1.0 - fraction)
                            if distToNextFront > 0 && distToNextFront < 1 {
                                let pull = (fraction - 0.75) / 0.25
                                return basePeek * (1.0 - pull)
                            }
                        }
                        return basePeek
                    }()

                    let yOffset: CGFloat = {
                        let stackY = max(0, depth) * stackPeek * 0.5
                        return isFront ? stackY + verticalDrag : stackY
                    }()

                    let scale: CGFloat = max(0.75, 1.0 - max(0, depth) * depthScale)

                    let opacity: CGFloat = {
                        if depth < 0 { return 1.0 }
                        let limit = CGFloat(maxCards - 1)
                        if depth >= limit { return max(0, 1.0 - (depth - limit + 1)) }
                        return 1.0
                    }()

                    return AnyView(
                        TabCardView(tab: tab, isActive: isFront)
                            .frame(width: cardW, height: cardH)
                            .scaleEffect(scale, anchor: .top)
                            .offset(x: xOffset, y: yOffset)
                            .opacity(opacity)
                            .zIndex(Double(tabs.count - index))
                            .allowsHitTesting(isFront)
                            .onTapGesture {
                                guard isFront, abs(verticalDrag) < 10 else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.selectTab(tab)
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, geo.size.height * 0.06)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .local)
                    .onChanged { v in
                        // Stop any ongoing momentum
                        stopMomentum()

                        let dx = v.translation.width
                        let dy = v.translation.height

                        if dragDir == .undecided {
                            if abs(dy) > abs(dx) * 1.4 && abs(dy) > 12 {
                                dragDir = .vertical
                            } else if abs(dx) > 10 {
                                dragDir = .horizontal
                            } else { return }
                        }

                        if dragDir == .horizontal {
                            // Raw 1:1 — zero animation
                            let raw = dragStart + dx
                            var tx = Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                if raw < 0 {
                                    offset = raw * 0.12
                                } else if raw > maxOff {
                                    offset = maxOff + (raw - maxOff) * 0.12
                                } else {
                                    offset = raw
                                }
                            }
                        } else if dragDir == .vertical {
                            var tx = Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) { verticalDrag = dy }
                        }
                    }
                    .onEnded { v in
                        defer { dragDir = .undecided }

                        if dragDir == .vertical {
                            if v.translation.height < -100 || v.predictedEndTranslation.height < -200 {
                                triggerDismiss()
                            } else {
                                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.72)) {
                                    verticalDrag = 0
                                }
                            }
                            return
                        }

                        // Launch physics momentum with finger velocity
                        let vel = v.velocity.width
                        if abs(vel) > 150 {
                            launchMomentum(velocity: vel, maxOff: maxOff)
                        }
                        // No snap on slow release — card stays exactly where finger left it
                        // Only momentum-end triggers a snap
                    }
            )
            .onAppear { dragStart = offset }
        }
    }

    // MARK: - Physics Momentum

    /// Launches a CADisplayLink-rate timer that applies friction each frame
    /// and moves offset by the decaying velocity — every card is physically visited.
    private func launchMomentum(velocity: CGFloat, maxOff: CGFloat) {
        stopMomentum()
        momentumVelocity = velocity

        // ~60fps timer
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            // Decay velocity
            momentumVelocity *= friction

            // Move offset — positive velocity = swipe right = offset increases
            let newOffset = offset + momentumVelocity / 60.0

            // Hard clamp at edges (no rubber band during momentum)
            if newOffset <= 0 {
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { offset = 0; dragStart = 0 }
                stopMomentum()
                return
            }
            if newOffset >= maxOff {
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { offset = maxOff; dragStart = maxOff }
                stopMomentum()
                return
            }

            // Direct assignment — no animation, pure frame-by-frame
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) { offset = newOffset }

            // When velocity is low enough, snap to nearest card and stop
            if abs(momentumVelocity) < snapThreshold {
                stopMomentum()
                snapToNearest(maxOff: maxOff)
            }
        }
    }

    private func stopMomentum() {
        momentumTimer?.invalidate()
        momentumTimer = nil
        momentumVelocity = 0
    }

    private func snapToNearest(maxOff: CGFloat) {
        let snapped = (offset / cardStep).rounded()
            .clamped(to: 0...CGFloat(tabs.count - 1)) * cardStep
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86)) {
            offset = snapped
        }
        dragStart = snapped
    }

    // MARK: - Dismiss (swipe up)

    private func triggerDismiss() {
        guard !tabs.isEmpty, !isDismissing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isDismissing = true

        let dismissedIndex = Int((offset / cardStep).rounded()).clamped(to: 0...(tabs.count - 1))
        let tab = tabs[dismissedIndex]

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.94)) {
            verticalDrag = -900
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            // Pre-shift offset so that after removal the next card sits at depth=0
            // with no positional change — prevents the slide-up jerk.
            // If dismissedIndex > 0, offset decreases by one step so the card
            // behind (now index-1) computes the same depth it had before removal.
            let targetOffset: CGFloat
            if dismissedIndex > 0 {
                targetOffset = max(0, offset - cardStep)
            } else {
                targetOffset = 0
            }

            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                // Silently reposition offset first — cards don't move visually
                offset = targetOffset
                dragStart = targetOffset
                // Now remove — the behind card is already at the right depth
                viewModel.closeTab(tab)
                verticalDrag = 0
            }

            isDismissing = false
            if viewModel.tabManager.tabs.isEmpty { viewModel.hideTabGrid() }
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

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}