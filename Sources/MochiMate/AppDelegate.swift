import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let world = World()
    private let updater = Updater()
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuBarIcon
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        world.contextMenu = { [weak self] pet in self?.petMenu(pet) }
        world.start()
        updater.onInstallFailed = { message in
            let alert = NSAlert()
            alert.messageText = ui(.updateFailed)
            alert.informativeText = message
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        updater.startAutomaticChecks()
    }

    // MARK: Menu bar

    /// The mochi face as a template image, so the menu bar tints it for light, dark and highlighted states.
    private static let menuBarIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            let body = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 17, height: 11.5), xRadius: 8.5, yRadius: 5.5)
            body.lineWidth = 1.6
            body.stroke()
            for x in [6.8, 13.2] { NSBezierPath(ovalIn: NSRect(x: x - 1, y: 6, width: 2, height: 2.6)).fill() }
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 8.6, y: 5.2))
            smile.curve(to: NSPoint(x: 11.4, y: 5.2), controlPoint1: NSPoint(x: 9.3, y: 3.9), controlPoint2: NSPoint(x: 10.7, y: 3.9))
            smile.lineWidth = 1.2
            smile.lineCapStyle = .round
            smile.stroke()
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: 10, y: 17.5))
            drop.curve(to: NSPoint(x: 10, y: 13.6), controlPoint1: NSPoint(x: 12.4, y: 15.4), controlPoint2: NSPoint(x: 12.4, y: 13.6))
            drop.curve(to: NSPoint(x: 10, y: 17.5), controlPoint1: NSPoint(x: 7.6, y: 13.6), controlPoint2: NSPoint(x: 7.6, y: 15.4))
            drop.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let character = Character.with(id: settings.characterID)
        menu.addItem(withTitle: "\(character.name) · \(character.profession.title)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for line in statusLines() { menu.addItem(withTitle: line, action: nil, keyEquivalent: "") }
        menu.addItem(.separator())

        menu.addItem(submenu(ui(.remindNow), items: ReminderKind.allCases.map { kind in
            ActionItem("\(kind.icon) \(kind.title)") { [weak self] in self?.world.scheduler.triggerNow(kind) }
        }))
        menu.addItem(skillsItem())
        if settings.isPaused {
            menu.addItem(ActionItem(ui(.resumeReminders)) { [weak self] in self?.world.scheduler.resume() })
        } else {
            menu.addItem(submenu(ui(.pauseReminders), items: pauseItems()))
        }
        menu.addItem(.separator())

        menu.addItem(submenu(ui(.characters), items: allCharacters.map { c in
            ActionItem("\(c.name) — \(c.profession.title)", checked: c.id == settings.characterID) { [weak self] in
                self?.settings.characterID = c.id
                self?.settings.showCompanion = true
            }
        }))
        menu.addItem(ActionItem(ui(.showCompanion), checked: settings.showCompanion) { [weak self] in
            guard let self else { return }
            self.settings.showCompanion.toggle()
        })
        menu.addItem(ActionItem(ui(.settings), key: ",") { [weak self] in self?.openSettings() })
        menu.addItem(.separator())
        menu.addItem(updateItem())
        menu.addItem(ActionItem(ui(.quit), key: "q") { NSApp.terminate(nil) })
    }

    /// What's coming up: pause, off hours, or the time of each next reminder.
    private func statusLines() -> [String] {
        let now = Date()
        if let until = settings.pausedUntil, until > now { return [ui(.pausedUntil, Self.time(until))] }
        if !settings.isWorkTime(now) { return [ui(.offHours)] }
        if settings.isQuietTime(now) { return [ui(.quietNow)] }
        return ReminderKind.allCases.compactMap { kind in
            if world.scheduler.showing == kind { return "\(kind.icon) \(kind.title): \(ui(.showingNow))" }
            return world.scheduler.nextTime(kind).map { "\(kind.icon) \(kind.title): \(Self.time(max($0, now)))" }
        }
    }

    private func pauseItems() -> [NSMenuItem] {
        let durations = [(15, ui(.minutes15)), (30, ui(.minutes30)), (60, ui(.hour1)), (120, ui(.hours2))]
        var items = durations.map { minutes, title in
            ActionItem(title) { [weak self] in self?.world.scheduler.pause(until: Date() + TimeInterval(minutes * 60)) }
        }
        items.append(ActionItem(ui(.restOfToday)) { [weak self] in
            let tomorrow = Calendar.current.startOfDay(for: Date() + 86_400)
            self?.world.scheduler.pause(until: tomorrow)
        })
        return items
    }

    private func updateItem() -> NSMenuItem {
        switch updater.state {
        case .available(let version, _) where Updater.canUpdate:
            return ActionItem(ui(.updateAvailable, version)) { [weak self] in self?.updater.install() }
        case .checking:
            return NSMenuItem(title: ui(.checkingUpdates), action: nil, keyEquivalent: "")
        case .installing:
            return NSMenuItem(title: ui(.installingUpdate), action: nil, keyEquivalent: "")
        default:
            return ActionItem(ui(.checkUpdates, Updater.currentVersion)) { [weak self] in self?.updater.check() }
        }
    }

    /// The current character's two skills, cast on the spot.
    private func skillsItem() -> NSMenuItem {
        submenu(ui(.skills), items: Character.with(id: settings.characterID).skills.map { skill in
            ActionItem(skill.title) { [weak self] in self?.world.pet?.cast(skill) }
        })
    }

    // MARK: Right-click on the pet

    private func petMenu(_ pet: Pet) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: pet.character.name, action: nil, keyEquivalent: "")
        if let reminder = pet.reminder {
            menu.addItem(withTitle: "\(reminder.kind.icon) \(reminder.kind.title)", action: nil, keyEquivalent: "")
            menu.addItem(ActionItem(ui(.reminderDone)) { [weak pet] in pet?.resolveReminder(.done) })
            menu.addItem(ActionItem(ui(.snooze10)) { [weak pet] in pet?.resolveReminder(.snoozed(minutes: 10)) })
            menu.addItem(ActionItem(ui(.snooze30)) { [weak pet] in pet?.resolveReminder(.snoozed(minutes: 30)) })
            menu.addItem(ActionItem(ui(.skipOnce)) { [weak pet] in pet?.resolveReminder(.skipped) })
        } else {
            menu.addItem(submenu(ui(.remindNow), items: ReminderKind.allCases.map { kind in
                ActionItem("\(kind.icon) \(kind.title)") { [weak self] in self?.world.scheduler.triggerNow(kind) }
            }))
            menu.addItem(skillsItem())
            menu.addItem(ActionItem(ui(.hideCompanion)) { [weak self] in self?.settings.showCompanion = false })
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem(ui(.settings)) { [weak self] in self?.openSettings() })
        return menu
    }

    // MARK: Settings window

    private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(updater: updater) { [weak self] kind in self?.world.scheduler.triggerNow(kind) }
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "MochiMate"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: Helpers

    private func submenu(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        items.forEach(menu.addItem)
        item.submenu = menu
        return item
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Language.current.rawValue)
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// A menu item that runs a closure.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", checked: Bool = false, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler() }
}
