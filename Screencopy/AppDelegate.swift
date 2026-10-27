import AppKit
import ScreencopyCapture
import ScreencopyCore
import ScreencopyHistory
import ScreencopyRecognition
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permission = ScreenRecordingPermission()
    private lazy var statusModel = PermissionStatusModel(permission: permission)
    private lazy var coordinator = CaptureCoordinator(
        permission: permission, capturer: ScreenCaptureKitCapturer(),
        showStatus: { [weak self] message in self?.showPermissionStatus(message: message) })
    private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "app")
    private var statusWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var openSettingsObserver: NSObjectProtocol?
    private let notice = NoticePresenter()
    lazy var history = HistoryModel(
        store: FileHistoryStore(directory: Self.historyDirectory), clipboard: ClipboardWriter(), notifier: notice)
    private lazy var pipeline = TextCapturePipeline(
        recognizer: VisionTextRecognizer(), clipboard: ClipboardWriter(), notifier: notice, history: history)

    /// Application Support, in a folder named for the bundle id, so a debug build keeps its own history.
    private static var historyDirectory: URL {
        URL.applicationSupportDirectory.appending(
            path: Bundle.main.bundleIdentifier ?? "com.norbertoignacio.screencopy", directoryHint: .isDirectory)
    }

    private var openSettingsNotification: Notification.Name {
        Notification.Name("\(Bundle.main.bundleIdentifier ?? "com.norbertoignacio.screencopy").openSettings")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One copy owns the hotkey. A second copy hands over to the running one and leaves.
        if let bundleID = Bundle.main.bundleIdentifier,
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .contains(where: { $0 != NSRunningApplication.current })
        {
            DistributedNotificationCenter.default().postNotificationName(
                openSettingsNotification, object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        openSettingsObserver = DistributedNotificationCenter.default().addObserver(
            forName: openSettingsNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showSettings() }
        }

        history.start()
        coordinator.onCaptured = { [pipeline] image, region in pipeline.start(image: image, region: region) }
        coordinator.onCaptureFailed = { [pipeline] region in pipeline.reportCaptureFailure(region: region) }
        HotkeyController.shared.start { [weak self] in self?.triggerCapture() }
        // The status window opens at launch only when screen recording is not allowed yet.
        if permission.status() != .granted {
            showPermissionStatus()
        }
    }

    /// The one capture entry point, used by the hotkey and the menu item.
    func triggerCapture() {
        // A new capture drops any recognition still running and clears the notice.
        pipeline.cancelCurrent()
        // `start()` ignores the press when a capture is already in progress.
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// Brings the Settings window in front of other apps.
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Screencopy Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(hotkey: HotkeyController.shared))
            window.setContentSize(window.contentView?.fittingSize ?? .zero)
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Brings the status window forward. `message` explains why a capture did not start.
    func showPermissionStatus(message: String? = nil) {
        statusModel.refresh(message: message)
        if statusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Screencopy"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PermissionStatusView(model: statusModel))
            window.center()
            statusWindow = window
        }
        NSApp.activate()
        statusWindow?.makeKeyAndOrderFront(nil)
    }
}
