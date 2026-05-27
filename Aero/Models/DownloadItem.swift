//
//  DownloadItem.swift
//  Aero
//
//  Created on 2026-05-27.
//

import Foundation
import Observation

// MARK: - DownloadItem

/// Represents a single file download, tracking its progress, state, and metadata.
///
/// This is an observable class so that views displaying download lists can react
/// to progress and state changes automatically.
@Observable
final class DownloadItem: Identifiable {

    /// Unique identifier for this download.
    let id: UUID

    /// The remote URL the file is being downloaded from.
    let url: URL

    /// The display filename for the download, which may be updated when the server
    /// provides a `Content-Disposition` header with a suggested filename.
    var filename: String

    /// The current state of the download.
    var state: DownloadState = .pending

    /// The fractional progress of the download, from 0.0 to 1.0.
    var progress: Double = 0.0

    /// The number of bytes downloaded so far.
    var bytesDownloaded: Int64 = 0

    /// The total number of bytes expected, or 0 if unknown.
    var totalBytes: Int64 = 0

    /// The local file URL where the downloaded file has been saved, set upon completion.
    var localURL: URL?

    /// A user-readable error message if the download failed.
    var errorMessage: String?

    /// The date and time when this download was initiated.
    let startedAt: Date

    /// Creates a new download item.
    ///
    /// - Parameters:
    ///   - url: The remote URL to download from.
    ///   - filename: The initial display filename for the download.
    init(url: URL, filename: String) {
        self.id = UUID()
        self.url = url
        self.filename = filename
        self.startedAt = Date()
    }

    /// A human-readable string showing download progress (e.g., "2.4 MB / 10 MB").
    var formattedProgress: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
        if totalBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
        return downloaded
    }
}

// MARK: - DownloadState

/// The possible states of a download.
enum DownloadState: Equatable {
    /// The download has been created but has not started transferring data.
    case pending

    /// The download is actively transferring data.
    case downloading

    /// The download completed successfully and the file is available at `localURL`.
    case completed

    /// The download failed; see `errorMessage` for details.
    case failed

    /// The download was cancelled by the user.
    case cancelled
}

// MARK: - DownloadToast

/// A short-lived notification shown when a download begins, providing visual feedback.
struct DownloadToast: Identifiable, Equatable {
    /// Unique identifier for SwiftUI list diffing.
    let id = UUID()

    /// The filename displayed in the toast.
    let filename: String
}
