import Foundation
import UIKit

enum NewTabBackgroundImageStoreError: LocalizedError {
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .unsupportedImage:
            "The selected file is not a supported image."
        }
    }
}

struct NewTabBackgroundImageStore {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directoryURL = appSupport.appendingPathComponent("NewTabBackgrounds", isDirectory: true)
        }
    }

    func saveImageData(_ data: Data) throws -> String {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.88) else {
            throw NewTabBackgroundImageStoreError.unsupportedImage
        }

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileName = "background-\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try jpegData.write(to: fileURL, options: .atomic)

        return fileName
    }

    func imageURL(for path: String?) -> URL? {
        guard let fileURL = fileURL(for: path),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return fileURL
    }

    func removeImage(at path: String?) {
        guard let fileURL = fileURL(for: path),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    private func fileURL(for path: String?) -> URL? {
        guard let path,
              path == URL(fileURLWithPath: path).lastPathComponent,
              path.hasSuffix(".jpg") else {
            return nil
        }

        return directoryURL.appendingPathComponent(path)
    }
}
