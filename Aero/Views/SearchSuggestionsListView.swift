import SwiftUI

struct SearchSuggestionsListView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                HStack(spacing: AeroSpacing.md) {
                    Image(systemName: iconName(for: suggestion))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.navigateToSearchSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.fillAddressBar(with: suggestion)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())

                if suggestion != viewModel.searchSuggestions.last {
                    Divider()
                        .overlay(Color.white.opacity(0.14))
                }
            }
        }
    }

    private func iconName(for suggestion: String) -> String {
        viewModel.recentSearches.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame })
            ? "clock"
            : "magnifyingglass"
    }
}
