import SwiftUI

struct SuggestionsDropdown: View {
    let suggestions: [BrowserSuggestion]
    let onSelect: (BrowserSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader

            ForEach(suggestions.indices, id: \.self) { index in
                suggestionRow(suggestions[index])

                if index < suggestions.count - 1 {
                    Divider()
                        .overlay(Color(UIColor.separator).opacity(0.28))
                        .padding(.leading, 56)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous)
                .strokeBorder(Color(UIColor.separator).opacity(0.28), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 5)
    }

    private var sectionHeader: some View {
        HStack(spacing: AeroSpacing.sm) {
            Text("Pages")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .lineLimit(1)

            Spacer(minLength: AeroSpacing.sm)

            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AeroColor.textTertiary)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.top, AeroSpacing.sm)
        .padding(.bottom, AeroSpacing.xs)
    }

    private func suggestionRow(_ suggestion: BrowserSuggestion) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(suggestion)
        } label: {
            HStack(spacing: AeroSpacing.md) {
                Image(systemName: suggestion.kind.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor(for: suggestion.kind))
                    .frame(width: 32, height: 32)
                    .background(iconBackground(for: suggestion.kind), in: Circle())

                VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                    Text(suggestion.title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(AeroColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(AeroFont.captionSmall)
                            .foregroundStyle(AeroColor.textTertiary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, AeroSpacing.md)
            .padding(.vertical, 7)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconColor(for kind: BrowserSuggestion.Kind) -> Color {
        switch kind {
        case .tab:
            return Color(UIColor.systemBlue)
        case .favorite:
            return Color(UIColor.systemOrange)
        case .history:
            return Color(UIColor.secondaryLabel)
        }
    }

    private func iconBackground(for kind: BrowserSuggestion.Kind) -> Color {
        switch kind {
        case .tab:
            return Color(UIColor.systemBlue).opacity(0.13)
        case .favorite:
            return Color(UIColor.systemOrange).opacity(0.14)
        case .history:
            return Color(UIColor.secondarySystemFill).opacity(0.75)
        }
    }
}
