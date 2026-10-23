import Foundation

enum Profession: String, CaseIterable {
    case developer, office, designer, marketing, manager

    var title: String {
        switch self {
        case .developer: return ui(.professionDeveloper)
        case .office: return ui(.professionOffice)
        case .designer: return ui(.professionDesigner)
        case .marketing: return ui(.professionMarketing)
        case .manager: return ui(.professionManager)
        }
    }
}

/// What a pet does between reminders.
enum Behavior: CaseIterable {
    case wander, idle, work, bored, sleep, happy, chatter, kick, window, skill
}

/// One character. Names, bios and dialogue live in the content pack (Resources/Content/content.json),
/// so they can be updated without a new app release; the look lives in the sprite sheet `<id>.png`.
struct Character {
    let id: String
    let profession: Profession
    let female: Bool
    var walkSpeed: Double = 60   // points per second
    var weights: [Behavior: Double]

    var name: String { ContentStore.shared.profile(for: id)?.name ?? id.capitalized }
    var skills: [Skill] { Skill.all(for: id) }
    var bio: String { ContentStore.shared.profile(for: id)?.bio ?? "" }

    static func with(id: String) -> Character { allCharacters.first { $0.id == id } ?? allCharacters[0] }
}

private let base: [Behavior: Double] = [.wander: 5, .idle: 3, .work: 2, .bored: 1.5, .sleep: 0.8, .happy: 1,
                                        .chatter: 1.2, .kick: 1.2, .window: 1.2, .skill: 1.4]

private func weights(_ changes: [Behavior: Double]) -> [Behavior: Double] {
    base.merging(changes) { $1 }
}

let allCharacters: [Character] = [
    // Kai lives on his laptop and naps whenever a build runs; Rin is quicker and pickier.
    Character(id: "kai", profession: .developer, female: false, walkSpeed: 55, weights: weights([.work: 4, .sleep: 1.4])),
    Character(id: "rin", profession: .developer, female: true, walkSpeed: 65, weights: weights([.work: 4, .kick: 1.6])),
    Character(id: "taro", profession: .office, female: false, walkSpeed: 58, weights: weights([.work: 3, .bored: 2.2])),
    Character(id: "hana", profession: .office, female: true, walkSpeed: 62, weights: weights([.chatter: 2.2, .happy: 1.6])),
    Character(id: "leo", profession: .designer, female: false, walkSpeed: 56, weights: weights([.idle: 4, .window: 1.8])),
    Character(id: "mei", profession: .designer, female: true, walkSpeed: 62, weights: weights([.happy: 2, .window: 1.6])),
    Character(id: "ken", profession: .marketing, female: false, walkSpeed: 75, weights: weights([.wander: 7, .chatter: 2, .kick: 1.8])),
    Character(id: "yui", profession: .marketing, female: true, walkSpeed: 70, weights: weights([.happy: 2.2, .chatter: 2.4])),
    Character(id: "sora", profession: .manager, female: false, walkSpeed: 64, weights: weights([.wander: 6, .work: 2.5])),
    Character(id: "aki", profession: .manager, female: true, walkSpeed: 60, weights: weights([.work: 3, .window: 1.6])),
]
