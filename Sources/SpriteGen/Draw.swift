import AppKit

// MARK: - Colors

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let white = rgb(0xFFFFFF)
let outline = rgb(0x4A2D3A)
let mouthRed = rgb(0xC2384E)
let waterBlue = rgb(0x9AD8FF)

// MARK: - Pose model

enum Eyes { case open(look: CGFloat), closed, happy, half, angry, wide, sleepy, teary, sparkle }
enum Mouth { case smile, open, flat, pout, o, yawn(CGFloat), grin, frown, wavy, smirk }
enum Brows { case none, angry, sad, raised }

struct Pose {
    var bob: CGFloat = 0            // vertical body offset (negative = up)
    var legBack: CGFloat = 0        // leg angles in radians, positive = forward
    var legFront: CGFloat = 0
    var armBack: CGFloat = 0.15     // arm angles, 0 = down, positive = forward, π = up
    var armFront: CGFloat = -0.15
    var eyes: Eyes = .open(look: 1)
    var mouth: Mouth = .smile
    var brows: Brows = .none
    var blush: CGFloat = 0.6
    var tilt: CGFloat = 0           // head tilt in radians
    var lean: CGFloat = 0           // whole body lean
    var hairSwing: CGFloat = 0
    var sitting = false
    var puffCheek = false
    var sweat = false
    var laptop = false
    /// A glass of water in the front hand.
    var cup = false
}

// MARK: - CGContext helpers

extension CGContext {
    func fillEllipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: CGColor) {
        setFillColor(color)
        fillEllipse(in: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    func stroke(_ build: (CGMutablePath) -> Void, _ color: CGColor, _ width: CGFloat) {
        let p = CGMutablePath(); build(p)
        addPath(p); setStrokeColor(color); setLineWidth(width)
        setLineCap(.round); setLineJoin(.round); strokePath()
    }

    func fill(_ build: (CGMutablePath) -> Void, _ color: CGColor, outlineWidth: CGFloat = 1.6) {
        let p = CGMutablePath(); build(p)
        addPath(p); setFillColor(color); fillPath()
        if outlineWidth > 0 {
            addPath(p); setStrokeColor(outline); setLineWidth(outlineWidth)
            setLineJoin(.round); strokePath()
        }
    }

    /// Fills a path with a vertical gradient between two y values, then outlines it.
    func fillGradient(_ build: (CGMutablePath) -> Void, _ colors: [CGColor], from y0: CGFloat, to y1: CGFloat,
                      outlineWidth: CGFloat = 1.6) {
        let p = CGMutablePath(); build(p)
        saveGState()
        addPath(p); clip()
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        drawLinearGradient(g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        restoreGState()
        if outlineWidth > 0 {
            addPath(p); setStrokeColor(outline); setLineWidth(outlineWidth); setLineJoin(.round); strokePath()
        }
    }
}

/// Draws a limb and returns where it ends.
@discardableResult
func limb(_ ctx: CGContext, from: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat,
          color: CGColor, end: (CGPoint) -> Void) -> CGPoint {
    let to = CGPoint(x: from.x + sin(angle) * length, y: from.y + cos(angle) * length)
    ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, outline, width + 2.4)
    ctx.stroke({ $0.move(to: from); $0.addLine(to: to) }, color, width)
    end(to)
    return to
}

func drawDrop(_ ctx: CGContext, at p: CGPoint, size s: CGFloat, color: CGColor = waterBlue) {
    ctx.fill({ path in
        path.move(to: CGPoint(x: p.x, y: p.y - 5 * s))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + 4 * s), control: CGPoint(x: p.x + 6 * s, y: p.y + 3 * s))
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - 5 * s), control: CGPoint(x: p.x - 6 * s, y: p.y + 3 * s))
    }, color, outlineWidth: 1.2)
}

/// Four-pointed sparkle star.
func fillStar(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.move(to: CGPoint(x: c.x, y: c.y - r))
    ctx.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: c)
    ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: c)
    ctx.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: c)
    ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: c)
    ctx.fillPath()
}

