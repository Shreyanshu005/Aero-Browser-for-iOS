






import SwiftUI

struct AddressBar: View {
    @Bindable var viewModel: BrowserViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)

            if viewModel.isAddressBarFocused {
                TextField("Search or enter URL", text: $viewModel.addressBarText)
                    .font(.system(.body, design: .default))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($isFocused)
                    .onSubmit {
                        viewModel.submitAddressBar()
                    }
            } else {
                Text(displayText)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(displayTextColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if viewModel.isAddressBarFocused && !viewModel.addressBarText.isEmpty {
                Button {
                    viewModel.addressBarText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if !viewModel.isAddressBarFocused {
                viewModel.syncAddressBarWithActiveTab()
                viewModel.isAddressBarFocused = true
            }
        }
        .onChange(of: viewModel.isAddressBarFocused) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue { viewModel.isAddressBarFocused = false }
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
