# Sumi 墨 — kanji, one quiet step at a time

A native SwiftUI kanji trainer for iPhone and iPad, from JLPT N5 to N1 and
beyond. Built in Swift Playgrounds and synced through GitHub.

*"Sumi" (墨, ink) is a working name — rename it in Swift Playgrounds' app
settings.*

## Design: munkens mat

*Munkens mat* — the monk's meal — serves only what nourishes. Every screen
offers one thing to do; everything else happens out of sight.

**What you see**

| Screen | Contents |
|---|---|
| **Home** | One number (reviews waiting) or one glyph (the next new kanji), and one button. When you're done: "Done", when the next review is, and at most two quiet links (read a text, learn more today). |
| **Study** | The prompt in the middle, the answer controls at the bottom, a thin progress line, Back and Undo. Nothing else. |
| **Library** | Kanji grouped by level. Each glyph's ink deepens as you learn it — faint when new, full black once known. A second tab lists the reading texts. Search takes kanji, English, kana or romaji. |
| **Kanji page** | The glyph, its meaning and readings, a memory hook (or your own), words and a sentence — tap any of them to hear it. |
| **Settings** | Daily pace, writing practice, furigana, typeface, speech, a daily reminder, import/export, privacy. |

**What happens behind it**

- **FSRS-6 scheduling** at a 90% recall target — intervals are never shown.
- **Pacing:** reviews always come before new kanji; after a long break,
  reviews arrive 50 at a time, most-at-risk first, and new lessons pause.
- **Order:** parts are taught before the kanji that contain them.
- **Three skills per kanji:** meaning, reading (typed in kana or romaji,
  inside a real word) and writing (unlocks once recognition is stable).
- **Mistakes are noticed for you:** near misses (small っ, long vowels,
  ゛ marks, a valid reading the word doesn't use) get a hint and a free retry;
  the type of slip is logged silently; the memory hook and look-alike tips
  appear only for new, relearning or repeatedly forgotten cards.
- **Adaptive furigana** shows readings only above kanji you haven't learned.
- **Reminders** (opt-in, offered once after your first session) state the
  exact number of reviews waiting and keep the app badge accurate.
- **Hidden power:** ⌘Z undo, Space to reveal, Return for Remembered/Continue,
  1 for Forgot; "I mistyped" override; practice any kanji from its page.

The research behind every decision is in [docs/RESEARCH.md](docs/RESEARCH.md).

## Project layout

```
Sumi.swiftpm/              ← the app. Open this folder in Swift Playgrounds or Xcode.
  Package.swift            app manifest (iOS 17+, iPhone + iPad)
  Sources/
    MyApp.swift            @main entry point — just WindowGroup { ContentView() }
    ContentView.swift      the whole app: design system, FSRS, store, all screens,
                           and the starter content embedded as JSON
content/core-n5.json       editable source of the starter content
docs/RESEARCH.md           pain points, learning science, UX and design-system rationale
docs/CONTENT_SCHEMA.md     how to write content packs for N4–N1
tools/                     validate and re-embed content (Python 3, optional)
```

Swift Playgrounds treats any folder ending in `.swiftpm` as an app project, so
`Sumi.swiftpm` opens directly — nothing to create or copy first. Docs and tools
live outside it so the project stays clean in Playgrounds.

`ContentView.swift` is self-contained: it owns its data store, so any App can
host it with `ContentView()`.

## Opening and building it

Requires Swift Playgrounds 4.4 or later on iPadOS 17+ (or a Mac with Swift
Playgrounds or Xcode 15+).

### On iPad, with GitHub sync (recommended)

[Working Copy](https://workingcopy.app) is a Git client whose repositories
appear in the Files app, so Swift Playgrounds can open the package in place
and every edit lands straight in the Git checkout.

1. In Working Copy, tap **+ → Clone repository** and enter
   `https://github.com/cosrx-c/KanjiIthink.git`.
2. Open Swift Playgrounds, tap **Locations** (or the folder icon) and choose
   **Working Copy → KanjiIthink → Sumi.swiftpm**. It opens as the app *Sumi*.
3. Press **▶︎** to build and run. First launch shows the onboarding.
4. **To sync:** edits made in Playgrounds show up as changes in Working Copy —
   commit and push there. Pull in Working Copy to bring in changes made
   elsewhere, then reopen the project.

If Swift Playgrounds can't see the Working Copy location, use Working Copy's
*Link Repository to Directory* instead: link the repository to a folder in
iCloud Drive and open `Sumi.swiftpm` from there.

### On iPad, without Git (quick try)

1. In Safari, open the repository on GitHub and choose **Code → Download ZIP**.
2. In Files, tap the ZIP to unzip it, open the folder and tap
   **Sumi.swiftpm** — it opens in Swift Playgrounds.
3. Press **▶︎**. (Changes made this way aren't synced back to GitHub.)

### On a Mac

Clone the repository and double-click `Sumi.swiftpm` to open it in Swift
Playgrounds, or open it from Xcode (**File → Open**) and run it on a
simulator or device.

Notes:

- Swift Playgrounds rewrites `Package.swift` when you change the app's name,
  icon or color in its settings. Afterwards, check the target still says
  `path: "Sources"`.
- Signing in with an Apple ID in Playgrounds adds a `teamIdentifier` to
  `Package.swift`; commit that change.
- Change `bundleIdentifier` to your own reverse-domain ID before publishing.
- To rename the project, rename the folder (e.g. `KanjiIthink.swiftpm`) and the
  `name` fields in `Package.swift`; then update the path in
  `tools/embed_content.py`.

## Adding content

The starter pack covers 59 N5 + 5 N4 kanji and 5 passages so the whole app
can be exercised. To add more, write a JSON pack (schema and examples in
[docs/CONTENT_SCHEMA.md](docs/CONTENT_SCHEMA.md)) and either:

- import it in the app: **Settings → Content & data → Import** — no rebuild;
  or
- add it to `content/core-n5.json`, then validate and re-embed:

  ```bash
  python tools/validate_content.py content/core-n5.json
  ```

  ```bash
  python tools/embed_content.py
  ```

## A note on "JLPT approved"

The JLPT (run by the Japan Foundation and JEES) doesn't endorse study apps,
and it hasn't published official kanji lists since the 2010 revision — every
"JLPT kanji list" is reconstructed from past papers and prep books. The app
labels levels as a study guide and disclaims affiliation; in store listings,
describe it as **JLPT-aligned** rather than approved or official. "JLPT" is a
registered trademark.

## Verification status

This was written on a Windows machine without Xcode, so it has **not yet been
compiled or run**. What was checked: bracket/string structure of the Swift
file, the starter content (every kanji annotated with furigana, readings in
the right script, every word containing its kanji, passage answers in
range), and that the content tools round-trip the embedded JSON exactly.
Build it once in Swift Playgrounds; if the compiler reports anything, the
error line will point to a specific view and is likely a one-line fix.

## Roadmap

- Content: N5 complete (~80), then N4, N3, N2, N1 packs; audio recordings.
- Stroke-order animation and stroke-by-stroke checking from KanjiVG (CC BY-SA 3.0).
- iCloud sync (CloudKit) so iPhone, iPad and a future Mac app share progress.
- Per-learner FSRS parameter optimization from the review log.
- iPad and Mac layouts with a sidebar (`NavigationSplitView`).
- Optional gentle reminders and a "reviews due" widget.
- Handwriting recognition with the Vision framework.
