import UIKit

enum SharePresenter {
    static func present(items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

