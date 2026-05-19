import SwiftUI

struct TabGridView: View {
    @Bindable var viewModel: BrowserViewModel

    @State private var appeared = false

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    @State private var dragDir: DragAxis = .undecided

    @State private var verticalDrag: CGFloat = 0
    @State private var verticalDragTabID: UUID? = nil
    @State private var isVerticalInteracting = false
    @State private var isDismissing = false

    private var tabs: [Tab] { viewModel.tabManager.tabs }

    private enum DragAxis { case undecided, horizontal, vertical }

    private let cardStep: CGFloat = 265
    private let stackPeek: CGFloat = 22
    private let depthScale: CGFloat = 0.055
    private let maxCards = 3

    var body: some View {
        ZStack {
            background

            deck
                .opacity(appeared ? 1 : 0)
                .padding(.top, 72)
                .padding(.bottom, 96)

            topControls
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)

            bottomControls
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 32)
                .ignoresSafeArea(.container, edges: [.bottom])
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) { appeared = true }
        }
    }

    private var deck: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.82
            let cardH = geo.size.height * 0.98
            let maxOff = max(0, CGFloat(tabs.count - 1) * cardStep)
            let fraction = (offset / cardStep) - floor(offset / cardStep)

            ZStack {
                ForEach(Array(tabs.enumerated().reversed()), id: \.element.id) { (index: Int, tab: Tab) in
                    let depth = CGFloat(index) - offset / cardStep
                    guard depth > -3.0 && depth < CGFloat(maxCards) else { return AnyView(EmptyView()) }

                    let isFront = depth > -0.5 && depth < 0.5

                    let xOffset: CGFloat = {
                        if depth < 0 { return -depth * cardStep }
                        let basePeek = -depth * stackPeek
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
                        return tab.id == verticalDragTabID ? stackY + verticalDrag : stackY
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
                            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .allowsHitTesting(depth >= -0.5 && depth < CGFloat(maxCards))
                            .onTapGesture {
                                guard isFront, !isVerticalInteracting else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.selectTab(tab)
                            }
                            .simultaneousGesture(verticalDismissGesture(for: tab))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .simultaneousGesture(horizontalPagingGesture(maxOff: maxOff))
            .onAppear {
                if let activeID = viewModel.activeTab?.id,
                   let i = viewModel.tabManager.tabs.firstIndex(where: { $0.id == activeID }) {
                    offset = CGFloat(i) * cardStep
                } else {
                    offset = 0
                }
                dragStart = offset
            }
        }
    }

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

    private var topControls: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.closeAllTabs()
            } label: {
                Text("Clear All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
            }
            .disabled(viewModel.tabManager.tabs.count <= 1)
            .opacity(viewModel.tabManager.tabs.count <= 1 ? 0.4 : 1.0)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func horizontalPagingGesture(maxOff: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { v in
                guard !isVerticalInteracting else { return }
                let dx = v.translation.width
                let dy = v.translation.height

                if dragDir == .undecided {
                    if abs(dx) > 8 {
                        dragDir = .horizontal
                        dragStart = offset
                    } else if abs(dy) > 24, abs(dy) > abs(dx) * 2.0 {
                        dragDir = .vertical
                        return
                    } else {
                        return
                    }
                }

                guard dragDir == .horizontal else { return }

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
            }
            .onEnded { v in
                defer { dragDir = .undecided }
                guard dragDir == .horizontal, !tabs.isEmpty else { return }

                let currentIndex = Int((offset / cardStep).rounded()).clamped(to: 0...(tabs.count - 1))
                let predicted = dragStart + v.predictedEndTranslation.width
                let predictedIndex = Int((predicted / cardStep).rounded()).clamped(to: 0...(tabs.count - 1))

                let maxJump = 2
                let targetIndex = predictedIndex.clamped(
                    to: max(0, currentIndex - maxJump)...min(tabs.count - 1, currentIndex + maxJump)
                )

                let target = CGFloat(targetIndex) * cardStep
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
                    offset = target
                }
                dragStart = target
            }
    }

    private func verticalDismissGesture(for tab: Tab) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { v in
                guard !isDismissing else { return }

                let dx = v.translation.width
                let dy = v.translation.height
                guard dy < -18, abs(dy) > abs(dx) * 1.35 else { return }

                isVerticalInteracting = true
                verticalDragTabID = tab.id

                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { verticalDrag = dy }
            }
            .onEnded { v in
                guard verticalDragTabID == tab.id else { return }

                let dy = v.translation.height
                let predicted = v.predictedEndTranslation.height
                let shouldDismiss = dy < -140 || predicted < -220

                if shouldDismiss {
                    triggerDismiss(tab: tab)
                } else {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82)) {
                        verticalDrag = 0
                    }
                    verticalDragTabID = nil
                    isVerticalInteracting = false
                }
            }
    }

    private func triggerDismiss(tab: Tab) {
        guard !isDismissing else { return }
        isDismissing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.92)) {
            verticalDrag = -1000
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let removedIndex = viewModel.tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
                let currentFrontIndex = Int((offset / cardStep).rounded())
                    .clamped(to: 0...max(viewModel.tabManager.tabs.count - 1, 0))
                viewModel.closeTab(tab)
                if removedIndex < currentFrontIndex {
                    offset = max(0, offset - cardStep)
                }
            } else {
                viewModel.closeTab(tab)
            }

            let maxOff = max(0, CGFloat(max(viewModel.tabManager.tabs.count - 1, 0)) * cardStep)
            offset = offset.clamped(to: 0...maxOff)
            dragStart = offset

            verticalDrag = 0
            verticalDragTabID = nil
            isVerticalInteracting = false
            isDismissing = false

            if viewModel.tabManager.tabs.isEmpty { viewModel.hideTabGrid() }
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
