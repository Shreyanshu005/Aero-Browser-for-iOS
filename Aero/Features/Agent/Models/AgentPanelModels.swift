import Foundation

enum AgentPanelRunState: Equatable {
    case ready
    case running
    case approvalNeeded
    case failed
    case completed
    case stopped
}

enum AgentPanelMessageRole: Equatable {
    case user
    case agent
}

struct AgentPanelMessage: Identifiable, Equatable {
    let id: UUID
    let role: AgentPanelMessageRole
    var text: String
    var timestampLabel: String

    init(
        id: UUID = UUID(),
        role: AgentPanelMessageRole,
        text: String,
        timestampLabel: String
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestampLabel = timestampLabel
    }
}

struct AgentPromptChip: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var systemImage: String
}

struct AgentRunLogItem: Identifiable, Equatable {
    enum Phase: Equatable {
        case observePage
        case selectedAction
        case result
        case approvalNeeded
        case retry
        case error
        case finalAnswer
    }

    enum Status: Equatable {
        case queued
        case running
        case waiting
        case approvalNeeded
        case completed
        case failed
        case stopped
    }

    let id: UUID
    var phase: Phase
    var status: Status
    var title: String
    var detail: String
    var metadataLabel: String?

    init(
        id: UUID = UUID(),
        phase: Phase,
        status: Status,
        title: String,
        detail: String,
        metadataLabel: String? = nil
    ) {
        self.id = id
        self.phase = phase
        self.status = status
        self.title = title
        self.detail = detail
        self.metadataLabel = metadataLabel
    }
}

enum AgentPanelSampleData {
    static let suggestedPrompts: [AgentPromptChip] = [
        AgentPromptChip(title: "Summarize this page", systemImage: "doc.text.magnifyingglass"),
        AgentPromptChip(title: "Tell me price of TV from Flipkart", systemImage: "cart"),
        AgentPromptChip(title: "Find latest post by Elon on X", systemImage: "bolt.horizontal.circle"),
        AgentPromptChip(title: "Extract links from this page", systemImage: "link"),
    ]
}
