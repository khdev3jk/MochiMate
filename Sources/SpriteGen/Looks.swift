import AppKit

// The ten office workers: one man and one woman for each of the five professions,
// built from the same skeleton so all sheets share identical animation rows.

enum HairStyle { case short, spiky, bob, ponytail, buns, long }
enum Outfit { case hoodie, suit, shirt, cardigan, turtleneck, blazer }
enum Accessory { case glasses, headphones, beret, lanyard, starClip, pencil }

struct Look {
    let id: String
    var skin = rgb(0xFFE6D6), skinShade = rgb(0xF3C7B4)
    var hair: CGColor, hairDark: CGColor, hairLight: CGColor
    var iris: CGColor, irisDark: CGColor, irisLight: CGColor
    let style: HairStyle
    let outfit: Outfit
    /// The main garment, also used for the sleeves.
    var top: CGColor, topDark: CGColor
    /// Shirt or blouse showing under a jacket or cardigan.
    var shirt = white
    var tie: CGColor? = nil
    /// Trousers drawn as the legs; nil shows bare legs.
    var trousers: CGColor? = nil
    /// A skirt below a jacket or cardigan.
    var skirt: CGColor? = nil
    var shoe = rgb(0x3A2A2A)
    var sock = white
    var accent = rgb(0xE3B341)     // small details: hoodie strings, laptop logo, clips, paint
    var restingLid: CGFloat = 0     // how much the upper lid covers the eye at rest
    var extras: [Accessory] = []
}

