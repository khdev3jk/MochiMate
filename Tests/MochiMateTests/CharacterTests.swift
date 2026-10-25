import XCTest
@testable import MochiMate

final class CharacterTests: XCTestCase {
    func testCharacterIDsAreUnique() {
        let ids = allCharacters.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.count, 12)
    }

    func testLookUpByID() {
        let rin = Character.with(id: "rin")
        XCTAssertEqual(rin.id, "rin")
        XCTAssertEqual(rin.profession, .developer)
        XCTAssertTrue(rin.female)
        XCTAssertEqual(rin.walkSpeed, 65)
    }

    func testUnknownIDFallsBackToTheFirstCharacter() {
        XCTAssertEqual(Character.with(id: "nobody").id, allCharacters[0].id)
        XCTAssertEqual(Character.with(id: "").id, allCharacters[0].id)
        XCTAssertEqual(Character.with(id: "KAI").id, allCharacters[0].id)   // ids are case-sensitive
    }

    func testWeightsOverrideTheBaseAndKeepTheRest() {
        let kai = Character.with(id: "kai")
        XCTAssertEqual(kai.weights[.work], 4)       // overridden
        XCTAssertEqual(kai.weights[.wander], 5)     // from the base
        for character in allCharacters {
            XCTAssertEqual(Set(character.weights.keys), Set(Behavior.allCases), character.id)
            XCTAssertTrue(character.weights.values.allSatisfy { $0 > 0 }, character.id)
        }
    }

    func testEveryProfessionHasTwoCharacters() {
        for profession in Profession.allCases {
            XCTAssertEqual(allCharacters.filter { $0.profession == profession }.count, 2, "\(profession)")
        }
    }

    func testTheMonkKnocksTheWoodenFishAndOffersIncense() {
        XCTAssertEqual(Skill.all(for: "tam"), [.woodenFish, .incense])
        XCTAssertEqual(Skill.woodenFish.anim, .knock)
        XCTAssertEqual(Skill.incense.anim, .pray)
    }

    func testTheMasterRingsTheBellAndMeditates() {
        XCTAssertEqual(Skill.all(for: "minh"), [.templeBell, .meditation])
        XCTAssertEqual(Skill.templeBell.anim, .bell)
        XCTAssertEqual(Skill.meditation.anim, .meditate)
    }

    func testSkillsBelongToTheirCharacterInSlotOrder() {
        XCTAssertEqual(Skill.all(for: "kai"), [.deploy, .bugSquash])
        XCTAssertEqual(Skill.deploy.characterID, "kai")
        XCTAssertEqual(Skill.deploy.slot, 1)
        XCTAssertEqual(Skill.bugSquash.slot, 2)
        XCTAssertEqual(Skill.deploy.lineKind, .skill1)
        XCTAssertEqual(Skill.bugSquash.lineKind, .skill2)
    }

    func testUnknownCharacterHasNoSkills() {
        XCTAssertEqual(Skill.all(for: "nobody"), [])
    }

    func testEverySkillBelongsToAKnownCharacter() {
        let ids = Set(allCharacters.map(\.id))
        for skill in Skill.allCases {
            XCTAssertTrue(ids.contains(skill.characterID), "\(skill)")
        }
    }
}

final class DictionaryMapKeysTests: XCTestCase {
    func testMapsKeysAndKeepsValues() {
        let mapped = [ReminderKind.water: 1, .move: 2].mapKeys(\.rawValue)
        XCTAssertEqual(mapped, ["water": 1, "move": 2])
    }

    func testEmptyDictionary() {
        XCTAssertEqual([String: Int]().mapKeys { $0.count }, [:])
    }
}
