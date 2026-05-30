import SwiftUI
import UIKit

struct AddressBar: View {
    @Bindable var viewModel: BrowserViewModel

    @State private var isTabSwipeGestureActive = false

    var body: some View {
        HStack(spacing: 8) {
            leadingAccessory

            if viewModel.isAddressBarFocused {
                SelectableTextField(
                    placeholder: "Search or enter URL",
                    text: $viewModel.addressBarText,
                    isFirstResponder: $viewModel.isAddressBarFocused,
                    selectAllOnFocus: true,
                    keyboardType: .webSearch,
                    onSubmit: { viewModel.submitAddressBar() }
                )
                .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                .layoutPriority(1)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 16, height: 16)

                    Text(displayText)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(displayTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)
            }

            trailingButton
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
        .background {
            Capsule(style: .continuous)
                .fill(
                    viewModel.isAddressBarFocused
                        ? Color(UIColor.systemBackground).opacity(0.52)
                        : Color(UIColor.secondarySystemBackground).opacity(0.58)
                )
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    viewModel.isAddressBarFocused
                        ? Color(UIColor.label).opacity(0.14)
                        : Color(UIColor.separator).opacity(0.34),
                    lineWidth: viewModel.isAddressBarFocused ? 1 : 0.5
                )
        }
        .shadow(
            color: viewModel.isAddressBarFocused ? Color.black.opacity(0.10) : Color.black.opacity(0.06),
            radius: viewModel.isAddressBarFocused ? 14 : 8,
            y: viewModel.isAddressBarFocused ? 5 : 2
        )
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            if !viewModel.isAddressBarFocused {
                viewModel.syncAddressBarWithActiveTab()
                viewModel.isAddressBarFocused = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { v in
                    guard viewModel.isAddressBarFocused == false else { return }

                    let dx = v.translation.width
                    let dy = v.translation.height
                    guard abs(dx) > 10, abs(dx) > abs(dy) * 2.0 else { return }

                    let dir: CGFloat = dx > 0 ? 1 : -1
                    if !isTabSwipeGestureActive {
                        isTabSwipeGestureActive = true
                        viewModel.beginTabSwipe(direction: dir)
                    }
                    viewModel.updateTabSwipe(translationX: dx)
                }
                .onEnded { v in
                    defer {
                        isTabSwipeGestureActive = false
                    }
                    guard viewModel.isAddressBarFocused == false else { return }

                    let dx = v.translation.width
                    let dy = v.translation.height
                    guard abs(dx) > 30, abs(dx) > abs(dy) * 2.0 else {
                        if viewModel.isTabSwipeActive {
                            viewModel.completeTabSwipe(commit: false, width: UIScreen.main.bounds.width)
                        }
                        return
                    }

                    let predicted = v.predictedEndTranslation.width
                    let commit = abs(predicted) > 120 || abs(dx) > 120
                    viewModel.completeTabSwipe(commit: commit, width: UIScreen.main.bounds.width)
                }
        )
        .onChange(of: viewModel.isAddressBarFocused) { _, newValue in
            if !newValue { viewModel.searchService.clearSearchSuggestions() }
        }
        .onChange(of: viewModel.addressBarText) { _, newText in
            viewModel.searchService.fetchSearchSuggestions(for: newText, isFocused: viewModel.isAddressBarFocused)
        }
        .onAppear {
            if viewModel.isAddressBarFocused {
                viewModel.searchService.fetchSearchSuggestions(for: viewModel.addressBarText, isFocused: viewModel.isAddressBarFocused)
            }
        }
        .animation(AeroAnimation.quick, value: viewModel.isAddressBarFocused)
        .animation(AeroAnimation.quick, value: viewModel.addressBarText.isEmpty)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if viewModel.isAddressBarFocused {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.addressBarText = ""
                viewModel.searchService.clearSearchSuggestions()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(viewModel.addressBarText.isEmpty ? 0 : 1)
            .disabled(viewModel.addressBarText.isEmpty)
            .accessibilityLabel("Clear address")
        } else if viewModel.activeTab?.isLoading == true {
            Button { viewModel.stopLoading() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop loading")
        } else if viewModel.activeTab?.displayURL != nil {
            Button { viewModel.reload() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reload")
        }
    }

    private var displayText: String {
        if let url = viewModel.activeTab?.displayURL {
            return url.displayHost ?? url.absoluteString
        }
        return "Search or enter URL"
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if viewModel.isAddressBarFocused {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(UIColor.secondaryLabel))
                .frame(width: 30, height: 30)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                shareCurrentPage()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeTab?.displayURL == nil)
            .opacity(viewModel.activeTab?.displayURL == nil ? 0.35 : 1.0)
            .accessibilityLabel("Share")
        }
    }

    private var displayTextColor: Color {
        viewModel.activeTab?.displayURL != nil ? Color(UIColor.label) : Color(UIColor.placeholderText)
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

    private func shareCurrentPage() {
        guard let url = viewModel.activeTab?.url else { return }
        SharePresenter.present(items: [url])
    }
}
