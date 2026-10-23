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

extension ReminderKind {
    static let variants = 3

    /// What fills the screen when the reminder is due, so it can't be missed: one of `variants` looks per kind, picked
    /// at random by the caller. Later call-outs are a lighter pulse.
    func cast(_ fx: SkillFX, intense: Bool, variant: Int) {
        let W = fx.size.width, H = fx.size.height
        let tint: UInt32
        switch self {
        case .water: tint = 0x38BDF8
        case .move: tint = 0xFB923C
        case .eyes: tint = 0xA78BFA
        }
        fx.ring(at: fx.body, color: color(tint), width: 16, duration: 1.1)
        fx.ring(at: fx.body, color: color(tint), width: 10, duration: 1.1, delay: 0.35)
        guard intense else {
            fx.pop(icon, 200, at: CGPoint(x: fx.head.x, y: fx.head.y + 110), hold: 0.8)
            return
        }
        let middle = CGPoint(x: W / 2, y: H / 2), upper = CGPoint(x: W / 2, y: H * 0.56)
        fx.flash(color(tint), peak: 0.35, duration: 1.2)
        fx.glow(at: middle, diameter: min(W, H) * 1.3, color: color(tint), duration: 3.5)
        fx.pop(title, 120, at: CGPoint(x: W / 2, y: H * 0.34), color: .white, hold: 2.0, delay: 0.2)

        switch (self, variant % Self.variants) {
        // Water: a downpour of drops; a tide rising from the bottom; a fountain.
        case (.water, 0):
            fx.rain(["💧", "🥤", "💦"], 100, rate: 14, seconds: 2.6)
            fx.pop(icon, 380, at: upper, hold: 2.2)
        case (.water, 1):
            fx.gradient([color(0x0EA5E9, 0.8), color(0x38BDF8, 0)], frame: CGRect(x: 0, y: 0, width: W, height: H * 0.6),
                        start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1), duration: 3.2)
            fx.rise(["🫧", "💧", "🐟"], 90, rate: 14, seconds: 2.6)
            fx.pop("🥤", 380, at: upper, hold: 2.2)
        case (.water, _):
            fx.burst(["💧", "💦", "🫧"], 90, at: CGPoint(x: W / 2, y: 0), rate: 120, seconds: 1.6, velocity: 1500,
                     longitude: .pi / 2, spread: .pi / 4, gravity: -1100, life: 3.2)
            fx.pop("🚰", 380, at: upper, hold: 2.2)

        // Move: a stampede of walkers; runners dashing across; a burst of effort.
        case (.move, 0):
            fx.rain(["🚶", "💪", "🏃"], 100, rate: 14, seconds: 2.6)
            fx.pop(icon, 380, at: upper, hold: 2.2)
        case (.move, 1):
            for (i, y) in [H * 0.2, H * 0.5, H * 0.8].enumerated() {
                fx.fly("🏃", 220, from: CGPoint(x: -200, y: y), to: CGPoint(x: W + 200, y: y), duration: 1.6, delay: Double(i) * 0.5,
                       trail: "💨", trailPx: 100)
            }
            fx.pop("💪", 380, at: upper, hold: 2.2, delay: 0.4)
        case (.move, _):
            fx.burst(["🔥", "💪", "⚡️", "✨"], 100, at: middle, rate: 140, seconds: 0.8, velocity: 1100, gravity: -500, life: 2.4)
            fx.ring(at: middle, color: color(tint), width: 22, duration: 1.4, delay: 0.2)
            fx.pop("🧘", 380, at: upper, hold: 2.2)

        // Eyes: raining eyes; one giant eye with ripples; a view into the distance.
        case (.eyes, 0):
            fx.rain(["👀", "✨", "🌙"], 100, rate: 14, seconds: 2.6)
            fx.pop(icon, 380, at: upper, hold: 2.2)
        case (.eyes, 1):
            for i in 0..<4 { fx.ring(at: upper, radius: 60, scale: 14, color: color(tint), width: 12, duration: 1.6, delay: Double(i) * 0.5) }
            fx.pop("👁️", 420, at: upper, hold: 2.4)
            fx.rise(["✨", "💫"], 70, rate: 10, seconds: 2.4)
        case (.eyes, _):
            fx.rise(["🌿", "☁️", "🦋"], 100, rate: 12, seconds: 2.6, speed: 200)
            fx.pop("🏞️", 400, at: upper, hold: 2.4)
        }
    }
}
