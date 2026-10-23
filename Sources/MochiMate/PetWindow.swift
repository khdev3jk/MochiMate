import AppKit

/// Small transparent, click-through panel that follows a pet around every screen.
/// Never straddles two screens: the window server flickers a window that does, so a pet on the seam is cut into
/// one window per screen (this one holds the larger part, `PetEdgeMirror` the rest).
final class PetWindow: NSPanel {
    static let size = CGSize(width: 260, height: 232)
    /// Where the pet's feet sit inside the window (bottom-left origin).
    static let feet = CGPoint(x: 130, y: 14)

    /// The frame the window would have if it were never cut: what the pet's own coordinates refer to.
    private(set) var fullFrame = CGRect(origin: .zero, size: PetWindow.size)
    /// The screen holding the smaller part of a pet on the seam, nil when the pet is on one screen.
    private(set) var overhangScreen: NSScreen?
    private let petView: NSView

    init(view: NSView) {
        petView = view
        super.init(contentRect: CGRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let content = NSView(frame: CGRect(origin: .zero, size: Self.size))
        content.addSubview(view)
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Let the pet walk across screen edges without AppKit pushing the window back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    func place(feetAt p: CGPoint) {
        let full = CGRect(origin: CGPoint(x: (p.x - Self.feet.x).rounded(), y: (p.y - Self.feet.y).rounded()), size: Self.size)
        var slices: [(screen: NSScreen, part: CGRect)] = []
        for screen in NSScreen.screens {
            let part = screen.frame.intersection(full)
            if part.width > 0 && part.height > 0 { slices.append((screen, part)) }
        }
        slices.sort { $0.part.width * $0.part.height > $1.part.width * $1.part.height }
        let mine = slices.count > 1 ? slices[0].part : full
        overhangScreen = slices.count > 1 ? slices[1].screen : nil
        fullFrame = full
        if mine != frame { setFrame(mine, display: false) }
        let offset = CGPoint(x: full.minX - mine.minX, y: full.minY - mine.minY)
        if petView.frame.origin != offset { petView.setFrameOrigin(offset) }
    }
}

/// Shows the part of a pet that hangs over onto a second screen, from a snapshot of the pet's own view.
final class PetEdgeMirror: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let content = NSView()
        content.wantsLayer = true
        content.layer?.contentsGravity = .resize
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// `windowFrame` is the pet window's frame; only its overlap with `screen` is shown.
    func show(copying view: PetView, windowFrame: CGRect, on screen: NSScreen, level: NSWindow.Level) {
        let part = windowFrame.intersection(screen.frame)
        setFrame(part, display: false)
        self.level = level
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentView?.layer?.contents = view.snapshot(scale: screen.backingScaleFactor)
        contentView?.layer?.contentsRect = CGRect(x: (part.minX - windowFrame.minX) / windowFrame.width,
                                                  y: (part.minY - windowFrame.minY) / windowFrame.height,
                                                  width: part.width / windowFrame.width,
                                                  height: part.height / windowFrame.height)
        CATransaction.commit()
        orderFrontRegardless()
    }
}

/// Layer-hosting view. The sprite and emote are CALayers whose contents are swapped per frame and
/// composited by the window server; only the speech bubble is drawn, and only when its text changes.
final class PetView: NSView {
    weak var pet: Pet?

    /// Area of the window covered by the character body, used for hit testing.
    let bodyRect = CGRect(x: PetWindow.feet.x - 30, y: PetWindow.feet.y, width: 60, height: 112)
    private let headTop = PetWindow.feet.y + 118
    private let effectOrigin = CGPoint(x: PetWindow.feet.x + 30, y: PetWindow.feet.y + 82)

    private let spriteLayer = CALayer()
    private let effectLayer = CALayer()
    private let textLayer = CALayer()

    private var shownFrame: CGImage?
    private var shownFacing: CGFloat = 1
    private var shownEffect: CGImage?
    private var shownRise: CGFloat = -1
    private var shownBubble: String?
    private var shownHint: String?