let looks: [Look] = [
    // Software developers.
    Look(id: "kai",
         hair: rgb(0x2E3550), hairDark: rgb(0x1A2035), hairLight: rgb(0x5E6C96),
         iris: rgb(0x3FAE9A), irisDark: rgb(0x1A5A50), irisLight: rgb(0xA0E8D8),
         style: .spiky, outfit: .hoodie, top: rgb(0x3A3F4B), topDark: rgb(0x272B33),
         trousers: rgb(0x2B3242), shoe: rgb(0xEDEDED), accent: rgb(0x3DDC84), restingLid: 0.3,
         extras: [.headphones]),
    Look(id: "rin",
         hair: rgb(0x6B4FA0), hairDark: rgb(0x48347A), hairLight: rgb(0xA58AD6),
         iris: rgb(0x8A6AE0), irisDark: rgb(0x3A2A80), irisLight: rgb(0xD0C2FF),
         style: .ponytail, outfit: .hoodie, top: rgb(0xB9A6E0), topDark: rgb(0x9682C4),
         shoe: rgb(0x2F2F3A), sock: rgb(0x2F2F3A), accent: rgb(0xFF7AB6), extras: [.glasses]),

    // Office workers.
    Look(id: "taro",
         hair: rgb(0x3A2A22), hairDark: rgb(0x22180F), hairLight: rgb(0x6A5242),
         iris: rgb(0x6A4A2A), irisDark: rgb(0x34200E), irisLight: rgb(0xC0A070),
         style: .short, outfit: .suit, top: rgb(0x2E3A5C), topDark: rgb(0x1F2840),
         tie: rgb(0xC8323A), trousers: rgb(0x2A344F), shoe: rgb(0x1E1E24), extras: [.lanyard]),
    Look(id: "hana",
         hair: rgb(0x8A5A3B), hairDark: rgb(0x6A4029), hairLight: rgb(0xC4936F),
         iris: rgb(0xA0602A), irisDark: rgb(0x5A3010), irisLight: rgb(0xE8B080),
         style: .long, outfit: .cardigan, top: rgb(0xF4A6B8), topDark: rgb(0xD9849A),
         skirt: rgb(0x3A4A7A), shoe: rgb(0x8A4A32), accent: rgb(0xFFD84D), extras: [.starClip]),

    // Designers.
    Look(id: "leo",
         hair: rgb(0xC4703A), hairDark: rgb(0x9A4E22), hairLight: rgb(0xF0A870),
         iris: rgb(0x4F86E8), irisDark: rgb(0x1F3F87), irisLight: rgb(0xB3CCFF),
         style: .short, outfit: .turtleneck, top: rgb(0x2A2A30), topDark: rgb(0x18181D),
         trousers: rgb(0xC8B48A), shoe: rgb(0x6A4028), accent: rgb(0xFF5C8A), extras: [.beret]),
    Look(id: "mei",
         hair: rgb(0xF59BC2), hairDark: rgb(0xD96E9C), hairLight: rgb(0xFFCFE3),
         iris: rgb(0x58BFD6), irisDark: rgb(0x226B80), irisLight: rgb(0xB5ECF7),
         style: .buns, outfit: .turtleneck, top: rgb(0xF2C14E), topDark: rgb(0xD9A22E),
         shoe: rgb(0x5B8DEF), sock: rgb(0xF4F4F0), accent: rgb(0x5B8DEF), extras: [.pencil]),

    // Marketing & content creators.
    Look(id: "ken",
         hair: rgb(0xF2C94C), hairDark: rgb(0xD9A022), hairLight: rgb(0xFFF0A0),
         iris: rgb(0xD9A030), irisDark: rgb(0x7A4A10), irisLight: rgb(0xFFE0A0),
         style: .spiky, outfit: .blazer, top: rgb(0xF28C38), topDark: rgb(0xD06A1E),
         trousers: rgb(0x3B5B8C), shoe: rgb(0xF4F4F0), accent: rgb(0xFF5C8A)),
    Look(id: "yui",
         hair: rgb(0xE8A0A0), hairDark: rgb(0xC87878), hairLight: rgb(0xFFD0D0),
         iris: rgb(0xE86A9A), irisDark: rgb(0x8A2A50), irisLight: rgb(0xFFC2DB),
         style: .bob, outfit: .blazer, top: rgb(0xE85A7A), topDark: rgb(0xC23E5C),
         skirt: rgb(0x2E2B3A), shoe: rgb(0x2E2B3A), accent: rgb(0xFFD84D), extras: [.starClip]),

    // Project managers & business analysts.
    Look(id: "sora",
         hair: rgb(0x2A3A44), hairDark: rgb(0x18222A), hairLight: rgb(0x5A7080),
         iris: rgb(0x3A5A7A), irisDark: rgb(0x1A2A40), irisLight: rgb(0x9AB8D8),
         style: .short, outfit: .shirt, top: rgb(0xBFD9F2), topDark: rgb(0x9ABCDE),
         tie: rgb(0x2E3A5C), trousers: rgb(0x4A4E58), shoe: rgb(0x2A1E1A), extras: [.lanyard]),
    Look(id: "aki",
         hair: rgb(0x2A2A33), hairDark: rgb(0x16161C), hairLight: rgb(0x5A5A6A),
         iris: rgb(0x6A7480), irisDark: rgb(0x2E343C), irisLight: rgb(0xB0B8C4),
         style: .long, outfit: .blazer, top: rgb(0x5A6070), topDark: rgb(0x3E4350),
         skirt: rgb(0x3E4350), shoe: rgb(0x1E1E24), sock: rgb(0x2A2A30), restingLid: 0.2, extras: [.glasses]),
]

// MARK: - Character

let feet = CGPoint(x: 64, y: 122)

