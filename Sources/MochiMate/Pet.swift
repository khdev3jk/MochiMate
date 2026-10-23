import AppKit

/// The companion on screen: a queue of steps (walk, play an animation, say something, run an action)
/// refilled by a weighted choice of behaviors whenever it runs dry. A reminder takes over the queue until
/// the user answers it.
final class Pet {
    enum Step {
        case walk(CGPoint)
        case play(Anim, TimeInterval, effect: Effect? = nil)
        case face(CGFloat)
        case run(() -> Void)
        case say(LineKind, app: String = "")
    }

    /// How long a reminder waits for an answer before the pet gives up on it.
    static let reminderTimeout: TimeInterval = 90

    let character: Character
    private let sheet: SpriteSheet
    unowned let world: World
    private let view: PetView
    private lazy var window = PetWindow(view: view)
    private var edgeMirror: PetEdgeMirror?

    private(set) var position: CGPoint
    private var facing: CGFloat = 1

    private var anim: Anim = .idle
    private var animStart: TimeInterval = 0
    private var effect: (effect: Effect, start: TimeInterval, until: TimeInterval)?
    private var bubble: (text: String, until: TimeInterval)?

    private var steps: [Step] = []
    private var current: Step?
    private var stepStart: TimeInterval = 0

    private var kickTarget: String?
    private var dragging = false
    private var boredom: Double = 0
    private var clicks: [TimeInterval] = []

    /// The reminder being shown, waiting for the user to click.
    private(set) var reminder: (kind: ReminderKind, since: TimeInterval, line: DialogueLine?)?
    var onReminderResolved: ((ReminderKind, ReminderOutcome) -> Void)?

    private var now: TimeInterval { CACurrentMediaTime() }

    init(character: Character, world: World, position: CGPoint) {
        self.character = character
        self.sheet = SpriteSheet.named(character.id)
        self.view = PetView()
        self.world = world
        self.position = position
        view.pet = self
        facing = Bool.random() ? 1 : -1
    }

    func show(greeting: Bool = true) {
        window.place(feetAt: position)
        window.orderFrontRegardless()
        if greeting { steps = [.say(.hello), .play(.happy, 1.6, effect: .heart)] }
    }

    func hide() {
        if let name = kickTarget { world.release(name) }
        window.orderOut(nil)
        edgeMirror?.orderOut(nil)
    }

    // MARK: - Rendering state

    private func setAnim(_ a: Anim) {
        if a != anim { anim = a; animStart = now }
    }

    private func say(_ kind: LineKind, app: String = "") {
        guard let line = ContentStore.shared.line(kind, for: character, app: app) else { return }
        speak(line, for: 3.5)
    }

    private func speak(_ line: DialogueLine, for seconds: TimeInterval) {
        bubble = (line.text, now + max(seconds, Double(line.text.count) * 0.06))
        Voice.play(line, female: character.female)
    }

    // MARK: - Tick

    func tick(_ dt: TimeInterval) {
        if dragging {
            setAnim(.dragged)
        } else {
            advance(dt)
        }
        if [.idle, .walk, .bored].contains(anim) { boredom += dt }
        window.place(feetAt: position)
        updateMousePassthrough()

        let fx = effect.flatMap { now < $0.until ? $0 : nil }
        // A reminder keeps its line up until it's answered.
        let text = reminder.map { $0.line?.text ?? $0.kind.title } ?? bubble.flatMap { now < $0.until ? $0.text : nil }
        view.render(frame: sheet.frame(anim, elapsed: now - animStart), facing: facing,
                    effect: fx.flatMap { SpriteSheet.effect($0.effect) }, effectAge: fx.map { now - $0.start } ?? 0,
                    bubble: text, hint: reminder == nil || dragging ? nil : ui(.reminderHint))
        mirrorOverhang()
    }

    /// Draws the part of the pet that lies on a second screen (see PetWindow).
    private func mirrorOverhang() {
        guard let screen = window.overhangScreen else { edgeMirror?.orderOut(nil); return }
        let mirror = edgeMirror ?? PetEdgeMirror()
        edgeMirror = mirror
        mirror.show(copying: view, windowFrame: window.fullFrame, on: screen, level: window.level)
    }

