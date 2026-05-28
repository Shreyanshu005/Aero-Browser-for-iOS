import SwiftUI
import UIKit

struct AgentChatPanelView: View {
    @Bindable var viewModel: BrowserViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var runEngine: AgentRunEngine
    @State private var draft = ""
    @State private var messages: [AgentPanelMessage] = []

    private let promptColumns = [
        GridItem(.adaptive(minimum: 148), spacing: AeroSpacing.sm, alignment: .top)
    ]

    init(viewModel: BrowserViewModel) {
        self.viewModel = viewModel
        _runEngine = State(
            initialValue: AgentRunEngine(
                toolLoopRunner: LiveAgentToolLoopRunner(searchEngine: viewModel.searchEngine),
                browserTools: viewModel
            )
        )
    }

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
        .onChange(of: runEngine.session.finalAnswer) { _, answer in
            appendAgentMessage(answer)
        }
        .onChange(of: runEngine.session.error?.message) { _, message in
            appendAgentMessage(message.map { "Run failed: \($0)" })
        }
    }

    private var header: some View {
        HStack(spacing: AeroSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemBackground).opacity(0.28))
                    .browserLiquidGlassBackground(in: Circle())

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
                    Text(activePageTitle)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AeroColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(activePageSubtitle)
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

            if messages.isEmpty {
                emptyTranscript
            } else {
                VStack(spacing: AeroSpacing.md) {
                    ForEach(messages) { message in
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

                    if runState == .approvalNeeded {
                        approvalActions
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

    private var approvalActions: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.sm) {
            HStack(alignment: .top, spacing: AeroSpacing.sm) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AeroColor.warning)
                    .frame(width: 30, height: 30)
                    .background(AeroColor.warning.opacity(0.14), in: Circle())

                Text("Approve page access to continue.")
                    .font(AeroFont.caption)
                    .foregroundStyle(AeroColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: AeroSpacing.sm) {
                Spacer(minLength: 0)

                Button("Not now") {
                    declineApproval()
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Allow once") {
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
                        .browserLiquidGlassBackground(
                            in: RoundedRectangle(cornerRadius: AeroRadius.lg, style: .continuous)
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
                    .browserLiquidGlassBackground(in: Circle())
            }
            .disabled(!runEngine.session.status.isActive)
            .opacity(runEngine.session.status.isActive ? 1 : 0.45)
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

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activePageTitle: String {
        viewModel.activeTab?.displayTitle ?? "New Tab"
    }

    private var activePageSubtitle: String {
        viewModel.activeTab?.displayURL?.displayHost ?? "Ready for browsing tasks"
    }

    private var runState: AgentPanelRunState {
        switch runEngine.session.status {
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

    private var runLogItems: [AgentRunLogItem] {
        runEngine.session.steps.map(AgentRunLogItem.init)
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
        runState == .stopped ? AeroColor.error : AeroColor.textPrimary
    }

    private func sendDraft() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        messages.append(
            AgentPanelMessage(
                role: .user,
                text: trimmedDraft,
                timestampLabel: "Now"
            )
        )
        runEngine.start(prompt: trimmedDraft)
        draft = ""
    }

    private func stopRun() {
        runEngine.stop()
    }

    private func clearConversation() {
        draft = ""
        messages = []
        runEngine.clear()
    }

    private func approveAccess() {
        appendAgentMessage("Approval handling is not available for this deterministic run yet.")
    }

    private func declineApproval() {
        runEngine.stop()
    }

    private func retryRun() {
        guard !runEngine.session.prompt.isEmpty else { return }
        runEngine.start(prompt: runEngine.session.prompt)
    }

    private func appendAgentMessage(_ text: String?) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        guard messages.last?.role != .agent || messages.last?.text != text else { return }

        messages.append(
            AgentPanelMessage(
                role: .agent,
                text: text,
                timestampLabel: "Now"
            )
        )
    }
}

private extension AgentRunLogItem {
    init(_ step: AgentRunStep) {
        self.init(
            id: step.id,
            phase: AgentRunLogItem.phase(for: step),
            status: AgentRunLogItem.status(for: step.status),
            title: step.title,
            detail: step.detail,
            metadataLabel: step.completedAt == nil ? nil : "Done"
        )
    }

    static func phase(for step: AgentRunStep) -> Phase {
        switch step.kind {
        case .approval:
            return .approvalNeeded
        case .error:
            return .error
        case .finalAnswer:
            return .finalAnswer
        case .run:
            return .result
        case .browserTool:
            let title = step.title.lowercased()
            if title.contains("observe") || title.contains("wait") || title.contains("extract") {
                return .observePage
            }
            if title.contains("scroll") {
                return .retry
            }
            return .selectedAction
        }
    }

    static func status(for status: AgentRunStepStatus) -> Status {
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
                .browserLiquidGlassBackground(
                    in: RoundedRectangle(cornerRadius: AeroRadius.md, style: .continuous)
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
