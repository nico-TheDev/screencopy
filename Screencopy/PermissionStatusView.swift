import AppKit
import Observation
import ScreencopyCapture
import SwiftUI

/// What the status window shows. Re-read from the system every time the window is shown.
@MainActor
@Observable
final class PermissionStatusModel {
    private(set) var status: ScreenRecordingStatus
    /// Set when a capture could not start. Cleared the next time the window is shown without one.
    private(set) var message: String?
    @ObservationIgnored private let permission: any ScreenRecordingPermissionChecking

    init(permission: any ScreenRecordingPermissionChecking) {
        self.permission = permission
        status = permission.status()
    }

    func refresh(message: String? = nil) {
        status = permission.status()
        self.message = message
    }

    func requestPermission() {
        status = permission.request()
    }
}

struct PermissionStatusView: View {
    let model: PermissionStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.status {
            case .granted:
                if let message = model.message {
                    Label("Capture did not work", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text(message)
                    openSettingsButton
                } else {
                    Label("Screen recording is allowed", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(
                        "\(captureInstruction), then drag over the part of the screen you want."
                    )
                }
            case .notGranted:
                Label("Screen recording is not allowed yet", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(
                    model.message
                        ?? "Screencopy needs permission to see your screen. Choose Allow, "
                        + "then turn Screencopy on in System Settings. "
                        + "macOS may ask you to quit and reopen the app."
                )
                HStack {
                    Button("Ask for permission") { model.requestPermission() }
                    openSettingsButton
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Check again") { model.refresh() }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: 420, height: 280, alignment: .topLeading)
    }

    private var captureInstruction: String {
        if let hotkey = HotkeyController.shared.shortcutText {
            return "Press \(hotkey) in any app, or choose Capture Text from the menu bar icon"
        }
        return "Choose Capture Text from the menu bar icon"
    }

    private var openSettingsButton: some View {
        Button("Open System Settings") {
            NSWorkspace.shared.open(ScreenRecordingPermission.settingsURL)
        }
    }
}
