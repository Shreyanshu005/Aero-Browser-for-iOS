






import SwiftUI

struct TabCardView: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let snapshot = tab.snapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(UIColor.tertiarySystemFill)
                            .overlay {
                                Image(systemName: "globe")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(height: 150)
                .clipped()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .padding(6)
            }

            HStack(spacing: 6) {
                Text(tab.displayTitle)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isActive ? Color(UIColor.label) : Color(UIColor.separator),
                    lineWidth: isActive ? 2.5 : 0.5
                )
        )
        .onTapGesture { onSelect() }
    }
}
