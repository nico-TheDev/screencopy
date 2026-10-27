import Foundation
import CoreGraphics

public enum ScreenRecordingStatus: Sendable, Equatable {
    case granted
    case notGranted
}

public protocol ScreenRecordingPermissionChecking: Sendable {
    /// Never shows a system prompt.
    func status() -> ScreenRecordingStatus
    /// Shows the system prompt the first time. Returns the status right now,
    /// which is usually still `notGranted` until the app is relaunched.
    func request() -> ScreenRecordingStatus
}

public struct ScreenRecordingPermission: ScreenRecordingPermissionChecking {
    /// Opens the Screen Recording pane in System Settings.
    /// Falls back to the System Settings app if the pane link ever stops parsing.
    public static let settingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")

    public init() {}

    public func status() -> ScreenRecordingStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .notGranted
    }

    public func request() -> ScreenRecordingStatus {
        CGRequestScreenCaptureAccess() ? .granted : .notGranted
    }
}