    init() {
        super.init(frame: CGRect(origin: .zero, size: PetWindow.size))
        layer = CALayer()   // set before wantsLayer: we own the layer tree and AppKit never redraws it
        wantsLayer = true
        let layout = SpriteSheet.layout
        let size = layout.frameSize
        spriteLayer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        // Pin the frame's feet to the window's feet point, which is also the axis for flipping.
        spriteLayer.anchorPoint = CGPoint(x: layout.anchor.x / size, y: (size - layout.anchor.y) / size)
        spriteLayer.position = PetWindow.feet
        effectLayer.bounds = CGRect(x: 0, y: 0, width: 52, height: 52)
        effectLayer.anchorPoint = .zero
        textLayer.frame = bounds
        for sublayer in [spriteLayer, effectLayer, textLayer] {
            sublayer.contentsGravity = .resize
            layer!.addSublayer(sublayer)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        textLayer.contents = bubbleImage()
    }

    /// Applies the pet's current look; does nothing when nothing visible changed.
    func render(frame: CGImage?, facing: CGFloat, effect: CGImage?, effectAge: TimeInterval, bubble: String?, hint: String?) {
        let rise = effect == nil ? 0 : (CGFloat(min(effectAge, 0.4) / 0.4) * 8).rounded()
        guard frame !== shownFrame || facing != shownFacing || effect !== shownEffect || rise != shownRise
                || bubble != shownBubble || hint != shownHint else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if frame !== shownFrame { spriteLayer.contents = frame }
        if facing != shownFacing { spriteLayer.setAffineTransform(CGAffineTransform(scaleX: facing, y: 1)) }
        if effect !== shownEffect { effectLayer.contents = effect }
        if rise != shownRise { effectLayer.position = CGPoint(x: effectOrigin.x, y: effectOrigin.y + rise) }
        if bubble != shownBubble || hint != shownHint {
            shownBubble = bubble
            shownHint = hint
            textLayer.contents = bubbleImage()
        }
        CATransaction.commit()
        shownFrame = frame
        shownFacing = facing
        shownEffect = effect
        shownRise = rise
    }

    /// What the pet looks like right now, drawn from the layer tree.
    func snapshot(scale: CGFloat) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        layer?.render(in: ctx)
        return ctx.makeImage()
    }

    /// The speech bubble rendered once into a bitmap at the screen's scale.
    private func bubbleImage() -> CGImage? {
        guard let text = shownBubble else { return nil }
        let scale = window?.backingScaleFactor ?? 2
        guard let ctx = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        drawBubble(text, hint: shownHint)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// Speech bubble with a pointer; `hint` is a smaller second line (what clicking does).
    private func drawBubble(_ text: String, hint: String?) {
        let ink = NSColor(calibratedRed: 0.29, green: 0.18, blue: 0.23, alpha: 1)
        let string = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: ink,
        ])
        if let hint {
            string.append(NSAttributedString(string: "\n" + hint, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: ink.withAlphaComponent(0.6),
            ]))
        }
        let maxWidth = bounds.width - 12
        let room = bounds.height - headTop - 12 - 4
        let textSize = string.boundingRect(with: CGSize(width: maxWidth - 16, height: room - 10),
                                           options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]).size
        let w = min(maxWidth, ceil(textSize.width) + 16), h = min(room, ceil(textSize.height) + 10)
        let rect = CGRect(x: (bounds.width - w) / 2, y: headTop + 12, width: w, height: h)

        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: rect.midX - 5, y: rect.minY + 1))
        tail.line(to: CGPoint(x: rect.midX + 1, y: rect.minY - 7))
        tail.line(to: CGPoint(x: rect.midX + 5, y: rect.minY + 1))
        NSColor.white.withAlphaComponent(0.96).setFill()
        path.fill(); tail.fill()
        ink.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 1.4
        path.stroke()
        string.draw(with: rect.insetBy(dx: 8, dy: 5), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    // MARK: Mouse

    private var grabOffset: CGPoint = .zero
    private var mouseDownAt: CGPoint = .zero
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        guard let pet else { return }
        let mouse = NSEvent.mouseLocation
        mouseDownAt = mouse
        grabOffset = CGPoint(x: mouse.x - pet.position.x, y: mouse.y - pet.position.y)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pet else { return }
        let mouse = NSEvent.mouseLocation
        if !didDrag && hypot(mouse.x - mouseDownAt.x, mouse.y - mouseDownAt.y) < 4 { return }
        if !didDrag { didDrag = true; pet.beginDrag() }
        pet.drag(to: CGPoint(x: mouse.x - grabOffset.x, y: mouse.y - grabOffset.y))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag { pet?.endDrag() } else { pet?.clicked() }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let pet, let menu = pet.world.contextMenu?(pet) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
