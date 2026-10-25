import AppKit

private final class OverlayPanel: NSPanel {
    // Cover the whole screen, menu bar included, instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Transparent, click-through panel covering the screen a skill is cast on. It sits just below the pet's own
/// window, so the effects fill the whole screen while the character stays in front of them.
final class SkillOverlay {
    static let shared = SkillOverlay()

    private lazy var panel: NSPanel = {
        let panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let content = NSView()
        content.layer = CALayer()
        content.wantsLayer = true
        panel.contentView = content
        return panel
    }()
    private var running = 0

    /// Runs `skill` on the screen under `feet` (the pet's feet in global coordinates). The effects are drawn for the
    /// whole screen and shrunk toward the pet's feet, so a skill stays around the character.
    func play(_ skill: Skill, feet: CGPoint, facing: CGFloat) {
        play(feet: feet, facing: facing, scale: 0.45, stretch: skill.stretch, skill.cast)
    }

    /// Runs a reminder's effect: full screen when `intense`, otherwise a quick pulse around the pet.
    func play(_ reminder: ReminderKind, variant: Int, intense: Bool, feet: CGPoint, facing: CGFloat) {
        play(feet: feet, facing: facing, scale: 1) { reminder.cast($0, intense: intense, variant: variant) }
    }

    private func play(feet: CGPoint, facing: CGFloat, scale: CGFloat, stretch: Double = 1, _ cast: (SkillFX) -> Void) {
        let screen = NSScreen.screens.first { $0.frame.contains(feet) } ?? NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(screen.frame, display: false)
        let local = CGPoint(x: feet.x - screen.frame.minX, y: feet.y - screen.frame.minY)
        let fx = SkillFX(size: screen.frame.size, feet: local, facing: facing, scale: scale, stretch: stretch)
        panel.contentView?.layer?.addSublayer(fx.container)
        panel.orderFrontRegardless()
        running += 1
        cast(fx)
        DispatchQueue.main.asyncAfter(deadline: .now() + fx.end + 0.4) { [weak self] in
            fx.container.removeFromSuperlayer()
            guard let self else { return }
            self.running -= 1
            if self.running == 0 {
                self.panel.orderOut(nil)
                SkillFX.clearGlyphCache()
            }
        }
    }
}

/// Drawing kit for one skill cast. Everything is fire-and-forget Core Animation; `end` is when the last effect is gone.
/// Coordinates are in the overlay (bottom-left origin, points).
final class SkillFX {
    let container = CALayer()
    let size: CGSize
    let feet: CGPoint
    let facing: CGFloat
    /// 1 fills the screen; less shrinks everything toward the feet.
    let scale: CGFloat
    /// Effects are timed in design seconds; everything runs `stretch` times slower (Core Animation through the container's speed).
    let stretch: Double
    private(set) var end: TimeInterval = 0

    var bounds: CGRect { CGRect(origin: .zero, size: size) }
    var body: CGPoint { CGPoint(x: feet.x, y: feet.y + 52) }
    var head: CGPoint { CGPoint(x: feet.x + 2, y: feet.y + 98) }

    init(size: CGSize, feet: CGPoint, facing: CGFloat, scale: CGFloat, stretch: Double = 1) {
        self.size = size
        self.feet = feet
        self.facing = facing
        self.scale = scale
        self.stretch = stretch
        container.speed = Float(1 / stretch)
        container.bounds = CGRect(origin: .zero, size: size)
        container.anchorPoint = CGPoint(x: feet.x / size.width, y: feet.y / size.height)
        container.position = feet
        container.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
    }

    // MARK: Plumbing