func drawText(_ ctx: CGContext, _ s: String, size: CGFloat, at p: CGPoint, color: CGColor) {
    let font = CTFontCreateWithName("AvenirNext-Heavy" as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor(cgColor: color)!])
    let line = CTLineCreateWithAttributedString(attr)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)  // context is flipped
    ctx.textPosition = p
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - Face

/// Eye centers relative to the head center; shifted slightly toward the facing side (+x).
let eyeOffsets: [CGPoint] = [CGPoint(x: -8, y: 3), CGPoint(x: 12, y: 3)]

func drawFace(_ ctx: CGContext, head c: CGPoint, pose: Pose, look: Look) {
    for o in eyeOffsets {
        let e = CGPoint(x: c.x + o.x, y: c.y + o.y)
        switch pose.eyes {
        case .open(let lookX):
            drawOpenEye(ctx, e, look: lookX, lid: look.restingLid, look)
        case .teary:
            drawOpenEye(ctx, e, look: 0, lid: look.restingLid, look)
            ctx.fillEllipse(CGPoint(x: e.x, y: e.y + 7), 4.2, 1.8, rgb(0x9AD8FF, 0.9))
        case .half:
            drawOpenEye(ctx, e, look: 1.5, lid: max(0.5, look.restingLid), look)
        case .angry:
            drawOpenEye(ctx, e, look: 0.5, lid: max(0.35, look.restingLid), look)
        case .wide:
            ctx.fill({ $0.addEllipse(in: CGRect(x: e.x - 5.5, y: e.y - 7, width: 11, height: 14)) }, white, outlineWidth: 1.4)
            ctx.fillEllipse(e, 2, 2.4, look.irisDark)
        case .closed, .sleepy:
            ctx.stroke({ p in
                p.move(to: CGPoint(x: e.x - 5, y: e.y + 1))
                p.addQuadCurve(to: CGPoint(x: e.x + 5, y: e.y + 1), control: CGPoint(x: e.x, y: e.y + 5))
            }, outline, 2)
        case .happy:
            ctx.stroke({ p in
                p.move(to: CGPoint(x: e.x - 5, y: e.y + 3))
                p.addQuadCurve(to: CGPoint(x: e.x + 5, y: e.y + 3), control: CGPoint(x: e.x, y: e.y - 6))
            }, outline, 2.4)
        case .sparkle:
            drawOpenEye(ctx, e, look: 0.5, lid: 0, look)
            fillStar(ctx, CGPoint(x: e.x - 0.5, y: e.y - 1), 3.8, white)
        }
    }

    // Brows.
    for (i, o) in eyeOffsets.enumerated() {
        let inner: CGFloat = i == 0 ? 1 : -1   // direction toward the nose
        let x = c.x + o.x, y = c.y + o.y - 11
        switch pose.brows {
        case .none:
            break
        case .angry:
            ctx.stroke({ p in
                p.move(to: CGPoint(x: x - inner * 5, y: y - 2)); p.addLine(to: CGPoint(x: x + inner * 4, y: y + 3))
            }, look.hairDark, 2.4)
        case .sad:
            ctx.stroke({ p in
                p.move(to: CGPoint(x: x - inner * 5, y: y + 2)); p.addLine(to: CGPoint(x: x + inner * 4, y: y - 2))
            }, look.hairDark, 2.2)
        case .raised:
            ctx.stroke({ p in
                p.move(to: CGPoint(x: x - 4, y: y - 2))
                p.addQuadCurve(to: CGPoint(x: x + 4, y: y - 2), control: CGPoint(x: x, y: y - 6))
            }, look.hairDark, 2)
        }
    }

    // Blush.
    if pose.blush > 0 {
        let color = rgb(0xFF8FA3, 0.3 + 0.4 * pose.blush)
        let y = c.y + eyeOffsets[0].y + 9
        ctx.fillEllipse(CGPoint(x: c.x + eyeOffsets[0].x - 3, y: y), 5, 2.6, color)
        ctx.fillEllipse(CGPoint(x: c.x + eyeOffsets[1].x + 3, y: y), 5, 2.6, color)
    }
    if pose.puffCheek {
        ctx.fill({ $0.addEllipse(in: CGRect(x: c.x + 18, y: c.y + 9, width: 10, height: 10)) }, look.skin, outlineWidth: 1.2)
        ctx.fillEllipse(CGPoint(x: c.x + 23, y: c.y + 14), 3.5, 2.2, rgb(0xFF8FA3, 0.6))
    }
    drawMouth(ctx, CGPoint(x: c.x + 3, y: c.y + 15), pose.mouth)
}

