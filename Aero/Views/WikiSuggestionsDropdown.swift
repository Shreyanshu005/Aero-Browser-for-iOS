import SwiftUI

struct WikiSuggestionsDropdown: View {
    let suggestions: [WikiSuggestion]
    let onSelect: (WikiSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: AeroSpacing.md) {
                        Image(systemName: "w.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(UIColor.secondaryLabel))

                        VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                            Text(suggestion.title)
                                .font(AeroFont.body)
                                .foregroundStyle(AeroColor.textPrimary)
                                .lineLimit(1)

                            if !suggestion.summary.isEmpty {
                                Text(suggestion.summary)
                                    .font(AeroFont.captionSmall)
                                    .foregroundStyle(AeroColor.textTertiary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AeroSpacing.md)
                    .padding(.vertical, AeroSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.last?.id {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AeroRadius.md)
                .strokeBorder(Color(UIColor.separator).opacity(0.35), lineWidth: 0.5)
        )
    }
}
