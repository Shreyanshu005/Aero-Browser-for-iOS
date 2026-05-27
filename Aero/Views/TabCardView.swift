import SwiftUI

struct TabCardView: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isClosing = false

    private let closeThreshold: CGFloat = 90

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

                if tab.isPrivate {
                    Label("Private", systemImage: "eye.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

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
                if tab.isPrivate {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

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
        .offset(x: dragOffset.width)
        .rotationEffect(.degrees(Double(dragOffset.width) / 24))
        .scaleEffect(isClosing ? 0.86 : 1)
        .opacity(isClosing ? 0 : max(0.55, 1 - abs(dragOffset.width) / 260.0))
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: dragOffset)
        .animation(AeroAnimation.smooth, value: isClosing)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = CGSize(width: value.translation.width, height: 0)
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let predicted = value.predictedEndTranslation.width
                    if abs(horizontal) > closeThreshold || abs(predicted) > closeThreshold * 1.35 {
                        closeToward(horizontal == 0 ? predicted : horizontal)
                    } else {
                        dragOffset = .zero
                    }
                }
        )
        .onTapGesture {
            if abs(dragOffset.width) < 8 {
                onSelect()
            }
        }
    }

    private func closeToward(_ direction: CGFloat) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isClosing = true
        dragOffset = CGSize(width: direction >= 0 ? 420 : -420, height: 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onClose()
            dragOffset = .zero
            isClosing = false
        }
    }
}