func drawMouth(_ ctx: CGContext, _ m: CGPoint, _ mouth: Mouth) {
    switch mouth {
    case .smile:
        ctx.stroke({ p in
            p.move(to: CGPoint(x: m.x - 3.5, y: m.y)); p.addQuadCurve(to: CGPoint(x: m.x + 3.5, y: m.y), control: CGPoint(x: m.x, y: m.y + 3.5))
        }, outline, 1.6)
    case .grin, .open:
        ctx.fill({ p in
            p.move(to: CGPoint(x: m.x - 5, y: m.y - 1))
            p.addLine(to: CGPoint(x: m.x + 5, y: m.y - 1))
            p.addQuadCurve(to: CGPoint(x: m.x - 5, y: m.y - 1), control: CGPoint(x: m.x, y: m.y + 9))
        }, mouthRed, outlineWidth: 1.4)
        ctx.fillEllipse(CGPoint(x: m.x, y: m.y + 3.5), 2.4, 1.4, rgb(0xFF9AAE))
    case .flat:
        ctx.stroke({ p in p.move(to: CGPoint(x: m.x - 3.5, y: m.y + 1)); p.addLine(to: CGPoint(x: m.x + 3.5, y: m.y + 1)) }, outline, 1.6)
    case .frown:
        ctx.stroke({ p in
            p.move(to: CGPoint(x: m.x - 4, y: m.y + 2)); p.addQuadCurve(to: CGPoint(x: m.x + 4, y: m.y + 2), control: CGPoint(x: m.x, y: m.y - 2))
        }, outline, 1.6)
    case .pout:
        ctx.stroke({ p in
            p.move(to: CGPoint(x: m.x - 3, y: m.y + 2)); p.addQuadCurve(to: CGPoint(x: m.x + 3, y: m.y + 2), control: CGPoint(x: m.x, y: m.y - 1.5))
        }, outline, 1.8)
    case .wavy:
        ctx.stroke({ p in
            p.move(to: CGPoint(x: m.x - 5, y: m.y + 1))
            p.addCurve(to: CGPoint(x: m.x + 5, y: m.y + 1),
                       control1: CGPoint(x: m.x - 2, y: m.y - 3), control2: CGPoint(x: m.x + 2, y: m.y + 5))
        }, outline, 1.6)
    case .o:
        ctx.fill({ $0.addEllipse(in: CGRect(x: m.x - 2.6, y: m.y - 1, width: 5.2, height: 6)) }, mouthRed, outlineWidth: 1.3)
    case .smirk:
        ctx.stroke({ p in
            p.move(to: CGPoint(x: m.x - 4, y: m.y + 1))
            p.addQuadCurve(to: CGPoint(x: m.x + 4.5, y: m.y - 1.5), control: CGPoint(x: m.x + 1, y: m.y + 3.5))
        }, outline, 1.7)
    case .yawn(let amount):
        let h = 3 + 9 * amount
        ctx.fill({ $0.addEllipse(in: CGRect(x: m.x - 3 - 2 * amount, y: m.y - 2, width: 6 + 4 * amount, height: h)) },
                 mouthRed, outlineWidth: 1.4)
    }
}