func drawCharacter(_ ctx: CGContext, _ pose: Pose, _ look: Look) {
    ctx.saveGState()
    ctx.translateBy(x: feet.x, y: feet.y)

    // Ground shadow (does not bob).
    ctx.fillEllipse(.zero, 22, 4.5, rgb(0x000000, 0.18))

    ctx.translateBy(x: 0, y: pose.bob + (pose.sitting ? 15 : 0))
    ctx.rotate(by: pose.lean)

    let head = CGPoint(x: 0, y: -76)
    func withHead(_ draw: () -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -50); ctx.rotate(by: pose.tilt); ctx.translateBy(x: 0, y: 50)
        draw()
        ctx.restoreGState()
    }

    func leg(_ x: CGFloat, _ angle: CGFloat, dark: Bool) {
        let color = look.trousers ?? (dark ? look.skinShade : look.skin)
        limb(ctx, from: CGPoint(x: x, y: -20), angle: angle, length: 17, width: 6, color: color) { foot in
            ctx.fillEllipse(CGPoint(x: foot.x, y: foot.y - 3), 3.6, 3, look.sock)
            ctx.saveGState()
            ctx.translateBy(x: foot.x, y: foot.y)
            ctx.rotate(by: -angle * 0.5)
            ctx.fill({ $0.addEllipse(in: CGRect(x: -4, y: -2, width: 10, height: 6)) }, look.shoe, outlineWidth: 1.2)
            ctx.restoreGState()
        }
    }

    func arm(_ x: CGFloat, _ angle: CGFloat, dark: Bool) -> CGPoint {
        limb(ctx, from: CGPoint(x: x, y: -44), angle: angle, length: 15, width: 5,
             color: dark ? look.topDark : look.top) { hand in
            ctx.fill({ $0.addEllipse(in: CGRect(x: hand.x - 3.4, y: hand.y - 3.4, width: 6.8, height: 6.8)) },
                     dark ? look.skinShade : look.skin, outlineWidth: 1.2)
        }
    }

    withHead { drawLongHair(ctx, look, head, swing: pose.hairSwing, sitting: pose.sitting) }

    leg(-5, pose.sitting ? 1.45 : pose.legBack, dark: true)
    _ = arm(-9, pose.armBack, dark: true)
    drawOutfit(ctx, look)
    leg(5, pose.sitting ? 1.6 : pose.legFront, dark: false)

    withHead {
        drawHairCap(ctx, look, head)
        ctx.fill({ $0.addEllipse(in: CGRect(x: head.x - 27, y: head.y - 25, width: 54, height: 50)) }, look.skin)
        drawFace(ctx, head: head, pose: pose, look: look)
        if look.extras.contains(.glasses) { drawGlasses(ctx, head) }
        drawBangs(ctx, look, head)
        for extra in look.extras where extra != .glasses { drawExtra(ctx, extra, look, head) }
    }

    let hand = arm(9, pose.armFront, dark: false)
    if pose.cup { drawCup(ctx, at: hand, tilt: -max(0, pose.armFront - 1.2) * 0.9) }
    if pose.laptop { drawLaptop(ctx, look) }
    if pose.sweat { drawDrop(ctx, at: CGPoint(x: -25, y: head.y - 14), size: 1) }
    ctx.restoreGState()
}

// MARK: - Hair

/// Hair that hangs behind the body.
func drawLongHair(_ ctx: CGContext, _ look: Look, _ h: CGPoint, swing: CGFloat, sitting: Bool) {
    let shorten: CGFloat = sitting ? 18 : 0   // hair rests on the floor when sitting
    switch look.style {
    case .long:
        let bottom = h.y + 62 - shorten
        ctx.fillGradient({ p in
            p.move(to: CGPoint(x: h.x - 28, y: h.y - 4))
            p.addCurve(to: CGPoint(x: h.x - 30 + swing * 20, y: bottom),
                       control1: CGPoint(x: h.x - 36, y: h.y + 24), control2: CGPoint(x: h.x - 34, y: bottom - 20))
            p.addQuadCurve(to: CGPoint(x: h.x + 28 + swing * 20, y: bottom), control: CGPoint(x: h.x + swing * 20, y: bottom + 6))
            p.addCurve(to: CGPoint(x: h.x + 28, y: h.y - 4),
                       control1: CGPoint(x: h.x + 34, y: bottom - 20), control2: CGPoint(x: h.x + 36, y: h.y + 24))
            p.closeSubpath()
        }, [look.hairDark, look.hair], from: h.y + 20, to: bottom)
    case .ponytail:
        // Ponytail swinging behind the back-side of the head.
        let top = CGPoint(x: h.x - 22, y: h.y - 14)
        let tip = CGPoint(x: h.x - 34 + swing * 30, y: h.y + 40 - shorten / 2)
        ctx.fill({ p in
            p.move(to: CGPoint(x: top.x - 2, y: top.y - 6))
            p.addCurve(to: tip, control1: CGPoint(x: top.x - 22, y: top.y + 4), control2: CGPoint(x: tip.x - 10, y: tip.y - 16))
            p.addCurve(to: CGPoint(x: top.x + 6, y: top.y + 4), control1: CGPoint(x: tip.x + 6, y: tip.y - 14),
                       control2: CGPoint(x: top.x - 4, y: top.y + 16))
            p.closeSubpath()
        }, look.hair)
    case .short, .spiky, .bob, .buns:
        break
    }
}

