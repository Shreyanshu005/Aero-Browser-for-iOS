import SwiftUI
import UIKit

struct AgentChatPanelView: View {
    let viewModel: BrowserViewModel
    let engine: AgentRunEngine
    let pageTitle: String
    let pageSubtitle: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var draft = ""

    private let promptColumns = [
        GridItem(.adaptive(minimum: 148), spacing: AeroSpacing.sm, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, AeroSpacing.lg)
                .padding(.top, AeroSpacing.lg)
                .padding(.bottom, AeroSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: AeroSpacing.lg) {
                    pageContext
                    promptChips
                    transcriptSection
                    runLogSection
                }
                .padding(.horizontal, AeroSpacing.lg)
                .padding(.bottom, AeroSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            composer
                .padding(.horizontal, AeroSpacing.lg)
                .padding(.top, AeroSpacing.md)
                .padding(.bottom, AeroSpacing.lg)
                .background {
                    Rectangle()
                        .fill(Color(UIColor.systemBackground).opacity(0.26))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        .background(sheetBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("agent.chat.panel")
    }

    private var header: some View {
        HStack(spacing: AeroSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemBackground).opacity(0.28))
                    .aeroGlassSurface(style: .control, in: Circle())

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AeroColor.textPrimary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                Text("Agent")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AeroColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AeroSpacing.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)

                    Text(statusTitle)
                        .font(AeroFont.caption)
                        .foregroundStyle(AeroColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer(minLength: AeroSpacing.sm)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                clearConversation()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AeroColor.textPrimary)
            .accessibilityLabel("Clear")
            .accessibilityIdentifier("agent.chat.clear")

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AeroColor.textPrimary)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("agent.chat.close")
        }
    }

    private var pageContext: some View {
        AeroGlassPanel(style: .panel, cornerRadius: AeroRadius.lg) {
            HStack(spacing: AeroSpacing.md) {
                Image(systemName: "safari")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AeroColor.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                    Text(pageTitle)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AeroColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(pageSubtitle)
                        .font(AeroFont.caption)
                        .foregroundStyle(AeroColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: AeroSpacing.sm)
            }
            .padding(AeroSpacing.md)
        }
    }

    private var promptChips: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            AgentSectionHeader(title: "Suggestions")

            LazyVGrid(columns: promptColumns, alignment: .leading, spacing: AeroSpacing.sm) {
                ForEach(AgentPanelSampleData.suggestedPrompts) { prompt in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        draft = prompt.title
                        isInputFocused = true
                    } label: {
                        AgentPromptChipView(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("agent.chat.prompt.\(prompt.title)")
                }
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            AgentSectionHeader(title: "Transcript")

            if transcriptMessages.isEmpty {
                emptyTranscript
            } else {
                VStack(spacing: AeroSpacing.md) {
                    ForEach(transcriptMessages) { message in
                        AgentMessageBubble(message: message)
                    }
                }
            }
        }
    }

    private var emptyTranscript: some View {
        AeroGlassPanel(style: .panel, cornerRadius: AeroRadius.lg) {
            VStack(spacing: AeroSpacing.md) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 30, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AeroColor.textSecondary)

                VStack(spacing: AeroSpacing.xs) {
                    Text("Start with a browsing task")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AeroColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Use a suggestion or type what you want handled next.")
                        .font(AeroFont.caption)
                        .foregroundStyle(AeroColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AeroSpacing.xl)
            .padding(.horizontal, AeroSpacing.lg)
        }
        .accessibilityIdentifier("agent.chat.empty")
    }

    private var runLogSection: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            AgentSectionHeader(title: "Run Log") {
                statusPill
            }

            AeroGlassPanel(style: .panel, cornerRadius: AeroRadius.lg) {
                VStack(spacing: 0) {
                    if runLogItems.isEmpty {
                        Text("Waiting for a task. Timeline steps will appear here.")
                            .font(AeroFont.caption)
                            .foregroundStyle(AeroColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AeroSpacing.md)
                    } else {
                        ForEach(Array(runLogItems.enumerated()), id: \.element.id) { index, item in
                            AgentRunTimelineRow(
                                item: item,
                                isFirst: index == 0,
                                isLast: index == runLogItems.count - 1
                            )
                        }
                    }

                    if let pendingApproval = engine.session.pendingApproval {
                        approvalActions(pendingApproval)
                            .padding(.top, runLogItems.isEmpty ? 0 : AeroSpacing.sm)
                            .padding([.horizontal, .bottom], AeroSpacing.md)
                    } else if runState == .failed {
                        retryActions
                            .padding(.top, runLogItems.isEmpty ? 0 : AeroSpacing.sm)
                            .padding([.horizontal, .bottom], AeroSpacing.md)
                    }
                }
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: AeroSpacing.xs) {
            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .bold))

            Text(statusTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, AeroSpacing.sm)
        .padding(.vertical, AeroSpacing.xs)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    private func approvalActions(_ approval: AgentApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            HStack(alignment: .top, spacing: AeroSpacing.sm) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AeroColor.warning)
                    .frame(width: 30, height: 30)
                    .background(AeroColor.warning.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(approval.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AeroColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(approval.detail)
                        .font(AeroFont.caption)
                        .foregroundStyle(AeroColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: AeroSpacing.sm) {
                Spacer(minLength: 0)

                Button("Deny") {
                    declineApproval()
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Approve") {
                    approveAccess()
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .accessibilityIdentifier("agent.chat.approval")
    }

    private var retryActions: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            HStack(alignment: .top, spacing: AeroSpacing.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AeroColor.error)
                    .frame(width: 30, height: 30)
                    .background(AeroColor.error.opacity(0.14), in: Circle())

                Text("Retry the blocked step or start a new task.")
                    .font(AeroFont.caption)
                    .foregroundStyle(AeroColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: AeroSpacing.sm) {
                Spacer(minLength: 0)

                Button("Retry") {
                    retryRun()
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .accessibilityIdentifier("agent.chat.retry")
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: AeroSpacing.sm) {
            TextField("Ask Agent to browse...", text: $draft, axis: .vertical)
                .font(AeroFont.body)
                .lineLimit(1...3)
                .textInputAutocapitalization(.sentences)
                .focused($isInputFocused)
                .padding(.horizontal, AeroSpacing.md)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous)
                        .fill(Color(UIColor.systemBackground).opacity(0.42))
                        .aeroGlassSurface(style: .control,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7)
                }
                .accessibilityIdentifier("agent.chat.input")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                stopRun()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(stopButtonColor)
            .background {
                Circle()
                    .fill(Color(UIColor.systemBackground).opacity(0.34))
                    .aeroGlassSurface(style: .control, in: Circle())
            }
            .disabled(!canStop)
            .opacity(canStop ? 1 : 0.45)
            .accessibilityLabel("Stop")
            .accessibilityIdentifier("agent.chat.stop")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                sendDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(UIColor.systemBackground))
            .background {
                Circle()
                    .fill(canSend ? AeroColor.textPrimary : AeroColor.textTertiary)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("agent.chat.send")
        }
    }

    private var sheetBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            Color(UIColor.systemBackground)
                .opacity(0.18)
                .ignoresSafeArea()
        }
    }

    private var session: AgentRunSession {
        engine.session
    }

    private var runState: AgentPanelRunState {
        switch session.status {
        case .idle:
            return .ready
        case .running:
            return .running
        case .waitingForApproval:
            return .approvalNeeded
        case .stopped:
            return .stopped
        case .completed:
            return .completed
        case .failed:
            return .failed
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStop: Bool {
        session.status.isActive
    }

    private var transcriptMessages: [AgentPanelMessage] {
        var messages: [AgentPanelMessage] = []

        if !session.prompt.isEmpty {
            messages.append(
                AgentPanelMessage(
                    id: session.id,
                    role: .user,
                    text: session.prompt,
                    timestampLabel: timestampLabel(for: session.startedAt)
                )
            )
        }

        if let finalAnswer = session.finalAnswer {
            messages.append(
                AgentPanelMessage(
                    id: session.steps.first { $0.kind == .finalAnswer }?.id ?? session.id,
                    role: .agent,
                    text: finalAnswer,
                    timestampLabel: timestampLabel(for: session.endedAt ?? Date())
                )
            )
        }

        if let error = session.error {
            messages.append(
                AgentPanelMessage(
                    id: session.steps.first { $0.kind == .error }?.id ?? session.id,
                    role: .agent,
                    text: error.message,
                    timestampLabel: timestampLabel(for: session.endedAt ?? Date())
                )
            )
        }

        return messages
    }

    private var runLogItems: [AgentRunLogItem] {
        session.steps.map { step in
            AgentRunLogItem(
                id: step.id,
                phase: phase(for: step),
                status: status(for: step.status),
                title: step.title,
                detail: step.detail,
                metadataLabel: timestampLabel(for: step.completedAt ?? step.createdAt)
            )
        }
    }

    private var statusTitle: String {
        switch runState {
        case .ready:
            return "Ready"
        case .running:
            return "Working"
        case .approvalNeeded:
            return "Needs approval"
        case .failed:
            return "Blocked"
        case .completed:
            return "Complete"
        case .stopped:
            return "Stopped"
        }
    }

    private var statusIcon: String {
        switch runState {
        case .ready:
            return "circle"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .approvalNeeded:
            return "hand.raised.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .stopped:
            return "stop.fill"
        }
    }

    private var statusColor: Color {
        switch runState {
        case .ready:
            return AeroColor.textSecondary
        case .running:
            return Color(UIColor.systemBlue)
        case .approvalNeeded:
            return AeroColor.warning
        case .failed:
            return AeroColor.error
        case .completed:
            return AeroColor.success
        case .stopped:
            return AeroColor.error
        }
    }

    private var stopButtonColor: Color {
        canStop ? AeroColor.textPrimary : AeroColor.textTertiary
    }

    private func phase(for step: AgentRunStep) -> AgentRunLogItem.Phase {
        switch step.kind {
        case .run:
            return .selectedAction
        case .browserTool:
            if step.title.localizedCaseInsensitiveContains("observe") {
                return .observePage
            }
            return .result
        case .approval:
            return .approvalNeeded
        case .finalAnswer:
            return .finalAnswer
        case .error:
            return .error
        }
    }

    private func status(for status: AgentRunStepStatus) -> AgentRunLogItem.Status {
        switch status {
        case .queued:
            return .queued
        case .running:
            return .running
        case .waitingForApproval:
            return .approvalNeeded
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .stopped:
            return .stopped
        }
    }

    private func timestampLabel(for date: Date) -> String {
        let elapsed = max(0, Int(Date().timeIntervalSince(date)))
        if elapsed < 60 {
            return "Now"
        }
        if elapsed < 3_600 {
            return "\(elapsed / 60)m"
        }

        return "\(elapsed / 3_600)h"
    }

    private func sendDraft() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        viewModel.startAgentRun(prompt: trimmedDraft)
        draft = ""
        isInputFocused = false
    }

    private func stopRun() {
        viewModel.stopAgentRun()
    }

    private func clearConversation() {
        draft = ""
        viewModel.clearAgentRunSession()
    }

    private func approveAccess() {
        viewModel.approvePendingAgentAction()
    }

    private func declineApproval() {
        viewModel.denyPendingAgentAction()
    }

    private func retryRun() {
        let prompt = session.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        viewModel.startAgentRun(prompt: prompt)
    }
}