func drawOpenEye(_ ctx: CGContext, _ e: CGPoint, look lookX: CGFloat, lid: CGFloat, _ look: Look) {
    let rect = CGRect(x: e.x - 5.5, y: e.y - 7.5, width: 11, height: 15)
    ctx.saveGState()
    ctx.addEllipse(in: rect); ctx.clip()
    ctx.fillEllipse(e, 5.5, 7.5, white)
    let ic = CGPoint(x: e.x + lookX * 1.4, y: e.y + 0.8)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: ic.x - 4.6, y: ic.y - 6.4, width: 9.2, height: 12.8)); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [look.irisDark, look.iris, look.irisLight] as CFArray, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: ic.y - 6.4), end: CGPoint(x: 0, y: ic.y + 6.4), options: [])
    ctx.restoreGState()
    ctx.fillEllipse(CGPoint(x: ic.x, y: ic.y + 0.5), 2.2, 3, look.irisDark)
    ctx.fillEllipse(CGPoint(x: ic.x - 1.6, y: ic.y - 2.6), 1.8, 1.8, white)
    ctx.fillEllipse(CGPoint(x: ic.x + 1.8, y: ic.y + 2.8), 0.9, 0.9, white)
    if lid > 0 {
        ctx.setFillColor(look.skin)
        ctx.fill(CGRect(x: rect.minX - 1, y: rect.minY - 1, width: rect.width + 2, height: rect.height * lid + 1))
    }
    ctx.restoreGState()
    let lashY = rect.minY + rect.height * lid
    ctx.stroke({ p in
        if lid > 0 {
            p.move(to: CGPoint(x: rect.minX - 0.5, y: lashY)); p.addLine(to: CGPoint(x: rect.maxX + 0.5, y: lashY))
        } else {
            p.addArc(center: e, radius: 6.5, startAngle: .pi * 1.12, endAngle: .pi * 1.88, clockwise: false)
        }
    }, outline, 2.2)
}

// MARK: - Effects (emote icons), each drawn centered in its frame

let effectNames = ["heart", "note", "anger", "zzz", "dots", "sweat", "exclaim", "sparkle", "check", "water", "eye", "clock"]

