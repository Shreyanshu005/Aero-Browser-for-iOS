import Foundation
import Observation

@Observable
final class NewTabBackgroundSettings {
    static let shared = NewTabBackgroundSettings()

    @ObservationIgnored
    private let settingsStore: BrowserSettingsStore
    @ObservationIgnored
    private let imageStore: NewTabBackgroundImageStore

    var imagePath: String? {
        didSet {
            guard imagePath != oldValue else { return }
            settingsStore.saveNewTabBackgroundImagePath(imagePath)
        }
    }

    var imageURL: URL? {
        imageStore.imageURL(for: imagePath)
    }

    init(
        settingsStore: BrowserSettingsStore = BrowserSettingsStore(),
        imageStore: NewTabBackgroundImageStore = NewTabBackgroundImageStore()
    ) {
        self.settingsStore = settingsStore
        self.imageStore = imageStore
        self.imagePath = settingsStore.loadSettings().newTabBackgroundImagePath
    }

    func setBackgroundImage(data: Data) throws {
        let previousPath = imagePath
        let newPath = try imageStore.saveImageData(data)

        imagePath = newPath
        imageStore.removeImage(at: previousPath)
    }

    func resetBackgroundImage() {
        imageStore.removeImage(at: imagePath)
        imagePath = nil
    }
}