    private func advance(_ dt: TimeInterval) {
        if current == nil { startNextStep() }
        guard let step = current else { return }
        switch step {
        case .walk(let target):
            let dx = target.x - position.x, dy = target.y - position.y
            let dist = hypot(dx, dy)
            // Runs when the trip is long or a reminder is waiting.
            let fast = dist > 450 || reminder != nil
            setAnim(fast ? .run : .walk)
            if abs(dx) > 1 { facing = dx > 0 ? 1 : -1 }
            let len = CGFloat(character.walkSpeed * (fast ? 2.4 : 1) * dt)
            if dist <= len {
                position = target
                current = nil
            } else {
                position.x += dx / dist * len
                position.y += dy / dist * len
            }
        case .play(_, let duration, _):
            if now - stepStart >= duration { current = nil }
        case .face, .run, .say:
            current = nil
        }
    }

    private func startNextStep() {
        if steps.isEmpty {
            if let reminder {
                if now - reminder.since > Self.reminderTimeout {
                    resolveReminder(.ignored)
                } else {
                    // Keep demonstrating, calling out to the user now and then.
                    steps = [.play(reminder.line?.anim ?? reminder.kind.anim, sheet.duration(reminder.kind.anim) * 2, effect: reminder.kind.effect),
                             .face(directionToCursor()),
                             .play(.wave, 1.5, effect: reminder.line?.effect ?? .exclaim)]
                }
            } else {
                steps = plan(for: chooseBehavior())
            }
        }
        guard !steps.isEmpty else { return }
        let step = steps.removeFirst()
        current = step
        stepStart = now
        switch step {
        case .play(let a, let duration, let fx):
            setAnim(a)
            if let fx { effect = (fx, now, now + duration) }
        case .face(let f):
            facing = f
        case .run(let action):
            action()
        case .say(let kind, let app):
            say(kind, app: app)
        case .walk:
            break
        }
    }

    /// Plays `newSteps` right away; an interrupted walk is redone afterwards.
    private func interrupt(_ newSteps: [Step]) {
        if let current, case .walk = current { steps.insert(current, at: 0) }
        steps.insert(contentsOf: newSteps, at: 0)
        current = nil
    }

    /// Drops whatever the pet was up to.
    private func cancelErrands() {
        steps.removeAll()
        current = nil
        if let name = kickTarget {
            kickTarget = nil
            world.release(name)
        }
    }

    // MARK: - Reminders

    /// Runs to where the user will see it, then demonstrates the reminder until the user answers.
    func remind(_ kind: ReminderKind) {
        cancelErrands()
        let line = ContentStore.shared.line(kind.lineKind, for: character, minutes: Settings.shared.config(kind).minutes)
        reminder = (kind, now, line)
        bubble = nil
        let spot = presentationSpot()
        steps = [.play(.surprised, 0.5, effect: .exclaim)]
        if hypot(spot.x - position.x, spot.y - position.y) > 30 { steps.append(.walk(spot)) }
        steps += [.face(directionToCursor()),
                  .run { if let line { Voice.play(line, female: character.female) } },
                  .play(.wave, 1.6, effect: line?.effect ?? kind.effect)]
    }

    func resolveReminder(_ outcome: ReminderOutcome) {
        guard let shown = reminder else { return }
        reminder = nil
        cancelErrands()
        switch outcome {
        case .done:
            steps = [.say(.thanks), .play(.happy, 2, effect: .check)]
        case .snoozed:
            steps = [.say(.snoozed), .play(.idle, 1.5, effect: .clock)]
        case .skipped:
            steps = [.say(.ignored), .play(.sad, 2.5, effect: .sweat)]
        case .ignored:
            steps = [.say(.ignored), .play(.grumpy, 2.5, effect: .anger)]
        }
        onReminderResolved?(shown.kind, outcome)
    }

