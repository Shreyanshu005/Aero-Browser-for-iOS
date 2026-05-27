import Combine
import UIKit

@MainActor
final class KeyboardObserver: ObservableObject {
    @Published var isVisible: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                self?.isVisible = visible
            }
            .store(in: &cancellables)
    }
}

