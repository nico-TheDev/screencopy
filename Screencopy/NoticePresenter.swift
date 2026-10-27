import AppKit
import ScreencopyCore

/// A small non activating notice that says how the capture went, over the region or at the top of the screen.
/// It never shows the copied text, never takes focus, and is kept out of screen capture.
@MainActor
final class NoticePresenter: OutcomeNotifying {
    private enum Metrics {
        static let height: CGFloat = 36
        static let horizontalPadding: CGFloat = 16
        static let edgeMargin: CGFloat = 8
        static let topOffset: CGFloat = 48
        static let visibleFor: Duration = .milliseconds(1500)
        static let fade: TimeInterval = 0.25
    }

    private let panel: NoticePanel
    private let label = NSTextField(labelWithString: "")
    private var hideTask: Task<Void, Never>?
    private let settings = CaptureSettings()

    init() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Metrics.height / 2
        background.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        panel = NoticePanel(content: background)
    }

    func show(_ outcome: CaptureOutcome, region: CaptureRegion?) {
        present(outcome.message, region: region, autoHide: true)
        if settings.soundsEnabled { sound(for: outcome)?.play() }
        announce(outcome.message)
    }

    func showReading(region: CaptureRegion) {
        present(CaptureOutcome.readingMessage, region: region, autoHide: false)
    }

    func dismiss() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }

    // MARK: Showing

    private func present(_ message: String, region: CaptureRegion?, autoHide: Bool) {
        hideTask?.cancel()
        label.stringValue = message
        label.sizeToFit()
        let size = CGSize(width: label.frame.width + Metrics.horizontalPadding * 2, height: Metrics.height)
        panel.setFrame(frame(for: size, region: region), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        guard autoHide else { return }
        hideTask = Task {
            try? await Task.sleep(for: Metrics.visibleFor)
            guard !Task.isCancelled else { return }
            await fadeOut()
        }
    }

    private func fadeOut() async {
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup(
                { context in
                    context.duration = Metrics.fade
                    panel.animator().alphaValue = 0
                },
                completionHandler: { continuation.resume() })
        }
        guard !Task.isCancelled else { return }
        panel.orderOut(nil)
    }

    /// `region.rect` is display local with a top left origin; Cocoa wants global, bottom left.
    /// With no region (a history pick) the notice goes top center on the display under the mouse.
    private func frame(for size: CGSize, region: CaptureRegion?) -> CGRect {
        let screen =
            region.flatMap { region in NSScreen.screens.first { $0.displayID == region.displayID } }
            ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return CGRect(origin: .zero, size: size) }

        if let region,
            region.rect.width >= size.width + Metrics.edgeMargin * 2,
            region.rect.height >= size.height + Metrics.edgeMargin * 2
        {
            let center = CGPoint(
                x: screen.frame.minX + region.rect.midX, y: screen.frame.maxY - region.rect.midY)
            return CGRect(
                x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        }
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.midX - size.width / 2, y: visible.maxY - Metrics.topOffset - size.height,
            width: size.width, height: size.height)
    }

    // MARK: Feedback

    private func sound(for outcome: CaptureOutcome) -> NSSound? {
        switch outcome {
        case .copied: NSSound(named: "Pop")
        case .noText, .failed, .copyFailed: NSSound(named: "Funk")
        }
    }

    private func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
    }
}

private final class NoticePanel: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // The notice must never be read back as text by a later capture.
        sharingType = .none
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