/// Hair volume behind the face.
func drawHairCap(_ ctx: CGContext, _ look: Look, _ h: CGPoint) {
    switch look.style {
    case .short:
        ctx.fill({ $0.addEllipse(in: CGRect(x: h.x - 30, y: h.y - 32, width: 60, height: 52)) }, look.hairDark)
    case .ponytail, .long:
        ctx.fill({ $0.addEllipse(in: CGRect(x: h.x - 31, y: h.y - 31, width: 62, height: 56)) }, look.hairDark)
    case .bob:
        // Chin-length bob curling in under the cheeks.
        ctx.fill({ p in
            p.move(to: CGPoint(x: h.x - 20, y: h.y + 22))
            p.addCurve(to: CGPoint(x: h.x, y: h.y - 32), control1: CGPoint(x: h.x - 40, y: h.y + 18), control2: CGPoint(x: h.x - 37, y: h.y - 32))
            p.addCurve(to: CGPoint(x: h.x + 20, y: h.y + 22), control1: CGPoint(x: h.x + 37, y: h.y - 32), control2: CGPoint(x: h.x + 40, y: h.y + 18))
            p.closeSubpath()
        }, look.hairDark)
    case .spiky:
        ctx.fill({ p in
            p.addEllipse(in: CGRect(x: h.x - 31, y: h.y - 31, width: 62, height: 54))
            // Tufts sticking out at the sides.
            for (bx, by, tx, ty) in [(-29.0, -10.0, -38.0, -2.0), (-27.0, 2.0, -34.0, 12.0), (29.0, -10.0, 38.0, -2.0),
                                     (27.0, 2.0, 33.0, 12.0)] {
                p.move(to: CGPoint(x: h.x + CGFloat(bx), y: h.y + CGFloat(by) - 6))
                p.addLine(to: CGPoint(x: h.x + CGFloat(tx), y: h.y + CGFloat(ty)))
                p.addLine(to: CGPoint(x: h.x + CGFloat(bx), y: h.y + CGFloat(by) + 6))
                p.closeSubpath()
            }
        }, look.hairDark)
    case .buns:
        for side: CGFloat in [-1, 1] {
            ctx.fillGradient({ $0.addEllipse(in: CGRect(x: h.x + side * 22 - 10, y: h.y - 38, width: 20, height: 20)) },
                             [look.hair, look.hairDark], from: h.y - 38, to: h.y - 18)
        }
        ctx.fill({ $0.addEllipse(in: CGRect(x: h.x - 31, y: h.y - 31, width: 62, height: 56)) }, look.hairDark)
    }
}

/// Fringe over the forehead. Tips are listed right-to-left relative to the head center.
func drawBangs(_ ctx: CGContext, _ look: Look, _ h: CGPoint) {
    let tips: [(CGFloat, CGFloat)]
    switch look.style {
    case .short:
        // Neat cut swept to one side.
        tips = [(27, 2), (23, -6), (17, -12), (10, -15), (3, -14), (-4, -10), (-9, -14), (-15, -10), (-21, -4), (-27, 2)]
    case .spiky:
        tips = [(27, 4), (22, -6), (17, -2), (12, -14), (6, -6), (1, -18), (-5, -7), (-11, -15), (-17, -4), (-22, -8), (-27, 4)]
    case .bob, .buns:
        tips = [(26, -2), (19, 1), (12, -10), (5, -2), (-1, -12), (-7, -2), (-14, -10), (-20, 1), (-26, -2)]
    case .ponytail:
        tips = [(26, 0), (20, -4), (12, -14), (4, -12), (-4, -10), (-12, -6), (-20, 0), (-26, 2)]
    case .long:
        tips = [(26, -2), (20, 2), (13, -11), (6, -2), (1, -16), (-4, -2), (-12, -11), (-19, 2), (-26, -2)]
    }
    ctx.fill({ p in
        p.move(to: CGPoint(x: h.x - 30, y: h.y + 6))
        p.addCurve(to: CGPoint(x: h.x + 30, y: h.y + 6),
                   control1: CGPoint(x: h.x - 34, y: h.y - 40), control2: CGPoint(x: h.x + 34, y: h.y - 40))
        for (x, y) in tips { p.addLine(to: CGPoint(x: h.x + x, y: h.y + y)) }
        p.closeSubpath()
    }, look.hair)

    // Side locks framing the cheeks.
    if look.style == .long {
        for side: CGFloat in [-1, 1] {
            ctx.fill({ p in
                p.move(to: CGPoint(x: h.x + side * 27, y: h.y - 8))
                p.addQuadCurve(to: CGPoint(x: h.x + side * 23, y: h.y + 26), control: CGPoint(x: h.x + side * 30, y: h.y + 12))
                p.addQuadCurve(to: CGPoint(x: h.x + side * 21, y: h.y - 4), control: CGPoint(x: h.x + side * 22, y: h.y + 10))
                p.closeSubpath()
            }, look.hair, outlineWidth: 1.2)
        }
    }

    // Shine.
    ctx.stroke({ p in
        p.addArc(center: CGPoint(x: h.x - 4, y: h.y - 6), radius: 22, startAngle: .pi * 1.18, endAngle: .pi * 1.38, clockwise: false)
    }, look.hairLight, 3)
}

