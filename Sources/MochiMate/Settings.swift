import Foundation

enum Language: String, CaseIterable, Identifiable {
    case vi, en, ja

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    static var current: Language { Settings.shared.language }

    /// The system language if it's one we have, else Vietnamese.
    static var preferred: Language {
        let code = Locale.preferredLanguages.first?.prefix(2) ?? "vi"
        return Language(rawValue: String(code)) ?? .vi
    }
}

struct ReminderConfig: Codable, Equatable {
    var enabled: Bool
    var minutes: Int
}

/// User preferences, saved in UserDefaults. Published so the settings window, the menu and the scheduler stay in sync.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var characterID: String { didSet { defaults.set(characterID, forKey: "characterID") } }
    @Published var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
    @Published var showCompanion: Bool { didSet { defaults.set(showCompanion, forKey: "showCompanion") } }
    /// Voice volume, 0...1 (see Voice).
    @Published var volume: Double { didSet { defaults.set(volume, forKey: "volume") } }

    @Published var reminders: [ReminderKind: ReminderConfig] {
        didSet { defaults.set(try? JSONEncoder().encode(reminders.mapKeys(\.rawValue)), forKey: "reminders") }
    }
    /// Only remind on work days, between workStart and workEnd (minutes after midnight).
    @Published var workHoursOnly: Bool { didSet { defaults.set(workHoursOnly, forKey: "workHoursOnly") } }
    @Published var workStart: Int { didSet { defaults.set(workStart, forKey: "workStart") } }
    @Published var workEnd: Int { didSet { defaults.set(workEnd, forKey: "workEnd") } }
    /// Calendar weekdays, 1 = Sunday.
    @Published var workDays: Set<Int> { didSet { defaults.set(Array(workDays), forKey: "workDays") } }
    /// No reminders in this window (lunch break by default).
    @Published var quietEnabled: Bool { didSet { defaults.set(quietEnabled, forKey: "quietEnabled") } }
    @Published var quietStart: Int { didSet { defaults.set(quietStart, forKey: "quietStart") } }
    @Published var quietEnd: Int { didSet { defaults.set(quietEnd, forKey: "quietEnd") } }
    /// All reminders are snoozed until this date.
    @Published var pausedUntil: Date? { didSet { defaults.set(pausedUntil, forKey: "pausedUntil") } }

    /// Kicking real Desktop icons (needs permission to control Finder), off until the user turns it on.
    @Published var kickIcons: Bool { didSet { defaults.set(kickIcons, forKey: "kickIcons") } }
    /// Perching on the frontmost window and teasing the app by name. Never touches the app itself.
    @Published var playWithWindows: Bool { didSet { defaults.set(playWithWindows, forKey: "playWithWindows") } }
    /// Random remarks between reminders.
    @Published var chatter: Bool { didSet { defaults.set(chatter, forKey: "chatter") } }
    @Published var autoUpdate: Bool { didSet { defaults.set(autoUpdate, forKey: "autoUpdate") } }

    private init() {
        let d = defaults
        characterID = d.string(forKey: "characterID") ?? "kai"
        language = d.string(forKey: "language").flatMap(Language.init) ?? .preferred
        showCompanion = d.object(forKey: "showCompanion") as? Bool ?? true
        volume = d.object(forKey: "volume") as? Double ?? 0.7
        let saved = (d.data(forKey: "reminders")).flatMap { try? JSONDecoder().decode([String: ReminderConfig].self, from: $0) } ?? [:]
        reminders = Dictionary(uniqueKeysWithValues: ReminderKind.allCases.map {
            ($0, saved[$0.rawValue] ?? ReminderConfig(enabled: true, minutes: $0.defaultMinutes))
        })
        workHoursOnly = d.object(forKey: "workHoursOnly") as? Bool ?? true
        workStart = d.object(forKey: "workStart") as? Int ?? 9 * 60
        workEnd = d.object(forKey: "workEnd") as? Int ?? 18 * 60
        workDays = Set(d.array(forKey: "workDays") as? [Int] ?? [2, 3, 4, 5, 6])
        quietEnabled = d.object(forKey: "quietEnabled") as? Bool ?? true
        quietStart = d.object(forKey: "quietStart") as? Int ?? 12 * 60
        quietEnd = d.object(forKey: "quietEnd") as? Int ?? 13 * 60
        pausedUntil = d.object(forKey: "pausedUntil") as? Date
        kickIcons = d.object(forKey: "kickIcons") as? Bool ?? false
        playWithWindows = d.object(forKey: "playWithWindows") as? Bool ?? true
        chatter = d.object(forKey: "chatter") as? Bool ?? true
        autoUpdate = d.object(forKey: "autoUpdate") as? Bool ?? true
    }

    func config(_ kind: ReminderKind) -> ReminderConfig { reminders[kind] ?? ReminderConfig(enabled: true, minutes: kind.defaultMinutes) }

    // MARK: Schedule

    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    func isWorkTime(_ date: Date) -> Bool {
        guard workHoursOnly else { return true }
        let calendar = Calendar.current
        return workDays.contains(calendar.component(.weekday, from: date))
            && Self.minute(of: date).isWithin(workStart, workEnd)
    }

    func isQuietTime(_ date: Date) -> Bool {
        quietEnabled && Self.minute(of: date).isWithin(quietStart, quietEnd)
    }

    /// Whether reminders may fire right now.
    func remindersActive(at date: Date) -> Bool {
        isWorkTime(date) && !isQuietTime(date) && !isPaused
    }

    static func minute(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

private extension Int {
    /// In [start, end), wrapping past midnight when end <= start.
    func isWithin(_ start: Int, _ end: Int) -> Bool {
        start < end ? (self >= start && self < end) : (self >= start || self < end)
    }
}

extension Dictionary {
    func mapKeys<K: Hashable>(_ transform: (Key) -> K) -> [K: Value] {
        Dictionary<K, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
