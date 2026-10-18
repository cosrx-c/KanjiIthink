# Sumi 墨 — kanji, one card at a time

A native SwiftUI kanji trainer for iPhone and iPad, from JLPT N5 to N1 and
beyond. Built in Swift Playgrounds and synced through GitHub.

*"Sumi" (墨, ink) is a working name — rename it in Swift Playgrounds' app
settings.*

## Design: munkens mat, moving like a feed

*Munkens mat* — the monk's meal — serves only what nourishes. Every screen
offers one thing to do; everything else happens out of sight. Study has no
buttons at all: the page is the control, and it moves the way people
already move through short-video feeds.

**Study: one full-screen feed, no buttons**

Each card fills the screen, edge to edge. Drag up and the next card slides
over this one while this one recedes — smaller, dimmer, its corners
rounding — the way a sheet pushes back what's beneath it. Lessons use the
same feed: a page for each new kanji, then its quiz.

| Gesture | Action | Borrowed from |
|---|---|---|
| Tap | Reveal the answer (tap again: hear it) | Tap to play |
| Swipe ↑ | Next — counts as "knew it" unless marked | Next reel |
| Swipe ↓ | Previous card, its answer undone (first card: close) | Previous reel; pulling a photo down to close it |
| Swipe → | Forgot | Mail-style swipe action |
| Swipe ← | Save for later | Mail-style swipe action |
| Double-tap | Easy — a heart pops (on a new kanji: "I already know this") | Liking a post |
| Hold | Stroke order and sound together, a soft tap on every stroke | Pressing a Live Photo |
| Pinch | Close | Pinching a photo closed |

Swiping up on a hidden answer reveals it as the card moves, so you always
see what you're confirming. Swiping sideways uncovers the action behind
the page, and a tick of haptics marks the point where letting go commits.
Directions that do nothing rubber-band. Small glass chips at the top show
what's marked (Forgot, Easy, Saved). The first five cards each teach one
gesture in a single line of text, then the hints are gone for good.
Hardware keys (Space, Return, ↑ ↓ ← →, E, P, Esc) and VoiceOver actions
cover every gesture.

**Built to feel like it belongs on iOS**

- *Motion:* springs that start from where things are and inherit the
  finger's velocity, so a flick carries straight into the page turn;
  momentum is projected the way scroll views decelerate; edges resist with
  Apple's rubber-band curve. Reduce Motion turns all of it into crossfades.
- *Spatial continuity:* the session rises from Home on the same swipe up
  that starts it; the cover is clear, so pulling the first page down or
  pinching shows Home underneath; the recap and the onboarding lift away
  like the Lock Screen.
- *Haptics (Core Haptics):* a soft tap per stroke in time with the drawing,
  a rising double pop for the heart, two dull knocks for Forgot, a crisp
  click for Save, a selection tick at commit points, a barely-there detent
  as each page lands. Each one fires on the same frame as its visual, and
  all of them can be switched off.
- *Sound:* the best Japanese voice installed (Premium, then Enhanced), or
  the one you pick in Settings. Automatic speech follows the Ring/Silent
  switch and mixes with your music; anything you ask for (tap, hold)
  plays and briefly ducks it.
- *Materials:* Liquid Glass (iOS 26) for the floating chips only — never
  for content — with a thin material on earlier systems.

**Light gamification, no anxiety.** A combo chip (×3, ×4…) counts first-try
answers and quietly resets on a miss; milestones get a haptic, the recap
notes your best run, and a hanko stamp closes each session. Saved kanji
form a collection you can practice. There are no streaks to lose, no
lives, no leaderboards.

**Screens**

| Screen | Contents |
|---|---|
| **Home** | One number (reviews waiting) or one glyph (the next new kanji), and "Swipe up to review/learn". When you're done: when the next review is, plus quiet links (read a text, practice saved, learn more). |
| **Library** | Kanji, Saved and Texts. Each glyph's ink deepens as you learn it — faint when new, full black once known. Search takes kanji, English, kana or romaji. |
| **Kanji page** | The glyph (hold for strokes and sound, double-tap to save), meaning, readings, a memory hook (or your own), words and a sentence — tap any to hear it. |
| **Settings** | Daily pace, writing, type readings, furigana, typeface, audio, voice, haptics, a daily reminder, import/export, privacy. |

**What happens behind it**

- **FSRS-6 scheduling** at a 90% recall target — intervals are never shown.
- **Pacing:** reviews always come before new kanji; after a long break,
  reviews arrive 50 at a time, most-at-risk first, and new lessons pause.
- **Order:** parts are taught before the kanji that contain them.
- **Three skills per kanji:** meaning; reading inside a real word (said in
  your head and checked by ear, or typed in kana/romaji with *Type
  readings*); and writing — in the air or on paper — which unlocks once
  recognition is stable and ends with the stroke order drawing itself.
- **Context cards:** every seventh first-try success is followed by an
  ungraded sentence that shows the kanji at work.
- **Mistakes are noticed for you:** typed near misses (small っ, long
  vowels, ゛ marks, a valid reading the word doesn't use) get a hint and a
  free retry; the type of slip is logged silently; the memory hook and
  look-alike tips appear only for new, relearning or repeatedly forgotten
  cards.
- **Adaptive furigana** shows readings only above kanji you haven't learned.
- **Audio** plays automatically on reveal but respects the Ring/Silent
  switch; a tap or hold plays even in silent mode.
- **Reminders** (opt-in, offered once after your first session) state the
  exact number of reviews waiting and keep the app badge accurate.

Stroke order data comes from [KanjiVG](https://kanjivg.tagaini.net)
(CC BY-SA 3.0) — see [content/KANJIVG-NOTICE.md](content/KANJIVG-NOTICE.md).

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

- import it in the app: **Settings → Import** — no rebuild; or
- add it to `content/core-n5.json`, fetch stroke order for any new kanji,
  then validate and re-embed:

  ```bash
  python tools/add_strokes.py
  ```

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
- Stroke-by-stroke writing checks against KanjiVG (the animation is in).
- iCloud sync (CloudKit) so iPhone, iPad and a future Mac app share progress.
- Per-learner FSRS parameter optimization from the review log.
- iPad and Mac layouts with a sidebar (`NavigationSplitView`).
- Optional gentle reminders and a "reviews due" widget.
- Handwriting recognition with the Vision framework.