private struct AgentSectionHeader<Trailing: View>: View {
    var title: String
    var trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: AeroSpacing.sm) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(AeroColor.textPrimary)

            Spacer(minLength: AeroSpacing.sm)

            trailing
        }
    }
}

private extension AgentSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) {
            EmptyView()
        }
    }
}

private struct AgentPromptChipView: View {
    var prompt: AgentPromptChip

    var body: some View {
        HStack(alignment: .top, spacing: AeroSpacing.sm) {
            Image(systemName: prompt.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AeroColor.textPrimary)
                .frame(width: 22, height: 22)

            Text(prompt.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AeroColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
        .padding(AeroSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous)
                .fill(Color(UIColor.systemBackground).opacity(0.30))
                .aeroGlassSurface(style: .control,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
        }
    }
}

private struct AgentMessageBubble: View {
    var message: AgentPanelMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: AeroSpacing.sm) {
            if message.role == .user {
                Spacer(minLength: 42)
            } else {
                avatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AeroSpacing.xs) {
                Text(message.text)
                    .font(AeroFont.body)
                    .foregroundStyle(message.role == .user ? Color(UIColor.systemBackground) : AeroColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AeroSpacing.md)
                    .padding(.vertical, 10)
                    .background(messageBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous))

                Text(message.timestampLabel)
                    .font(AeroFont.captionSmall)
                    .foregroundStyle(AeroColor.textTertiary)
                    .padding(.horizontal, AeroSpacing.xs)
            }
            .frame(maxWidth: 290, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .agent {
                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var avatar: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(AeroColor.textPrimary)
            .frame(width: 30, height: 30)
            .background(Color(UIColor.systemBackground).opacity(0.36), in: Circle())
    }

    private var messageBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(AeroColor.textPrimary)
        }

        return AnyShapeStyle(.regularMaterial)
    }
}

