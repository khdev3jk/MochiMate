# MochiMate

An anime chibi companion for macOS that lives on your Desktop and keeps office workers healthy: it reminds you to drink water, get up and move, and rest your eyes, with a funny line in your language each time.

The app lives in the menu bar only (a mochi-face icon); it has no Dock icon.

## Features

- **10 characters, 5 professions, one man and one woman each**, each with its own look, personality and lines:
  - Names are localized: e.g. Kai is Khải (vi), Ethan (en), カイ (ja); the ids stay `kai`, `rin`, …
  - Software Developer: Kai, Rin
  - Office Worker: Taro, Hana
  - Designer: Leo, Mei
  - Marketing & Content Creator: Ken, Yui
  - Project Manager & Business Analyst: Sora, Aki
- **Lives on the Desktop:** walks and runs around, across every screen; works on a laptop, gets bored, yawns, falls asleep. Click it, drag it, poke it too often and it gets grumpy.
- **2 skills per character (20 in all):** screen-filling effects (rocket launch, code rain, payday rain, approval stamp, aurora, radar…), 2–3× the size of the character, with a line of dialogue. Cast now and then on their own, or from the **Skills** submenu in the menu bar and the right-click menu.
- **Plays around (opt-in):** perches on top of the window you're using and teases the app by name, and kicks Desktop icons around (needs permission to control Finder; off by default).
- **Health reminders:** water (every 45 min), move (60 min), eye rest (20 min, the 20-20-20 rule) by default, each with its own interval. When one is due the character runs to the bottom of the screen near your cursor, acts it out (drinks, stretches, does eye exercises) and says a line. Click it when you've done it; right-click to snooze 10/30 minutes or skip.
- **Schedule:** reminders only during work hours (days and times), none during quiet hours (lunch break by default), and a pause for 15 min to the rest of the day. Countdowns stand still outside those times, and being away from the Mac for 5+ minutes counts as a break.
- **Lines that don't repeat:** recently said lines are skipped until the rest have been used, across launches.
- **3 languages:** Vietnamese, English and Japanese, for the settings, menus and dialogue.
- **Updates from GitHub Releases:** new app versions in one click, plus dialogue/audio packs that install automatically without an app release.

It stays light: one 30 fps timer, layer-based rendering, and reminders checked every 10 seconds. It never reads your data: the only things it looks at are where the frontmost window is and that app's name (for the window antics), and the Desktop icon positions (only with icon kicking on).

## Usage

Everything is in the menu-bar menu: the time of each next reminder, **Remind me now**, **Pause reminders**, the character picker, **Show the character on screen**, **Settings…** and updates. Hiding the character keeps the reminders going: it comes out for each one and leaves again.

Settings has five tabs: Character (pick one, language, voice volume), Reminders (on/off, interval, try one now, pause), Schedule (work hours and days, quiet hours), Behavior (chatter, window antics, icon kicking) and Updates.

## Build

Requirements: macOS 13+ and Xcode 15+ (or a Swift 5.9 toolchain).

```sh
make run
```

| Command | What it does |
| --- | --- |
| `make app` | Regenerate the sprite sheets, build a release binary and wrap it as `build/MochiMate.app`. |
| `make run` | `make app`, then open the app. |
| `make dmg` | `make app`, then package `build/MochiMate-<VERSION>.dmg` (default `VERSION=1.0.0`). |
| `make content` | Zip the content pack as `build/mochimate-content-<N>.zip`, N being `version` in content.json. |
| `make sprites` | Regenerate the sprite sheets only. |
| `swift test` | Run the tests (content pack completeness, schedule rules, version comparison). |

The app is ad-hoc signed by default; set `SIGN_IDENTITY` to sign with a real certificate (it also keeps the Finder permission between builds).

## Releasing

The updater reads the releases of `vfa-khuongdv/MochiMate` (`Updater.repository`).

- **App:** `make dmg VERSION=1.1.0`, then attach the DMG to a release tagged `v1.1.0`. The app offers the update when the tag is newer than its own version.
- **Content (dialogue and audio):** bump `version` in `Sources/MochiMate/Resources/Content/content.json`, run `make content` and attach `mochimate-content-<N>.zip` to any release (a content-only release works too). Apps whose pack is older download it, check it loads, and install it into `~/Library/Application Support/MochiMate/Content`.

## Content pack

`Sources/MochiMate/Resources/Content/content.json`:

```jsonc
{
  "version": 1,                       // bump on every published pack
  "profiles":   { "<character>": { "<lang>": { "name": "...", "bio": "..." } } },
  "characters": { "<character>": { "<lang>": { "<kind>": [ /* lines */ ] } } },
  "shared":     { "<lang>": { "<kind>": [ /* lines for kinds a character has none of */ ] } }
}
```

- Characters: `kai rin taro hana leo mei ken yui sora aki`. Languages: `vi en ja`.
- Kinds: `water move eyes` (reminders), `thanks snoozed ignored` (answers to a reminder), `hello click poke wake bored sleepy kick window chatter endOfDay`.
- Placeholders: `{minutes}` (the reminder's interval), `{app}` (the frontmost app, for `window`), `{name}` (the character).
- A line is a string, or an object to set more: `{ "text": "...", "id": "...", "anim": "drink", "effect": "water", "audio": "audio/vi/kai.vi.water.1.m4a" }`. `anim` is one of the animation names in `SpriteSheet.swift`, `effect` an emote name.
- Each line has an id: `<character>.<lang>.<kind>.<n>` (n counts from 1), or `shared.<lang>.<kind>.<n>`, unless it sets its own. Inserting a line in the middle renumbers the ones after it, so give lines an explicit `id` once they have audio.

### Audio (TODO)

Voice playback is not implemented yet: `Voice.play` in `Content.swift` is a stub. The plan is pre-recorded TTS files inside the pack, at the line's `audio` path or by default `audio/<lang>/<line id>.m4a`, played at the volume set in Settings.

## Project layout

```
Sources/
  MochiMate/
    AppDelegate.swift    Menu bar menu, the pet's right-click menu, the settings window
    SettingsView.swift   Settings window (SwiftUI)
    Settings.swift       Preferences, work and quiet hours
    World.swift          Owns the companion, the reminder schedule and the animation clock
    Reminders.swift      Reminder kinds and the scheduler
    Pet.swift            Behavior of the character, including how it shows a reminder
    PetWindow.swift      Transparent window that draws the character and its speech bubble
    Characters.swift     The 10 characters and their behavior weights
    Content.swift        Loads the content pack and picks lines; voice playback stub
    FrontWindow.swift    Frontmost window position and app name
    DesktopIcons.swift   Reads and moves Desktop icons through AppleScript (Finder)
    Updater.swift        App and content updates from GitHub Releases
    UIText.swift         Menu and settings labels per language
    Resources/Sprites/   Sprite sheets generated by SpriteGen
    Resources/Content/   The bundled content pack
  SpriteGen/             Draws the characters with Core Graphics and writes the sprite sheets
Tests/MochiMateTests/    Tests
```
