import CoreGraphics
import ScreencopyCore

/// Reads the on screen windows from the system, front most first. Only the frame, layer, and owner process
/// are read. Window names and owner names are never touched.
public struct SystemWindowLister: WindowListing {
    public init() {}

    public func frontToBackWindows() throws -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { throw ScreencopyError.captureFailed }
        return list.compactMap { entry in
            guard let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                let layer = entry[kCGWindowLayer as String] as? Int,
                let pid = entry[kCGWindowOwnerPID as String] as? Int32
            else { return nil }
            // Fully see through windows are not something the user can point at.
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha <= 0 { return nil }
            return WindowInfo(frame: frame, layer: layer, ownerProcessID: pid)
        }
    }
}
