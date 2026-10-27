import AppKit
import ScreencopyCapture
import ScreencopyCore
import os

enum CaptureMessages {
    static let permissionNeeded =
        "Capture needs screen recording permission. Turn Screencopy on in System Settings, "
        + "then quit and reopen Screencopy. macOS may ask you to approve it again from time to time."
    static let snapshotFailed =
        "Screencopy could not take a picture of your screen, so nothing was captured. Try again. "
        + "If it keeps happening, check that Screencopy is turned on in the Screen Recording setting."
}

extension NSScreen {
    /// The display ID that ScreenCaptureKit uses for this screen.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Runs one capture: permission check, snapshot of every display, overlay, drag, crop, handoff.
/// Images stay in memory and are released the moment the capture ends. Only sizes are logged.
@MainActor
final class CaptureCoordinator: SelectionViewDelegate {
    enum State: Equatable {
        case idle
        case snapshotting(token: Int)
        case selecting
        case finishing
    }

    /// The cropped picture and the box it came from.
    var onCaptured: (CGImage, CaptureRegion) -> Void = { _, _ in }
    /// The drag ended but no picture could be cut from the snapshot.
    var onCaptureFailed: (CaptureRegion) -> Void = { _ in }

    private(set) var state = State.idle

    private let permission: any ScreenRecordingPermissionChecking
    private let capturer: any ScreenCapturing
    private let showStatus: (String) -> Void
    private let snapshotTimeout: Duration
    private let windows: any WindowListing
    private let settings: CaptureSettings
    private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "capture")

    private var nextToken = 0
    private var timeoutTask: Task<Void, Never>?
    private var panels: [OverlayPanel] = []
    private var snapshots: [CGDirectDisplayID: DisplaySnapshot] = [:]
    private var activeDisplay: CGDirectDisplayID?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var shownAt: ContinuousClock.Instant?
    private var toolbar: ToolbarPanel?
    private var toolbarModel: ToolbarModel?
    private var mode = CaptureMode.portion

    init(
        permission: any ScreenRecordingPermissionChecking,
        capturer: any ScreenCapturing,
        windows: any WindowListing = SystemWindowLister(),
        settings: CaptureSettings = CaptureSettings(),
        snapshotTimeout: Duration = .seconds(2),
        showStatus: @escaping (String) -> Void
    ) {
        self.permission = permission
        self.capturer = capturer
        self.snapshotTimeout = snapshotTimeout
        self.windows = windows
        self.settings = settings
        self.showStatus = showStatus
    }

    // MARK: Start

    func start() {
        guard state == .idle else { return }
        // Never `request()` from the hotkey: that would pop the system prompt on every press.
        guard permission.status() == .granted else {
            showStatus(CaptureMessages.permissionNeeded)
            return
        }
        let screens = NSScreen.screens
        let ids = screens.compactMap(\.displayID)
        guard !screens.isEmpty, ids.count == screens.count else {
            showStatus(CaptureMessages.snapshotFailed)
            return
        }

        nextToken += 1
        let token = nextToken
        state = .snapshotting(token: token)
        let mouse = NSEvent.mouseLocation
        logger.info("capture started on \(ids.count) displays")

        Task { [capturer] in
            do {
                let shots = try await capturer.snapshot(displays: ids)
                snapshotsArrived(.success(shots), token: token, hintPoint: mouse)
            } catch {
                snapshotsArrived(.failure(error), token: token, hintPoint: mouse)
            }
        }
        timeoutTask = Task { [snapshotTimeout] in
            try? await Task.sleep(for: snapshotTimeout)
            guard !Task.isCancelled else { return }
            snapshotFailed(token: token, message: CaptureMessages.snapshotFailed)
        }
    }