// MARK: - Accessories

func drawGlasses(_ ctx: CGContext, _ h: CGPoint) {
    for o in eyeOffsets {
        let r = CGRect(x: h.x + o.x - 8, y: h.y + o.y - 8, width: 16, height: 16)
        ctx.fillEllipse(CGPoint(x: r.midX, y: r.midY), 8, 8, rgb(0xFFFFFF, 0.18))
        ctx.stroke({ $0.addEllipse(in: r) }, rgb(0x1E1E24), 1.8)
    }
    ctx.stroke({ p in
        p.move(to: CGPoint(x: h.x + eyeOffsets[0].x + 8, y: h.y + eyeOffsets[0].y - 1))
        p.addQuadCurve(to: CGPoint(x: h.x + eyeOffsets[1].x - 8, y: h.y + eyeOffsets[1].y - 1),
                       control: CGPoint(x: h.x + 2, y: h.y - 2))
    }, rgb(0x1E1E24), 1.6)
}

func drawExtra(_ ctx: CGContext, _ extra: Accessory, _ look: Look, _ h: CGPoint) {
    switch extra {
    case .glasses:
        drawGlasses(ctx, h)
    case .starClip:
        let c = CGPoint(x: h.x + 18, y: h.y - 17)
        for (color, width) in [(outline, CGFloat(3.6)), (look.accent, CGFloat(2))] {
            for i in 0..<8 {
                let a = CGFloat(i) / 8 * 2 * .pi
                let len: CGFloat = i % 2 == 0 ? 6 : 4.5
                ctx.stroke({ p in p.move(to: c); p.addLine(to: CGPoint(x: c.x + cos(a) * len, y: c.y + sin(a) * len)) }, color, width)
            }
        }
    case .headphones:
        for (color, width) in [(outline, CGFloat(6.4)), (rgb(0x2B2F36), CGFloat(4))] {
            ctx.stroke({ p in
                p.addArc(center: CGPoint(x: h.x, y: h.y + 2), radius: 33, startAngle: .pi * 1.02, endAngle: .pi * 1.98, clockwise: false)
            }, color, width)
        }
        for side: CGFloat in [-1, 1] {
            ctx.fill({ $0.addRoundedRect(in: CGRect(x: h.x + side * 31 - 5, y: h.y - 6, width: 10, height: 16),
                                         cornerWidth: 4, cornerHeight: 4) }, rgb(0x2B2F36), outlineWidth: 1.4)
            ctx.fillEllipse(CGPoint(x: h.x + side * 31, y: h.y + 2), 2.2, 4, look.accent)
        }
    case .beret:
        // A red beret slouched toward the back, with its little stalk on top.
        ctx.fill({ p in
            p.move(to: CGPoint(x: h.x - 34, y: h.y - 14))
            p.addCurve(to: CGPoint(x: h.x + 26, y: h.y - 20), control1: CGPoint(x: h.x - 36, y: h.y - 44), control2: CGPoint(x: h.x + 22, y: h.y - 46))
            p.addQuadCurve(to: CGPoint(x: h.x - 34, y: h.y - 14), control: CGPoint(x: h.x - 4, y: h.y - 12))
        }, rgb(0xD83A3A))
        ctx.stroke({ p in p.move(to: CGPoint(x: h.x - 6, y: h.y - 38)); p.addLine(to: CGPoint(x: h.x - 4, y: h.y - 44)) }, outline, 2.4)
    case .pencil:
        // Tucked behind the ear.
        ctx.saveGState()
        ctx.translateBy(x: h.x + 27, y: h.y - 4)
        ctx.rotate(by: -0.7)
        ctx.fill({ $0.addRect(CGRect(x: -2.5, y: -13, width: 5, height: 20)) }, rgb(0xFFD84D), outlineWidth: 1.1)
        ctx.fill({ p in
            p.move(to: CGPoint(x: -2.5, y: 7)); p.addLine(to: CGPoint(x: 2.5, y: 7)); p.addLine(to: CGPoint(x: 0, y: 12)); p.closeSubpath()
        }, rgb(0xF2D3B0), outlineWidth: 1)
        ctx.fill({ $0.addRect(CGRect(x: -2.5, y: -16, width: 5, height: 3)) }, rgb(0xFF8FA3), outlineWidth: 1)
        ctx.restoreGState()
    case .lanyard:
        break   // drawn with the outfit, see drawOutfit
    }
}

