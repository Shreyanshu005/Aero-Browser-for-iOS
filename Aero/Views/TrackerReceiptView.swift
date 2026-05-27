






import SwiftUI

struct TrackerReceiptView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss


    private let trackerCategories: [(name: String, icon: String, domains: [String], color: Color)] = [
        ("Advertising", "megaphone.fill", ["doubleclick.net", "googlesyndication.com", "googleadservices.com", "ads.yahoo.com"], AeroColor.error),
        ("Analytics", "chart.bar.fill", ["google-analytics.com", "analytics.google.com", "hotjar.com", "mixpanel.com"], AeroColor.warning),
        ("Social", "person.2.fill", ["facebook.net", "connect.facebook.net", "platform.twitter.com"], AeroColor.accentBlue),
        ("Fingerprinting", "hand.raised.fill", ["fingerprint.com", "canvas-fingerprint.com"], Color(hex: 0x8B5CF6)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AeroColor.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AeroSpacing.xl) {

                        shieldHeader


                        securityCard


                        trackersSection


                        blockerStatus
                    }
                    .padding(AeroSpacing.lg)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AeroColor.accentCyan)
                }
            }
        }
    }



    private var shieldHeader: some View {
        VStack(spacing: AeroSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        viewModel.contentBlockerEnabled
                            ? AeroColor.success.opacity(0.15)
                            : AeroColor.warning.opacity(0.15)
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: viewModel.contentBlockerEnabled ? "shield.checkered" : "shield.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(viewModel.contentBlockerEnabled ? AeroColor.success : AeroColor.warning)
            }

            Text(viewModel.contentBlockerEnabled ? "Protection Active" : "Protection Disabled")
                .font(AeroFont.title)
                .foregroundStyle(AeroColor.textPrimary)

            if let host = viewModel.activeTab?.url?.displayHost {
                Text(host)
                    .font(AeroFont.caption)
                    .foregroundStyle(AeroColor.textSecondary)
            }
        }
        .padding(.vertical, AeroSpacing.lg)
    }



    private var securityCard: some View {
        let summary = viewModel.activeTab?.securitySummary ?? SecuritySummary(url: nil)

        return VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Text("CONNECTION")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(1.0)

            VStack(alignment: .leading, spacing: AeroSpacing.md) {
                HStack(alignment: .top, spacing: AeroSpacing.md) {
                    Image(systemName: securityIconName(for: summary.status))
                        .font(.system(size: 20))
                        .foregroundStyle(securityColor(for: summary.status))
                        .frame(width: 32, height: 32)
                        .background(
                            securityColor(for: summary.status).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 8)
                        )

                    VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                        Text(summary.title)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)

                        Text(summary.explanation)
                            .font(AeroFont.captionSmall)
                            .foregroundStyle(AeroColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Divider()

                VStack(spacing: AeroSpacing.sm) {
                    ForEach(summary.detailRows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: AeroSpacing.md) {
                            Text(row.label)
                                .font(AeroFont.captionSmall)
                                .foregroundStyle(AeroColor.textTertiary)

                            Spacer(minLength: AeroSpacing.md)

                            Text(row.value)
                                .font(AeroFont.captionSmall)
                                .foregroundStyle(AeroColor.textPrimary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
            }
            .padding(AeroSpacing.lg)
            .background(AeroColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: AeroRadius.md))
        }
    }



    private func securityIconName(for status: SecuritySummary.Status) -> String {
        switch status {
        case .secureHTTPS:
            return "lock.fill"
        case .insecureHTTP:
            return "lock.open.fill"
        case .browserPage:
            return "app.fill"
        case .noPage, .nonWebScheme:
            return "info.circle.fill"
        }
    }



    private func securityColor(for status: SecuritySummary.Status) -> Color {
        switch status {
        case .secureHTTPS:
            return AeroColor.success
        case .insecureHTTP:
            return AeroColor.error
        case .browserPage:
            return AeroColor.accentBlue
        case .noPage, .nonWebScheme:
            return AeroColor.warning
        }
    }



    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Text("TRACKER CATEGORIES")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(1.0)

            ForEach(trackerCategories, id: \.name) { category in
                HStack(spacing: AeroSpacing.md) {
                    Image(systemName: category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(category.color)
                        .frame(width: 32, height: 32)
                        .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)

                        Text("\(category.domains.count) known domains")
                            .font(AeroFont.captionSmall)
                            .foregroundStyle(AeroColor.textTertiary)
                    }

                    Spacer()

                    Image(systemName: viewModel.contentBlockerEnabled ? "checkmark.shield.fill" : "xmark.shield")
                        .foregroundStyle(viewModel.contentBlockerEnabled ? AeroColor.success : AeroColor.textTertiary)
                }
                .padding(AeroSpacing.md)
                .background(AeroColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: AeroRadius.md))
            }
        }
    }



    private var blockerStatus: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Toggle(isOn: $viewModel.contentBlockerEnabled) {
                HStack(spacing: AeroSpacing.md) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(AeroColor.accentCyan)
                    Text("Content Blocker")
                        .font(AeroFont.body)
                        .foregroundStyle(AeroColor.textPrimary)
                }
            }
            .tint(AeroColor.accentCyan)
            .padding(AeroSpacing.lg)
            .background(AeroColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: AeroRadius.md))
        }
    }
}
