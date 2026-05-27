import SwiftUI

struct DownloadToastView: View {
    let filename: String
    let onShowDownloads: () -> Void

    var body: some View {
        HStack(spacing: AeroSpacing.md) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Download started")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                Text(filename)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("View") { onShowDownloads() }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, AeroSpacing.lg)
        .padding(.vertical, AeroSpacing.md)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.6)
        )
        .padding(.horizontal, AeroSpacing.lg)
    }
}