    /// Bottom of the screen the cursor is on, a little to the side of the cursor.
    private func presentationSpot() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let f = screenFrame(containing: mouse)
        let side: CGFloat = mouse.x < f.midX ? 1 : -1
        return CGPoint(x: min(max(mouse.x + side * 180, f.minX + 80), f.maxX - 80), y: f.minY + 16)
    }

    private func directionToCursor() -> CGFloat { NSEvent.mouseLocation.x >= position.x ? 1 : -1 }

    /// The working day is over.
    func sayGoodbye() {
        guard reminder == nil, !dragging else { return }
        interrupt([.say(.endOfDay), .play(.happy, 2.5, effect: .heart)])
    }

    // MARK: - Behaviors

    private func chooseBehavior() -> Behavior {
        let settings = Settings.shared
        var weights = character.weights
        weights[.bored, default: 0] *= 1 + boredom / 40
        weights[.sleep, default: 0] *= 1 + boredom / 60
        weights[.kick, default: 0] *= settings.kickIcons && !world.availableIcons().isEmpty ? 1 : 0
        weights[.window, default: 0] *= settings.playWithWindows ? 1 : 0
        weights[.chatter, default: 0] *= settings.chatter ? 1 : 0
        let total = weights.values.reduce(0, +)
        var roll = Double.random(in: 0..<max(total, 0.001))
        for behavior in Behavior.allCases {
            roll -= weights[behavior, default: 0]
            if roll < 0 { return behavior }
        }
        return .wander
    }

    private func plan(for behavior: Behavior) -> [Step] {
        switch behavior {
        case .wander:
            return [.walk(randomDestination()), .play(.idle, .random(in: 1...3))]
        case .idle:
            return [.play(.idle, .random(in: 3...6))]
        case .work:
            return [.play(.work, .random(in: 6...14), effect: Bool.random() ? .note : nil)]
        case .bored:
            return [.say(.bored), .play(.bored, .random(in: 4...8), effect: .dots)]
        case .sleep:
            return [.say(.sleepy), .play(.yawn, sheet.duration(.yawn) + 0.3),
                    .play(.sleep, .random(in: 8...16), effect: .zzz),
                    .run { [weak self] in self?.boredom = 0 }]
        case .happy:
            return [.play(.happy, 1.8, effect: .note),
                    .run { [weak self] in self?.boredom = max(0, (self?.boredom ?? 0) - 20) }]
        case .chatter:
            return [.say(.chatter), .play(.idle, 3.5)]
        case .kick:
            return kickPlan()
        case .window:
            return windowPlan()
        case .skill:
            return character.skills.randomElement().map(skillPlan) ?? plan(for: .wander)
        }
    }

    // MARK: Skills

    /// Casts `skill` right now, unless a reminder is on or the pet is being dragged.
    func cast(_ skill: Skill) {
        guard reminder == nil, !dragging else { return }
        cancelErrands()
        steps = skillPlan(skill)
        current = nil
    }

    private func skillPlan(_ skill: Skill) -> [Step] {
        [.face(directionToCursor()),
         .say(skill.lineKind),
         .play(.surprised, 0.5, effect: .exclaim),
         .run { [weak self] in
             guard let self else { return }
             SkillOverlay.shared.play(skill, feet: self.position, facing: self.facing)
         },
         .play(skill.anim, Skill.duration, effect: .sparkle),
         .play(.happy, 1.2, effect: .heart)]
    }

    // MARK: Kicking icons

    private func kickPlan() -> [Step] {
        guard let icon = world.pickIcon(near: position) else { return plan(for: .wander) }
        world.claim(icon.name)
        kickTarget = icon.name
        let side: CGFloat = icon.center.x >= position.x ? 1 : -1
        let stand = clampToScreens(CGPoint(x: icon.center.x - side * 46, y: icon.center.y - 44))
        return [.walk(stand),
                       .face(side),
                       .say(.kick),
                       .play(.kick, 0.33),
                       .run { [weak self] in self?.launch(icon.name, side: side) },
                       .play(.kick, 0.3),
                       .play(.happy, 1.2, effect: .sparkle)]
    }

    private func launch(_ name: String, side: CGFloat) {
        kickTarget = nil
        guard let icon = world.desktop.icons.first(where: { $0.name == name }) else {
            world.release(name)
            return
        }
        let path = flightPath(of: icon.center, direction: side, distance: .random(in: 160...320))
        world.desktop.move(name, along: path) { [weak self] _ in self?.world.release(name) }
    }

    /// A kicked icon's arc, with a hop, kept on the icon's screen.
    private func flightPath(of start: CGPoint, direction: CGFloat, distance: CGFloat) -> [CGPoint] {
        let bounds = screenFrame(containing: start).insetBy(dx: 40, dy: 40)
        let n = 12
        return (1...n).map { i in
            let t = CGFloat(i) / CGFloat(n)
            let ease = 1 - (1 - t) * (1 - t)
            let p = CGPoint(x: start.x + direction * distance * ease, y: start.y + sin(t * .pi) * 50)
            return CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
        }
    }

    // MARK: Window visits

    /// Climbs onto the frontmost window's title bar, sits there teasing the app, then hops off.
    /// Only reads where the window is and the app's name; the app itself is never touched.
    private func windowPlan() -> [Step] {
        guard let target = FrontWindow.current() else { return plan(for: .wander) }
        let screen = screenFrame(containing: CGPoint(x: target.frame.midX, y: target.frame.maxY))
        let left = max(target.frame.minX, screen.minX) + 50, right = min(target.frame.maxX, screen.maxX) - 50
        // A maximized window leaves no room above it.
        guard right > left, target.frame.maxY < screen.maxY - 140 else { return plan(for: .wander) }
        let seat = CGPoint(x: .random(in: left...right), y: target.frame.maxY - 2)
        let pose: Anim = [.bored, .work, .idle].randomElement()!
        return [.walk(seat),
                       .play(.surprised, 0.4, effect: .exclaim),
                       .say(.window, app: target.app),
                       .play(pose, .random(in: 6...10), effect: pose == .work ? .note : .dots),
                       .walk(randomDestination())]
    }

    // MARK: - Mouse

    func clicked() {
        if reminder != nil {
            resolveReminder(.done)
            return
        }
        let t = now
        clicks = clicks.filter { t - $0 < 3 } + [t]
        if anim == .sleep {
            interrupt([.play(.surprised, 0.7, effect: .exclaim), .say(.wake), .play(.grumpy, 1.8, effect: .anger)])
        } else if clicks.count >= 4 {
            clicks.removeAll()
            interrupt([.say(.poke), .play(.grumpy, 2.2, effect: .anger)])
        } else {
            boredom = 0
            interrupt([.say(.click), .play(.happy, 1.3, effect: .heart)])
        }
    }

    func beginDrag() {
        dragging = true
        effect = (.sweat, now, .infinity)
    }

    func drag(to p: CGPoint) { position = p }

    func endDrag() {
        dragging = false
        effect = nil
        if reminder != nil { return }
        interrupt([.play(.surprised, 0.5),
                   Bool.random() ? .play(.happy, 1.2, effect: .note) : .play(.grumpy, 1.5, effect: .anger)])
    }

    private func updateMousePassthrough() {
        let m = NSEvent.mouseLocation
        let local = CGPoint(x: m.x - window.fullFrame.minX, y: m.y - window.fullFrame.minY)
        let over = dragging || view.bodyRect.contains(local)
        if window.ignoresMouseEvents == over { window.ignoresMouseEvents = !over }
    }

    // MARK: - Screen geometry

    private func screenFrame(containing p: CGPoint) -> CGRect {
        let screens = NSScreen.screens
        if let s = screens.first(where: { $0.frame.contains(p) }) { return s.visibleFrame }
        let nearest = screens.min { distance(p, $0.frame) < distance(p, $1.frame) }
        return nearest?.visibleFrame ?? .zero
    }

    private func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }

    /// Keeps the whole character inside a screen's visible area.
    private func clampToScreens(_ p: CGPoint) -> CGPoint {
        let f = screenFrame(containing: p)
        return CGPoint(x: min(max(p.x, f.minX + 40), f.maxX - 40),
                       y: min(max(p.y, f.minY), f.maxY - 130))
    }

    /// Mostly somewhere low on the current screen, sometimes over to another screen.
    private func randomDestination() -> CGPoint {
        let screens = NSScreen.screens
        let here = screens.first { $0.frame.contains(position) } ?? screens[0]
        let screen = Double.random(in: 0..<1) < 0.75 ? here : (screens.randomElement() ?? here)
        let f = screen.visibleFrame
        return CGPoint(x: .random(in: (f.minX + 60)...(f.maxX - 60)),
                       y: .random(in: f.minY...(f.minY + max(0, (f.height - 140) * 0.5))))
    }
}
