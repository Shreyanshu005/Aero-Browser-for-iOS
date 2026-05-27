import SwiftUI
import UIKit

struct SelectableTextField: UIViewRepresentable {
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectableTextField
        init(parent: SelectableTextField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if parent.selectAllOnFocus {
                DispatchQueue.main.async { textField.selectAll(nil) }
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFirstResponder = false
        }
    }

    let placeholder: String
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var selectAllOnFocus: Bool = true
    var keyboardType: UIKeyboardType = .webSearch
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.borderStyle = .none
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.keyboardType = keyboardType
        tf.returnKeyType = .go
        tf.placeholder = placeholder
        tf.delegate = context.coordinator
        tf.textAlignment = .natural
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }

        if isFirstResponder, !uiView.isFirstResponder {
            // The text field may not yet be in a window during the same update cycle.
            // Dispatching ensures the keyboard opens on first tap, but always re-check
            // the latest binding value (avoid stale self.isFirstResponder).
            let shouldBeFirstResponder = isFirstResponder
            DispatchQueue.main.async {
                guard shouldBeFirstResponder else { return }
                if !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                }
            }
        } else if !isFirstResponder, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
}
