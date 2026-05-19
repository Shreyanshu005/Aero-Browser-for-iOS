import SwiftUI

struct SearchSuggestionsDropdown: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: AeroSpacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(UIColor.secondaryLabel))

                        Text(suggestion)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AeroSpacing.md)
                    .padding(.vertical, AeroSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion != suggestions.last {
                    Divider()
                        .padding(.leading, 44)
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