func drawEffect(_ ctx: CGContext, _ index: Int) {
    let c = CGPoint(x: 64, y: 64)
    switch effectNames[index] {
    case "heart":
        ctx.fill({ p in
            p.move(to: CGPoint(x: c.x, y: c.y + 14))
            p.addCurve(to: CGPoint(x: c.x, y: c.y - 6), control1: CGPoint(x: c.x - 24, y: c.y - 2), control2: CGPoint(x: c.x - 12, y: c.y - 22))
            p.addCurve(to: CGPoint(x: c.x, y: c.y + 14), control1: CGPoint(x: c.x + 12, y: c.y - 22), control2: CGPoint(x: c.x + 24, y: c.y - 2))
        }, rgb(0xFF5C8A), outlineWidth: 2)
    case "note":
        ctx.fill({ $0.addEllipse(in: CGRect(x: c.x - 12, y: c.y + 4, width: 12, height: 9)) }, rgb(0x5B8DEF), outlineWidth: 1.6)
        ctx.stroke({ p in p.move(to: CGPoint(x: c.x - 1, y: c.y + 8)); p.addLine(to: CGPoint(x: c.x - 1, y: c.y - 16)) }, outline, 2.4)
        ctx.stroke({ p in p.move(to: CGPoint(x: c.x - 1, y: c.y - 16)); p.addQuadCurve(to: CGPoint(x: c.x + 11, y: c.y - 4), control: CGPoint(x: c.x + 12, y: c.y - 14)) }, outline, 2.4)
    case "anger":
        for (dx, dy, rot) in [(-1.0, -1.0, 0.0), (1.0, -1.0, 0.5), (-1.0, 1.0, 1.5), (1.0, 1.0, 1.0)] {
            ctx.saveGState()
            ctx.translateBy(x: c.x + CGFloat(dx) * 7, y: c.y + CGFloat(dy) * 7)
            ctx.rotate(by: CGFloat(rot) * .pi)
            ctx.stroke({ p in
                p.move(to: CGPoint(x: -6, y: -1)); p.addQuadCurve(to: CGPoint(x: -1, y: -6), control: CGPoint(x: -1, y: -1))
            }, rgb(0xE5484D), 4)
            ctx.restoreGState()
        }
    case "zzz":
        drawText(ctx, "Z", size: 22, at: CGPoint(x: c.x - 12, y: c.y + 10), color: rgb(0x6E7FD6))
        drawText(ctx, "z", size: 16, at: CGPoint(x: c.x + 4, y: c.y - 2), color: rgb(0x6E7FD6))
        drawText(ctx, "z", size: 12, at: CGPoint(x: c.x + 14, y: c.y - 12), color: rgb(0x6E7FD6))
    case "dots":
        for i in 0..<3 { ctx.fillEllipse(CGPoint(x: c.x - 10 + CGFloat(i) * 10, y: c.y), 3, 3, outline) }
    case "sweat":
        drawDrop(ctx, at: c, size: 2)
    case "exclaim":
        ctx.stroke({ p in p.move(to: CGPoint(x: c.x, y: c.y - 16)); p.addLine(to: CGPoint(x: c.x, y: c.y + 4)) }, rgb(0xFF9F1C), 6)
        ctx.fillEllipse(CGPoint(x: c.x, y: c.y + 13), 3.4, 3.4, rgb(0xFF9F1C))
    case "sparkle":
        ctx.fill({ p in
            p.move(to: CGPoint(x: c.x, y: c.y - 16))
            p.addQuadCurve(to: CGPoint(x: c.x + 16, y: c.y), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 16), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x - 16, y: c.y), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 16), control: c)
        }, rgb(0xFFD84D), outlineWidth: 1.4)
    case "check":
        for (color, width) in [(outline, CGFloat(8)), (rgb(0x3DBE6A), CGFloat(5))] {
            ctx.stroke({ p in
                p.move(to: CGPoint(x: c.x - 12, y: c.y)); p.addLine(to: CGPoint(x: c.x - 3, y: c.y + 10)); p.addLine(to: CGPoint(x: c.x + 14, y: c.y - 12))
            }, color, width)
        }
    case "water":
        // A big glossy water drop.
        drawDrop(ctx, at: CGPoint(x: c.x, y: c.y + 2), size: 3.2, color: rgb(0x5BB8F5))
        ctx.stroke({ p in
            p.addArc(center: CGPoint(x: c.x, y: c.y + 6), radius: 9, startAngle: .pi * 0.95, endAngle: .pi * 1.3, clockwise: false)
        }, white, 2.6)
    case "eye":
        ctx.fill({ p in
            p.move(to: CGPoint(x: c.x - 20, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + 20, y: c.y), control: CGPoint(x: c.x, y: c.y - 20))
            p.addQuadCurve(to: CGPoint(x: c.x - 20, y: c.y), control: CGPoint(x: c.x, y: c.y + 20))
        }, white, outlineWidth: 2.2)
        ctx.fill({ $0.addEllipse(in: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)) }, rgb(0x4FAE7A), outlineWidth: 1.6)
        ctx.fillEllipse(c, 3.2, 3.2, outline)
        ctx.fillEllipse(CGPoint(x: c.x - 3, y: c.y - 3), 1.8, 1.8, white)
    case "clock":
        ctx.fill({ $0.addEllipse(in: CGRect(x: c.x - 16, y: c.y - 14, width: 32, height: 32)) }, rgb(0xFFF4D6), outlineWidth: 2.4)
        for side: CGFloat in [-1, 1] {
            ctx.fill({ $0.addEllipse(in: CGRect(x: c.x + side * 12 - 5, y: c.y - 20, width: 10, height: 8)) }, rgb(0xFF9F1C), outlineWidth: 1.6)
        }
        ctx.stroke({ p in
            p.move(to: CGPoint(x: c.x, y: c.y - 7)); p.addLine(to: CGPoint(x: c.x, y: c.y + 2)); p.addLine(to: CGPoint(x: c.x + 7, y: c.y + 6))
        }, outline, 2.4)
    default:
        break
    }
}
