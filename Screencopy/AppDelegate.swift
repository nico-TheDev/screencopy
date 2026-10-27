import AppKit
import ScreencopyCapture
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permission = ScreenRecordingPermission()
    private var statusWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyController.shared.start()
        showPermissionStatus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPermissionStatus()
        return true
    }

    func showPermissionStatus() {
        if statusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Screencopy"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PermissionStatusView(permission: permission))
            window.center()
            statusWindow = window
        }
        NSApp.activate()
        statusWindow?.makeKeyAndOrderFront(nil)
    }
}
