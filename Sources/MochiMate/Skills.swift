import AppKit

/// Two signature moves per character: a line of dialogue plus a screen-filling effect (see SkillOverlay).
/// Used now and then between reminders, or picked from the menu.
enum Skill: String, CaseIterable {
    case deploy, bugSquash              // Kai
    case codeRain, refactorBeam         // Rin
    case paydayRain, approvalStamp      // Taro
    case snackParty, gossipBubbles      // Hana
    case colorSplash, biggerLogo        // Leo
    case pastelAurora, pixelGrid        // Mei
    case goViral, megaphone             // Ken
    case selfieFlash, liveStream        // Yui
    case quickSync, scopeShield         // Sora
    case checklist, radar               // Aki
    case woodenFish, incense            // Tâm
    case templeBell, meditation         // Thầy Minh

    /// How long the character holds the pose while the effect plays: the monks' effects are timed for 10 s, everyone else's for 3 s.
    var duration: TimeInterval { characterID == "tam" || characterID == "minh" ? 10 : 3 }

    static func all(for characterID: String) -> [Skill] { allCases.filter { $0.characterID == characterID } }

    var characterID: String {
        let ids = ["kai", "rin", "taro", "hana", "leo", "mei", "ken", "yui", "sora", "aki", "tam", "minh"]
        return ids[Skill.allCases.firstIndex(of: self)! / 2]
    }

    /// 1 or 2: which of the character's two moves, which is also its line of dialogue (`skill1` / `skill2`).
    var slot: Int { Skill.allCases.firstIndex(of: self)! % 2 + 1 }
    var lineKind: LineKind { slot == 1 ? .skill1 : .skill2 }

    var anim: Anim {
        switch self {
        case .deploy, .goViral, .megaphone, .quickSync: return .wave
        case .bugSquash, .refactorBeam, .codeRain, .scopeShield: return .kick
        case .pastelAurora, .biggerLogo: return .stretch
        case .woodenFish: return .knock
        case .incense: return .pray
        case .templeBell: return .bell
        case .meditation: return .meditate
        default: return .happy
        }
    }

    var title: String { skillNames[Language.current]?[self] ?? skillNames[.en]?[self] ?? rawValue }
}

private let skillNames: [Language: [Skill: String]] = [
    .vi: [
        .deploy: "Phóng Deploy", .bugSquash: "Diệt Bug", .codeRain: "Mưa Code", .refactorBeam: "Tia Refactor",
        .paydayRain: "Mưa Lương", .approvalStamp: "Đóng Dấu Duyệt", .snackParty: "Tiệc Snack", .gossipBubbles: "Bong Bóng Tin Đồn",
        .colorSplash: "Tung Màu", .biggerLogo: "Logo To Thêm Nữa", .pastelAurora: "Cực Quang Pastel", .pixelGrid: "Pixel Perfect",
        .goViral: "Lên Xu Hướng", .megaphone: "Loa Phóng Thanh", .selfieFlash: "Flash Selfie", .liveStream: "Livestream Thả Tim",
        .quickSync: "Sync 5 Phút", .scopeShield: "Khiên Chống Scope Creep", .checklist: "Acceptance Criteria", .radar: "Radar Yêu Cầu",
        .woodenFish: "Gõ Mõ Tụng Kinh", .incense: "Thắp Hương", .templeBell: "Thỉnh Chuông", .meditation: "Thiền Định",
    ],
    .en: [
        .deploy: "Deploy Rocket", .bugSquash: "Bug Squash", .codeRain: "Code Rain", .refactorBeam: "Refactor Beam",
        .paydayRain: "Payday Rain", .approvalStamp: "Approval Stamp", .snackParty: "Snack Party", .gossipBubbles: "Gossip Bubbles",
        .colorSplash: "Color Splash", .biggerLogo: "Make It Bigger", .pastelAurora: "Pastel Aurora", .pixelGrid: "Pixel Perfect",
        .goViral: "Go Viral", .megaphone: "Megaphone Blast", .selfieFlash: "Selfie Flash", .liveStream: "Live Stream",
        .quickSync: "Quick Sync", .scopeShield: "Scope Shield", .checklist: "Acceptance Criteria", .radar: "Requirements Radar",
        .woodenFish: "Chant & Wooden Fish", .incense: "Offer Incense", .templeBell: "Temple Bell", .meditation: "Meditation",
    ],
    .ja: [
        .deploy: "デプロイ・ロケット", .bugSquash: "バグ退治", .codeRain: "コードの雨", .refactorBeam: "リファクタビーム",
        .paydayRain: "給料日の雨", .approvalStamp: "承認ハンコ", .snackParty: "おやつパーティー", .gossipBubbles: "うわさバブル",
        .colorSplash: "カラースプラッシュ", .biggerLogo: "ロゴもっと大きく", .pastelAurora: "パステルオーロラ", .pixelGrid: "ピクセルパーフェクト",
        .goViral: "バズ爆発", .megaphone: "メガホンブラスト", .selfieFlash: "自撮りフラッシュ", .liveStream: "ライブ配信",
        .quickSync: "5分シンク", .scopeShield: "スコープシールド", .checklist: "受け入れ基準", .radar: "要件レーダー",
        .woodenFish: "木魚と読経", .incense: "お焼香", .templeBell: "鐘の音", .meditation: "坐禅",
    ],
]

