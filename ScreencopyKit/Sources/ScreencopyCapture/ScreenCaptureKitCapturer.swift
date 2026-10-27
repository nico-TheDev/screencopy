import CoreGraphics
import Foundation
import ScreenCaptureKit
import ScreencopyCore

/// Takes one still picture per display with ScreenCaptureKit. Pictures stay in memory only.
public struct ScreenCaptureKitCapturer: ScreenCapturing {
    private let excludedBundleIdentifier: String?

    /// Windows of the app with `excludingBundleIdentifier` never appear in a picture.
    public init(excludingBundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.excludedBundleIdentifier = excludingBundleIdentifier
    }

    public func snapshot(displays ids: [CGDirectDisplayID]) async throws -> [DisplaySnapshot] {
        guard !ids.isEmpty else { throw ScreencopyError.captureFailed }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            // Both lists must agree, or the overlay would cover only some of the screens.
            guard Set(content.displays.map(\.displayID)) == Set(ids) else { throw ScreencopyError.captureFailed }
            let ownApps = content.applications.filter { $0.bundleIdentifier == excludedBundleIdentifier }
            return try await withThrowingTaskGroup(of: DisplaySnapshot.self) { group in
                for display in content.displays {
                    let job = Job(display: display, ownApps: ownApps)
                    group.addTask { try await Self.snapshot(job) }
                }
                var snapshots: [DisplaySnapshot] = []
                for try await snapshot in group { snapshots.append(snapshot) }
                return snapshots
            }
        } catch {
            throw Self.mapped(error)
        }
    }

    /// ScreenCaptureKit objects are not marked `Sendable`, but these are only read, never changed,
    /// and each task gets its own display.
    private struct Job: @unchecked Sendable {
        let display: SCDisplay
        let ownApps: [SCRunningApplication]
    }

    private static func snapshot(_ job: Job) async throws -> DisplaySnapshot {
        let display = job.display
        let filter = SCContentFilter(display: display, excludingApplications: job.ownApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int((CGFloat(display.width) * scale).rounded())
        configuration.height = Int((CGFloat(display.height) * scale).rounded())
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return DisplaySnapshot(
            displayID: display.displayID, image: image,
            pointSize: CGSize(width: display.width, height: display.height))
    }

    private static func mapped(_ error: Error) -> ScreencopyError {
        if let known = error as? ScreencopyError { return known }
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.Code.userDeclined.rawValue {
            return .permissionDenied
        }
        return .captureFailed
    }
}