    private func later(_ delay: TimeInterval, lasting: TimeInterval, _ build: @escaping () -> Void) {
        end = max(end, (delay + lasting) * stretch)
        let run = {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            build()
            CATransaction.commit()
        }
        if delay > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + delay * stretch, execute: run) } else { run() }
    }

    private func keyframes(_ keyPath: String, _ values: [Any], times: [NSNumber]? = nil, duration: TimeInterval) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = values
        a.keyTimes = times
        a.duration = duration
        a.fillMode = .forwards
        a.isRemovedOnCompletion = false
        return a
    }

    private func basic(_ keyPath: String, _ from: Any, _ to: Any, duration: TimeInterval, ease: CAMediaTimingFunctionName = .easeOut) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = to
        a.duration = duration
        a.timingFunction = CAMediaTimingFunction(name: ease)
        a.fillMode = .forwards
        a.isRemovedOnCompletion = false
        return a
    }

    /// Fades a layer in, holds, fades out.
    private func fadeInOut(_ layer: CALayer, peak: Float = 1, duration: TimeInterval, fadeIn: Double = 0.1, fadeOut: Double = 0.2) {
        layer.opacity = 0
        layer.add(keyframes("opacity", [0, peak, peak, 0], times: [0, NSNumber(value: fadeIn), NSNumber(value: 1 - fadeOut), 1],
                            duration: duration), forKey: "fade")
    }

    // MARK: Glyphs

    private(set) static var glyphCache: [String: CGImage] = [:]

    /// Drops the bitmaps once no effect is on screen: they are rebuilt in a moment, and kept they add up to ~100 MB.
    static func clearGlyphCache() { glyphCache.removeAll() }
    /// Particle sizes are picked from these, not at random: every distinct size is its own cached bitmap.
    static let particleScales: [CGFloat] = [0.7, 0.85, 1, 1.2]

    /// An emoji or short text rendered to a bitmap `px` points tall (wider for long text).
    static func glyph(_ text: String, _ px: CGFloat, color: NSColor? = nil) -> CGImage? {
        let key = "\(text)|\(px)|\(color?.description ?? "")"
        if let cached = glyphCache[key] { return cached }
        let font = NSFont.systemFont(ofSize: px * 0.8, weight: .heavy)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let color { attributes[.foregroundColor] = color }
        let string = NSAttributedString(string: text, attributes: attributes)
        let text = string.size()
        let w = max(px, ceil(text.width) + px * 0.2)
        let scale: CGFloat = 2
        guard let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(px * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        string.draw(at: CGPoint(x: (w - text.width) / 2, y: (px - text.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
        let image = ctx.makeImage()
        glyphCache[key] = image
        return image
    }

    // MARK: Primitives

    /// A tint over the whole screen (left out when shrunk, where it would show up as a box).
    func flash(_ color: CGColor, peak: Float = 0.8, duration: TimeInterval = 0.5, delay: TimeInterval = 0) {
        guard scale == 1 else { return }
        later(delay, lasting: duration) { [self] in
            let layer = CALayer()
            layer.frame = bounds
            layer.backgroundColor = color
            container.addSublayer(layer)
            layer.opacity = 0
            layer.add(keyframes("opacity", [0, peak, 0], times: [0, 0.15, 1], duration: duration), forKey: "flash")
        }
    }

    /// An expanding, fading ring; `radius` grows by `scale` times.
    func ring(at p: CGPoint, radius: CGFloat = 40, scale: CGFloat = 12, color: CGColor, width: CGFloat = 10,
              duration: TimeInterval = 1.2, delay: TimeInterval = 0, filled: Bool = false) {
        later(delay, lasting: duration) { [self] in
            let layer = CAShapeLayer()
            layer.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            layer.fillColor = filled ? color.copy(alpha: 0.18) : nil
            layer.strokeColor = color
            layer.lineWidth = width
            layer.position = p
            container.addSublayer(layer)
            layer.opacity = 0
            let group = CAAnimationGroup()
            group.animations = [basic("transform.scale", 0.15, scale, duration: duration),
                                keyframes("opacity", [0, 1, 0], times: [0, 0.15, 1], duration: duration)]
            group.duration = duration
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: "ring")
        }
    }

    /// A soft radial glow that swells and fades.
    func glow(at p: CGPoint, diameter: CGFloat, color: CGColor, duration: TimeInterval = 2, delay: TimeInterval = 0) {
        later(delay, lasting: duration) { [self] in
            let layer = CAGradientLayer()
            layer.type = .radial
            layer.colors = [color.copy(alpha: 0.7)!, color.copy(alpha: 0)!]
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            layer.position = p
            container.addSublayer(layer)
            fadeInOut(layer, duration: duration, fadeIn: 0.2, fadeOut: 0.4)
            layer.add(basic("transform.scale", 0.4, 1, duration: duration), forKey: "swell")
        }
    }

    /// An emoji/text sprite that pops in with an overshoot, optionally spins, holds and fades.
    func pop(_ text: String, _ px: CGFloat, at p: CGPoint, color: NSColor? = nil, turns: CGFloat = 0, tilt: CGFloat = 0,
             hold: TimeInterval = 1.2, delay: TimeInterval = 0) {
        let total = 0.45 + hold + 0.3
        later(delay, lasting: total) { [self] in
            guard let image = Self.glyph(text, px, color: color) else { return }
            let layer = CALayer()
            layer.contents = image
            layer.contentsScale = 2
            layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
            layer.position = p
            layer.setAffineTransform(CGAffineTransform(rotationAngle: tilt))
            container.addSublayer(layer)
            let t = [0, 0.45 / total, (0.45 + hold) / total, 1].map { NSNumber(value: $0) }
            layer.opacity = 0
            layer.add(keyframes("opacity", [0, 1, 1, 0], times: t, duration: total), forKey: "fade")
            layer.add(keyframes("transform.scale", [0, 1.3, 1, 1, 0.8], times: [0, t[1], NSNumber(value: 0.45 / total + 0.1), t[2], 1],
                                duration: total), forKey: "scale")
            if turns != 0 {
                layer.add(basic("transform.rotation.z", tilt, tilt + turns * 2 * .pi, duration: 0.6), forKey: "spin")
            }
        }
    }

    /// Flies a sprite from `from` to `to`, leaving a trail of `trail` glyphs.
    func fly(_ text: String, _ px: CGFloat, from: CGPoint, to: CGPoint, tilt: CGFloat = 0, duration: TimeInterval,
             delay: TimeInterval = 0, trail: String? = nil, trailPx: CGFloat = 60) {
        later(delay, lasting: duration + 1) { [self] in
            if let image = Self.glyph(text, px) {
                let layer = CALayer()
                layer.contents = image
                layer.contentsScale = 2
                layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
                layer.position = to
                layer.setAffineTransform(CGAffineTransform(rotationAngle: tilt))
                container.addSublayer(layer)
                layer.add(basic("position", NSValue(point: from), NSValue(point: to), duration: duration, ease: .easeIn), forKey: "fly")
            }
            if let trail {
                let emitter = CAEmitterLayer()
                emitter.emitterShape = .point
                emitter.emitterPosition = to
                emitter.emitterCells = [cell(trail, trailPx, rate: 90, life: 0.9) { c in
                    c.velocity = 60; c.velocityRange = 50; c.emissionRange = .pi * 2
                    c.scaleSpeed = -0.6; c.alphaSpeed = -1.1; c.spinRange = 3
                }]
                container.addSublayer(emitter)
                emitter.add(basic("emitterPosition", NSValue(point: from), NSValue(point: to), duration: duration, ease: .easeIn),
                            forKey: "trail")
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * stretch) { emitter.birthRate = 0 }
            }
        }
    }

    func cell(_ glyph: String, _ px: CGFloat, rate: Float, life: Float, color: NSColor? = nil,
              _ configure: (CAEmitterCell) -> Void = { _ in }) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.contents = Self.glyph(glyph, px, color: color)
        c.contentsScale = 2
        c.birthRate = rate
        c.lifetime = life
        configure(c)
        return c
    }

    /// Runs emitter `cells` for `seconds` from a point or a line.
    func emit(_ cells: [CAEmitterCell], at p: CGPoint, shape: CAEmitterLayerEmitterShape = .point, extent: CGSize = .zero,
              seconds: TimeInterval, delay: TimeInterval = 0) {
        let life = TimeInterval(cells.map { $0.lifetime + $0.lifetimeRange }.max() ?? 1)
        later(delay, lasting: seconds + life) { [self] in
            let emitter = CAEmitterLayer()
            emitter.emitterShape = shape
            emitter.emitterPosition = p
            emitter.emitterSize = extent
            emitter.emitterCells = cells
            container.addSublayer(emitter)
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds * stretch) { emitter.birthRate = 0 }
        }
    }

    /// Particles falling over the whole width of the screen.
    func rain(_ glyphs: [String], _ px: CGFloat, rate: Float, seconds: TimeInterval, speed: CGFloat = 520,
              color: NSColor? = nil, delay: TimeInterval = 0) {
        sweep(glyphs, px, count: Int(rate * Float(seconds)), seconds: seconds, speed: speed, down: true, color: color, delay: delay)
    }

    /// Particles floating up from the bottom edge across the whole width.
    func rise(_ glyphs: [String], _ px: CGFloat, rate: Float, seconds: TimeInterval, speed: CGFloat = 260, delay: TimeInterval = 0) {
        sweep(glyphs, px, count: Int(rate * Float(seconds)), seconds: seconds, speed: speed, down: false, color: nil, delay: delay)
    }

    /// One layer per particle, each crossing the full screen height at its own time and speed.
    private func sweep(_ glyphs: [String], _ px: CGFloat, count: Int, seconds: TimeInterval, speed: CGFloat, down: Bool,
                       color: NSColor?, delay: TimeInterval) {
        let crossing = TimeInterval((size.height + 2 * px) / speed)
        later(delay, lasting: seconds + crossing * 1.3) { [self] in
            let start = container.convertTime(CACurrentMediaTime(), from: nil)
            for i in 0..<count {
                guard let image = Self.glyph(glyphs[i % glyphs.count], px * Self.particleScales.randomElement()!, color: color) else { continue }
                let layer = CALayer()
                layer.contents = image
                layer.contentsScale = 2
                layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
                let x = CGFloat.random(in: 0...size.width)
                let from = down ? size.height + px : -px, to = down ? -px : size.height + px
                layer.position = CGPoint(x: x, y: to)
                let fall = basic("position.y", from, to, duration: crossing * Double.random(in: 0.8...1.25), ease: .linear)
                let spin = basic("transform.rotation.z", 0, CGFloat.random(in: -3...3), duration: fall.duration, ease: .linear)
                for a in [fall, spin] {
                    a.beginTime = start + Double.random(in: 0...seconds)
                    a.fillMode = .both
                    layer.add(a, forKey: String(describing: a.keyPath))
                }
                container.addSublayer(layer)
            }
        }
    }

    /// A fountain / explosion of glyphs from `p`.
    func burst(_ glyphs: [String], _ px: CGFloat, at p: CGPoint, rate: Float = 60, seconds: TimeInterval = 0.4,
               velocity: CGFloat = 700, longitude: CGFloat = .pi / 2, spread: CGFloat = .pi * 2, gravity: CGFloat = -600,
               life: Float = 2, delay: TimeInterval = 0) {
        let cells = glyphs.map { g in
            cell(g, px, rate: rate / Float(glyphs.count), life: life) { c in
                c.velocity = velocity; c.velocityRange = velocity * 0.4
                c.emissionLongitude = longitude; c.emissionRange = spread
                c.yAcceleration = gravity
                c.spinRange = 4; c.scale = 1; c.scaleRange = 0.5; c.alphaSpeed = -0.35
            }
        }
        emit(cells, at: p, seconds: seconds, delay: delay)
    }

    /// A shape layer for custom effects: sized `rect`, filled/stroked as given, fading in and out over `duration`.
    func shape(_ path: CGPath, fill: CGColor? = nil, stroke: CGColor? = nil, width: CGFloat = 4, peak: Float = 1,
               duration: TimeInterval, delay: TimeInterval = 0, configure: ((CAShapeLayer) -> Void)? = nil) {
        later(delay, lasting: duration) { [self] in
            let layer = CAShapeLayer()
            layer.path = path
            layer.fillColor = fill
            layer.strokeColor = stroke
            layer.lineWidth = width
            layer.lineCap = .round
            container.addSublayer(layer)
            fadeInOut(layer, peak: peak, duration: duration)
            configure?(layer)
        }
    }

    /// A gradient layer filling `frame`, fading in and out; `configure` can add motion.
    func gradient(_ colors: [CGColor], frame: CGRect, start: CGPoint, end: CGPoint, peak: Float = 1, duration: TimeInterval,
                  delay: TimeInterval = 0, configure: ((CAGradientLayer) -> Void)? = nil) {
        later(delay, lasting: duration) { [self] in
            let layer = CAGradientLayer()
            layer.colors = colors
            layer.frame = frame
            layer.startPoint = start
            layer.endPoint = end
            container.addSublayer(layer)
            fadeInOut(layer, peak: peak, duration: duration)
            configure?(layer)
        }
    }

    func slam(_ layerBuilder: @escaping () -> CALayer, from scale: CGFloat, hold: TimeInterval, delay: TimeInterval = 0) {
        let drop = 0.22
        later(delay, lasting: drop + hold + 0.3) { [self] in
            let layer = layerBuilder()
            container.addSublayer(layer)
            layer.opacity = 0
            layer.add(keyframes("opacity", [0, 1, 1, 0], times: [0, 0.05, NSNumber(value: (drop + hold) / (drop + hold + 0.3)), 1],
                                duration: drop + hold + 0.3), forKey: "fade")
            layer.add(basic("transform.scale", scale, 1, duration: drop, ease: .easeIn), forKey: "slam")
        }
    }
}

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