// MARK: - Effects

extension Skill {
    /// Draws the effect. Sizes are meant to fill the screen: sprites of 200–600 pt, rings and beams across the whole width.
    func cast(_ fx: SkillFX) {
        let W = fx.size.width, H = fx.size.height, c = fx.body, f = fx.facing
        switch self {

        // Kai: a rocket launches off the top of the screen, then the bugs come down and get squashed.
        case .deploy:
            fx.glow(at: fx.feet, diameter: 700, color: color(0xFF9F43), duration: 2.2)
            fx.ring(at: fx.feet, color: color(0xFFB347), width: 14, duration: 0.9)
            fx.fly("🚀", 260, from: c, to: CGPoint(x: min(W - 120, c.x + H * 0.6), y: H + 200), tilt: 0, duration: 1.5, delay: 0.5,
                   trail: "🔥", trailPx: 110)
            fx.burst(["✨", "🎉", "🎊"], 80, at: CGPoint(x: min(W - 200, c.x + H * 0.45), y: H * 0.8), rate: 90, seconds: 0.5,
                     velocity: 900, gravity: -500, delay: 1.7)
        case .bugSquash:
            fx.rain(["🐛", "🐞", "🪲", "🦟"], 110, rate: 22, seconds: 2)
            fx.flash(color(0x4ADE80), peak: 0.35, duration: 0.6, delay: 2.2)
            fx.ring(at: c, color: color(0x22C55E), width: 18, duration: 1.2, delay: 2.2)
            fx.burst(["✅", "💚"], 110, at: c, rate: 80, seconds: 0.5, velocity: 1100, gravity: -900, delay: 2.2)

        // Rin: green code columns over the whole screen; a laser sweeping across it.
        case .codeRain:
            fx.rain(["0", "1", "{", "}", "</>", "=>", ";", "&&", "if"], 56, rate: 200, seconds: 3, speed: 620,
                    color: NSColor(srgbRed: 0.2, green: 1, blue: 0.45, alpha: 1))
            fx.glow(at: c, diameter: 800, color: color(0x22C55E), duration: 3.4)
            fx.flash(color(0x052E16), peak: 0.45, duration: 3.4)
        case .refactorBeam:
            fx.glow(at: c, diameter: 500, color: color(0x38BDF8), duration: 1.6)
            fx.gradient([color(0x38BDF8, 0), color(0x38BDF8, 0.9), color(0xFFFFFF), color(0x38BDF8, 0.9), color(0x38BDF8, 0)],
                        frame: CGRect(x: f > 0 ? c.x : 0, y: c.y - 90, width: f > 0 ? W - c.x : c.x, height: 180),
                        start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1), duration: 1.6, delay: 0.4) { layer in
                layer.anchorPoint = CGPoint(x: f > 0 ? 0 : 1, y: 0.5)
                layer.position = CGPoint(x: c.x, y: c.y)
                layer.add(CABasicAnimation.grow("transform.scale.x", from: 0.01, to: 1, duration: 0.25), forKey: "grow")
            }
            fx.burst(["✨", "♻️", "⚡️"], 90, at: CGPoint(x: f > 0 ? W - 300 : 300, y: c.y), rate: 120, seconds: 1.2,
                     velocity: 600, gravity: -300, delay: 0.5)
            fx.flash(.white, peak: 0.5, duration: 0.4, delay: 0.4)

        // Taro: a rain of money; a giant approval stamp slamming down.
        case .paydayRain:
            fx.glow(at: CGPoint(x: W / 2, y: H / 2), diameter: min(W, H) * 1.4, color: color(0xFACC15), duration: 3.5)
            fx.rain(["💴", "💰", "🪙", "💵"], 110, rate: 30, seconds: 3)
            fx.pop(Self.say(vi: "LƯƠNG VỀ!", en: "PAYDAY!", ja: "給料日"), 160, at: CGPoint(x: c.x, y: min(H - 160, c.y + 330)), color: NSColor(srgbRed: 1, green: 0.8, blue: 0.1, alpha: 1),
                   hold: 2, delay: 0.2)
        case .approvalStamp:
            let word = Self.say(vi: "DUYỆT", en: "APPROVED", ja: "承認")
            let size = min(W, H) * 0.7
            let center = CGPoint(x: W / 2, y: H / 2)
            fx.slam({ Skill.stampLayer(word, size: size, at: center) }, from: 4, hold: 2, delay: 0.3)
            fx.flash(color(0xDC2626), peak: 0.25, duration: 0.5, delay: 0.5)
            fx.ring(at: center, radius: size / 2, scale: 4, color: color(0xDC2626), width: 20, duration: 1, delay: 0.5)
            fx.burst(["💨", "📄", "✨"], 100, at: center, rate: 100, seconds: 0.3, velocity: 1000, gravity: -200, life: 1.5, delay: 0.5)

        // Hana: snacks everywhere; gossip bubbles floating up.
        case .snackParty:
            fx.rain(["🍪", "🍩", "🍬", "🍰", "🍡", "🍫"], 110, rate: 34, seconds: 3)
            fx.burst(["💖", "✨"], 90, at: c, rate: 60, seconds: 1, velocity: 600, gravity: -100, life: 2)
            fx.ring(at: c, color: color(0xFF8FB8), width: 14, duration: 1.2)
        case .gossipBubbles:
            fx.rise(["💬", "🗯️", "❓", "❗", "🤭", "👀"], 130, rate: 16, seconds: 3, speed: 300)
            fx.pop("👀", 260, at: CGPoint(x: c.x, y: c.y + 220), hold: 1.8)
            fx.ring(at: c, color: color(0xF472B6), width: 10, duration: 1.4)

        // Leo: paint blobs splash around; the logo grows and grows.
        case .colorSplash:
            let palette = [0xFF4D6D, 0xFFB703, 0x06D6A0, 0x4CC9F0, 0x9D4EDD, 0xFF70A6]
            for i in 0..<12 {
                let center = CGPoint(x: CGFloat.random(in: W * 0.08...W * 0.92), y: CGFloat.random(in: H * 0.12...H * 0.9))
                let r = CGFloat.random(in: 90...220)
                fx.shape(Skill.splat(radius: r), fill: color(UInt32(palette[i % palette.count]), 0.85), duration: 2.6,
                         delay: Double(i) * 0.12) { layer in
                    layer.position = center
                    layer.add(CABasicAnimation.grow("transform.scale", from: 0.1, to: 1, duration: 0.3), forKey: "splash")
                }
            }
            fx.burst(["🎨", "🖌️", "✨"], 90, at: c, rate: 70, seconds: 0.6, velocity: 900, gravity: -500)
        case .biggerLogo:
            fx.glow(at: CGPoint(x: W / 2, y: H / 2), diameter: min(W, H) * 1.5, color: color(0xFFD60A), duration: 3)
            fx.pop("⭐️", min(W, H) * 0.75, at: CGPoint(x: W / 2, y: H / 2), turns: 1, hold: 2)
            fx.pop(Self.say(vi: "TO NỮA!", en: "BIGGER!", ja: "もっと大きく！"), 190, at: CGPoint(x: W / 2, y: H / 2), color: .white, tilt: -0.12, hold: 1.8, delay: 0.5)
            fx.ring(at: CGPoint(x: W / 2, y: H / 2), color: color(0xFFD60A), width: 24, duration: 1.4, delay: 0.3)
            fx.burst(["✨", "🌟"], 90, at: CGPoint(x: W / 2, y: H / 2), rate: 120, seconds: 0.5, velocity: 1000, gravity: -100, delay: 0.3)

        // Mei: pastel aurora over the screen; a pixel grid snaps into place.
        case .pastelAurora:
            let colors = [color(0xFFB3D1), color(0xC8B6FF), color(0xB8F2E6), color(0xFFE3A3), color(0xFFB3D1)]
            for k in 0..<2 {
                fx.gradient(colors, frame: CGRect(x: -W * 0.3, y: H * (k == 0 ? 0.35 : 0.5), width: W * 1.6, height: H * 0.65),
                            start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 1, y: 0.5), peak: 0.75, duration: 3.6, delay: Double(k) * 0.4) { layer in
                    let mask = CAGradientLayer()
                    mask.frame = layer.bounds
                    mask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
                    mask.locations = [0, 1]
                    layer.mask = mask
                    layer.add(CABasicAnimation.grow("position.x", from: layer.position.x - W * 0.15, to: layer.position.x + W * 0.15, duration: 3.6),
                              forKey: "sway")
                }
            }
            fx.rise(["✨", "🌸", "💗"], 70, rate: 18, seconds: 3, speed: 200)
        case .pixelGrid:
            let grid = CGMutablePath()
            var x: CGFloat = 0
            while x <= W { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: H)); x += 40 }
            var y: CGFloat = 0
            while y <= H { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: W, y: y)); y += 40 }
            fx.shape(grid, stroke: color(0xFF6FA8, 0.5), width: 1.5, duration: 3.4)
            let cross = CGMutablePath()
            cross.move(to: CGPoint(x: 0, y: c.y)); cross.addLine(to: CGPoint(x: W, y: c.y))
            cross.move(to: CGPoint(x: c.x, y: 0)); cross.addLine(to: CGPoint(x: c.x, y: H))
            fx.shape(cross, stroke: color(0x38BDF8), width: 4, duration: 3.2, delay: 0.3)
            fx.ring(at: c, radius: 60, scale: 5, color: color(0x38BDF8), width: 8, duration: 1, delay: 0.5)
            fx.pop("1px", 170, at: CGPoint(x: c.x + 260 * -f, y: c.y + 200), color: NSColor(srgbRed: 1, green: 0.3, blue: 0.55, alpha: 1), hold: 1.5, delay: 0.6)
            fx.pop("✅", 200, at: CGPoint(x: c.x + 260 * f, y: c.y + 200), hold: 1.2, delay: 1.7)

        // Ken: a fountain of likes; a megaphone blasting sound waves across the screen.
        case .goViral:
            fx.glow(at: c, diameter: 900, color: color(0xFB923C), duration: 3)
            fx.burst(["❤️", "👍", "🔥", "📈", "💬"], 100, at: c, rate: 90, seconds: 2.4, velocity: 1100,
                     longitude: .pi / 2, spread: 1.0, gravity: -800, life: 2.6)
            fx.pop("+999K", 200, at: CGPoint(x: c.x, y: min(H - 140, c.y + 360)), color: .white, hold: 2, delay: 0.2)
            fx.ring(at: c, color: color(0xFB923C), width: 16, duration: 1.2)
        case .megaphone:
            let mouth = CGPoint(x: c.x + f * 90, y: c.y + 30)
            fx.pop("📣", 300, at: CGPoint(x: c.x + f * 130, y: c.y + 60), tilt: f > 0 ? 0 : 0, hold: 2.2)
            for i in 0..<7 {
                fx.ring(at: mouth, radius: 50, scale: 28, color: color(0xFB923C), width: 12, duration: 1.5, delay: 0.3 + Double(i) * 0.25)
            }
            fx.flash(color(0xFB923C), peak: 0.3, duration: 0.5, delay: 0.3)
            fx.burst(["💥", "🔥", "‼️"], 100, at: mouth, rate: 70, seconds: 1.5, velocity: 1200, longitude: f > 0 ? 0 : .pi, spread: 0.7,
                     gravity: 0, life: 1.4, delay: 0.3)

        // Yui: camera flash; a flood of hearts from a live stream.
        case .selfieFlash:
            let frame = CGRect(x: c.x - 320, y: max(40, c.y - 240), width: 640, height: 760)
            let corners = CGMutablePath()
            let L: CGFloat = 110
            for (cx, sx) in [(frame.minX, 1.0), (frame.maxX, -1.0)] {
                for (cy, sy) in [(frame.minY, 1.0), (frame.maxY, -1.0)] {
                    corners.move(to: CGPoint(x: cx + sx * L, y: cy)); corners.addLine(to: CGPoint(x: cx, y: cy))
                    corners.addLine(to: CGPoint(x: cx, y: cy + sy * L))
                }
            }
            fx.shape(corners, stroke: .white, width: 10, duration: 1.8)
            fx.flash(.white, peak: 1, duration: 0.5, delay: 0.7)
            fx.pop("📸", 280, at: CGPoint(x: c.x, y: frame.maxY + 60), hold: 1, delay: 0.1)
            fx.rain(["💖", "✨", "🌸", "💕"], 90, rate: 40, seconds: 2.4, delay: 1.0)
        case .liveStream:
            fx.rise(["💖", "💗", "💕", "❤️", "💘"], 100, rate: 40, seconds: 3.2, speed: 380)
            fx.pop("🔴 LIVE", 120, at: CGPoint(x: c.x, y: min(H - 100, c.y + 330)), color: .white, hold: 3, delay: 0.1)
            fx.glow(at: c, diameter: 800, color: color(0xFF4D8D), duration: 3.4)
            fx.ring(at: c, color: color(0xFF4D8D), width: 14, duration: 1.4, delay: 0.2)

        // Sora: five-minute sync pulses; a big shield against scope creep.
        case .quickSync:
            fx.pop("⏰", 300, at: CGPoint(x: c.x, y: c.y + 260), turns: 1, hold: 2)
            fx.pop("5:00", 150, at: CGPoint(x: c.x, y: c.y + 80), color: .white, hold: 1.8, delay: 0.4)
            for i in 0..<6 {
                fx.ring(at: c, radius: 40, scale: 30, color: color(i == 5 ? 0x22C55E : 0x38BDF8), width: 12, duration: 1.8,
                        delay: 0.2 + Double(i) * 0.3)
            }
            fx.burst(["💬", "👍", "✅"], 90, at: c, rate: 40, seconds: 1, velocity: 900, gravity: -400, delay: 1.8)
        case .scopeShield:
            fx.ring(at: c, radius: 120, scale: 3.4, color: color(0x3B82F6), width: 14, duration: 3.2, filled: true)
            fx.ring(at: c, radius: 120, scale: 5, color: color(0x93C5FD), width: 8, duration: 1.2, delay: 0.2)
            fx.pop("🛡️", 330, at: CGPoint(x: c.x, y: c.y + 230), hold: 2.4)
            for i in 0..<10 {
                let a = CGFloat(i) / 10 * 2 * .pi
                fx.pop(["📎", "📌", "💥"][i % 3], 120, at: CGPoint(x: c.x + cos(a) * 400, y: c.y + sin(a) * 400), hold: 0.4, delay: 0.6 + Double(i) * 0.16)
            }
            fx.flash(color(0x3B82F6), peak: 0.2, duration: 0.8, delay: 0.3)

        // Aki: acceptance criteria get ticked off; a radar sweeps for requirements.
        case .checklist:
            for i in 0..<7 {
                let x = W * (CGFloat(i) + 0.5) / 7
                fx.pop("✅", 190, at: CGPoint(x: x, y: H * (i % 2 == 0 ? 0.35 : 0.65)), hold: 1.2, delay: 0.2 + Double(i) * 0.22)
            }
            fx.burst(["✨", "✅"], 80, at: c, rate: 80, seconds: 0.5, velocity: 900, gravity: -600, delay: 1.9)
            fx.flash(color(0x22C55E), peak: 0.25, duration: 0.7, delay: 1.9)
        case .radar:
            let r = min(W, H) * 0.42
            fx.ring(at: c, radius: r, scale: 1, color: color(0x34D399), width: 6, duration: 3.6, filled: true)
            for k in 1...2 { fx.ring(at: c, radius: r * CGFloat(k) / 3, scale: 1, color: color(0x34D399, 0.8), width: 3, duration: 3.6) }
            fx.gradient([color(0x34D399, 0), color(0x34D399, 0.85)], frame: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2),
                        start: CGPoint(x: 0.5, y: 0.5), end: CGPoint(x: 0.5, y: 0), duration: 3.6) { layer in
                layer.type = .conic
                let mask = CAShapeLayer()
                mask.path = CGPath(ellipseIn: layer.bounds, transform: nil)
                layer.mask = mask
                layer.add(CABasicAnimation.grow("transform.rotation.z", from: 0, to: -4 * Double.pi, duration: 3.6), forKey: "sweep")
            }
            for i in 0..<5 {
                let a = CGFloat.random(in: 0..<(2 * .pi)), d = CGFloat.random(in: 0.3...0.9) * r
                fx.pop("📌", 100, at: CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), hold: 0.8, delay: 0.5 + Double(i) * 0.5)
            }

        // Tâm: the wooden fish keeps time with the chanting, one knock per strike frame, each adding a little merit (the last one makes it boundless); then offering incense with palms joined.
        case .woodenFish:
            let fish = CGPoint(x: fx.feet.x + f * 60, y: fx.feet.y + 30)
            let merit = Self.say(vi: "Công đức +1", en: "Merit +1", ja: "功徳+1")
            fx.glow(at: c, diameter: 800, color: color(0xF5C451), duration: 10)
            // Slowly turning rays of light behind Tâm, and the opening of the Great Compassion Mantra.
            let r = min(W, H) * 0.55
            fx.gradient((0..<16).map { color(0xFFD27A, $0 % 2 == 0 ? 0 : 0.45) }, frame: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2),
                        start: CGPoint(x: 0.5, y: 0.5), end: CGPoint(x: 0.5, y: 0), peak: 0.8, duration: 10) { layer in
                layer.type = .conic
                let mask = CAShapeLayer()
                mask.path = CGPath(ellipseIn: layer.bounds, transform: nil)
                layer.mask = mask
                layer.add(CABasicAnimation.grow("transform.rotation.z", from: 0, to: -0.5 * Double.pi, duration: 10), forKey: "turn")
            }
            fx.pop(Self.say(vi: "Nam mô hắc ra đát na đa ra dạ da", en: "Namo ratna-trayāya", ja: "ナムカラタンノー トラヤーヤー"), 80,
                   at: CGPoint(x: W / 2, y: min(H - 120, c.y + 480)), color: NSColor(srgbRed: 1, green: 0.85, blue: 0.4, alpha: 1), hold: 8, delay: 0.3)
            // In step with the strike frame of the knock animation (frame 2 at 6 fps, every 4 frames).
            let knocks = 14
            for i in 0..<knocks {
                let t = 2.0 / 6 + Double(i) * 4 / 6
                fx.ring(at: fish, radius: 30, scale: 14, color: color(0xF5C451), width: 10, duration: 1.1, delay: t)
                if i < knocks - 1 {
                    fx.pop(merit, 90, at: CGPoint(x: c.x + f * CGFloat(i % 2 == 0 ? 220 : 120), y: c.y + 160 + CGFloat(i % 4) * 90),
                           color: NSColor(srgbRed: 1, green: 0.82, blue: 0.3, alpha: 1), hold: 0.5, delay: t)
                } else {
                    // The last knock: all that merit adds up.
                    fx.pop(Self.say(vi: "Công đức vô lượng", en: "Boundless merit", ja: "功徳無量"), 130,
                           at: CGPoint(x: W / 2, y: min(H - 120, c.y + 330)), color: NSColor(srgbRed: 1, green: 0.85, blue: 0.3, alpha: 1), hold: 0.6, delay: t)
                }
            }
        case .incense:
            let bowl = CGPoint(x: fx.feet.x + f * 60, y: fx.feet.y + 30)
            fx.glow(at: c, diameter: 700, color: color(0xFFD27A), duration: 9.8)
            // A small bowl with three sticks, their tips glowing and the smoke curling up.
            fx.shape(CGPath(ellipseIn: CGRect(x: bowl.x - 22, y: bowl.y - 10, width: 44, height: 16), transform: nil),
                     fill: color(0x8A5A1A), stroke: color(0x4A2E0C), width: 3, duration: 9.8)
            for (i, dx) in [-10.0, 0.0, 10.0].enumerated() {
                let base = CGPoint(x: bowl.x + CGFloat(dx), y: bowl.y), tip = CGPoint(x: base.x + CGFloat(dx) * 0.2, y: base.y + 80)
                let stick = CGMutablePath()
                stick.move(to: base); stick.addLine(to: tip)
                fx.shape(stick, stroke: color(0xB0492A), width: 4, duration: 9.8)
                fx.glow(at: tip, diameter: 36, color: color(0xFF7A2A), duration: 9.6, delay: 0.1)
                fx.burst(["☁️"], 50, at: tip, rate: 5, seconds: 9, velocity: 90, longitude: .pi / 2, spread: 0.35, gravity: 25,
                         life: 3, delay: 0.3 + Double(i) * 0.15)
            }
            fx.pop(Self.say(vi: "A Di Đà Phật", en: "Amitabha", ja: "南無阿弥陀仏"), 80,
                   at: CGPoint(x: c.x, y: c.y + 330), color: NSColor(srgbRed: 1, green: 0.85, blue: 0.4, alpha: 1), hold: 8, delay: 0.4)

        // Thầy Minh: one strike of the bell carries across the whole screen; meditation stills everything.
        case .templeBell:
            let bell = CGPoint(x: fx.feet.x + f * 60, y: fx.feet.y + 30)
            // The strike frame of the bell animation is frame 2 at 4 fps; it repeats every 1.5 s.
            for strike in [0.5, 2.0, 3.5, 5.0, 6.5] {
                fx.flash(color(0xFFE08A), peak: 0.2, duration: 0.6, delay: strike)
                for i in 0..<4 {
                    fx.ring(at: bell, radius: 40, scale: 30, color: color(0xE0B040), width: 10, duration: 2.2, delay: strike + Double(i) * 0.3)
                }
            }
            fx.pop("🔔", 260, at: CGPoint(x: c.x, y: c.y + 280), tilt: 0.15, hold: 8, delay: 0.4)
            for (i, strike) in [0.5, 2.0, 3.5, 5.0, 6.5].enumerated() {
                fx.pop(Self.say(vi: "Boong...", en: "Dong...", ja: "ゴーン…"), 120, at: CGPoint(x: c.x - f * CGFloat(i % 2 == 0 ? 260 : 160), y: c.y + 200 + CGFloat(i % 3) * 70),
                       color: NSColor(srgbRed: 1, green: 0.85, blue: 0.4, alpha: 1), hold: 0.9, delay: strike)
            }
        case .meditation:
            fx.flash(color(0x0B1A3A), peak: 0.35, duration: 10)
            fx.glow(at: c, diameter: min(W, H) * 1.2, color: color(0x9AD8FF), duration: 10)
            for i in 0..<6 {
                fx.ring(at: c, radius: 80, scale: 9, color: color(0xBFE6FF, 0.8), width: 6, duration: 2.6, delay: 0.2 + Double(i) * 1.4)
            }
            fx.pop(Self.say(vi: "Thở vào, tâm tĩnh lặng. Thở ra, mỉm cười.", en: "Breathing in, I calm my mind. Breathing out, I smile.",
                            ja: "息を吸って、心静かに。息を吐いて、ほほえむ。"), 64,
                   at: CGPoint(x: W / 2, y: min(H - 120, c.y + 420)), color: .white, hold: 8, delay: 0.4)
        }
    }

    private static func say(vi: String, en: String, ja: String) -> String {
        switch Language.current {
        case .vi: return vi
        case .en: return en
        case .ja: return ja
        }
    }

    /// A round red ink stamp with `text` inside.
    private static func stampLayer(_ text: String, size: CGFloat, at p: CGPoint) -> CALayer {
        let red = NSColor(srgbRed: 0.86, green: 0.15, blue: 0.15, alpha: 1)
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            red.setStroke()
            let outer = NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.04, dy: size * 0.04))
            outer.lineWidth = size * 0.045
            outer.stroke()
            let inner = NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.12, dy: size * 0.12))
            inner.lineWidth = size * 0.015
            inner.stroke()
            let font = NSFont.systemFont(ofSize: size * (text.count > 3 ? 0.17 : 0.3), weight: .black)
            let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: red])
            let s = string.size()
            string.draw(at: CGPoint(x: (size - s.width) / 2, y: (size - s.height) / 2))
            return true
        }
        let layer = CALayer()
        layer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        layer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        layer.position = p
        layer.setAffineTransform(CGAffineTransform(rotationAngle: -0.22))
        return layer
    }

    /// A paint splat: a round blob with droplets around it, centered on the origin.
    private static func splat(radius r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        for i in 0..<7 {
            let a = CGFloat(i) / 7 * 2 * .pi + CGFloat.random(in: 0...0.4)
            let d = r * CGFloat.random(in: 1.0...1.5), dr = r * CGFloat.random(in: 0.12...0.3)
            path.addEllipse(in: CGRect(x: cos(a) * d - dr, y: sin(a) * d - dr, width: dr * 2, height: dr * 2))
        }
        return path
    }
}

private extension CABasicAnimation {
    static func grow(_ keyPath: String, from: Any, to: Any, duration: TimeInterval) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = to
        a.duration = duration
        a.timingFunction = CAMediaTimingFunction(name: .easeOut)
        a.fillMode = .both
        return a
    }
}
