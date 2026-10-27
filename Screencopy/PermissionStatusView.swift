import AppKit
import ScreencopyCapture
import SwiftUI

struct PermissionStatusView: View {
    let permission: any ScreenRecordingPermissionChecking
    @State private var status: ScreenRecordingStatus

    init(permission: any ScreenRecordingPermissionChecking) {
        self.permission = permission
        _status = State(initialValue: permission.status())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch status {
            case .granted:
                Label("Screen recording is allowed", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Screencopy can read your screen. Capture arrives in the next release.")
            case .notGranted:
                Label("Screen recording is not allowed yet", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Screencopy needs permission to see your screen. Choose Allow, then turn Screencopy on in System Settings. macOS may ask you to quit and reopen the app.")
                HStack {
                    Button("Ask for permission") { status = permission.request() }
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(ScreenRecordingPermission.settingsURL)
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Check again") { status = permission.status() }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: 420, height: 240, alignment: .topLeading)
    }
}