private struct AgentRunTimelineRow: View {
    var item: AgentRunLogItem
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AeroSpacing.md) {
            VStack(spacing: AeroSpacing.xs) {
                Rectangle()
                    .fill(isFirst ? Color.clear : tint.opacity(0.28))
                    .frame(width: 2, height: 10)

                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())

                Rectangle()
                    .fill(isLast ? Color.clear : tint.opacity(0.28))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: AeroSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: AeroSpacing.xs) {
                    Text(item.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AeroColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusBadge

                    Spacer(minLength: 0)
                }

                Text(item.detail)
                    .font(AeroFont.caption)
                    .foregroundStyle(AeroColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.vertical, AeroSpacing.sm)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Text(statusLabel)
                .font(.system(size: 10, weight: .bold))

            if let metadataLabel = item.metadataLabel {
                Text(metadataLabel)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var iconName: String {
        switch item.phase {
        case .observePage:
            return "eye"
        case .selectedAction:
            return "cursorarrow.click.2"
        case .result:
            return "checklist"
        case .approvalNeeded:
            return "hand.raised.fill"
        case .retry:
            return "arrow.counterclockwise"
        case .error:
            return "exclamationmark.triangle.fill"
        case .finalAnswer:
            return "sparkles"
        }
    }

    private var statusLabel: String {
        switch item.status {
        case .queued:
            return "Queued"
        case .running:
            return "Running"
        case .waiting:
            return "Waiting"
        case .approvalNeeded:
            return "Approval"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .stopped:
            return "Stopped"
        }
    }

    private var tint: Color {
        switch item.status {
        case .queued:
            return AeroColor.textSecondary
        case .running:
            return Color(UIColor.systemBlue)
        case .waiting:
            return AeroColor.textSecondary
        case .approvalNeeded:
            return AeroColor.warning
        case .completed:
            return AeroColor.success
        case .failed:
            return AeroColor.error
        case .stopped:
            return AeroColor.error
        }
    }
}
