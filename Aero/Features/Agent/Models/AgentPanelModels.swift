import Foundation

enum AgentPanelRunState: Equatable {
    case ready
    case running
    case approvalNeeded
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
    enum Kind: Equatable {
        case queued
        case running
        case approvalNeeded
        case completed
        case stopped
    }

    let id: UUID
    var kind: Kind
    var title: String
    var detail: String

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        detail: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

enum AgentPanelSampleData {
    static let suggestedPrompts: [AgentPromptChip] = [
        AgentPromptChip(title: "Summarize this page", systemImage: "doc.text.magnifyingglass"),
        AgentPromptChip(title: "Find latest post by Elon on X", systemImage: "bolt.horizontal.circle"),
        AgentPromptChip(title: "Compare open tabs", systemImage: "square.grid.2x2"),
        AgentPromptChip(title: "Extract links from this page", systemImage: "link"),
    ]

    static let initialMessages: [AgentPanelMessage] = [
        AgentPanelMessage(
            role: .user,
            text: "Compare the active tab with the research tabs and call out the main differences.",
            timestampLabel: "2m"
        ),
        AgentPanelMessage(
            role: .agent,
            text: "I can line up the open tabs, identify the main claims, and keep the final notes in this thread.",
            timestampLabel: "1m"
        ),
    ]

    static let initialRunLog: [AgentRunLogItem] = [
        AgentRunLogItem(
            kind: .completed,
            title: "Task captured",
            detail: "Ready to compare active and open tabs."
        ),
        AgentRunLogItem(
            kind: .approvalNeeded,
            title: "Approval needed",
            detail: "Allow access to the current page before continuing."
        ),
        AgentRunLogItem(
            kind: .queued,
            title: "Draft response",
            detail: "Findings will appear in the transcript."
        ),
    ]
}
