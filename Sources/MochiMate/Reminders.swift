import AppKit
import Combine

enum ReminderKind: String, CaseIterable, Codable {
    case water, move, eyes

    var defaultMinutes: Int {
        switch self {
        case .water: return 45
        case .move: return 60
        case .eyes: return 20   // the 20-20-20 rule
        }
    }

    var lineKind: LineKind {
        switch self {
        case .water: return .water
        case .move: return .move
        case .eyes: return .eyes
        }
    }

    /// What the pet does to show the reminder.
    var anim: Anim {
        switch self {
        case .water: return .drink
        case .move: return .stretch
        case .eyes: return .eyerest
        }
    }

    var effect: Effect {
        switch self {
        case .water: return .water
        case .move: return .sparkle
        case .eyes: return .eye
        }
    }

    var icon: String {
        switch self {
        case .water: return "💧"
        case .move: return "🚶"
        case .eyes: return "👀"
        }
    }

    var title: String {
        switch self {
        case .water: return ui(.reminderWater)
        case .move: return ui(.reminderMove)
        case .eyes: return ui(.reminderEyes)
        }
    }
}

enum ReminderOutcome {
    case done, skipped, ignored
    case snoozed(minutes: Int)
}

/// Decides when each reminder is due. Time only counts while reminders are active: outside work hours, during
/// quiet hours, while paused and while the user is away, the countdowns stand still.
final class ReminderScheduler {
    /// Away from the keyboard this long counts as a break: the move and eye-rest countdowns start over.
    static let breakSeconds: TimeInterval = 5 * 60

    private let settings = Settings.shared
    private(set) var nextDue: [ReminderKind: Date] = [:]
    /// The reminder being shown right now; it is not due again until it is resolved.
    private(set) var showing: ReminderKind?

    /// Asked to show a reminder. Returns false when it can't right now (it is tried again later).
    var onDue: ((ReminderKind) -> Bool)?
    /// The working day just ended.
    var onEndOfDay: (() -> Void)?

    private var timer: Timer?
    private var lastTick = Date()
    private var wasWorkTime = false
    private var observer: AnyCancellable?

    func start() {
        let now = Date()
        for kind in ReminderKind.allCases { nextDue[kind] = now + interval(kind) }
        wasWorkTime = settings.isWorkTime(now)
        var previous = settings.reminders
        // Changing an interval (or turning a reminder back on) restarts its countdown.
        observer = settings.$reminders.sink { [weak self] configs in
            guard let self else { return }
            for kind in ReminderKind.allCases where configs[kind] != previous[kind] && self.showing != kind {
                self.nextDue[kind] = Date() + TimeInterval((configs[kind]?.minutes ?? kind.defaultMinutes) * 60)
            }
            previous = configs
        }
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func interval(_ kind: ReminderKind) -> TimeInterval { TimeInterval(settings.config(kind).minutes * 60) }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now

        let workTime = settings.isWorkTime(now)
        if wasWorkTime, !workTime, settings.workHoursOnly { onEndOfDay?() }
        wasWorkTime = workTime
        if let until = settings.pausedUntil, until <= now { settings.pausedUntil = nil }

        let away = Self.secondsSinceLastInput() >= Self.breakSeconds
        if away {
            for kind in [ReminderKind.move, .eyes] where showing != kind { nextDue[kind] = now + interval(kind) }
        }
        guard settings.remindersActive(at: now), !away else {
            // Freeze the countdowns (a sleeping Mac also lands here with a large `elapsed`).
            for kind in ReminderKind.allCases where showing != kind { nextDue[kind]? += elapsed }
            return
        }
        guard showing == nil else { return }
        let due = ReminderKind.allCases
            .filter { settings.config($0).enabled && (nextDue[$0] ?? .distantFuture) <= now }
            .min { nextDue[$0]! < nextDue[$1]! }
        if let due { show(due) }
    }

    /// Shows a reminder right away (from the menu), whatever the schedule says.
    func triggerNow(_ kind: ReminderKind) {
        guard showing == nil else { return }
        show(kind)
    }

    private func show(_ kind: ReminderKind) {
        guard onDue?(kind) == true else { return }
        showing = kind
    }

    func resolve(_ kind: ReminderKind, _ outcome: ReminderOutcome) {
        if showing == kind { showing = nil }
        switch outcome {
        case .done, .skipped, .ignored:
            nextDue[kind] = Date() + interval(kind)
        case .snoozed(let minutes):
            nextDue[kind] = Date() + TimeInterval(minutes * 60)
        }
    }

    func pause(until date: Date) { settings.pausedUntil = date }
    func resume() { settings.pausedUntil = nil }

    /// When the reminder will next show, or nil when it is off.
    func nextTime(_ kind: ReminderKind) -> Date? {
        settings.config(kind).enabled ? nextDue[kind] : nil
    }

    static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
