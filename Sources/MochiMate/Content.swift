import AVFoundation
import Foundation

/// What a line is for. Reminder lines use "{minutes}" for the reminder's interval, window lines "{app}" for the app's name.
enum LineKind: String, CaseIterable {
    case hello, click, poke, wake, bored, sleepy, kick, window, chatter, endOfDay
    case water, move, eyes, thanks, snoozed, ignored
    /// The lines said when casting each of a character's two skills.
    case skill1, skill2
}

/// One line of dialogue, optionally with the animation, emote and pre-recorded audio that go with it.
struct DialogueLine {
    /// "<character>.<language>.<kind>.<n>" (n from 1), or "shared.<language>.<kind>.<n>" unless the pack sets one.
    let id: String
    let language: Language
    let text: String
    let anim: Anim?
    let effect: Effect?
    /// Audio file inside the content folder, e.g. "audio/vi/kai.vi.water.1.m4a".
    let audio: String?
}

/// The dialogue pack: `content.json`, plus its audio files next to it. The copy in the app bundle can be replaced
/// by a newer one downloaded into Application Support (see Updater), so lines and audio ship without an app release.
struct ContentPack: Decodable {
    struct Profile: Decodable {
        let name: String
        let bio: String
    }

    /// A line is either plain text or an object with "text" and optional "id", "anim", "effect" and "audio".
    struct Entry: Decodable {
        let id: String?
        let text: String
        let anim: String?
        let effect: String?
        let audio: String?

        private enum Keys: String, CodingKey { case id, text, anim, effect, audio }

        init(from decoder: Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                (id, self.text, anim, effect, audio) = (nil, text, nil, nil, nil)
                return
            }
            let c = try decoder.container(keyedBy: Keys.self)
            id = try c.decodeIfPresent(String.self, forKey: .id)
            text = try c.decode(String.self, forKey: .text)
            anim = try c.decodeIfPresent(String.self, forKey: .anim)
            effect = try c.decodeIfPresent(String.self, forKey: .effect)
            audio = try c.decodeIfPresent(String.self, forKey: .audio)
        }
    }

    /// Bumped on every published pack; the updater installs a pack only if its version is higher.
    let version: Int
    /// character id → language → profile
    let profiles: [String: [String: Profile]]
    /// character id → language → kind → lines
    let characters: [String: [String: [String: [Entry]]]]
    /// language → kind → lines, for kinds a character has no lines of its own for.
    let shared: [String: [String: [Entry]]]
}

final class ContentStore {
    static let shared = ContentStore()

    private(set) var pack: ContentPack
    /// Folder of the active pack, which audio paths are relative to.
    private(set) var directory: URL

    /// Ids of recently said lines, newest last, so nothing repeats too soon (kept across launches).
    private var recent: [String]
    private let recentKey = "recentLines"
    private let recentLimit = 60

    static let bundledDirectory: URL = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Content"),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("content.json").path) {
            return url
        }
        return Bundle.module.resourceURL!.appendingPathComponent("Content")
    }()

    static let installedDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MochiMate/Content")

    private init() {
        recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        (pack, directory) = Self.loadBest()
    }

    /// Picks up a newly installed pack.
    func reload() {
        (pack, directory) = Self.loadBest()
    }

    static func load(from directory: URL) -> ContentPack? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("content.json")) else { return nil }
        return try? JSONDecoder().decode(ContentPack.self, from: data)
    }

    /// The downloaded pack when it is newer than the one inside the app, else the bundled one.
    private static func loadBest() -> (ContentPack, URL) {
        guard let bundled = load(from: bundledDirectory) else { fatalError("Missing or invalid bundled content.json") }
        if let installed = load(from: installedDirectory), installed.version > bundled.version {
            return (installed, installedDirectory)
        }
        return (bundled, bundledDirectory)
    }

    func profile(for character: String) -> ContentPack.Profile? {
        let profiles = pack.profiles[character]
        return profiles?[Language.current.rawValue] ?? profiles?[Language.en.rawValue] ?? profiles?.values.first
    }

    /// A line of `kind` for `character` in the current language, avoiding lines said recently.
    func line(_ kind: LineKind, for character: Character, app: String = "", minutes: Int = 0) -> DialogueLine? {
        let candidates = self.candidates(kind, character.id, Language.current)
            ?? self.candidates(kind, character.id, .en)
            ?? self.candidates(kind, character.id, .vi)
        guard let candidates, !candidates.isEmpty else { return nil }
        let fresh = candidates.filter { !recent.contains($0.id) }
        // Everything was said lately: take the one said longest ago.
        let pick = fresh.randomElement() ?? candidates.min { recent.firstIndex(of: $0.id)! < recent.firstIndex(of: $1.id)! }!
        remember(pick.id)
        let text = pick.text
            .replacingOccurrences(of: "{app}", with: app)
            .replacingOccurrences(of: "{minutes}", with: "\(minutes)")
            .replacingOccurrences(of: "{name}", with: character.name)
        return DialogueLine(id: pick.id, language: pick.language, text: text, anim: pick.anim, effect: pick.effect, audio: pick.audio)
    }

    private func candidates(_ kind: LineKind, _ character: String, _ language: Language) -> [DialogueLine]? {
        func lines(_ entries: [ContentPack.Entry]?, prefix: String) -> [DialogueLine]? {
            guard let entries, !entries.isEmpty else { return nil }
            return entries.enumerated().map { i, entry in
                DialogueLine(id: entry.id ?? "\(prefix).\(language.rawValue).\(kind.rawValue).\(i + 1)", language: language, text: entry.text,
                             anim: entry.anim.flatMap(Anim.init), effect: entry.effect.flatMap(Effect.init), audio: entry.audio)
            }
        }
        return lines(pack.characters[character]?[language.rawValue]?[kind.rawValue], prefix: character)
            ?? lines(pack.shared[language.rawValue]?[kind.rawValue], prefix: "shared")
    }

    private func remember(_ id: String) {
        recent.removeAll { $0 == id }
        recent.append(id)
        if recent.count > recentLimit { recent.removeFirst(recent.count - recentLimit) }
        UserDefaults.standard.set(recent, forKey: recentKey)
    }
}

/// Plays the pre-recorded voice that goes with a line of dialogue.
enum Voice {
    private static var player: AVAudioPlayer?

    /// Plays `line` at the volume set in Settings, cutting off whatever was still playing. Lines without a recording
    /// (the ones with {placeholders}) stay silent. Shared lines have one recording per gender, "<id>.m" and "<id>.f".
    static func play(_ line: DialogueLine, female: Bool) {
        player?.stop()
        let volume = Settings.shared.volume
        guard volume > 0 else { return }
        let path = line.audio ?? "audio/\(line.language.rawValue)/\(line.id).m4a"
        let gendered = path.replacingOccurrences(of: ".m4a", with: ".\(female ? "f" : "m").m4a")
        let directory = ContentStore.shared.directory
        guard let url = [path, gendered].map({ directory.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.volume = Float(volume)
        next.play()
        player = next
    }
}
