import Foundation

enum AgentRunStatus: Equatable {
    case idle
    case running
    case waitingForApproval
    case stopped
    case completed
    case failed

    var isActive: Bool {
        self == .running || self == .waitingForApproval
    }
}

struct AgentRunSession: Identifiable, Equatable {
    let id: UUID
    var prompt: String
    var status: AgentRunStatus
    var steps: [AgentRunStep]
    var pendingApproval: AgentApprovalRequest?
    var finalAnswer: String?
    var error: AgentRunError?
    let startedAt: Date
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        prompt: String = "",
        status: AgentRunStatus = .idle,
        steps: [AgentRunStep] = [],
        pendingApproval: AgentApprovalRequest? = nil,
        finalAnswer: String? = nil,
        error: AgentRunError? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.status = status
        self.steps = steps
        self.pendingApproval = pendingApproval
        self.finalAnswer = finalAnswer
        self.error = error
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

struct AgentRunStep: Identifiable, Equatable {
    let id: UUID
    var kind: AgentRunStepKind
    var status: AgentRunStepStatus
    var title: String
    var detail: String
    let createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        kind: AgentRunStepKind,
        status: AgentRunStepStatus,
        title: String,
        detail: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum AgentRunStepKind: Equatable {
    case run
    case browserTool
    case approval
    case finalAnswer
    case error
}

enum AgentRunStepStatus: Equatable {
    case queued
    case running
    case waitingForApproval
    case completed
    case failed
    case stopped
}

struct AgentRunError: Equatable {
    var message: String

    init(message: String) {
        self.message = message
    }

    init(_ error: Error) {
        self.message = error.localizedDescription
    }
}
