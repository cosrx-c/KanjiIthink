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

**Three places.** A tab bar — **Today**, **Kanji**, **Read** — the one
navigation every iPhone user already knows. Today shows the cards waiting
for you as a small deck and one button; Kanji is the library (all, or only
what you've saved); Read holds the short texts, the most readable first.
Settings is behind the gear on Today.

**Study: one full-screen deck, no buttons on the cards**

The cards are a deck of paper: the one in your hand on top, the next two
peeking out beneath it. Drag up and the top card lifts away while the deck
rises to meet your finger; drag down and the previous card drops back on
top. Lessons use the same deck: each new kanji gets a page, and you're
asked about it one page later, then again a little later, with other kanji
in between — so the first recall comes while it's fresh and the gaps grow.

| Gesture | Action | Borrowed from |
|---|---|---|
| Tap | Reveal the answer (tap again: hear it) | Tap to play |
| Swipe ↑ | Next — counts as "knew it" unless marked | Next reel |
| Swipe ↓ | Previous card, its answer undone (first card: close) | Previous reel; pulling a photo down to close it |
| ✕ | Close (pinching works too) | Every full-screen view on iOS |
| Swipe → | Forgot | Mail-style swipe action |
| Swipe ← | Save for later | Mail-style swipe action |
| Double-tap | Easy — a heart pops (on a new kanji: "I already know this") | Liking a post |
| Hold | Stroke order and sound together, a soft tap on every stroke | Pressing a Live Photo |
| Pinch | Close | Pinching a photo closed |

Touch is recognized by UIKit's gesture recognizers, so a tap is never
swallowed by a swipe and a hold is never cut short by a tap; a swipe locks
to its direction only after the finger has clearly chosen one. Swiping up
on a hidden answer reveals it as the card moves, so you always see what
you're confirming. Swiping sideways uncovers the action behind the card —
a vermilion Forgot panel or an indigo Save panel, as in Mail — and a tick
marks the point where letting go commits. A saved card wears a bookmark
ribbon on its top edge; a marked card carries a small Forgot or Easy badge.
The first five cards each teach one gesture in a single line of text, then
the hints are gone for good. A ✕ closes the session; so do pinching and
pulling the first card down. Hardware keys (Space, Return, ↑ ↓ ← →, E, P,
Esc) and VoiceOver actions cover every gesture.

**The look: ink on washi**

- *Paper:* warm off-white by day, true black by night. Every surface is a
  step on one ladder of light — the page, a sheet lying on it, a well
  pressed into it — told apart by lightness, never by a border. Sheets
  catch light along their top edge and cast two warm shadows; wells hold
  a soft inner shadow; the page is faintly vignetted and a slow ink wash
  drifts behind everything (a mesh gradient on iOS 18), turning a few
  percent cooler while you study and warmer when the day is done.
- *Depth:* the deck on Today and the glyph on a kanji page lean a few
  degrees as you move the phone and a sheen slides across them; a soft
  light follows your finger. On iPad, the pointer lifts and highlights
  what it's over. Study cards stay still, so nothing moves under the
  character you're reading.
- *Type:* San Francisco for text, New York (Apple's serif) for a few
  display lines, SF Rounded for numbers, Hiragino for Japanese. Everything
  scales with Dynamic Type and keeps at least 4.5:1 contrast.
- *Story:* onboarding is four pages you swipe up through: the 墨 mark writes
  itself, a forgetting curve draws as its page arrives, the gestures
  arrive one by one, and you set your daily pace on a 3D number wheel.
- *Settings* sits on the same paper and sheets as every other screen,
  with an Appearance option (Automatic, Light or Dark).

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
- *Materials:* Liquid Glass (iOS 26) for the floating controls only —
  the ✕ and the pill buttons, the prominent one tinted indigo — never for
  content. Before iOS 26 the prominent button is lit from above and
  blooms softly onto the page. Bloom appears in exactly three places (the
  ring as it closes, the prominent button, the stroke being written) so
  it still means "alive".

**Light gamification, no anxiety.** A small ring beside the date fills as
the day's cards are done — a goal to close, like the Activity rings, never
a streak to lose. A combo chip (×3, ×4…) counts first-try answers and
quietly resets on a miss; milestones get a haptic, the recap notes your
best run, and a hanko stamp closes each session. Saved kanji form a
collection you can practice. There are no streaks, lives or leaderboards.

**Screens**

| Screen | Contents |
|---|---|
| **Today** | The cards waiting for you as a small deck, how many there are and roughly how long they'll take, a ring that fills as the day is done, and one button: Review or Learn (the deck lifts under a swipe up too). When you're done: a hanko seal, when the next review is, and quiet buttons (read a text, practice saved, learn more). |
| **Kanji** | The library: all kanji by level, or only the ones you've saved. A kanji you haven't started sits pressed into the paper; once started, its tile lies on top, and its ink deepens as you learn it — faint at first, full black once known. Each level shows how much of it you know. Search takes kanji, English, kana or romaji. |
| **Read** | Short texts with furigana only above kanji you haven't learned, the most readable first, each with a ring showing how much of it you can already read. Tap any word to look it up. |
| **Kanji page** | The glyph on a sheet of practice paper (hold for strokes and sound, double-tap to save), its level, stroke count and type, the meaning, on and kun readings, a memory hook (or your own), words and a sentence — tap any of them to hear it. |
| **Settings** | Daily pace, type readings, appearance, typeface, furigana, audio, voice, haptics, a daily reminder, import/export, privacy — on the same paper and sheets as every other screen. |

**What happens behind it**

- **FSRS-6 scheduling** at a 90% recall target — intervals are never shown.
- **Pacing:** reviews always come before new kanji; after a long break,
  reviews arrive 50 at a time, most-at-risk first, and new lessons pause.
- **Order:** parts are taught before the kanji that contain them.
- **Two skills per kanji:** meaning, and the reading inside a real word
  (said in your head and checked by ear, or typed in kana/romaji with
  *Type readings*). Holding any card plays its stroke order.
- **Context cards:** right after a miss, an ungraded sentence shows the
  kanji at work while the correction is fresh; one also follows every
  tenth first-try success.
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

### On an iPhone, without a Mac

Swift Playgrounds can only run the app inside itself, on the iPad. To put
Sumi on an iPhone the build has to come out of Xcode, so the repository
builds itself on GitHub's macOS machines instead
([.github/workflows/ios.yml](.github/workflows/ios.yml)):

1. Every push to `main` that touches `Sumi.swiftpm` runs the **iOS build**
   workflow (or start one by hand under **Actions → iOS build → Run
   workflow**). It takes a few minutes.
2. When it's done, the build is published as the release called **latest**:
   <https://github.com/cosrx-c/KanjiIthink/releases/latest> — download
   `Sumi-unsigned.ipa` from there (no GitHub login needed). The same file
   is also attached to the run as an artifact, and if the run failed, the
   **build-log** artifact has the compiler's output.
3. On a Windows PC, install [Sideloadly](https://sideloadly.io) and Apple's
   own iTunes (from apple.com, not the Microsoft Store build). Plug the
   iPhone in, open Sideloadly, drag the `.ipa` onto it, enter your Apple ID,
   and press **Start**. Sideloadly signs the app with your Apple ID and
   installs it.
4. On the iPhone: turn on **Settings → Privacy & Security → Developer
   Mode**, then trust your Apple ID under **Settings → General → VPN &
   Device Management**.

With a free Apple ID the app expires after 7 days (install it again to
renew; progress is kept) and you can have three sideloaded apps at once. A
paid Apple Developer membership removes both limits and opens the door to
TestFlight. Private repositories get 2,000 free Actions minutes a month,
and macOS minutes count ten times over, so that's roughly 25–40 builds;
public repositories are unlimited.

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

The code is written on a Windows machine without Xcode. Every push to
`main` is compiled for iPhone by the GitHub Actions workflow in
`.github/workflows/ios.yml` (Xcode 26.3, iOS 26 SDK, unsigned), so a green
run means the whole app builds; the result is published as the `latest`
release. What is checked before each push: bracket/string structure of
the Swift file, the starter content (every kanji annotated with furigana,
readings in the right script, every word containing its kanji, passage
answers in range), and that the content tools round-trip the embedded JSON
exactly. What still needs a person: running it on a device and looking at
it — the layout, the motion and the feel can only be judged there.

## Roadmap

- Content: N5 complete (~80), then N4, N3, N2, N1 packs; audio recordings.
- Stroke-by-stroke writing checks against KanjiVG (the animation is in).
- iCloud sync (CloudKit) so iPhone, iPad and a future Mac app share progress.
- Per-learner FSRS parameter optimization from the review log.
- iPad and Mac layouts with a sidebar (`NavigationSplitView`).
- Optional gentle reminders and a "reviews due" widget.
- Handwriting recognition with the Vision framework.
