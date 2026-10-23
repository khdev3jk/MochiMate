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

    func testVersionComparisonOlderSameAndMalformed() {
        XCTAssertFalse(Updater.isNewer("1.9", than: "1.10"))
        XCTAssertFalse(Updater.isNewer("1.2", than: "1.2"))
        XCTAssertTrue(Updater.isNewer("1.0.1", than: "1.0"))
        // Parts that aren't numbers count as 0.
        XCTAssertFalse(Updater.isNewer("1.x", than: "1.0"))
        XCTAssertTrue(Updater.isNewer("1.1", than: "1.beta"))
        XCTAssertFalse(Updater.isNewer("", than: "0"))
        XCTAssertTrue(Updater.isNewer("0.0.1", than: ""))
    }

    func testWorkHoursBoundaries() {
        let s = Settings.shared
        let saved = (s.workHoursOnly, s.workStart, s.workEnd, s.workDays)
        defer { (s.workHoursOnly, s.workStart, s.workEnd, s.workDays) = saved }
        s.workHoursOnly = true; s.workStart = 9 * 60; s.workEnd = 18 * 60; s.workDays = [2, 3, 4, 5, 6]

        XCTAssertFalse(s.isWorkTime(date(weekday: 2, hour: 8, minute: 59)))
        XCTAssertTrue(s.isWorkTime(date(weekday: 2, hour: 9, minute: 1)))
        XCTAssertTrue(s.isWorkTime(date(weekday: 2, hour: 17, minute: 59)))
        XCTAssertFalse(s.isWorkTime(date(weekday: 2, hour: 18, minute: 1)))
        XCTAssertTrue(s.isWorkTime(date(weekday: 6, hour: 10)))    // Friday
        XCTAssertFalse(s.isWorkTime(date(weekday: 7, hour: 10)))   // Saturday
    }

    func testEveryTimeIsWorkTimeWhenWorkHoursAreOff() {
        let s = Settings.shared
        let saved = (s.workHoursOnly, s.workDays)
        defer { (s.workHoursOnly, s.workDays) = saved }
        s.workHoursOnly = false; s.workDays = []

        XCTAssertTrue(s.isWorkTime(date(weekday: 1, hour: 3)))
        XCTAssertTrue(s.isWorkTime(date(weekday: 7, hour: 23, minute: 59)))
    }

    func testNoWorkTimeWithoutWorkDays() {
        let s = Settings.shared
        let saved = (s.workHoursOnly, s.workStart, s.workEnd, s.workDays)
        defer { (s.workHoursOnly, s.workStart, s.workEnd, s.workDays) = saved }
        s.workHoursOnly = true; s.workStart = 9 * 60; s.workEnd = 18 * 60; s.workDays = []

        XCTAssertFalse(s.isWorkTime(date(weekday: 3, hour: 10)))
    }

    func testQuietHoursOffAndBoundaries() {
        let s = Settings.shared
        let saved = (s.quietEnabled, s.quietStart, s.quietEnd)
        defer { (s.quietEnabled, s.quietStart, s.quietEnd) = saved }
        s.quietStart = 12 * 60; s.quietEnd = 13 * 60

        s.quietEnabled = false
        XCTAssertFalse(s.isQuietTime(date(weekday: 3, hour: 12, minute: 30)))

        s.quietEnabled = true
        XCTAssertFalse(s.isQuietTime(date(weekday: 3, hour: 11, minute: 59)))
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 12)))
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 12, minute: 59)))

        // The same start and end wraps past midnight, so the whole day is quiet.
        s.quietStart = 12 * 60; s.quietEnd = 12 * 60
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 0)))
        XCTAssertTrue(s.isQuietTime(date(weekday: 3, hour: 23, minute: 59)))
    }

    func testRemindersActiveOnlyInWorkTimeOutsideQuietHoursAndNotPaused() {
        let s = Settings.shared
        let saved = (s.workHoursOnly, s.workStart, s.workEnd, s.workDays, s.quietEnabled, s.quietStart, s.quietEnd, s.pausedUntil)
        defer { (s.workHoursOnly, s.workStart, s.workEnd, s.workDays, s.quietEnabled, s.quietStart, s.quietEnd, s.pausedUntil) = saved }
        s.workHoursOnly = true; s.workStart = 9 * 60; s.workEnd = 18 * 60; s.workDays = [2, 3, 4, 5, 6]
        s.quietEnabled = true; s.quietStart = 12 * 60; s.quietEnd = 13 * 60
        s.pausedUntil = nil

        XCTAssertTrue(s.remindersActive(at: date(weekday: 2, hour: 10)))
        XCTAssertFalse(s.remindersActive(at: date(weekday: 2, hour: 12, minute: 30)))   // quiet
        XCTAssertFalse(s.remindersActive(at: date(weekday: 2, hour: 20)))               // after work

        s.pausedUntil = Date().addingTimeInterval(3600)
        XCTAssertTrue(s.isPaused)
        XCTAssertFalse(s.remindersActive(at: date(weekday: 2, hour: 10)))

        s.pausedUntil = Date().addingTimeInterval(-1)   // a pause that already ended
        XCTAssertFalse(s.isPaused)
        XCTAssertTrue(s.remindersActive(at: date(weekday: 2, hour: 10)))
    }

    func testMinuteOfDay() {
        XCTAssertEqual(Settings.minute(of: date(weekday: 2, hour: 0)), 0)
        XCTAssertEqual(Settings.minute(of: date(weekday: 2, hour: 9, minute: 30)), 570)
        XCTAssertEqual(Settings.minute(of: date(weekday: 2, hour: 23, minute: 59)), 1439)
    }
}
