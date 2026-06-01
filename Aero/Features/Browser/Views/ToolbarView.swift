import SwiftUI

struct ToolbarView: View {
    @Bindable var viewModel: BrowserViewModel

    private let buttonHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: AeroSpacing.xs) {
            toolbarButton(
                "chevron.left",
                accessibilityLabel: "Back",
                accessibilityIdentifier: "browser.toolbar.back",
                enabled: viewModel.activeTab?.canGoBack ?? false
            ) {
                viewModel.goBack()
            }

            toolbarButton(
                "chevron.right",
                accessibilityLabel: "Forward",
                accessibilityIdentifier: "browser.toolbar.forward",
                enabled: viewModel.activeTab?.canGoForward ?? false
            ) {
                viewModel.goForward()
            }

            toolbarButton(
                "plus",
                accessibilityLabel: "New Tab",
                accessibilityIdentifier: "browser.toolbar.newTab",
                enabled: true
            ) {
                viewModel.newTab()
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.isShowingTabGrid = true
            } label: {
                toolbarButtonShell(isEnabled: true) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(UIColor.label), lineWidth: 1.45)
                            .frame(width: 22, height: 18)

                        Text(visibleTabCount)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .frame(width: 18)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs")
            .accessibilityValue(Text("\(viewModel.tabManager.tabCount)"))
            .accessibilityIdentifier("browser.toolbar.tabs")

            toolbarButton(
                "line.3.horizontal",
                accessibilityLabel: "Menu",
                accessibilityIdentifier: "browser.toolbar.menu",
                enabled: true
            ) {
                viewModel.showMenu = true
            }
        }
        .frame(height: buttonHeight)
        .accessibilityIdentifier("browser.toolbar")
    }

    @ViewBuilder
    private func toolbarButton(
        _ icon: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            toolbarButtonShell(isEnabled: enabled) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(enabled ? Color(UIColor.label) : Color(UIColor.tertiaryLabel))
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func toolbarButtonShell<Content: View>(
        isEnabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .contentShape(Rectangle())
    }

    private var visibleTabCount: String {
        let count = viewModel.tabManager.tabCount
        return count > 99 ? "99+" : "\(count)"
    }
}
