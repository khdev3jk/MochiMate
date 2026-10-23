import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var updater: Updater
    /// Shows a reminder right away, to try it out.
    let test: (ReminderKind) -> Void

    var body: some View {
        TabView {
            CharacterTab(settings: settings)
                .tabItem { Label(ui(.tabCharacter), systemImage: "person.crop.circle") }
            RemindersTab(settings: settings, test: test)
                .tabItem { Label(ui(.tabReminders), systemImage: "bell") }
            ScheduleTab(settings: settings)
                .tabItem { Label(ui(.tabSchedule), systemImage: "calendar") }
            BehaviorTab(settings: settings)
                .tabItem { Label(ui(.tabBehavior), systemImage: "sparkles") }
            UpdatesTab(settings: settings, updater: updater)
                .tabItem { Label(ui(.tabUpdates), systemImage: "arrow.down.circle") }
        }
        .padding()
        .frame(width: 600, height: 560)
        .environment(\.locale, Locale(identifier: settings.language.rawValue))
    }
}

// MARK: - Character

private struct CharacterTab: View {
    @ObservedObject var settings: Settings
    private static let portraits = Dictionary(uniqueKeysWithValues: allCharacters.map { ($0.id, SpriteSheet.portrait($0.id)) })

    var body: some View {
        let selected = Character.with(id: settings.characterID)
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(allCharacters, id: \.id) { character in
                        card(character, selected: character.id == selected.id)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selected.name) · \(selected.profession.title)").font(.headline)
                    Text(selected.bio).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Toggle(ui(.showCompanion), isOn: $settings.showCompanion)
            }
            Section {
                Picker(ui(.language), selection: $settings.language) {
                    ForEach(Language.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent(ui(.volume)) {
                    Slider(value: $settings.volume, in: 0...1)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func card(_ character: Character, selected: Bool) -> some View {
        Button {
            settings.characterID = character.id
        } label: {
            VStack(spacing: 2) {
                if let image = Self.portraits[character.id] ?? nil {
                    Image(nsImage: image).resizable().interpolation(.high).frame(width: 76, height: 76)
                }
                Text(character.name).font(.callout.weight(.semibold))
                Text(character.profession.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.18) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25),
                                                               lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reminders

private struct RemindersTab: View {
    @ObservedObject var settings: Settings
    let test: (ReminderKind) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(ReminderKind.allCases, id: \.self) { kind in
                    HStack {
                        Toggle("\(kind.icon) \(kind.title)", isOn: enabled(kind))
                        Spacer()
                        Stepper(ui(.everyMinutes, "\(settings.config(kind).minutes)"), value: minutes(kind), in: 5...240, step: 5)
                            .disabled(!settings.config(kind).enabled)
                        Button(ui(.tryNow)) { test(kind) }
                    }
                }
                Text(ui(.remindersExplain)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section(ui(.pauseReminders)) {
                if let until = settings.pausedUntil, until > Date() {
                    HStack {
                        Text(ui(.pausedUntil, AppDelegate.time(until)))
                        Spacer()
                        Button(ui(.resumeReminders)) { settings.pausedUntil = nil }
                    }
                } else {
                    HStack {
                        ForEach([15, 30, 60, 120], id: \.self) { m in
                            Button(m < 60 ? ui(.minutesShort, "\(m)") : ui(.hoursShort, "\(m / 60)")) {
                                settings.pausedUntil = Date() + TimeInterval(m * 60)
                            }
                        }
                        Button(ui(.restOfToday)) {
                            settings.pausedUntil = Calendar.current.startOfDay(for: Date() + 86_400)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func enabled(_ kind: ReminderKind) -> Binding<Bool> {
        Binding(get: { settings.config(kind).enabled }, set: { settings.reminders[kind]?.enabled = $0 })
    }

    private func minutes(_ kind: ReminderKind) -> Binding<Int> {
        Binding(get: { settings.config(kind).minutes }, set: { settings.reminders[kind]?.minutes = $0 })
    }
}

// MARK: - Schedule

private struct ScheduleTab: View {
    @ObservedObject var settings: Settings
    /// Monday first.
    private let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        Form {
            Section(ui(.workHours)) {
                Toggle(ui(.workHoursOnly), isOn: $settings.workHoursOnly)
                HStack {
                    DatePicker(ui(.from), selection: time(\.workStart), displayedComponents: .hourAndMinute)
                    DatePicker(ui(.to), selection: time(\.workEnd), displayedComponents: .hourAndMinute)
                }
                .disabled(!settings.workHoursOnly)
                HStack(spacing: 6) {
                    ForEach(weekdays, id: \.self) { day in
                        Toggle(weekdayName(day), isOn: workDay(day)).toggleStyle(.button)
                    }
                }
                .disabled(!settings.workHoursOnly)
            }
            Section(ui(.quietHours)) {
                Toggle(ui(.quietHoursOn), isOn: $settings.quietEnabled)
                HStack {
                    DatePicker(ui(.from), selection: time(\.quietStart), displayedComponents: .hourAndMinute)
                    DatePicker(ui(.to), selection: time(\.quietEnd), displayedComponents: .hourAndMinute)
                }
                .disabled(!settings.quietEnabled)
                Text(ui(.scheduleExplain)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func time(_ keyPath: ReferenceWritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(get: { Calendar.current.startOfDay(for: Date()) + TimeInterval(settings[keyPath: keyPath] * 60) },
                set: { settings[keyPath: keyPath] = Settings.minute(of: $0) })
    }

    private func workDay(_ day: Int) -> Binding<Bool> {
        Binding(get: { settings.workDays.contains(day) },
                set: { on in if on { settings.workDays.insert(day) } else { settings.workDays.remove(day) } })
    }

    private func weekdayName(_ day: Int) -> String {
        switch settings.language {
        case .vi: return day == 1 ? "CN" : "T\(day)"
        case .en: return Calendar.current.shortWeekdaySymbols[day - 1]
        case .ja: return ["日", "月", "火", "水", "木", "金", "土"][day - 1]
        }
    }
}

// MARK: - Behavior

private struct BehaviorTab: View {
    @ObservedObject var settings: Settings
    /// The system owns this state (the user can also change it in System Settings), so it's read back, not stored.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { launchAtLogin }, set: { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {}
            launchAtLogin = SMAppService.mainApp.status == .enabled
        })
    }

    var body: some View {
        Form {
            Section {
                Toggle(ui(.launchAtLogin), isOn: launchAtLoginBinding)
                    .disabled(!Updater.canUpdate)
                Toggle(ui(.chatter), isOn: $settings.chatter)
                toggle(ui(.playWithWindows), ui(.playWithWindowsExplain), $settings.playWithWindows)
                toggle(ui(.kickIcons), ui(.kickIconsExplain), $settings.kickIcons)
                if settings.kickIcons {
                    Button(ui(.openAutomation)) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func toggle(_ title: String, _ explain: String, _ value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: value)
            Text(explain).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Updates

private struct UpdatesTab: View {
    @ObservedObject var settings: Settings
    @ObservedObject var updater: Updater

    var body: some View {
        Form {
            Section {
                LabeledContent(ui(.appVersion), value: Updater.currentVersion)
                LabeledContent(ui(.contentVersion), value: "\(updater.contentVersion)")
                Toggle(ui(.autoUpdate), isOn: $settings.autoUpdate)
                HStack {
                    Button(ui(.checkNow)) { updater.check() }
                        .disabled(updater.state == .checking || updater.state == .installing)
                    Spacer()
                    status
                }
                Text(ui(.updatesExplain)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var status: some View {
        switch updater.state {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .upToDate: Text(ui(.upToDate)).foregroundStyle(.secondary)
        case .installing: Text(ui(.installingUpdate)).foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.red).lineLimit(2)
        case .available(let version, _):
            if Updater.canUpdate {
                Button(ui(.updateAvailable, version)) { updater.install() }.buttonStyle(.borderedProminent)
            } else {
                Text(ui(.updateAvailable, version))
            }
        }
    }
}
