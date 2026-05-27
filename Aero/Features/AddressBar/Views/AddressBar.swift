






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
                .frame(height: 22)
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 6) {
                    if viewModel.activeTab?.isSecure == true {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AeroColor.secure)
                    }

                    Text(displayText)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(displayTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            trailingButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
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
            }
            .buttonStyle(.plain)
            .opacity(viewModel.addressBarText.isEmpty ? 0 : 1)
            .disabled(viewModel.addressBarText.isEmpty)
        } else if viewModel.activeTab?.isLoading == true {
            Button { viewModel.stopLoading() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.activeTab?.url != nil {
            Button { viewModel.reload() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var displayText: String {
        if let url = viewModel.activeTab?.url {
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
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                shareCurrentPage()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeTab?.url == nil)
            .opacity(viewModel.activeTab?.url == nil ? 0.35 : 1.0)
        }
    }

    private var displayTextColor: Color {
        viewModel.activeTab?.url != nil ? .white : Color.white.opacity(0.55)
    }

    private func shareCurrentPage() {
        guard let url = viewModel.activeTab?.url else { return }
        SharePresenter.present(items: [url])
    }
}
