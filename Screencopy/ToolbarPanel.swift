import AppKit
import ScreencopyCore
import SwiftUI

/// The state the bar shows. The coordinator owns the truth and pushes changes in.
@MainActor
@Observable
final class ToolbarModel {
    var mode: CaptureMode
    var onSelectMode: (CaptureMode) -> Void = { _ in }
    var onOptions: () -> Void = {}
    var onClose: () -> Void = {}

    init(mode: CaptureMode) {
        self.mode = mode
    }
}

/// The floating bar. A non activating panel that can never become key, so the overlay under it keeps getting
/// Escape and the number keys and the app you copy from stays active.
final class ToolbarPanel: NSPanel {
    /// Called when the user lets go of the bar after dragging it, with the fractions to save.
    var onMoved: (CGPoint) -> Void = { _ in }

    private let dockSafeFrame: CGRect
    private var lastSaved: CGRect

    init(screen: NSScreen, model: ToolbarModel, saved: CGPoint?) {
        dockSafeFrame = screen.visibleFrame
        let frame = ToolbarPlacement.frame(in: screen.visibleFrame, saved: saved)
        lastSaved = frame
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // The bar must never be read back by a later capture.
        sharingType = .none
        contentView = NSHostingView(rootView: CaptureToolbarView(model: model))
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Keeps the whole bar on its own display while it is dragged.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        ToolbarPlacement.clamped(frameRect, to: dockSafeFrame)
    }

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        switch event.type {
        case .mouseMoved:
            NSCursor.arrow.set()
        case .leftMouseUp where frame != lastSaved:
            lastSaved = frame
            if let position = ToolbarPlacement.position(of: frame, in: dockSafeFrame) { onMoved(position) }
        default:
            break
        }
    }

    /// Shows the Options menu under the pointer. A plain `NSMenu`, so this panel never needs to become key.
    func popUpMenu(_ menu: NSMenu) {
        guard let view = contentView else { return }
        let point = view.convert(mouseLocationOutsideOfEventStream, from: nil)
        menu.popUp(positioning: nil, at: point, in: view)
    }
}

struct CaptureToolbarView: View {
    let model: ToolbarModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                modeButton(mode)
            }
            Divider().frame(height: 22).padding(.horizontal, 4)
            Button(action: model.onOptions) {
                HStack(spacing: 3) {
                    Text("Options")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options")
            Button(action: model.onClose) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 8)
        .frame(width: ToolbarPlacement.size.width, height: ToolbarPlacement.size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }

    private func modeButton(_ mode: CaptureMode) -> some View {
        let selected = model.mode == mode
        return Button {
            model.onSelectMode(mode)
        } label: {
            Image(systemName: Self.symbol(for: mode))
                .frame(width: 40, height: 32)
                .background(selected ? Color.accentColor.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("\(Self.title(for: mode)) (\(String(mode.key)))")
        .accessibilityLabel(Self.accessibilityLabel(for: mode))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private static func symbol(for mode: CaptureMode) -> String {
        switch mode {
        case .portion: "rectangle.dashed"
        case .screen: "display"
        case .window: "macwindow"
        }
    }

    private static func title(for mode: CaptureMode) -> String {
        switch mode {
        case .portion: "Selected portion"
        case .screen: "Entire screen"
        case .window: "Selected window"
        }
    }

    private static func accessibilityLabel(for mode: CaptureMode) -> String {
        "Capture \(title(for: mode).lowercased())"
    }
}
