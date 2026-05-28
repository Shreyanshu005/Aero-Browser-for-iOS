import Foundation

enum PageObservationLimits {
    static let maxVisibleTextSummaryCharacters = 4_000
    static let maxElementTextCharacters = 240
    static let maxShortTextCharacters = 160
    static let maxInputValueCharacters = 240
    static let maxURLCharacters = 2_048
    static let maxTargetPathCharacters = 1_024
    static let maxTargetIDCharacters = 96
    static let maxLinks = 50
    static let maxButtons = 50
    static let maxInputs = 50
    static let maxForms = 20
    static let maxElements = 120
    static let maxFormFields = 30
}

enum PageObservedElementKind: String, Codable, Equatable {
    case link
    case button
    case input
    case form
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .other
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum PageElementTargetConvention {
    static let version = "aero.page-element-target.v1"
    static let targetIDPrefix = "aero-v1"
    static let targetPathDescription = "CSS selector path from documentElement using tag:nth-of-type(n) steps."

    static func makeTargetID(kind: PageObservedElementKind, targetPath: String) -> String {
        makeTargetID(kind: kind.rawValue, targetPath: targetPath)
    }

    static func makeTargetID(kind: String, targetPath: String) -> String {
        let cappedPath = String(targetPath.prefix(PageObservationLimits.maxTargetPathCharacters))
        return "\(targetIDPrefix):\(kind):\(fnv1aBase36(cappedPath))"
    }

    private static func fnv1aBase36(_ value: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return String(hash, radix: 36, uppercase: false)
    }
}

struct PageObservation: Codable, Equatable {
    var url: String?
    var title: String
    var visibleTextSummary: String
    var links: [PageObservedLink]
    var buttons: [PageObservedButton]
    var inputs: [PageObservedInput]
    var forms: [PageObservedForm]
    var scroll: PageScrollMetrics
    var elements: [PageObservedElement]
    var observedAt: Date

    init(
        url: String?,
        title: String,
        visibleTextSummary: String,
        links: [PageObservedLink],
        buttons: [PageObservedButton],
        inputs: [PageObservedInput],
        forms: [PageObservedForm],
        scroll: PageScrollMetrics,
        elements: [PageObservedElement],
        observedAt: Date = Date()
    ) {
        self.url = url
        self.title = title
        self.visibleTextSummary = visibleTextSummary
        self.links = links
        self.buttons = buttons
        self.inputs = inputs
        self.forms = forms
        self.scroll = scroll
        self.elements = elements
        self.observedAt = observedAt
    }
}

struct PageObservedLink: Codable, Equatable {
    var targetID: String
    var targetPath: String
    var text: String
    var url: String?
    var title: String?
    var ariaLabel: String?
}

struct PageObservedButton: Codable, Equatable {
    var targetID: String
    var targetPath: String
    var text: String
    var type: String?
    var name: String?
    var ariaLabel: String?
    var isDisabled: Bool
}

struct PageObservedInput: Codable, Equatable {
    var targetID: String
    var targetPath: String
    var label: String
    var type: String
    var name: String?
    var placeholder: String?
    var value: String?
    var isRequired: Bool
    var isDisabled: Bool
    var isSearchField: Bool
}

struct PageObservedForm: Codable, Equatable {
    var targetID: String
    var targetPath: String
    var label: String
    var action: String?
    var method: String
    var fieldTargetIDs: [String]
    var searchFieldTargetIDs: [String]
}

struct PageObservedElement: Codable, Equatable {
    var targetID: String
    var targetPath: String
    var kind: PageObservedElementKind
    var label: String
    var text: String?
    var isEnabled: Bool
}

struct PageScrollMetrics: Codable, Equatable {
    var scrollX: Double
    var scrollY: Double
    var viewportWidth: Double
    var viewportHeight: Double
    var contentWidth: Double
    var contentHeight: Double
    var scrollableX: Bool
    var scrollableY: Bool

    init(
        scrollX: Double = 0,
        scrollY: Double = 0,
        viewportWidth: Double = 0,
        viewportHeight: Double = 0,
        contentWidth: Double = 0,
        contentHeight: Double = 0,
        scrollableX: Bool = false,
        scrollableY: Bool = false
    ) {
        self.scrollX = scrollX
        self.scrollY = scrollY
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.contentWidth = contentWidth
        self.contentHeight = contentHeight
        self.scrollableX = scrollableX
        self.scrollableY = scrollableY
    }
}
