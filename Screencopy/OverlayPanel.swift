import AppKit

/// One borderless panel per display, above the menu bar and on every Space.
/// Non activating, so the app you copy from stays the active app.
final class OverlayPanel: NSPanel {
    init(screen: NSScreen, view: SelectionView) {
        super.init(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = false
        isOpaque = true
        backgroundColor = .black
        acceptsMouseMovedEvents = true
        contentView = view
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Without this the menu bar pushes a full screen panel down.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func cancelOperation(_ sender: Any?) {
        (contentView as? SelectionView)?.requestCancel()
    }
}
