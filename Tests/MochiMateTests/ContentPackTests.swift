import XCTest
@testable import MochiMate

final class ContentPackTests: XCTestCase {
    private func decodeEntry(_ json: String) throws -> ContentPack.Entry {
        try JSONDecoder().decode(ContentPack.Entry.self, from: Data(json.utf8))
    }

    func testEntryFromPlainText() throws {
        let entry = try decodeEntry(#""Uống nước nào!""#)
        XCTAssertEqual(entry.text, "Uống nước nào!")
        XCTAssertNil(entry.id)
        XCTAssertNil(entry.anim)
        XCTAssertNil(entry.effect)
        XCTAssertNil(entry.audio)
    }

    func testEntryFromObject() throws {
        let entry = try decodeEntry(#"{"id": "kai.en.water.9", "text": "Drink!", "anim": "drink", "effect": "water", "audio": "audio/en/x.m4a"}"#)
        XCTAssertEqual(entry.id, "kai.en.water.9")
        XCTAssertEqual(entry.text, "Drink!")
        XCTAssertEqual(entry.anim, "drink")
        XCTAssertEqual(entry.effect, "water")
        XCTAssertEqual(entry.audio, "audio/en/x.m4a")
    }

    func testEntryObjectWithOnlyText() throws {
        let entry = try decodeEntry(#"{"text": "Hi"}"#)
        XCTAssertEqual(entry.text, "Hi")
        XCTAssertNil(entry.id)
    }

    func testEntryWithEmptyText() throws {
        XCTAssertEqual(try decodeEntry(#""""#).text, "")
    }

    func testEntryWithoutTextFails() {
        XCTAssertThrowsError(try decodeEntry(#"{"id": "x"}"#))
    }

    func testEntryOfTheWrongTypeFails() {
        XCTAssertThrowsError(try decodeEntry("42"))
        XCTAssertThrowsError(try decodeEntry(#"{"text": 42}"#))
    }

    func testLoadFromAFolderWithoutAPack() {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertNil(ContentStore.load(from: empty))
    }

    func testLoadAnInvalidPack() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("{ not json".utf8).write(to: folder.appendingPathComponent("content.json"))

        XCTAssertNil(ContentStore.load(from: folder))
    }

    func testBundledPackLoads() {
        let pack = ContentStore.load(from: ContentStore.bundledDirectory)
        XCTAssertNotNil(pack)
        XCTAssertGreaterThan(pack?.version ?? 0, 0)
    }

    func testLineIDsNameCharacterLanguageAndKind() {
        let settings = Settings.shared
        let saved = settings.language
        defer { settings.language = saved }
        settings.language = .en

        let line = ContentStore.shared.line(.hello, for: Character.with(id: "kai"))
        XCTAssertEqual(line?.language, .en)
        XCTAssertTrue(line?.id.contains(".en.hello.") ?? false, line?.id ?? "nil")
    }

    func testMissingPlaceholderValuesLeaveNoBraces() {
        let character = Character.with(id: "rin")
        for _ in 0..<6 {
            let text = ContentStore.shared.line(.window, for: character)?.text ?? ""
            XCTAssertFalse(text.contains("{app}"), text)
        }
    }
}
