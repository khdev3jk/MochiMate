import XCTest
@testable import MochiMate

final class ReminderSchedulerTests: XCTestCase {
    private let settings = Settings.shared
    private var savedReminders: [ReminderKind: ReminderConfig] = [:]

    override func setUp() {
        savedReminders = settings.reminders
        settings.reminders = [
            .water: ReminderConfig(enabled: true, minutes: 45),
            .move: ReminderConfig(enabled: true, minutes: 60),
            .eyes: ReminderConfig(enabled: false, minutes: 20),
        ]
    }

    override func tearDown() {
        settings.reminders = savedReminders
    }

    private func assertDue(_ scheduler: ReminderScheduler, _ kind: ReminderKind, inMinutes minutes: Int,
                           file: StaticString = #filePath, line: UInt = #line) {
        guard let due = scheduler.nextDue[kind] else { return XCTFail("\(kind) has no due time", file: file, line: line) }
        XCTAssertEqual(due.timeIntervalSinceNow, TimeInterval(minutes * 60), accuracy: 5, file: file, line: line)
    }

    func testDefaultIntervals() {
        XCTAssertEqual(ReminderKind.water.defaultMinutes, 45)
        XCTAssertEqual(ReminderKind.move.defaultMinutes, 60)
        XCTAssertEqual(ReminderKind.eyes.defaultMinutes, 20)
    }

    func testEachKindHasItsOwnLineAnimationAndEffect() {
        XCTAssertEqual(ReminderKind.allCases.map(\.lineKind), [.water, .move, .eyes])
        XCTAssertEqual(ReminderKind.allCases.map(\.anim), [.drink, .stretch, .eyerest])
        XCTAssertEqual(ReminderKind.allCases.map(\.effect), [.water, .sparkle, .eye])
    }

    func testTriggerNowShowsWhenThePetCan() {
        let scheduler = ReminderScheduler()
        var asked: [ReminderKind] = []
        scheduler.onDue = { asked.append($0); return true }

        scheduler.triggerNow(.water)

        XCTAssertEqual(asked, [.water])
        XCTAssertEqual(scheduler.showing, .water)
    }

    func testTriggerNowDoesNothingWhenThePetCant() {
        let scheduler = ReminderScheduler()
        scheduler.onDue = { _ in false }

        scheduler.triggerNow(.move)

        XCTAssertNil(scheduler.showing)
    }

    func testTriggerNowWithoutAHandlerShowsNothing() {
        let scheduler = ReminderScheduler()
        scheduler.triggerNow(.water)
        XCTAssertNil(scheduler.showing)
    }

    func testOnlyOneReminderAtATime() {
        let scheduler = ReminderScheduler()
        var asked: [ReminderKind] = []
        scheduler.onDue = { asked.append($0); return true }

        scheduler.triggerNow(.water)
        scheduler.triggerNow(.move)

        XCTAssertEqual(asked, [.water])
        XCTAssertEqual(scheduler.showing, .water)
    }

    func testResolvingRestartsTheCountdown() {
        let scheduler = ReminderScheduler()
        scheduler.onDue = { _ in true }
        scheduler.triggerNow(.water)

        scheduler.resolve(.water, .done)

        XCTAssertNil(scheduler.showing)
        assertDue(scheduler, .water, inMinutes: 45)
    }

    func testSkippedAndIgnoredAlsoWaitAFullInterval() {
        let scheduler = ReminderScheduler()
        scheduler.resolve(.water, .skipped)
        scheduler.resolve(.move, .ignored)
        assertDue(scheduler, .water, inMinutes: 45)
        assertDue(scheduler, .move, inMinutes: 60)
    }

    func testSnoozeWaitsTheSnoozeTime() {
        let scheduler = ReminderScheduler()
        scheduler.resolve(.move, .snoozed(minutes: 10))
        assertDue(scheduler, .move, inMinutes: 10)
    }

    func testSnoozeForZeroMinutesIsDueNow() {
        let scheduler = ReminderScheduler()
        scheduler.resolve(.water, .snoozed(minutes: 0))
        assertDue(scheduler, .water, inMinutes: 0)
    }

    func testResolvingAnotherKindKeepsTheShownOne() {
        let scheduler = ReminderScheduler()
        scheduler.onDue = { _ in true }
        scheduler.triggerNow(.water)

        scheduler.resolve(.move, .done)

        XCTAssertEqual(scheduler.showing, .water)
    }

    func testNextTimeIsNilForADisabledReminder() {
        let scheduler = ReminderScheduler()
        scheduler.resolve(.eyes, .done)
        scheduler.resolve(.water, .done)

        XCTAssertNil(scheduler.nextTime(.eyes))
        XCTAssertEqual(scheduler.nextTime(.water), scheduler.nextDue[.water])
    }

    func testNextTimeIsNilBeforeAnythingIsScheduled() {
        XCTAssertNil(ReminderScheduler().nextTime(.water))
    }

    func testPauseAndResume() {
        let saved = settings.pausedUntil
        defer { settings.pausedUntil = saved }
        let scheduler = ReminderScheduler()
        let until = Date().addingTimeInterval(1800)

        scheduler.pause(until: until)
        XCTAssertEqual(settings.pausedUntil, until)
        XCTAssertTrue(settings.isPaused)

        scheduler.resume()
        XCTAssertNil(settings.pausedUntil)
        XCTAssertFalse(settings.isPaused)
    }
}
