import SwiftUI

@main
struct ScreencopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A SwiftUI App needs at least one scene. Feature 5 adds the real settings window.
        Settings { EmptyView() }
    }
}
