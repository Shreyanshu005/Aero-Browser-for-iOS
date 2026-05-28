import Foundation

struct AgentToolLoopRequest: Equatable {
    let runID: UUID
    var prompt: String

    init(runID: UUID, prompt: String) {
        self.runID = runID
        self.prompt = prompt
    }
}

struct AgentToolLoopResult: Equatable {
    var finalAnswer: String

    init(finalAnswer: String) {
        self.finalAnswer = finalAnswer
    }
}

enum AgentToolLoopEvent: Equatable {
    case stepStarted(AgentRunStep)
    case stepUpdated(id: UUID, status: AgentRunStepStatus, title: String?, detail: String?)
    case approvalRequested(AgentApprovalRequest)
    case approvalResolved(AgentApprovalRequest, AgentApprovalDecision)
}

protocol AgentToolLoopRunning {
    func run(
        request: AgentToolLoopRequest,
        browserTools: AgentBrowserTooling,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult
}
