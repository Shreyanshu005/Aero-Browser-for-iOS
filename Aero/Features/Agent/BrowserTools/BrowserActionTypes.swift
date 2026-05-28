import Foundation

struct BrowserElementID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum BrowserActionKind: String, Codable, Equatable, Sendable {
    case openURL = "open_url"
    case clickElement = "click_element"
    case typeText = "type_text"
    case clearField = "clear_field"
    case pressEnter = "press_enter"
    case scroll
    case wait
    case back
    case forward
    case reload
    case stop
}

enum BrowserScrollDirection: String, Codable, Equatable, Sendable {
    case up
    case down
    case left
    case right
}

struct BrowserScrollRequest: Codable, Equatable, Sendable {
    var direction: BrowserScrollDirection
    var amount: Double?

    init(direction: BrowserScrollDirection, amount: Double? = nil) {
        self.direction = direction
        self.amount = amount
    }
}

struct BrowserActionRequest: Codable, Equatable, Sendable {
    var kind: BrowserActionKind
    var url: String?
    var elementID: BrowserElementID?
    var text: String?
    var scroll: BrowserScrollRequest?
    var waitMilliseconds: Int?
    var userApproved: Bool

    init(
        kind: BrowserActionKind,
        url: String? = nil,
        elementID: BrowserElementID? = nil,
        text: String? = nil,
        scroll: BrowserScrollRequest? = nil,
        waitMilliseconds: Int? = nil,
        userApproved: Bool = false
    ) {
        self.kind = kind
        self.url = url
        self.elementID = elementID
        self.text = text
        self.scroll = scroll
        self.waitMilliseconds = waitMilliseconds
        self.userApproved = userApproved
    }
}

enum BrowserActionStatus: String, Codable, Equatable, Sendable {
    case succeeded
    case failed
    case approvalRequired
}

enum BrowserActionResultCode: String, Codable, Equatable, Sendable {
    case success
    case approvalRequired
    case invalidRequest
    case invalidURL
    case unsupportedURL
    case noActiveTab
    case missingWebView
    case navigationUnavailable
    case elementMissing
    case elementNotInteractable
    case javaScriptFailed
    case failed
}

struct BrowserElementActionSummary: Codable, Equatable, Sendable {
    var elementID: BrowserElementID?
    var tagName: String?
    var role: String?
    var type: String?
    var label: String?
    var isVisible: Bool
    var isDisabled: Bool
    var requiresApproval: Bool
}

struct BrowserScrollState: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var contentWidth: Double
    var contentHeight: Double
    var viewportWidth: Double
    var viewportHeight: Double
}

struct BrowserActionResult: Codable, Equatable, Sendable {
    var status: BrowserActionStatus
    var code: BrowserActionResultCode
    var message: String
    var action: BrowserActionKind
    var tabID: UUID?
    var pageURL: URL?
    var pageTitle: String?
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var element: BrowserElementActionSummary?
    var scroll: BrowserScrollState?
}

struct BrowserActionScriptResult: Codable, Equatable, Sendable {
    var ok: Bool
    var code: BrowserActionResultCode
    var message: String
    var element: BrowserElementActionSummary?
    var scroll: BrowserScrollState?
}