/// Glass of water held in a hand, tilted toward the mouth when drinking.
func drawCup(_ ctx: CGContext, at hand: CGPoint, tilt: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: hand.x, y: hand.y)
    ctx.rotate(by: tilt)
    let glass = CGRect(x: -4.5, y: -13, width: 9, height: 15)
    ctx.fill({ $0.addRoundedRect(in: glass, cornerWidth: 2, cornerHeight: 2) }, rgb(0xEAF6FF, 0.85), outlineWidth: 1.3)
    ctx.saveGState()
    ctx.addRect(glass.insetBy(dx: 1, dy: 1)); ctx.clip()
    ctx.setFillColor(rgb(0x5BB8F5, 0.85))
    ctx.fill(CGRect(x: -6, y: -6, width: 12, height: 9))
    ctx.restoreGState()
    ctx.stroke({ p in p.move(to: CGPoint(x: -2.5, y: -10)); p.addLine(to: CGPoint(x: -2.5, y: -4)) }, white, 1.2)
    ctx.restoreGState()
}

/// Laptop on the lap, screen facing the character (we see its back).
func drawLaptop(_ ctx: CGContext, _ look: Look) {
    ctx.fill({ $0.addRoundedRect(in: CGRect(x: -15, y: -24, width: 34, height: 5), cornerWidth: 2, cornerHeight: 2) },
             rgb(0xB8BDC8), outlineWidth: 1.3)
    ctx.fillGradient({ $0.addRoundedRect(in: CGRect(x: -13, y: -46, width: 30, height: 23), cornerWidth: 3, cornerHeight: 3) },
                     [rgb(0xDADDE4), rgb(0xA9AFBC)], from: -46, to: -23, outlineWidth: 1.4)
    ctx.fillEllipse(CGPoint(x: 2, y: -35), 3, 3, look.accent)
}

// MARK: - Outfits

func dressPath(_ p: CGMutablePath) {
    p.move(to: CGPoint(x: -9, y: -48))
    p.addLine(to: CGPoint(x: 9, y: -48))
    p.addQuadCurve(to: CGPoint(x: 17, y: -17), control: CGPoint(x: 13, y: -30))
    p.addQuadCurve(to: CGPoint(x: -17, y: -17), control: CGPoint(x: 0, y: -13))
    p.addQuadCurve(to: CGPoint(x: -9, y: -48), control: CGPoint(x: -13, y: -30))
}

/// A straight-cut jacket or shirt that stops at the hips, over the legs.
func jacketPath(_ p: CGMutablePath) {
    p.move(to: CGPoint(x: -10, y: -48)); p.addLine(to: CGPoint(x: 10, y: -48))
    p.addQuadCurve(to: CGPoint(x: 14, y: -19), control: CGPoint(x: 15, y: -38))
    p.addLine(to: CGPoint(x: 3, y: -18)); p.addLine(to: CGPoint(x: 1, y: -21)); p.addLine(to: CGPoint(x: -1, y: -18))
    p.addLine(to: CGPoint(x: -13, y: -19))
    p.addQuadCurve(to: CGPoint(x: -10, y: -48), control: CGPoint(x: -14, y: -38))
}

/// Draws inside a silhouette only.
func inside(_ ctx: CGContext, _ shape: (CGMutablePath) -> Void, _ draw: () -> Void) {
    ctx.saveGState()
    let p = CGMutablePath(); shape(p)
    ctx.addPath(p); ctx.clip()
    draw()
    ctx.restoreGState()
}

