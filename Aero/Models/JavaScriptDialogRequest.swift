import Foundation

enum JavaScriptDialogKind: Equatable {
    case alert
    case confirm
    case prompt(defaultText: String?)
}

final class JavaScriptDialogRequest: Identifiable {
    enum Completion {
        case alert(() -> Void)
        case confirm((Bool) -> Void)
        case prompt((String?) -> Void)
    }

    let id: UUID
    let kind: JavaScriptDialogKind
    let message: String
    let sourceHost: String

    private var completion: Completion?

    init(
        id: UUID = UUID(),
        kind: JavaScriptDialogKind,
        message: String,
        sourceHost: String,
        completion: Completion
    ) {
        let trimmedSourceHost = sourceHost.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = id
        self.kind = kind
        self.message = message
        self.sourceHost = trimmedSourceHost.isEmpty ? "This Page" : trimmedSourceHost
        self.completion = completion
    }

    deinit {
        cancel()
    }

    var defaultPromptText: String {
        guard case .prompt(let defaultText) = kind else { return "" }
        return defaultText ?? ""
    }

    var isPrompt: Bool {
        if case .prompt = kind {
            return true
        }
        return false
    }

    func accept(promptText: String? = nil) {
        guard let completion else { return }
        self.completion = nil

        switch completion {
        case .alert(let handler):
            handler()
        case .confirm(let handler):
            handler(true)
        case .prompt(let handler):
            handler(promptText ?? defaultPromptText)
        }
    }

    func cancel() {
        guard let completion else { return }
        self.completion = nil

        switch completion {
        case .alert(let handler):
            handler()
        case .confirm(let handler):
            handler(false)
        case .prompt(let handler):
            handler(nil)
        }
    }
}
