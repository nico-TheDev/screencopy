import Testing
@testable import ScreencopyCapture

@Suite struct PermissionTests {
    @Test func settingsURLPointsAtScreenRecordingPane() {
        #expect(ScreenRecordingPermission.settingsURL.absoluteString.hasSuffix("Privacy_ScreenCapture"))
    }
}