func drawTie(_ ctx: CGContext, _ color: CGColor) {
    ctx.fill({ p in
        p.move(to: CGPoint(x: -1.5, y: -46)); p.addLine(to: CGPoint(x: 3.5, y: -46))
        p.addLine(to: CGPoint(x: 2.6, y: -43.5)); p.addLine(to: CGPoint(x: 3.6, y: -28))
        p.addLine(to: CGPoint(x: 1, y: -25)); p.addLine(to: CGPoint(x: -1.6, y: -28))
        p.addLine(to: CGPoint(x: -0.6, y: -43.5)); p.closeSubpath()
    }, color, outlineWidth: 1)
}

func drawCollar(_ ctx: CGContext, _ color: CGColor) {
    for side: CGFloat in [-1, 1] {
        ctx.fill({ p in
            p.move(to: CGPoint(x: 1 + side * 1.5, y: -47)); p.addLine(to: CGPoint(x: 1 + side * 8, y: -49))
            p.addLine(to: CGPoint(x: 1 + side * 4.5, y: -42)); p.closeSubpath()
        }, color, outlineWidth: 0.9)
    }
}

func drawSkirt(_ ctx: CGContext, _ color: CGColor) {
    ctx.fill({ p in
        p.move(to: CGPoint(x: -13, y: -26)); p.addLine(to: CGPoint(x: 14, y: -26))
        p.addLine(to: CGPoint(x: 18, y: -13)); p.addQuadCurve(to: CGPoint(x: -17, y: -13), control: CGPoint(x: 0, y: -11))
        p.closeSubpath()
    }, color)
}

