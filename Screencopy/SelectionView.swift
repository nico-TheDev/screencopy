import AppKit
import ScreencopyCore

@MainActor
protocol SelectionViewDelegate: AnyObject {
    /// Asks whether this display may start a drag. Only one display at a time may.
    func selectionViewShouldBeginDrag(_ view: SelectionView) -> Bool
    /// The mouse went up. `selection` is nil when the box was too small to count.
    func selectionView(_ view: SelectionView, didEndDragWith selection: CGRect?)
    func selectionViewDidRequestCancel(_ view: SelectionView)
    /// A click in screen or window mode. The view knows what the click would pick (`target(at:)`).
    func selectionView(_ view: SelectionView, didClickAt point: CGPoint)
    /// One of the number keys. Ignored by the coordinator when the toolbar is off.
    func selectionView(_ view: SelectionView, didRequestMode mode: CaptureMode)
}

/// Draws the frozen picture of one display, dims it, and lets the user drag a clear box.
/// Flipped, so every point here is already top left and display local, like a `CGImage`.
final class SelectionView: NSView {
    let displayID: CGDirectDisplayID
    let displaySize: CGSize
    weak var delegate: SelectionViewDelegate?

    /// What a click does. Changing it clears any hover and updates the hint and cursor.
    var mode = CaptureMode.portion {
        didSet {
            guard mode != oldValue else { return }
            hint.stringValue = mode.hint
            refreshHover()
            updateLayers()
            currentCursor.set()
        }
    }
    /// Pickable windows on this display, display local, front to back. Empty when the list could not be read.
    var windowRects: [CGRect] = []
    /// Whether the number keys switch modes. Off when the toolbar is off.
    var modeKeysEnabled = false

    private let scale: CGFloat
    private let pixelBounds: CGRect
    private let dimLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let outlineLayer = CAShapeLayer()
    private let readout = SelectionView.makeLabel(fontSize: 12)
    private let hint = SelectionView.makeLabel(fontSize: 14)
    private var anchor: CGPoint?
    private var selection: CGRect?
    private var hintFade: Task<Void, Never>?
    private var hoverRect: CGRect?

    init(snapshot: DisplaySnapshot, displaySize: CGSize) {
        displayID = snapshot.displayID
        self.displaySize = displaySize
        scale = CGFloat(snapshot.image.width) / displaySize.width
        pixelBounds = CGRect(x: 0, y: 0, width: snapshot.image.width, height: snapshot.image.height)
        super.init(frame: CGRect(origin: .zero, size: displaySize))
        wantsLayer = true
        layer?.contents = snapshot.image
        layer?.contentsGravity = .resize
        dimLayer.fillColor = NSColor.black.withAlphaComponent(0.45).cgColor
        dimLayer.fillRule = .evenOdd
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.white.cgColor
        borderLayer.lineWidth = 1
        layer?.addSublayer(dimLayer)
        layer?.addSublayer(borderLayer)
        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = NSColor.controlAccentColor.cgColor
        outlineLayer.lineWidth = 2
        layer?.addSublayer(outlineLayer)
        readout.isHidden = true
        hint.isHidden = true
        hint.stringValue = mode.hint
        addSubview(readout)
        addSubview(hint)
        updateLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Showing and releasing

    /// Shows the hint near the top, then fades it out after about 3 seconds.
    func showHint() {
        hintFade?.cancel()
        hint.sizeToFit()
        hint.frame = padded(hint.frame)
        hint.frame.origin = CGPoint(x: (bounds.width - hint.frame.width) / 2, y: 48)
        hint.alphaValue = 1
        hint.isHidden = false
        hintFade = Task { @MainActor [hint] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                hint.animator().alphaValue = 0
            }
        }
    }

    /// Drops the picture so the memory can be freed as soon as the capture ends.
    func releaseSnapshot() {
        hintFade?.cancel()
        layer?.contents = nil
        dimLayer.path = nil
        borderLayer.path = nil
        outlineLayer.path = nil
        selection = nil
        anchor = nil
        hoverRect = nil
        windowRects = []
    }

    /// What a click at `point` would capture in the current mode, or nil when nothing is pickable there.
    func target(at point: CGPoint) -> CGRect? {
        switch mode {
        case .portion: nil
        case .screen: bounds
        case .window: WindowHitTester.window(at: point, in: windowRects)
        }
    }