    private func snapshotsArrived(_ result: Result<[DisplaySnapshot], Error>, token: Int, hintPoint: CGPoint) {
        // The call cannot be stopped, so a late result for an old start is simply dropped.
        guard state == .snapshotting(token: token) else { return }
        switch result {
        case .failure(let error):
            let denied = (error as? ScreencopyError) == .permissionDenied
            snapshotFailed(
                token: token, message: denied ? CaptureMessages.permissionNeeded : CaptureMessages.snapshotFailed)
        case .success(let shots):
            let screens = NSScreen.screens
            let byID = Dictionary(shots.map { ($0.displayID, $0) }, uniquingKeysWith: { first, _ in first })
            // AppKit and ScreenCaptureKit must agree on which displays exist and how big they are.
            let agrees =
                Set(screens.compactMap(\.displayID)) == Set(byID.keys)
                && screens.allSatisfy { screen in
                    guard let id = screen.displayID, let shot = byID[id] else { return false }
                    return abs(shot.pointSize.width - screen.frame.width) <= 1
                        && abs(shot.pointSize.height - screen.frame.height) <= 1
                }
            guard agrees else {
                snapshotFailed(token: token, message: CaptureMessages.snapshotFailed)
                return
            }
            timeoutTask?.cancel()
            beginSelecting(screens: screens, snapshots: byID, hintPoint: hintPoint)
        }
    }

    private func snapshotFailed(token: Int, message: String) {
        guard state == .snapshotting(token: token) else { return }
        timeoutTask?.cancel()
        state = .idle
        logger.info("capture failed before the overlay")
        showStatus(message)
    }

    // MARK: Selecting

    private func beginSelecting(
        screens: [NSScreen], snapshots: [CGDirectDisplayID: DisplaySnapshot], hintPoint: CGPoint
    ) {
        self.snapshots = snapshots
        let toolbarOn = settings.toolbarEnabled
        // With the bar off this is today's plain overlay: portion mode only, number keys do nothing.
        mode = toolbarOn ? settings.mode : .portion
        let windowList = toolbarOn ? readWindows() : []
        var hinted: (panel: OverlayPanel, screen: NSScreen)?
        for screen in screens {
            guard let id = screen.displayID, let shot = snapshots[id] else { continue }
            let view = SelectionView(snapshot: shot, displaySize: screen.frame.size)
            view.delegate = self
            view.modeKeysEnabled = toolbarOn
            view.mode = mode
            view.windowRects = WindowHitTester.pickableRects(
                from: windowList, displayBounds: CGDisplayBounds(id),
                excludingProcess: ProcessInfo.processInfo.processIdentifier)
            let panel = OverlayPanel(screen: screen, view: view)
            panels.append(panel)
            if screen.frame.contains(hintPoint) { hinted = (panel, screen) }
        }
        let keyPanel = hinted?.panel ?? panels.first
        shownAt = .now
        state = .selecting
        watchForCancelSources()
        for panel in panels where panel !== keyPanel { panel.orderFrontRegardless() }
        if let keyPanel, let view = keyPanel.contentView as? SelectionView {
            keyPanel.makeKeyAndOrderFront(nil)
            keyPanel.makeFirstResponder(view)
            view.showHint()
        }
        if toolbarOn, let screen = hinted?.screen ?? NSScreen.screens.first(where: { $0.displayID == keyDisplayID }) {
            showToolbar(on: screen)
        }
        for case let view as SelectionView in panels.map(\.contentView) { view.refreshHover() }
        (mode == .portion ? NSCursor.crosshair : NSCursor.arrow).set()
    }

    private var keyDisplayID: CGDirectDisplayID? {
        (panels.first(where: \.isKeyWindow)?.contentView as? SelectionView)?.displayID
    }

    /// Read once per capture. A failure leaves window mode with nothing to pick, and logs no names.
    private func readWindows() -> [WindowInfo] {
        do {
            return try windows.frontToBackWindows()
        } catch {
            logger.info("window list could not be read")
            return []
        }
    }

    // MARK: Toolbar

    private func showToolbar(on screen: NSScreen) {
        let model = ToolbarModel(mode: mode)
        model.onSelectMode = { [weak self] in self?.setMode($0) }
        model.onClose = { [weak self] in self?.cancel() }
        let saved = screen.displayID.flatMap { settings.toolbarPosition(display: $0) }
        let panel = ToolbarPanel(screen: screen, model: model, saved: saved)
        let settings = settings
        panel.onMoved = { [displayID = screen.displayID] position in
            if let displayID { settings.setToolbarPosition(position, display: displayID) }
        }
        model.onOptions = { [weak self, weak panel] in
            guard let self, let panel else { return }
            panel.popUpMenu(self.makeOptionsMenu())
        }
        toolbar = panel
        toolbarModel = model
        panel.orderFrontRegardless()
    }

