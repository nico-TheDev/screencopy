import Foundation
import Testing

@testable import ScreencopyCore
@testable import ScreencopyHistory

@Suite struct FileHistoryStoreTests {
    private let root: URL
    private var folder: URL { root.appending(path: "store") }
    private var file: URL { folder.appending(path: "history.json") }
    private var backup: URL { folder.appending(path: "history.json.bak") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "screencopy-history-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func entries(_ texts: [String]) -> [HistoryEntry] {
        texts.enumerated().map { index, text in
            HistoryEntry(
                id: UUID(), text: text, capturedAt: Date(timeIntervalSince1970: 1_700_000_000.25 + Double(index)),
                wasShortened: index == 1)
        }
    }

    private func mode(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? Int ?? -1) & 0o777
    }

    private func cleanUp() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func savedListComesBackInOrderAfterARestart() async throws {
        defer { cleanUp() }
        let saved = entries(["one\nline two", "two", "ünï 😀 three"])
        try await FileHistoryStore(directory: folder).save(saved)
        let loaded = await FileHistoryStore(directory: folder).load()
        #expect(loaded == saved)
    }

    @Test func missingFileStartsEmptyWithoutABackup() async {
        defer { cleanUp() }
        #expect(await FileHistoryStore(directory: folder).load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func fileAndFolderAreOwnerOnlyAfterEveryWrite() async throws {
        defer { cleanUp() }
        let store = FileHistoryStore(directory: folder)
        try await store.save(entries(["a"]))
        #expect(try mode(file) == 0o600)
        try await store.save(entries(["a", "b"]))
        #expect(try mode(file) == 0o600)
        #expect(try mode(folder) == 0o700)
    }

    @Test func loadFixesAFolderThatWasTooOpen() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        _ = await FileHistoryStore(directory: folder).load()
        #expect(try mode(folder) == 0o700)
    }

    @Test func folderIsExcludedFromBackups() async throws {
        defer { cleanUp() }
        _ = await FileHistoryStore(directory: folder).load()
        let values = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func garbageStartsEmptyAndIsSetAside() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json at all".utf8).write(to: file)
        try Data("older".utf8).write(to: backup)
        #expect(await FileHistoryStore(directory: folder).load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(try String(contentsOf: backup, encoding: .utf8) == "not json at all")
        #expect(try mode(backup) == 0o600)
    }

    @Test func unknownVersionIsTreatedAsABadFile() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"version":2,"entries":[]}"#.utf8).write(to: file)
        #expect(await FileHistoryStore(directory: folder).load().isEmpty)
        #expect(FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func savingNeverLeavesATempFileBehind() async throws {
        defer { cleanUp() }
        let store = FileHistoryStore(directory: folder)
        for count in 1...5 { try await store.save(entries(Array(repeating: "x", count: count))) }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names == ["history.json"])
    }

    @Test func aFailedSaveThrowsAndKeepsTheOldFile() async throws {
        defer { cleanUp() }
        let store = FileHistoryStore(directory: folder)
        let good = entries(["keep me"])
        try await store.save(good)
        // The store resets the folder mode itself, so block the save another way: the folder is under a file.
        let blocked = FileHistoryStore(directory: file.appending(path: "nested"))
        await #expect(throws: (any Error).self) { try await blocked.save(good) }
        #expect(await FileHistoryStore(directory: folder).load() == good)
    }

    @Test func clearingWritesAValidEmptyFile() async throws {
        defer { cleanUp() }
        let store = FileHistoryStore(directory: folder)
        try await store.save(entries(["secret"]))
        try await store.save([])
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("secret"))
        #expect(await store.load().isEmpty)
    }

    @Test func removeBackupDeletesIt() async throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: backup)
        let store = FileHistoryStore(directory: folder)
        try await store.removeBackup()
        #expect(!FileManager.default.fileExists(atPath: backup.path))
        try await store.removeBackup()
    }
}