    /// Recomputes the hover from where the mouse is right now (after a mode change or when the overlay appears).
    func refreshHover() {
        guard let window else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        updateHover(at: bounds.contains(point) ? point : nil)
    }

    private var currentCursor: NSCursor { mode == .portion ? .crosshair : .arrow }

    private func updateHover(at point: CGPoint?) {
        let rect = point.flatMap { anchor == nil ? target(at: $0) : nil }
        guard rect != hoverRect else { return }
        hoverRect = rect
        updateLayers()
    }

    func requestCancel() {
        delegate?.selectionViewDidRequestCancel(self)
    }

    // MARK: Mouse and keyboard

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.activeAlways, .cursorUpdate, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        currentCursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        // Cursor rects only work in the active app, and this app is not active.
        currentCursor.set()
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        updateHover(at: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard mode == .portion else { return }
        guard delegate?.selectionViewShouldBeginDrag(self) == true else { return }
        anchor = clamped(convert(event.locationInWindow, from: nil))
        selection = nil
        updateLayers()
    }

    override func mouseDragged(with event: NSEvent) {
        currentCursor.set()
        guard let anchor else { return }
        let point = clamped(convert(event.locationInWindow, from: nil))
        selection = CGRect(
            x: min(anchor.x, point.x), y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
        updateLayers()
        updateReadout(near: point)
    }

    override func mouseUp(with event: NSEvent) {
        if mode != .portion {
            delegate?.selectionView(self, didClickAt: convert(event.locationInWindow, from: nil))
            return
        }
        guard anchor != nil else { return }
        anchor = nil
        readout.isHidden = true
        let box = selection.flatMap { RegionCropper.isUsable($0) ? $0 : nil }
        if box == nil {
            selection = nil
            updateLayers()
        }
        delegate?.selectionView(self, didEndDragWith: box)
    }

    override func rightMouseDown(with event: NSEvent) {
        requestCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            requestCancel()
        } else if modeKeysEnabled, anchor == nil, event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
            let key = event.charactersIgnoringModifiers?.first, let newMode = CaptureMode(key: key)
        {
            delegate?.selectionView(self, didRequestMode: newMode)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        requestCancel()
    }

    // MARK: Drawing

    override func layout() {
        super.layout()
        updateLayers()
    }

    private func updateLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.frame = bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        if let selection {
            path.addRect(selection)
        } else if let hoverRect {
            path.addRect(hoverRect)
        }
        dimLayer.path = path
        borderLayer.frame = bounds
        borderLayer.path = selection.map { CGPath(rect: $0, transform: nil) }
        outlineLayer.frame = bounds
        // Window mode only. Inset by half the line so the outline stays inside the display.
        outlineLayer.path =
            mode == .window && selection == nil
            ? hoverRect.map { CGPath(rect: $0.insetBy(dx: 1, dy: 1), transform: nil) } : nil
        CATransaction.commit()
    }

    private func updateReadout(near cursor: CGPoint) {
        guard let selection else { return }
        let pixels = RegionCropper.pixelRect(for: selection, scale: scale, bounds: pixelBounds)
        readout.stringValue = "\(Int(pixels.width)) × \(Int(pixels.height)) px"
        readout.sizeToFit()
        readout.frame = padded(readout.frame)
        let gap: CGFloat = 12
        var origin = CGPoint(x: cursor.x + gap, y: cursor.y + gap)
        if origin.x + readout.frame.width > bounds.maxX { origin.x = cursor.x - gap - readout.frame.width }
        if origin.y + readout.frame.height > bounds.maxY { origin.y = cursor.y - gap - readout.frame.height }
        readout.frame.origin = origin
        readout.isHidden = false
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }

    private func padded(_ frame: CGRect) -> CGRect {
        CGRect(origin: frame.origin, size: CGSize(width: frame.width + 16, height: frame.height + 8))
    }

    private static func makeLabel(fontSize: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.drawsBackground = true
        label.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        label.wantsLayer = true
        label.layer?.cornerRadius = 5
        label.layer?.masksToBounds = true
        return label
    }
}