    private func makeOptionsMenu() -> NSMenu {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Play sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        item.target = self
        item.state = settings.soundsEnabled ? .on : .off
        menu.addItem(item)
        return menu
    }

    @objc private func toggleSounds(_ sender: NSMenuItem) {
        settings.soundsEnabled.toggle()
    }

    /// Switches how a click picks pixels. Saved at once. Ignored during a drag or when the bar is off.
    func setMode(_ newMode: CaptureMode) {
        guard state == .selecting, activeDisplay == nil, settings.toolbarEnabled, newMode != mode else { return }
        mode = newMode
        settings.mode = newMode
        toolbarModel?.mode = newMode
        for case let view as SelectionView in panels.map(\.contentView) { view.mode = newMode }
        (panels.first(where: \.isKeyWindow)?.contentView as? SelectionView)?.showHint()
    }

    // MARK: SelectionViewDelegate

    func selectionViewShouldBeginDrag(_ view: SelectionView) -> Bool {
        guard state == .selecting else { return false }
        if let activeDisplay, activeDisplay != view.displayID { return false }
        activeDisplay = view.displayID
        return true
    }

    func selectionView(_ view: SelectionView, didEndDragWith selection: CGRect?) {
        guard state == .selecting else { return }
        activeDisplay = nil
        guard let selection else { return }
        finish(display: view.displayID, selection: selection, displaySize: view.displaySize)
    }

    func selectionViewDidRequestCancel(_ view: SelectionView) {
        cancel()
    }

    func selectionView(_ view: SelectionView, didClickAt point: CGPoint) {
        guard state == .selecting, mode != .portion, let rect = view.target(at: point) else { return }
        finish(display: view.displayID, selection: rect, displaySize: view.displaySize)
    }

    func selectionView(_ view: SelectionView, didRequestMode mode: CaptureMode) {
        setMode(mode)
    }

    // MARK: Ending

    private func finish(display: CGDirectDisplayID, selection: CGRect, displaySize: CGSize) {
        state = .finishing
        let cropped = snapshots[display].flatMap {
            RegionCropper.crop($0.image, selection: selection, displaySize: displaySize)
        }
        tearDown()
        state = .idle
        let region = CaptureRegion(displayID: display, rect: selection)
        if let cropped {
            logger.info("captured \(cropped.width)x\(cropped.height) px")
            onCaptured(cropped, region)
        } else {
            logger.info("crop came back empty")
            onCaptureFailed(region)
        }
    }

    /// Closes the overlay and hands nothing over.
    func cancel() {
        guard state == .selecting else { return }
        tearDown()
        state = .idle
        logger.info("capture cancelled")
    }

    /// Every path back to idle goes through here, so the screen is never left dimmed.
    private func tearDown() {
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers = []
        for panel in panels {
            (panel.contentView as? SelectionView)?.releaseSnapshot()
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels = []
        toolbar?.orderOut(nil)
        toolbar?.contentView = nil
        toolbar?.close()
        toolbar = nil
        toolbarModel = nil
        snapshots = [:]
        activeDisplay = nil
        shownAt = nil
    }

    // MARK: Cancel sources

    private func watchForCancelSources() {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default

        for panel in panels {
            observe(center, NSWindow.didResignKeyNotification, object: panel) { [weak self] in
                // Clicking another display's panel moves key status between our own panels; that is fine.
                Task { @MainActor in
                    guard let self, self.state == .selecting else { return }
                    if !self.panels.contains(where: \.isKeyWindow) { self.cancel() }
                }
            }
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            // Screencopy's own activation (status window) is not another app taking over.
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self?.cancel()
            }
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in self?.cancel() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in self?.cancel() }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in
            // Showing a panel over a full screen app can fire this on its own.
            guard let self, let shownAt = self.shownAt, shownAt.duration(to: .now) > .milliseconds(200) else { return }
            self.cancel()
        }
        observe(center, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.cancel() }
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, object: AnyObject? = nil,
        handler: @escaping @MainActor () -> Void
    ) {
        let token = center.addObserver(forName: name, object: object, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append((center, token))
    }
}
