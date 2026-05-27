import Foundation

struct SiteStatus: Equatable {
    var host: String?
    var isSecureConnection: Bool
    var contentBlocker: SiteContentBlockerStatus
    private(set) var permissions: [SitePermissionStatus]

    init(
        url: URL? = nil,
        isSecureConnection: Bool = false,
        contentBlockerEnabled: Bool = true
    ) {
        self.host = url?.displayHost
        self.isSecureConnection = isSecureConnection
        self.contentBlocker = contentBlockerEnabled ? .enabled : .disabled
        self.permissions = Self.defaultPermissions
    }

    var displayHost: String {
        host ?? "No Site"
    }

    mutating func updatePage(url: URL?, isSecureConnection: Bool) {
        let newHost = url?.displayHost
        if host != newHost {
            permissions = Self.defaultPermissions
        }

        host = newHost
        self.isSecureConnection = isSecureConnection
    }

    mutating func updateContentBlocker(isEnabled: Bool) {
        contentBlocker = isEnabled ? .enabled : .disabled
    }

    mutating func recordMediaCaptureRequest(_ type: SiteMediaCaptureType) {
        for kind in type.permissionKinds {
            updatePermission(kind) { permission in
                permission.disposition = .ask
                permission.wasObservedThisSession = true
            }
        }
    }

    mutating func recordPopupAttempt() {
        updatePermission(.popups) { permission in
            permission.disposition = .default
            permission.wasObservedThisSession = true
        }
    }

    func permission(for kind: SitePermissionKind) -> SitePermissionStatus? {
        permissions.first { $0.kind == kind }
    }

    private mutating func updatePermission(
        _ kind: SitePermissionKind,
        update: (inout SitePermissionStatus) -> Void
    ) {
        guard let index = permissions.firstIndex(where: { $0.kind == kind }) else { return }
        update(&permissions[index])
    }

    private static let defaultPermissions: [SitePermissionStatus] = [
        SitePermissionStatus(kind: .camera, disposition: .ask),
        SitePermissionStatus(kind: .microphone, disposition: .ask),
        SitePermissionStatus(kind: .location, disposition: .unsupported),
        SitePermissionStatus(kind: .popups, disposition: .default),
    ]
}

enum SiteContentBlockerStatus: Equatable {
    case enabled
    case disabled
}

struct SitePermissionStatus: Identifiable, Equatable {
    var kind: SitePermissionKind
    var disposition: SitePermissionDisposition
    var wasObservedThisSession: Bool = false

    var id: SitePermissionKind { kind }
}

enum SitePermissionKind: String, CaseIterable, Equatable {
    case camera
    case microphone
    case location
    case popups
}

enum SitePermissionDisposition: Equatable {
    case `default`
    case ask
    case unsupported
}

enum SiteMediaCaptureType: Equatable {
    case camera
    case microphone
    case cameraAndMicrophone

    var permissionKinds: [SitePermissionKind] {
        switch self {
        case .camera:
            return [.camera]
        case .microphone:
            return [.microphone]
        case .cameraAndMicrophone:
            return [.camera, .microphone]
        }
    }
}
