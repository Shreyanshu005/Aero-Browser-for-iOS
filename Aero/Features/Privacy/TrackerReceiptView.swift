import SwiftUI

struct TrackerReceiptView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    private var siteStatus: SiteStatus {
        viewModel.activeTab?.siteStatus ?? SiteStatus(contentBlockerEnabled: viewModel.contentBlockerEnabled)
    }

    private var securitySummary: SecuritySummary {
        viewModel.activeTab?.securitySummary ?? SecuritySummary(url: viewModel.activeTab?.displayURL)
    }

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
                        connectionCard
                        siteControlsSection
                        permissionsSection
                        trackersSection
                        blockerStatus
                    }
                    .padding(AeroSpacing.lg)
                }
            }
            .navigationTitle("Site Status")
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
                    .fill(viewModel.contentBlockerEnabled ? AeroColor.success.opacity(0.15) : AeroColor.warning.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: viewModel.contentBlockerEnabled ? "shield.checkered" : "shield.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(viewModel.contentBlockerEnabled ? AeroColor.success : AeroColor.warning)
            }

            Text(viewModel.contentBlockerEnabled ? "Protection Active" : "Protection Disabled")
                .font(AeroFont.title)
                .foregroundStyle(AeroColor.textPrimary)

            Text(siteStatus.displayHost)
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textSecondary)
        }
        .padding(.vertical, AeroSpacing.lg)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Text("CONNECTION")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(1.0)

            VStack(alignment: .leading, spacing: AeroSpacing.md) {
                HStack(alignment: .top, spacing: AeroSpacing.md) {
                    Image(systemName: securityIconName(for: securitySummary.status))
                        .font(.system(size: 20))
                        .foregroundStyle(securityColor(for: securitySummary.status))
                        .frame(width: 32, height: 32)
                        .background(securityColor(for: securitySummary.status).opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                        Text(securitySummary.title)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)

                        Text(securitySummary.explanation)
                            .font(AeroFont.captionSmall)
                            .foregroundStyle(AeroColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Divider()

                VStack(spacing: AeroSpacing.sm) {
                    ForEach(securitySummary.detailRows) { row in
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

    private var siteControlsSection: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Text("SITE STATUS")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(1.0)

            statusRow(
                icon: "globe",
                title: "Site",
                value: siteStatus.displayHost,
                detail: viewModel.activeTab?.displayURL?.absoluteString ?? "No page loaded",
                color: AeroColor.accentBlue
            )

            statusRow(
                icon: "shield.fill",
                title: "Content Blocker",
                value: contentBlockerValue,
                detail: contentBlockerDetail,
                color: siteStatus.contentBlocker == .enabled ? AeroColor.success : AeroColor.warning
            )
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.md) {
            Text("SITE PERMISSIONS")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(1.0)

            ForEach(siteStatus.permissions) { permission in
                statusRow(
                    icon: permissionIcon(for: permission.kind),
                    title: permissionTitle(for: permission.kind),
                    value: dispositionTitle(for: permission.disposition),
                    detail: permissionDetail(for: permission),
                    color: dispositionColor(for: permission.disposition)
                )
            }
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

    private func statusRow(
        icon: String,
        title: String,
        value: String,
        detail: String,
        color: Color
    ) -> some View {
        HStack(spacing: AeroSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AeroSpacing.sm) {
                    Text(title)
                        .font(AeroFont.body)
                        .foregroundStyle(AeroColor.textPrimary)

                    Spacer(minLength: AeroSpacing.sm)

                    Text(value)
                        .font(AeroFont.caption)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }

                Text(detail)
                    .font(AeroFont.captionSmall)
                    .foregroundStyle(AeroColor.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(AeroSpacing.md)
        .background(AeroColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: AeroRadius.md))
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

    private var contentBlockerValue: String {
        switch siteStatus.contentBlocker {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        }
    }

    private var contentBlockerDetail: String {
        switch siteStatus.contentBlocker {
        case .enabled:
            return "Aero's tracker protection toggle is on"
        case .disabled:
            return "Aero's tracker protection toggle is off"
        }
    }

    private func permissionIcon(for kind: SitePermissionKind) -> String {
        switch kind {
        case .camera:
            return "camera.fill"
        case .microphone:
            return "mic.fill"
        case .location:
            return "location.fill"
        case .popups:
            return "rectangle.on.rectangle"
        }
    }

    private func permissionTitle(for kind: SitePermissionKind) -> String {
        switch kind {
        case .camera:
            return "Camera"
        case .microphone:
            return "Microphone"
        case .location:
            return "Location"
        case .popups:
            return "Popups"
        }
    }

    private func dispositionTitle(for disposition: SitePermissionDisposition) -> String {
        switch disposition {
        case .default:
            return "Default"
        case .ask:
            return "Ask"
        case .unsupported:
            return "Unsupported"
        }
    }

    private func dispositionColor(for disposition: SitePermissionDisposition) -> Color {
        switch disposition {
        case .default:
            return AeroColor.accentBlue
        case .ask:
            return AeroColor.warning
        case .unsupported:
            return AeroColor.textTertiary
        }
    }

    private func permissionDetail(for permission: SitePermissionStatus) -> String {
        switch permission.kind {
        case .camera:
            return permission.wasObservedThisSession
                ? "This site requested camera access during this session"
                : "WebKit will show a system prompt when this site asks"
        case .microphone:
            return permission.wasObservedThisSession
                ? "This site requested microphone access during this session"
                : "WebKit will show a system prompt when this site asks"
        case .location:
            return "Aero does not manage website location permission yet"
        case .popups:
            return permission.wasObservedThisSession
                ? "This site attempted a new window; Aero opened it here"
                : "New-window requests use Aero's default handling"
        }
    }
}
