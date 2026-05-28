import Foundation

struct AgentApprovalRequest: Identifiable, Equatable {
    enum Kind: Equatable {
        case pageAccess
        case browserAction
        case sensitiveAction
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

enum AgentApprovalDecision: Equatable {
    case approved
    case denied
}

struct AgentPageObservation: Equatable {
    var title: String
    var url: URL?
    var visibleText: String
    var elements: [AgentPageElement]

    init(
        title: String = "",
        url: URL? = nil,
        visibleText: String = "",
        elements: [AgentPageElement] = []
    ) {
        self.title = title
        self.url = url
        self.visibleText = visibleText
        self.elements = elements
    }
}

struct AgentPageElement: Identifiable, Equatable {
    let id: String
    var role: String
    var label: String
    var text: String

    init(
        id: String,
        role: String,
        label: String = "",
        text: String = ""
    ) {
        self.id = id
        self.role = role
        self.label = label
        self.text = text
    }
}

struct AgentBrowserToolResult: Equatable {
    var summary: String
    var extraction: AgentExtractionBundle?

    init(summary: String, extraction: AgentExtractionBundle? = nil) {
        self.summary = summary
        self.extraction = extraction
    }
}

struct AgentDataExtractionRequest: Equatable {
    var prompt: String
    var kinds: Set<AgentExtractionKind>

    init(
        prompt: String,
        kinds: Set<AgentExtractionKind> = Set(AgentExtractionKind.allCases)
    ) {
        self.prompt = prompt
        self.kinds = kinds
    }
}

enum AgentBrowserKey: String, Equatable {
    case enter
    case escape
    case tab
    case backspace
}

enum AgentScrollDirection: String, Equatable {
    case up
    case down
    case left
    case right
}
