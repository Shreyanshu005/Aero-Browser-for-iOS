import Foundation
import Observation

@MainActor
@Observable
final class AgentRunEngine {
    private(set) var session: AgentRunSession

    @ObservationIgnored
    private let toolLoopRunner: AgentToolLoopRunning

    @ObservationIgnored
    private let browserTools: AgentBrowserTooling

    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeRunID: UUID?

    init(
        toolLoopRunner: AgentToolLoopRunning,
        browserTools: AgentBrowserTooling,
        session: AgentRunSession = AgentRunSession()
    ) {
        self.toolLoopRunner = toolLoopRunner
        self.browserTools = browserTools
        self.session = session
    }

    deinit {
        activeTask?.cancel()
    }

    @discardableResult
    func start(prompt: String) -> UUID? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return nil }

        activeTask?.cancel()

        let runID = UUID()
        let startedAt = Date()
        session = AgentRunSession(
            id: runID,
            prompt: trimmedPrompt,
            status: .running,
            steps: [
                AgentRunStep(
                    kind: .run,
                    status: .running,
                    title: "Run started",
                    detail: trimmedPrompt,
                    createdAt: startedAt
                )
            ],
            startedAt: startedAt
        )
        activeRunID = runID

        let request = AgentToolLoopRequest(runID: runID, prompt: trimmedPrompt)
        activeTask = Task { [weak self, toolLoopRunner, browserTools] in
            do {
                let result = try await toolLoopRunner.run(
                    request: request,
                    browserTools: browserTools
                ) { event in
                    await self?.handle(event, runID: runID)
                }
                await self?.complete(result, runID: runID)
            } catch is CancellationError {
                await self?.completeStoppedRun(runID: runID)
            } catch {
                await self?.fail(error, runID: runID)
            }
        }

        return runID
    }

    func stop() {
        guard session.status.isActive else { return }

        activeTask?.cancel()
        activeTask = nil
        activeRunID = nil

        session.status = .stopped
        session.pendingApproval = nil
        session.endedAt = Date()
        appendStep(
            AgentRunStep(
                kind: .run,
                status: .stopped,
                title: "Run stopped",
                detail: "No more steps will be taken for this task.",
                completedAt: Date()
            )
        )
    }

    func clear() {
        activeTask?.cancel()
        activeTask = nil
        activeRunID = nil
        session = AgentRunSession()
    }

    func recordApprovalRequested(_ request: AgentApprovalRequest) {
        guard session.status.isActive else { return }

        session.status = .waitingForApproval
        session.pendingApproval = request
        appendStep(
            AgentRunStep(
                kind: .approval,
                status: .waitingForApproval,
                title: request.title,
                detail: request.detail
            )
        )
    }

    func recordApprovalResolved(_ request: AgentApprovalRequest, _ decision: AgentApprovalDecision) {
        guard session.status.isActive || session.pendingApproval?.id == request.id else { return }

        if session.pendingApproval?.id == request.id {
            session.pendingApproval = nil
        }
        if session.status == .waitingForApproval {
            session.status = .running
        }
        appendStep(
            AgentRunStep(
                kind: .approval,
                status: decision == .approved ? .completed : .failed,
                title: decision == .approved ? "Approval granted" : "Approval denied",
                detail: request.title,
                completedAt: Date()
            )
        )
    }

    private func handle(_ event: AgentToolLoopEvent, runID: UUID) {
        guard activeRunID == runID else { return }

        switch event {
        case .stepStarted(let step):
            appendStep(step)
        case .stepUpdated(let id, let status, let title, let detail):
            updateStep(id: id, status: status, title: title, detail: detail)
        case .approvalRequested(let request):
            recordApprovalRequested(request)
        case .approvalResolved(let request, let decision):
            recordApprovalResolved(request, decision)
        }
    }

    private func complete(_ result: AgentToolLoopResult, runID: UUID) {
        guard activeRunID == runID else { return }

        activeTask = nil
        activeRunID = nil
        session.status = .completed
        session.pendingApproval = nil
        session.finalAnswer = result.finalAnswer
        session.endedAt = Date()
        appendStep(
            AgentRunStep(
                kind: .finalAnswer,
                status: .completed,
                title: "Final answer",
                detail: result.finalAnswer,
                completedAt: Date()
            )
        )
    }

    private func fail(_ error: Error, runID: UUID) {
        guard activeRunID == runID else { return }

        activeTask = nil
        activeRunID = nil
        let runError = AgentRunError(error)
        session.status = .failed
        session.pendingApproval = nil
        session.error = runError
        session.endedAt = Date()
        appendStep(
            AgentRunStep(
                kind: .error,
                status: .failed,
                title: "Run failed",
                detail: runError.message,
                completedAt: Date()
            )
        )
    }

    private func completeStoppedRun(runID: UUID) {
        guard activeRunID == runID else { return }

        activeTask = nil
        activeRunID = nil
        session.status = .stopped
        session.pendingApproval = nil
        session.endedAt = Date()
        appendStep(
            AgentRunStep(
                kind: .run,
                status: .stopped,
                title: "Run stopped",
                detail: "The task was cancelled before completion.",
                completedAt: Date()
            )
        )
    }

    private func appendStep(_ step: AgentRunStep) {
        session.steps.append(step)
    }

    private func updateStep(
        id: UUID,
        status: AgentRunStepStatus,
        title: String?,
        detail: String?
    ) {
        guard let index = session.steps.firstIndex(where: { $0.id == id }) else { return }

        session.steps[index].status = status
        if let title {
            session.steps[index].title = title
        }
        if let detail {
            session.steps[index].detail = detail
        }
        if status.isTerminal {
            session.steps[index].completedAt = Date()
        }
    }
}
private extension AgentRunStepStatus {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .stopped:
            return true
        case .queued, .running, .waitingForApproval:
            return false
        }
    }
}
