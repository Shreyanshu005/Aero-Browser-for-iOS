import SwiftUI

struct SearchSuggestionsListView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader

            ForEach(viewModel.searchSuggestions.indices, id: \.self) { index in
                suggestionRow(viewModel.searchSuggestions[index])

                if index < viewModel.searchSuggestions.count - 1 {
                    Divider()
                        .overlay(Color(UIColor.separator).opacity(0.28))
                        .padding(.leading, 56)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous)
                .strokeBorder(Color(UIColor.separator).opacity(0.28), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 5)
    }

    private var sectionHeader: some View {
        HStack(spacing: AeroSpacing.sm) {
            Text(sectionTitle)
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .lineLimit(1)

            Spacer(minLength: AeroSpacing.sm)

            Image(systemName: viewModel.searchEngine.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AeroColor.textTertiary)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.top, AeroSpacing.sm)
        .padding(.bottom, AeroSpacing.xs)
    }

    private func suggestionRow(_ suggestion: String) -> some View {
        HStack(spacing: AeroSpacing.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.navigateToSearchSuggestion(suggestion)
            } label: {
                HStack(spacing: AeroSpacing.md) {
                    Image(systemName: iconName(for: suggestion))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.secondarySystemFill).opacity(0.75), in: Circle())

                    Text(suggestion)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(AeroColor.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.fillAddressBar(with: suggestion)
            } label: {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .frame(width: 36, height: 36)
                    .background(Color(UIColor.secondarySystemFill).opacity(0.65), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fill address bar")
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.vertical, 7)
        .frame(minHeight: 54)
    }

    private func iconName(for suggestion: String) -> String {
        viewModel.recentSearches.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame })
            ? "clock"
            : "magnifyingglass"
    }

    private var sectionTitle: String {
        viewModel.addressBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Recent Searches"
            : "Search Suggestions"
    }
}
