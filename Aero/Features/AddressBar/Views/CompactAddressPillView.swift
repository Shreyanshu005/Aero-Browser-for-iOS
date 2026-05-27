import SwiftUI

struct CompactAddressPillView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.isAddressBarFocused = true
            viewModel.chromeController.expand()
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
            .background(.ultraThinMaterial, in: Capsule())
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
                viewModel.isShowingTabGrid = true
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
