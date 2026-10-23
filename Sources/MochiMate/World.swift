import AppKit
import Combine

/// Owns the companion, the reminder schedule and the animation clock.
final class World {
    let desktop = DesktopIcons()
    let scheduler = ReminderScheduler()
    private(set) var pet: Pet?
    /// Right-click menu for the pet, built by the app delegate.
    var contextMenu: ((Pet) -> NSMenu?)?

    private let settings = Settings.shared
    private var claimed: Set<String> = []
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastRefresh: TimeInterval = 0
    private var observers: [AnyCancellable] = []

    func start() {
        scheduler.onDue = { [weak self] kind in self?.present(kind) ?? false }
        scheduler.onEndOfDay = { [weak self] in self?.pet?.sayGoodbye() }
        scheduler.start()
        if settings.showCompanion { summon(settings.characterID) }

        // Published values arrive before they are stored, so read the new value from the stream.
        observers = [
            settings.$characterID.dropFirst().removeDuplicates().sink { [weak self] id in
                guard let self, self.pet != nil else { return }
                self.summon(id)
            },
            settings.$showCompanion.dropFirst().removeDuplicates().sink { [weak self] show in
                guard let self else { return }
                if show { self.summon(self.settings.characterID) } else if self.pet?.reminder == nil { self.dismiss() }
            },
            settings.$kickIcons.dropFirst().filter { $0 }.sink { [weak self] _ in self?.desktop.refresh() },
        ]

        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)   // keep animating while menus are open
        self.timer = timer
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        pet?.tick(dt)
        if settings.kickIcons, now - lastRefresh > 15 {
            lastRefresh = now
            desktop.refresh()
        }
    }

    // MARK: Companion

    /// Puts a character on screen, taking over from the current one where it stands (and any reminder it shows).
    func summon(_ id: String, greeting: Bool = true) {
        let character = Character.with(id: id)
        let position = pet?.position ?? defaultPosition()
        let pending = pet?.reminder?.kind
        if let old = pet {
            old.onReminderResolved = nil
            old.hide()
        }
        let pet = Pet(character: character, world: self, position: position)
        pet.onReminderResolved = { [weak self] kind, outcome in self?.resolved(kind, outcome) }
        self.pet = pet
        pet.show(greeting: greeting && pending == nil)
        if let pending { pet.remind(pending) }
    }

    func dismiss() {
        guard let pet else { return }
        if let kind = pet.reminder?.kind { scheduler.resolve(kind, .skipped) }
        pet.onReminderResolved = nil
        pet.hide()
        self.pet = nil
    }

    private func defaultPosition() -> CGPoint {
        let f = NSScreen.main?.visibleFrame ?? NSScreen.screens[0].visibleFrame
        return CGPoint(x: f.minX + 200, y: f.minY + 10)
    }

    // MARK: Reminders

    /// Shows a reminder. A hidden companion comes out just for it and leaves again afterwards.
    private func present(_ kind: ReminderKind) -> Bool {
        if pet == nil { summon(settings.characterID, greeting: false) }
        pet?.remind(kind)
        return pet != nil
    }

    private func resolved(_ kind: ReminderKind, _ outcome: ReminderOutcome) {
        scheduler.resolve(kind, outcome)
        guard !settings.showCompanion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, !self.settings.showCompanion, self.pet?.reminder == nil else { return }
            self.dismiss()
        }
    }

    // MARK: Icons

    func claim(_ name: String) { claimed.insert(name) }
    func release(_ name: String) { claimed.remove(name) }

    func availableIcons() -> [DesktopIcon] {
        desktop.iconsArePinned ? [] : desktop.icons.filter { !claimed.contains($0.name) }
    }

    /// A random icon among the few closest to `point`, so the pet doesn't cross every screen for one kick.
    func pickIcon(near point: CGPoint) -> DesktopIcon? {
        let sorted = availableIcons().sorted {
            hypot($0.center.x - point.x, $0.center.y - point.y) < hypot($1.center.x - point.x, $1.center.y - point.y)
        }
        return sorted.prefix(5).randomElement()
    }
}
