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
                    VStack(spacing: AeroSpacing.lg) {
                        siteHeader
                        connectionSection
                        permissionsSection
                        contentBlockerSection
                        trackerCategoriesSection
                    }
                    .padding(.horizontal, AeroSpacing.lg)
                    .padding(.vertical, AeroSpacing.md)
                }
            }
            .navigationTitle("Site Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(AeroColor.accentTint)
                }
            }
        }
    }

    private var siteHeader: some View {
        statusPanel(spacing: AeroSpacing.lg) {
            HStack(alignment: .center, spacing: AeroSpacing.md) {
                ZStack {
                    Circle()
                        .fill(currentSecurityColor.opacity(0.16))
                        .frame(width: 64, height: 64)

                    Image(systemName: securityIconName(for: securitySummary.status))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(currentSecurityColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                    Text(securitySummary.title)
                        .font(AeroFont.title)
                        .foregroundStyle(AeroColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(siteStatus.displayHost)
                        .font(AeroFont.body)
                        .foregroundStyle(AeroColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(securitySummary.explanation)
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AeroSpacing.sm) {
                    statusChip(
                        icon: securityIconName(for: securitySummary.status),
                        text: connectionChipTitle,
                        color: currentSecurityColor
                    )
                    statusChip(
                        icon: siteStatus.contentBlocker == .enabled ? "shield.checkered" : "shield.slash",
                        text: contentBlockerValue,
                        color: contentBlockerColor
                    )
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: AeroSpacing.sm) {
                    statusChip(
                        icon: securityIconName(for: securitySummary.status),
                        text: connectionChipTitle,
                        color: currentSecurityColor
                    )
                    statusChip(
                        icon: siteStatus.contentBlocker == .enabled ? "shield.checkered" : "shield.slash",
                        text: contentBlockerValue,
                        color: contentBlockerColor
                    )
                }
            }
        }
    }

    private var connectionSection: some View {
        section("Connection & Certificate") {
            VStack(spacing: 0) {
                infoRow(
                    icon: "globe",
                    title: "Host",
                    value: securitySummary.host,
                    detail: activePageDetail,
                    color: AeroColor.accentBlue
                )

                rowDivider

                infoRow(
                    icon: securityIconName(for: securitySummary.status),
                    title: "Connection",
                    value: connectionValue,
                    detail: securitySummary.explanation,
                    color: currentSecurityColor
                )

                rowDivider

                infoRow(
                    icon: "checkmark.seal.fill",
                    title: "Certificate",
                    value: securitySummary.certificateStatus,
                    detail: certificateDetail,
                    color: certificateColor
                )

                if let fingerprint = securitySummary.certificateSummary?.shortFingerprint {
                    rowDivider

                    infoRow(
                        icon: "number",
                        title: "SHA-256",
                        value: fingerprint,
                        detail: "Leaf certificate fingerprint",
                        color: AeroColor.textSecondary
                    )
                }
            }
            .statusPanelPadding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous))
            .overlay(cardStroke(cornerRadius: AeroRadius.md))
        }
    }

    private var permissionsSection: some View {
        section("Site Permissions") {
            VStack(spacing: 0) {
                ForEach(siteStatus.permissions) { permission in
                    permissionRow(permission)

                    if permission.id != siteStatus.permissions.last?.id {
                        rowDivider
                    }
                }
            }
            .statusPanelPadding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous))
            .overlay(cardStroke(cornerRadius: AeroRadius.md))
        }
    }

    private var contentBlockerSection: some View {
        section("Content Blocker") {
            Toggle(isOn: $viewModel.contentBlockerEnabled) {
                HStack(alignment: .top, spacing: AeroSpacing.md) {
                    symbolTile(
                        icon: siteStatus.contentBlocker == .enabled ? "shield.checkered" : "shield.slash",
                        color: contentBlockerColor
                    )

                    VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                        Text(contentBlockerValue)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        Text(contentBlockerDetail)
                            .font(AeroFont.captionSmall)
                            .foregroundStyle(AeroColor.textTertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(AeroColor.accentTint)
            .padding(AeroSpacing.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous))
            .overlay(cardStroke(cornerRadius: AeroRadius.md))
        }
    }

    private var trackerCategoriesSection: some View {
        section("Tracker Categories") {
            VStack(spacing: AeroSpacing.sm) {
                ForEach(trackerCategories, id: \.name) { category in
                    HStack(alignment: .top, spacing: AeroSpacing.md) {
                        symbolTile(icon: category.icon, color: category.color)

                        VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                            Text(category.name)
                                .font(AeroFont.body)
                                .foregroundStyle(AeroColor.textPrimary)
                                .lineLimit(1)

                            Text("\(category.domains.count) known domains")
                                .font(AeroFont.captionSmall)
                                .foregroundStyle(AeroColor.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: AeroSpacing.sm)

                        Image(systemName: viewModel.contentBlockerEnabled ? "checkmark.shield.fill" : "xmark.shield")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(viewModel.contentBlockerEnabled ? AeroColor.success : AeroColor.textTertiary)
                            .frame(width: 28, height: 28)
                            .accessibilityLabel(viewModel.contentBlockerEnabled ? "Blocked" : "Not blocked")
                    }
                    .padding(AeroSpacing.md)
                    .background(AeroColor.backgroundSecondary.opacity(0.72), in: RoundedRectangle(cornerRadius: AeroRadius.sm, style: .continuous))
                    .overlay(cardStroke(cornerRadius: AeroRadius.sm, opacity: 0.18))
                }
            }
        }
    }

    private func permissionRow(_ permission: SitePermissionStatus) -> some View {
        HStack(alignment: .top, spacing: AeroSpacing.md) {
            symbolTile(
                icon: permissionIcon(for: permission.kind),
                color: dispositionColor(for: permission.disposition)
            )

            VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AeroSpacing.sm) {
                        Text(permissionTitle(for: permission.kind))
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: AeroSpacing.sm)

                        pill(
                            dispositionTitle(for: permission.disposition),
                            color: dispositionColor(for: permission.disposition)
                        )
                    }

                    VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                        Text(permissionTitle(for: permission.kind))
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        pill(
                            dispositionTitle(for: permission.disposition),
                            color: dispositionColor(for: permission.disposition)
                        )
                    }
                }

                Text(permissionDetail(for: permission))
                    .font(AeroFont.captionSmall)
                    .foregroundStyle(AeroColor.textTertiary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AeroSpacing.md)
    }

    private func infoRow(
        icon: String,
        title: String,
        value: String,
        detail: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: AeroSpacing.md) {
            symbolTile(icon: icon, color: color)

            VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AeroSpacing.sm) {
                        Text(title)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: AeroSpacing.sm)

                        Text(value)
                            .font(AeroFont.caption)
                            .foregroundStyle(color)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                        Text(title)
                            .font(AeroFont.body)
                            .foregroundStyle(AeroColor.textPrimary)
                            .lineLimit(1)

                        Text(value)
                            .font(AeroFont.caption)
                            .foregroundStyle(color)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                    }
                }

                Text(detail)
                    .font(AeroFont.captionSmall)
                    .foregroundStyle(AeroColor.textTertiary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AeroSpacing.md)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            Text(title.uppercased())
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
                .tracking(0.8)
                .lineLimit(1)

            content()
        }
    }

    private func statusPanel<Content: View>(
        spacing: CGFloat = AeroSpacing.md,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(AeroSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous))
        .overlay(cardStroke(cornerRadius: AeroRadius.lg, opacity: 0.32))
    }

    private func symbolTile(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: AeroRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }

    private func statusChip(icon: String, text: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(AeroFont.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, AeroSpacing.sm)
        .padding(.vertical, AeroSpacing.xs)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.24), lineWidth: 0.5)
        )
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AeroFont.captionSmall)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, AeroSpacing.sm)
            .padding(.vertical, AeroSpacing.xs)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.24), lineWidth: 0.5)
            )
    }

    private func cardStroke(cornerRadius: CGFloat, opacity: Double = 0.24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(AeroColor.surfaceBorder.opacity(opacity), lineWidth: 0.5)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 46)
            .opacity(0.42)
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

    private var currentSecurityColor: Color {
        securityColor(for: securitySummary.status)
    }

    private var certificateColor: Color {
        guard securitySummary.isHTTPS else { return AeroColor.textTertiary }
        return securitySummary.certificateSummary == nil ? AeroColor.warning : AeroColor.success
    }

    private var certificateDetail: String {
        guard securitySummary.isHTTPS else {
            return "Certificate details do not apply to this page."
        }

        guard let certificateSummary = securitySummary.certificateSummary else {
            return "Aero has not received a matching server certificate summary for this page."
        }

        return "\(certificateSummary.certificateCount) certificate\(certificateSummary.certificateCount == 1 ? "" : "s") in the verified server chain."
    }

    private var activePageDetail: String {
        viewModel.activeTab?.displayURL?.absoluteString ?? "No page loaded"
    }

    private var connectionChipTitle: String {
        switch securitySummary.status {
        case .secureHTTPS:
            return "HTTPS"
        case .insecureHTTP:
            return "HTTP"
        case .browserPage:
            return "Local"
        case .noPage:
            return "No Page"
        case .nonWebScheme:
            return securitySummary.scheme
        }
    }

    private var connectionValue: String {
        switch securitySummary.status {
        case .secureHTTPS:
            return "Encrypted"
        case .insecureHTTP:
            return "Not secure"
        case .browserPage:
            return "Local page"
        case .noPage:
            return "Unavailable"
        case .nonWebScheme:
            return securitySummary.scheme
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

    private var contentBlockerColor: Color {
        switch siteStatus.contentBlocker {
        case .enabled:
            return AeroColor.success
        case .disabled:
            return AeroColor.warning
        }
    }

    private var contentBlockerDetail: String {
        switch siteStatus.contentBlocker {
        case .enabled:
            return "Aero's tracker protection toggle is on."
        case .disabled:
            return "Aero's tracker protection toggle is off."
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
                ? "This site requested camera access during this session."
                : "WebKit will show a system prompt when this site asks."
        case .microphone:
            return permission.wasObservedThisSession
                ? "This site requested microphone access during this session."
                : "WebKit will show a system prompt when this site asks."
        case .location:
            return "Aero does not manage website location permission yet."
        case .popups:
            return permission.wasObservedThisSession
                ? "This site attempted a new window; Aero opened it here."
                : "New-window requests use Aero's default handling."
        }
    }
}

private extension View {
    func statusPanelPadding() -> some View {
        padding(.horizontal, AeroSpacing.md)
    }
}
