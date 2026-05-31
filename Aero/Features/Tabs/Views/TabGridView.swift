import SwiftUI

struct TabGridView: View {
    var viewModel: BrowserViewModel

    @State private var appeared = false

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    @State private var dragDir: DragAxis = .undecided

    @State private var verticalDrag: CGFloat = 0
    @State private var verticalDragTabID: UUID? = nil
    @State private var isVerticalInteracting = false
    @State private var isDismissing = false

    private var tabs: [Tab] { viewModel.tabManager.tabs(in: viewModel.activeBrowsingMode) }

    private enum DragAxis { case undecided, horizontal, vertical }

    private let cardStep: CGFloat = 265
    private let stackPeek: CGFloat = 22
    private let depthScale: CGFloat = 0.055
    private let maxCards = 3
    private let controlHeight: CGFloat = 46



    var body: some View {
        ZStack {
            background

            deck
                .opacity(appeared ? 1 : 0)
                .padding(.top, 72)
                .padding(.bottom, 24)

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
        .preferredColorScheme(.dark)
    }

    private var deck: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.75
            let headerH: CGFloat = 36
            let totalH = geo.size.height
            let cardH = max(240, totalH - headerH)
            let maxOff = max(0, CGFloat(tabs.count - 1) * cardStep)
            let fraction = (offset / cardStep) - floor(offset / cardStep)

            ZStack {
                ForEach(Array(tabs.enumerated().reversed()), id: \.element.id) { item in
                    let index = item.offset
                    let tab = item.element
                    let depth = CGFloat(index) - offset / cardStep
                    if depth > -3.0 && depth < CGFloat(maxCards) {
                        buildCard(tab: tab, index: index, fraction: fraction, cardW: cardW, cardH: cardH, headerH: headerH)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, bottomControlsClearance)
            .contentShape(Rectangle())
            .simultaneousGesture(horizontalPagingGesture(maxOff: maxOff))
            .onAppear {
                if let activeID = viewModel.activeTab?.id,
                   let i = tabs.firstIndex(where: { $0.id == activeID }) {
                    offset = CGFloat(i) * cardStep
                } else {
                    offset = 0
                }
                dragStart = offset
            }
        }
    }

    private var bottomControlsClearance: CGFloat { 84 }

    private struct TabCardHeaderView: View {
        let tab: Tab
        let isFront: Bool

        var body: some View {
            HStack(spacing: 10) {
                if let favicon = tab.favicon {
                    Image(uiImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 18, height: 18)
                }

                if isFront {
                    Text(domainText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.18), value: isFront)
        }

        private var domainText: String {
            tab.url?.displayHost ?? tab.url?.host ?? "New Tab"
        }
    }

    private var background: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()
    }

    private var bottomControls: some View {
        HStack(spacing: 14) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.newTab()
                viewModel.isShowingTabGrid = false
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Tab")

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let nextMode: BrowsingMode = viewModel.activeBrowsingMode == .standard ? .privateBrowsing : .standard
                viewModel.switchBrowsingMode(nextMode)
            } label: {
                Image(systemName: viewModel.activeBrowsingMode == .standard ? BrowsingMode.privateBrowsing.systemImage : BrowsingMode.standard.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.activeBrowsingMode == .standard ? "Switch to Private Mode" : "Switch to Standard Mode")
        }
        .padding(.horizontal, 24)
    }

    private var topControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.closeAllTabs()
                } label: {
                    Label("Clear", systemImage: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 88, minHeight: controlHeight)
                        .padding(.horizontal, 4)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .disabled(tabs.count <= 1)
                .opacity(tabs.count <= 1 ? 0.4 : 1.0)

                VStack(spacing: 2) {
                    Text(viewModel.activeBrowsingMode.tabGridTitle(count: tabs.count))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(viewModel.activeBrowsingMode == .privateBrowsing ? "Private" : "Browsing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: controlHeight)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.reopenLastClosedTab()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: controlHeight, height: controlHeight)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canReopenLastClosedTab)
                .opacity(viewModel.canReopenLastClosedTab ? 1 : 0.4)
                .accessibilityLabel("Reopen Last Closed Tab")
            }
        }
        .padding(.horizontal, 22)
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
            if let removedIndex = tabs.firstIndex(where: { $0.id == tab.id }) {
                let currentFrontIndex = Int((offset / cardStep).rounded())
                    .clamped(to: 0...max(tabs.count - 1, 0))
                viewModel.closeTab(tab)
                if removedIndex < currentFrontIndex {
                    offset = max(0, offset - cardStep)
                }
            } else {
                viewModel.closeTab(tab)
            }

            let maxOff = max(0, CGFloat(max(tabs.count - 1, 0)) * cardStep)
            offset = offset.clamped(to: 0...maxOff)
            dragStart = offset

            verticalDrag = 0
            verticalDragTabID = nil
            isVerticalInteracting = false
            isDismissing = false

            if tabs.isEmpty { viewModel.isShowingTabGrid = false }
        }
    }

    @ViewBuilder
    private func buildCard(tab: Tab, index: Int, fraction: CGFloat, cardW: CGFloat, cardH: CGFloat, headerH: CGFloat) -> some View {
        let depth = CGFloat(index) - offset / cardStep
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

        VStack(spacing: 6) {
            TabCardHeaderView(tab: tab, isFront: isFront)
                .frame(width: cardW, height: headerH, alignment: .leading)

            TabCardView(tab: tab, isActive: isFront)
                .frame(width: cardW, height: cardH)
        }
        .scaleEffect(x: 1.0, y: scale, anchor: .top)
        .offset(x: xOffset, y: yOffset)
        .opacity(opacity)
        .zIndex(Double(tabs.count - index))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .allowsHitTesting(depth >= -0.5 && depth < CGFloat(maxCards))
        .onTapGesture {
            guard !isVerticalInteracting else { return }
            if isFront {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.selectTab(tab)
            } else {
                let target = CGFloat(index) * cardStep
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
                    offset = target
                }
                dragStart = target
            }
        }
        .simultaneousGesture(verticalDismissGesture(for: tab))
    }
}
