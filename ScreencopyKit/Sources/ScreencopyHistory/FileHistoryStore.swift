import Darwin
import Foundation
import ScreencopyCore
import os

/// History in one JSON file. Only the user can read it (folder 0700, file 0600), the folder is kept out
/// of Time Machine, and every write goes to a temp file first and is renamed over the old one.
/// Text is never logged: errors are reported by type only.
public actor FileHistoryStore: HistoryStoring {
    static let currentVersion = 1
    static let fileName = "history.json"
    static let backupName = "history.json.bak"

    private struct File: Codable {
        let version: Int
        let entries: [HistoryEntry]
    }

    private let directory: URL
    private let logger = Logger(subsystem: "com.norbertoignacio.screencopy", category: "history")

    public init(directory: URL) {
        self.directory = directory
    }

    private var fileURL: URL { directory.appending(path: Self.fileName) }
    private var backupURL: URL { directory.appending(path: Self.backupName) }

    // MARK: HistoryStoring

    public func load() -> [HistoryEntry] {
        do {
            try prepareDirectory()
        } catch {
            logger.error("history folder could not be prepared: \(String(describing: type(of: error)))")
            return []
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let file = try Self.decoder.decode(File.self, from: Data(contentsOf: fileURL))
            guard file.version == Self.currentVersion else { throw CocoaError(.fileReadCorruptFile) }
            return file.entries
        } catch {
            logger.error("history file could not be read: \(String(describing: type(of: error)))")
            setAside()
            return []
        }
    }

    public func save(_ entries: [HistoryEntry]) throws {
        try prepareDirectory()
        let data = try Self.encoder.encode(File(version: Self.currentVersion, entries: entries))
        try write(data, to: fileURL)
    }

    public func removeBackup() throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try FileManager.default.removeItem(at: backupURL)
    }

    // MARK: Folder

    /// Runs at every launch and before every save, so the rules hold even if the folder was changed by hand.
    private func prepareDirectory() throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = directory
        try url.setResourceValues(values)
    }

    // MARK: Files

    /// A temp file created as 0600 in the same folder, flushed, then renamed over the target.
    private func write(_ data: Data, to target: URL) throws {
        let temp = directory.appending(path: "\(Self.fileName).tmp-\(UUID().uuidString)")
        let descriptor = open(temp.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        do {
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            // The mask can only remove bits, but set the mode outright so it never depends on it.
            guard fchmod(descriptor, 0o600) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            guard rename(temp.path, target.path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }

    /// Renames a file that cannot be read to `history.json.bak`, replacing an older one.
    private func setAside() {
        let manager = FileManager.default
        do {
            try? manager.removeItem(at: backupURL)
            try manager.moveItem(at: fileURL, to: backupURL)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
        } catch {
            logger.error("bad history file could not be set aside: \(String(describing: type(of: error)))")
        }
    }

    // MARK: Coding

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            return try dateStyle.parse(string)
        }
        return decoder
    }

    /// ISO 8601 with fractional seconds, for example 2026-10-28T09:30:00.250Z.
    private static var dateStyle: Date.ISO8601FormatStyle { Date.ISO8601FormatStyle(includingFractionalSeconds: true) }
}
