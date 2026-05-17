






import SwiftUI

struct AddressBar: View {
    @Bindable var viewModel: BrowserViewModel
    @FocusState private var isFocused: Bool

    @State private var isTabSwipeGestureActive = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)

            if viewModel.isAddressBarFocused {
                SelectableTextField(
                    placeholder: "Search or enter URL",
                    text: $viewModel.addressBarText,
                    isFirstResponder: $isFocused,
                    selectAllOnFocus: true,
                    keyboardType: .webSearch,
                    onSubmit: { viewModel.submitAddressBar() }
                )
                .frame(height: 22)
            } else {
                Text(displayText)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(displayTextColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if viewModel.activeTab?.isLoading == true {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
            isFocused = newValue
            if !newValue { viewModel.clearWikiSuggestions() }
        }
        .onChange(of: viewModel.addressBarText) { _, newText in
            viewModel.fetchWikiSuggestions(for: newText)
        }
    }

    private var displayText: String {
        if let url = viewModel.activeTab?.url {
            return url.displayHost ?? url.absoluteString
        }
        return "Search or enter URL"
    }

    private var displayTextColor: Color {
        viewModel.activeTab?.url != nil ? Color(UIColor.label) : Color(UIColor.placeholderText)
    }

    private var iconName: String {
        if viewModel.isAddressBarFocused { return "magnifyingglass" }
        if viewModel.activeTab?.isSecure == true { return "lock.fill" }
        if viewModel.activeTab?.url != nil { return "globe" }
        return "magnifyingglass"
    }

    private var iconColor: Color {
        if viewModel.activeTab?.isSecure == true { return .green }
        return Color(UIColor.secondaryLabel)
    }
}
