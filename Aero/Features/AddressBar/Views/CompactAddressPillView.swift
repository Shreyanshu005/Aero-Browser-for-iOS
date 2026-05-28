import SwiftUI

struct CompactAddressPillView: View {
    @Bindable var viewModel: BrowserViewModel

    private let pillHeight: CGFloat = 40

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.expandChromeForInteraction(focusAddressBar: true)
        } label: {
            HStack(spacing: AeroSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 15)

                Text(displayText)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
            }
            .padding(.horizontal, AeroSpacing.lg)
            .frame(minWidth: 132)
            .frame(height: pillHeight)
            .background {
                Capsule()
                    .fill(Color(UIColor.systemBackground).opacity(0.34))
                    .browserLiquidGlassBackground(in: Capsule())
            }
            .overlay(
                Capsule()
                    .strokeBorder(pillBorder, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 16, y: 6)
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
        if let url = viewModel.activeTab?.displayURL {
            return url.displayHost ?? viewModel.activeTab?.displayTitle ?? url.absoluteString
        }
        return "Search or enter URL"
    }

    private var iconName: String {
        if viewModel.activeTab?.navigationError != nil { return "exclamationmark.triangle.fill" }
        if viewModel.activeTab?.isPrivate == true { return "eye.slash" }
        if viewModel.activeTab?.isSecure == true { return "lock.fill" }
        if viewModel.activeTab?.displayURL != nil { return "globe" }
        return "magnifyingglass"
    }

    private var iconColor: Color {
        if viewModel.activeTab?.navigationError != nil { return AeroColor.warning }
        if viewModel.activeTab?.isSecure == true { return AeroColor.secure }
        return Color(UIColor.secondaryLabel)
    }

    private var pillBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.48),
                Color(UIColor.separator).opacity(0.24),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
