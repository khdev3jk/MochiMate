import XCTest
@testable import MochiMate

final class SpriteSheetTests: XCTestCase {
    // idle: 4 frames at 4 fps, looping. kick: 7 frames at 12 fps, played once (see layout.json).
    private let sheet = SpriteSheet.named("kai")

    func testLoopingAnimationAdvancesAndWraps() {
        let first = sheet.frame(.idle, elapsed: 0)
        XCTAssertNotNil(first)
        XCTAssertTrue(sheet.frame(.idle, elapsed: 0.24) === first)
        XCTAssertFalse(sheet.frame(.idle, elapsed: 0.25) === first)
        XCTAssertTrue(sheet.frame(.idle, elapsed: 1.0) === first)    // back to the start after 4 frames
        XCTAssertTrue(sheet.frame(.idle, elapsed: 100.0) === first)
    }

    func testOneShotAnimationStopsOnLastFrame() {
        let last = sheet.frame(.kick, elapsed: 6.0 / 12)
        XCTAssertNotNil(last)
        XCTAssertFalse(sheet.frame(.kick, elapsed: 5.0 / 12) === last)
        XCTAssertTrue(sheet.frame(.kick, elapsed: 7.0 / 12) === last)
        XCTAssertTrue(sheet.frame(.kick, elapsed: 60) === last)
    }

    func testEveryAnimationHasFrames() {
        for anim in Anim.allCases {
            XCTAssertNotNil(sheet.frame(anim, elapsed: 0), "\(anim)")
        }
    }

    func testDurationIsFramesOverFPS() {
        XCTAssertEqual(sheet.duration(.idle), 1.0, accuracy: 1e-9)
        XCTAssertEqual(sheet.duration(.kick), 7.0 / 12, accuracy: 1e-9)
        XCTAssertEqual(sheet.duration(.eyerest), 8 / 2.5, accuracy: 1e-9)
    }

    func testFramesMatchTheLayoutSize() {
        let px = Int(SpriteSheet.layout.frameSize * SpriteSheet.layout.pixelScale)
        let frame = sheet.frame(.walk, elapsed: 0)
        XCTAssertEqual(frame?.width, px)
        XCTAssertEqual(frame?.height, px)
    }

    func testSameCharacterReusesItsSheet() {
        XCTAssertTrue(SpriteSheet.named("rin") === SpriteSheet.named("rin"))
    }

    func testOnlyTheLatestCharacterStaysCached() {
        let rin = SpriteSheet.named("rin")
        _ = SpriteSheet.named("mei")
        XCTAssertFalse(SpriteSheet.named("rin") === rin)
    }

    func testEveryEffectHasAnIcon() {
        for effect in Effect.allCases {
            XCTAssertNotNil(SpriteSheet.effect(effect), "\(effect)")
        }
    }

    func testEveryCharacterHasAPortrait() {
        for character in allCharacters {
            let portrait = SpriteSheet.portrait(character.id)
            XCTAssertNotNil(portrait, character.id)
            XCTAssertEqual(portrait?.size, NSSize(width: SpriteSheet.layout.frameSize, height: SpriteSheet.layout.frameSize))
        }
    }
}