func drawOutfit(_ ctx: CGContext, _ look: Look) {
    if let skirt = look.skirt, [.suit, .blazer].contains(look.outfit) { drawSkirt(ctx, skirt) }
    switch look.outfit {
    case .hoodie:
        ctx.fill(dressPath, look.top)
        inside(ctx, dressPath) {
            // Kangaroo pocket and ribbed hem.
            ctx.stroke({ $0.addRoundedRect(in: CGRect(x: -9, y: -31, width: 20, height: 8), cornerWidth: 3, cornerHeight: 3) }, look.topDark, 1.4)
            ctx.stroke({ p in p.move(to: CGPoint(x: -20, y: -20)); p.addQuadCurve(to: CGPoint(x: 20, y: -20), control: CGPoint(x: 0, y: -16)) }, look.topDark, 1.6)
        }
        // Hood around the neck.
        ctx.stroke({ p in
            p.move(to: CGPoint(x: -10, y: -48)); p.addQuadCurve(to: CGPoint(x: 11, y: -48), control: CGPoint(x: 1, y: -39))
        }, look.topDark, 3)
        for x: CGFloat in [-3, 5] {
            ctx.stroke({ p in p.move(to: CGPoint(x: x, y: -44)); p.addLine(to: CGPoint(x: x - 0.5, y: -36)) }, look.accent, 1.3)
            ctx.fillEllipse(CGPoint(x: x - 0.5, y: -35.5), 1.3, 1.3, look.accent)
        }
    case .suit, .blazer:
        ctx.fill(jacketPath, look.top)
        inside(ctx, jacketPath) {
            // Shirt (or a tee under a blazer) showing in the V of the jacket.
            ctx.fill({ p in
                p.move(to: CGPoint(x: -8, y: -49)); p.addLine(to: CGPoint(x: 10, y: -49))
                p.addLine(to: CGPoint(x: 2, y: -30)); p.addLine(to: CGPoint(x: 0, y: -30)); p.closeSubpath()
            }, look.shirt, outlineWidth: 0)
            if let tie = look.tie { drawTie(ctx, tie) }
            if look.outfit == .suit { drawCollar(ctx, look.shirt) }
            // Lapels.
            for side: CGFloat in [-1, 1] {
                ctx.fill({ p in
                    p.move(to: CGPoint(x: 1 + side * 10, y: -49)); p.addLine(to: CGPoint(x: 1 + side * 5, y: -42))
                    p.addLine(to: CGPoint(x: 1 + side * 8, y: -40)); p.addLine(to: CGPoint(x: 1 + side * 1.2, y: -29))
                    p.addLine(to: CGPoint(x: 1 + side * 14, y: -40)); p.closeSubpath()
                }, look.topDark, outlineWidth: 1)
            }
            ctx.stroke({ $0.move(to: CGPoint(x: 1, y: -29)); $0.addLine(to: CGPoint(x: 1, y: -21)) }, look.topDark, 1)
        }
        ctx.fillEllipse(CGPoint(x: 3.5, y: -26), 1.3, 1.3, rgb(0x0E0E12))
        if look.outfit == .blazer {
            // A pocket square in the accent color.
            ctx.fill({ p in
                p.move(to: CGPoint(x: -9, y: -38)); p.addLine(to: CGPoint(x: -4, y: -38)); p.addLine(to: CGPoint(x: -6, y: -42)); p.closeSubpath()
            }, look.accent, outlineWidth: 0.8)
        }
    case .shirt:
        // Dress shirt tucked into the trousers, with a belt.
        ctx.fill(jacketPath, look.top)
        inside(ctx, jacketPath) {
            ctx.stroke({ $0.move(to: CGPoint(x: 1, y: -44)); $0.addLine(to: CGPoint(x: 1, y: -22)) }, look.topDark, 1)
            for y: CGFloat in [-38, -32, -26] { ctx.fillEllipse(CGPoint(x: 2.5, y: y), 0.9, 0.9, look.topDark) }
            ctx.setFillColor(rgb(0x3A2A22))
            ctx.fill(CGRect(x: -20, y: -23, width: 40, height: 4))
        }
        if let tie = look.tie { drawTie(ctx, tie) }
        drawCollar(ctx, look.top)
    case .cardigan:
        // A blouse and skirt with an open cardigan over them.
        ctx.fill(dressPath, look.shirt)
        inside(ctx, dressPath) {
            ctx.setFillColor(look.skirt ?? look.topDark)
            ctx.fill(CGRect(x: -20, y: -28, width: 40, height: 14))
            ctx.setFillColor(look.top)
            ctx.fill(CGRect(x: -20, y: -50, width: 15, height: 24))
            ctx.fill(CGRect(x: 7, y: -50, width: 14, height: 24))
            ctx.stroke({ p in
                p.move(to: CGPoint(x: -5, y: -50)); p.addLine(to: CGPoint(x: -5, y: -26))
                p.move(to: CGPoint(x: 7, y: -50)); p.addLine(to: CGPoint(x: 7, y: -26))
            }, outline, 1)
            for y: CGFloat in [-42, -35] { ctx.fillEllipse(CGPoint(x: -7.5, y: y), 1.2, 1.2, look.accent) }
        }
        drawCollar(ctx, look.shirt)
    case .turtleneck:
        ctx.fill(dressPath, look.top)
        inside(ctx, dressPath) {
            // A few paint spots: designers never quite get it all off.
            for (x, y, r) in [(-10.0, -24.0, 1.8), (8.0, -30.0, 1.4), (-4.0, -36.0, 1.2), (11.0, -21.0, 1.6)] {
                ctx.fillEllipse(CGPoint(x: CGFloat(x), y: CGFloat(y)), CGFloat(r), CGFloat(r), look.accent)
            }
        }
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: -9, y: -52, width: 20, height: 8), cornerWidth: 3, cornerHeight: 3) },
                 look.topDark, outlineWidth: 1.2)
        for x: CGFloat in [-5, -1, 3, 7] {
            ctx.stroke({ p in p.move(to: CGPoint(x: x, y: -51)); p.addLine(to: CGPoint(x: x, y: -45)) }, look.top, 0.8)
        }
    }
    if look.extras.contains(.lanyard) {
        // Staff ID badge on a lanyard.
        ctx.stroke({ p in
            p.move(to: CGPoint(x: -7, y: -48)); p.addLine(to: CGPoint(x: -3, y: -36))
            p.move(to: CGPoint(x: 9, y: -48)); p.addLine(to: CGPoint(x: 5, y: -36))
        }, rgb(0x3B6FB6), 1.4)
        ctx.fill({ $0.addRoundedRect(in: CGRect(x: -4, y: -37, width: 10, height: 12), cornerWidth: 1.5, cornerHeight: 1.5) }, white, outlineWidth: 1)
        ctx.setFillColor(rgb(0x3B6FB6))
        ctx.fill(CGRect(x: -3, y: -36, width: 8, height: 3))
        ctx.fillEllipse(CGPoint(x: 1, y: -29.5), 1.8, 1.8, rgb(0xC0C4CC))
    }
}
