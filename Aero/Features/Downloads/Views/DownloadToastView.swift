import SwiftUI

struct DownloadToastView: View {
    private let filename: String
    private let status: DownloadToastStatus
    let onShowDownloads: () -> Void

    init(filename: DownloadToastPresentation, onShowDownloads: @escaping () -> Void) {
        self.filename = filename.filename
        self.status = filename.status
        self.onShowDownloads = onShowDownloads
    }

    init(filename: String, onShowDownloads: @escaping () -> Void) {
        self.filename = filename
        self.status = .started
        self.onShowDownloads = onShowDownloads
    }

    var body: some View {
        HStack(spacing: AeroSpacing.md) {
            Image(systemName: status.iconName)
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(status.tint)
                .frame(width: 36, height: 36)
                .background(status.tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(1)

                Text(filename)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button {
                onShowDownloads()
            } label: {
                Text("View")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: 58, height: 34)
            }
            .buttonStyle(.plain)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(UIColor.separator).opacity(0.35), lineWidth: 0.6)
            )
        }
        .padding(.leading, AeroSpacing.md)
        .padding(.trailing, AeroSpacing.sm)
        .padding(.vertical, AeroSpacing.sm)
        .frame(maxWidth: 520, minHeight: 64)
        .downloadToastGlass(in: RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous)
                .strokeBorder(Color(UIColor.separator).opacity(0.42), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
        .padding(.horizontal, AeroSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

private extension DownloadToastStatus {
    var title: String {
        switch self {
        case .started:
            return "Download started"
        case .completed:
            return "Download completed"
        case .failed:
            return "Download failed"
        }
    }

    var iconName: String {
        switch self {
        case .started:
            return "arrow.down.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .started:
            return Color(UIColor.systemBlue)
        case .completed:
            return AeroColor.success
        case .failed:
            return AeroColor.error
        }
    }
}

private extension View {
    @ViewBuilder
    func downloadToastGlass<S: Shape>(in shape: S) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(true), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
#else
        self.background(.ultraThinMaterial, in: shape)
#endif
    }
}
