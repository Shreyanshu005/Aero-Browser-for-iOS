import SwiftUI

struct SearchSuggestionsListView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                HStack(spacing: AeroSpacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.navigateToSearchSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.fillAddressBar(with: suggestion)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())

                if suggestion != viewModel.searchSuggestions.last {
                    Divider()
                        .overlay(Color.white.opacity(0.12))
                }
            }
        }
    }
}

