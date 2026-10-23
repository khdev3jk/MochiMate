import XCTest
@testable import MochiMate

final class ContentTests: XCTestCase {
    func testEveryCharacterHasEveryLineInEveryLanguage() {
        let settings = Settings.shared
        let saved = settings.language
        defer { settings.language = saved }
        for language in Language.allCases {
            settings.language = language
            for character in allCharacters {
                XCTAssertNotNil(ContentStore.shared.profile(for: character.id), "\(character.id) profile")
                for kind in LineKind.allCases {
                    XCTAssertNotNil(ContentStore.shared.line(kind, for: character), "\(character.id) \(language) \(kind)")
                }
            }
        }
    }

    func testEveryCharacterHasTwoNamedSkills() {
        let settings = Settings.shared
        let saved = settings.language
        defer { settings.language = saved }
        for character in allCharacters {
            XCTAssertEqual(character.skills.map(\.slot), [1, 2], character.id)
        }
        for language in Language.allCases {
            settings.language = language
            for skill in Skill.allCases { XCTAssertNotEqual(skill.title, skill.rawValue, "\(skill) \(language)") }
        }
    }

    func testLinesDontRepeatUntilAllWereSaid() {
        let character = Character.with(id: "kai")
        let count = 3   // Kai has three water lines in each language
        let ids = (0..<count).compactMap { _ in ContentStore.shared.line(.water, for: character)?.id }
        XCTAssertEqual(Set(ids).count, count)
    }

    func testPlaceholdersAreFilled() {
        let character = Character.with(id: "rin")
        for _ in 0..<6 {
            let text = ContentStore.shared.line(.water, for: character, minutes: 45)?.text ?? ""
            XCTAssertFalse(text.contains("{minutes}"))
        }
        let window = ContentStore.shared.line(.window, for: character, app: "Xcode")?.text ?? ""
        XCTAssertTrue(window.contains("Xcode"))
    }
}

final class ScheduleTests: XCTestCase {
    private func date(weekday: Int, hour: Int, minute: Int = 0) -> Date {
        // 2026-10-19 is a Monday (weekday 2).
        var c = DateComponents(year: 2026, month: 10, day: 19 + (weekday + 5) % 7, hour: hour, minute: minute)
        c.calendar = Calendar.current
        return c.date!
    }

    func testWorkHoursAndQuietHours() {
        let s = Settings.shared
        let saved = (s.workHoursOnly, s.workStart, s.workEnd, s.workDays, s.quietEnabled, s.quietStart, s.quietEnd)
        defer { (s.workHoursOnly, s.workStart, s.workEnd, s.workDays, s.quietEnabled, s.quietStart, s.quietEnd) = saved }
        s.workHoursOnly = true; s.workStart = 9 * 60; s.workEnd = 18 * 60; s.workDays = [2, 3, 4, 5, 6]
        s.quietEnabled = true; s.quietStart = 12 * 60; s.quietEnd = 13 * 60

        XCTAssertTrue(s.isWorkTime(date(weekday: 2, hour: 9)))
        XCTAssertFalse(s.isWorkTime(date(weekday: 2, hour: 18)))
        XCTAssertFalse(s.isWorkTime(date(weekday: 1, hour: 10)))   // Sunday
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 12, minute: 30)))
        XCTAssertFalse(s.isQuietTime(date(weekday: 3, hour: 13)))

        // A quiet window across midnight.
        s.quietStart = 22 * 60; s.quietEnd = 6 * 60
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 23)))
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 5)))
        XCTAssertFalse(s.isQuietTime(date(weekday: 3, hour: 7)))
    }

    func testVersionComparison() {
        XCTAssertTrue(Updater.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(Updater.isNewer("2.0", than: "1.9.9"))
        XCTAssertFalse(Updater.isNewer("1.0", than: "1.0.0"))
    }
}
