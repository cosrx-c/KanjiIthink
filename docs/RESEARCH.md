# Research and design rationale

This document records *why* Sumi works the way it does: what learners
struggle with in existing apps, what the learning-science and linguistics
research says, which UX principles were applied, and how each one maps to a
concrete decision in `Sumi.swiftpm/Sources/ContentView.swift`. It also lists the open
questions that only testing with real learners can answer.

---

## 0a. Revision 3 — a feed people already know how to use

Revision 2 made the app quiet; revision 3 makes it move. The aim: keep the
minimal surface, but let study feel as effortless as scrolling a short-video
feed, without importing the parts of those apps that harm learning.

**Borrowed mental models.** People arrive already fluent in a handful of
gesture vocabularies. Each study action is mapped to the one that already
means the same thing:

| Action | Gesture | Prior meaning people carry |
|---|---|---|
| Reveal | Tap | Tap to play; HIG: tap activates |
| Next (counts as known) | Swipe ↑ | Reels, TikTok, Shorts: up = next |
| Previous (undo) | Swipe ↓ | Reels, TikTok, Shorts: down = previous |
| Mark / clear Forgot | Swipe ← / → | Flashcard apps: left = still learning |
| Save | Double-tap | Liking or saving a post |
| Stroke order | Touch and hold | Live Photos play while pressed; HIG: hold reveals more |

*Revision 3.1:* the feed now pages vertically like Reels — every card is a
full-screen page and the next one physically rises from below as you drag,
so swipe up is the one gesture that drives a session. Because most reviews
at a 90% target are successes, "swipe up" counts as known by default, and a
miss is marked first (swipe ←, the rail's Forgot, or the ← key) — the
common case takes one gesture, the rarer case two. Swiping up on a hidden
answer reveals it as the card moves, so a confirmation is never blind.
Vertical swiping is standard scrolling (HIG), not a custom gesture; the
rail and the tappable caption still give it visible alternatives.
Double-tap stays "save", where people already expect saving.

**Apple's gesture guidance applied** (HIG, Gestures):
- *"Give people more than one way to interact"* — every gesture has a
  visible button or rail icon, a keyboard key and a VoiceOver action.
- *"Provide feedback that helps them predict its results"* — the card tilts,
  a labelled pill fades in, and a haptic tick marks the commit point.
- *"Indicate when a gesture isn't available"* — unavailable swipes
  rubber-band and show "Not available" with a firmer haptic.
- *"Make custom gestures easy to learn"* — the swipe vocabulary is printed
  on the card until it's been used three times; the hold/double-tap tip
  shows until one of them is used.
- *"Avoid conflicting with gestures that access system UI"* — study runs
  full-screen, so card swipes never collide with edge-swipe-back; the Home
  indicator fades, as in other immersive media.

**Gamification, chosen against evidence.** Sailer & Homner's 2020
meta-analysis finds gamification helps learning on average (cognitive
g ≈ 0.49; motivational g ≈ 0.36 and behavioral g ≈ 0.25, both less
stable). The mechanics that help are feedback and visible competence; the
ones learners resent are loss-framed (streak anxiety, hearts). So:

| Kept | Why |
|---|---|
| Combo badge (first-try run), quiet reset | Immediate competence feedback; nothing is lost on a miss |
| Milestone haptics (5, 10, 20…) | Small, unpredictable-feeling reward tied to real recall |
| Recap: best run, personal best | Peak-end: sessions close on a high point |
| Saved collection | Ownership and curation, as with saved posts |
| Ink-density library | Progress you can see without a chart |

| Rejected | Why |
|---|---|
| Daily streaks, streak freezes | Loss aversion becomes anxiety and "streak-saving" instead of learning |
| Hearts / lives | Punishes the errors that drive learning |
| Leaderboards, XP | Shifts attention from recall to points; social comparison |
| Infinite feed | Spacing needs sessions to end; the feed always ends with a stamp |

**Learning integrity inside the feed.**
- Reading cards default to saying the reading in your head, then checking by
  ear. Covert retrieval can benefit retention much as overt retrieval does
  for simple items (Smith, Roediger & Karpicke 2013), with weaker effects in
  some later studies, so *Type readings* keeps objective, auto-graded typing
  for anyone who wants it.
- Writing cards ask for writing in the air or on paper. Air-writing (空書) is
  common among Japanese readers and linked to a small recall advantage; the
  pad stays one tap away in a sheet, so drawing never fights the feed's
  swipes.
- Grading before revealing is allowed for speed, but the answer is shown as
  the card leaves, and swipe ↓ brings it straight back.
- Every seventh first-try success adds an ungraded sentence card: variety
  for attention, context for meaning.

**iOS technologies used.** SwiftUI gestures (drag, tap, double-tap, long
press), 3D card flip via `rotation3DEffect` with a Reduce Motion fade,
`Canvas` + `TimelineView` stroke-order animation from KanjiVG SVG paths,
UIKit haptics, PencilKit drawing, `AVSpeechSynthesizer` (respecting the
Ring/Silent switch for automatic audio), local notifications with accurate
badge counts, keyboard shortcuts for iPad keyboards, and VoiceOver custom
actions.

## 0. Revision 2 — munkens mat (minimal redesign)

The first build exposed too much: four tabs, cards on every screen,
interval labels, charts, eleven settings. Revision 2 follows *munkens mat*,
the monk's meal: serve only what nourishes. The learning logic below is
unchanged — it simply moved out of sight.

| Removed from view | Where the logic lives now |
|---|---|
| Today dashboard (rhythm, tricky kanji, backlog banner, reading card) | Home picks one state — review, learn or rest — from the store. Catch-up batching and lesson pausing still run silently. |
| Progress tab (charts, heatmap, forecast, misses) | Stage is shown by ink density in the Library; statistics are still computed and stored. |
| Interval labels, Hard/Easy, "why did you miss?" chips | FSRS still schedules; grading is pass/fail; slip type is inferred from the answer and logged. |
| Retention, batch size, day start, grading and haptics settings | Fixed research defaults (90%, 5, 4 AM); haptics follow the system setting. |
| Mnemonic and look-alikes on every answer | Shown only for new, relearning or leech cards — support appears when it's needed. |
| Cards, chips, eyebrows, custom buttons | Plain typography on the system background; system bordered buttons. |

What Apple's guidance asked for, and how it's met:

- *"Help people concentrate on primary tasks and content by limiting the
  number of onscreen controls while making secondary details and actions
  discoverable with minimal interaction"* (Designing for iOS) — one primary
  action per screen; secondary actions live in toolbars, menus and taps.
- *"Minimizing modal interfaces and full-screen transitions"* (Designing for
  iPadOS) — study sessions are pushed onto the navigation stack, so Back
  always leaves and every answer is already saved.
- iPhone Duo (Sept 2026) — standard `NavigationStack`, toolbars and system
  buttons, so the system can move bars to the side; no fixed widths (only
  maximum widths); toolbar items use `Label` with both title and symbol;
  layouts adapt by available space.
- App Review 5.1.1 — an in-app Privacy page (no data collected, everything
  on device). 2.1 — no placeholder content: levels without kanji are hidden
  rather than shown as "coming soon". 2.3.7 / 5.2.1 — "JLPT" isn't used in
  the app name, and the app disclaims affiliation.

---

## 1. Where existing apps let learners down

Findings from learner communities (WaniKani forums, Anki forums, reviews of
Duolingo/Renshuu/Kanshudo) and app reviews, paired with Sumi's response.

| # | Pain point | What learners report | Sumi's response |
|---|---|---|---|
| P1 | **Review avalanches after a break** | Missing a day or two makes the backlog "daunting"; a major cause of quitting Anki and WaniKani. | *Catch-up mode* (over 100 due): a calm "Welcome back" card, batches of 50, **lowest-recall cards first** (FSRS "relative overdueness"), new lessons paused automatically. No guilt copy. |
| P2 | **"Ease hell" / too many reviews** | SM-2's ease factor spirals down and inflates reviews; default settings risk "a massive backlog". | FSRS-6 scheduler (no ease factor). The retention slider shows the workload cost live (95% ≈ 2.5× the reviews of 90%). |
| P3 | **Steep learning curve, settings overload (Anki)** | "Functional rather than polished"; beginners don't know what to configure. | Eleven settings total, each with a default and a one-line footer explaining the trade-off. Everything else is decided by research-backed defaults. |
| P4 | **Forced slow pace / level locks (WaniKani)** | Can't skip what you know; "level 1 again" for returning learners. | *What you know* picker in onboarding and Settings; "I already know this one" on every lesson page; "Learn next" on any kanji. Known items are verified by spaced checks, not trusted blindly. |
| P5 | **Strict grading, no undo** | Marked wrong for typos or valid synonyms; the "Double-Check" userscript exists only to work around it. | Multi-level **undo** (⌘Z), an "I mistyped" override, one **free retry** for near-misses (small っ, long vowel, voicing) and for valid-but-wrong readings, with a hint saying exactly what to notice. |
| P6 | **"Which reading do they want?"** | Readings tested on a lone kanji are ambiguous; users ask for multiple readings. | Readings are **always tested inside a real word** (and rotate through the kanji's words). Meanings are self-graded, removing synonym-matching problems entirely. |
| P7 | **Kanji learned in isolation** | Users recognize a character in a quiz but not in real text; "useless kanji" complaints. | Every kanji ships with words, a real sentence, "In real life" usage notes, and appears in graded passages with adaptive furigana. |
| P8 | **No writing** | Most apps are recognition-only; writing is a separate app. | Writing facet with a PencilKit pad over 田-grid paper; model glyph fades in beneath your strokes for comparison. Unlocks once recognition is stable. |
| P9 | **Kanji never explained (Duolingo)** | "Every new kanji is never explained"; no radicals or mnemonics. | Parts, formation type (象形/指事/会意/形声/仮借), phonetic hints, a mnemonic, and a prompt to write your own. |
| P10 | **Gamification over learning, streak anxiety** | Streak loss creates anxiety; "the notifications stop being about language learning". | No streaks, hearts, XP or leaderboards. A gentle weekly rhythm ("4 of 7 days") and a 16-week activity map titled "No streaks to break — just your rhythm." |
| P11 | **Opaque SRS ("does it even work?")** | Burned items forgotten; no idea why something came back. | Each grade button shows its next interval. Each kanji page shows "% chance of recall now", next review and review count. A "How Sumi teaches" page explains every mechanism. |
| P12 | **Mismatch with JLPT** | WaniKani order ignores JLPT levels. | Lessons follow JLPT level order, with parts taught before the kanji that contain them. Levels are labelled honestly as unofficial (see §8). |

## 2. Learning science → features

| Principle | Evidence | Where it lives in the app |
|---|---|---|
| **Spacing effect** | Cepeda et al. 2006 meta-analysis (839 assessments, 317 experiments): distributed practice gives ~15% more retention than massed, and the optimal gap grows with the retention interval. | FSRS-6 scheduler; reviews arrive together at the start of the study day (4 AM default). |
| **Retrieval practice (testing effect)** | Adesope et al. 2017 meta-analysis (188 articles, 272 effect sizes): practice testing beats restudy, g ≈ 0.50–0.61; strongest with 1–6 day lags. Roediger & Karpicke 2006. | Every card demands an answer before the reveal; lessons end with an immediate quiz; misses are re-asked 3–6 cards later. |
| **Modern SRS (FSRS-6)** | Open Spaced Repetition / Anki (2023+). Models stability S, difficulty D and retrievability R per card; 21 parameters trained on large review datasets. | `FSRS` and `ReviewScheduler` structs. Formulas in §3. |
| **Interleaving** | Rohrer & Taylor 2007. Mixed practice improves discrimination between similar items. | `SessionModel.interleave` — never the same kanji twice in a row; facets are mixed. |
| **Component analysis + dual coding** | JALT Journal 20.2: the component-analysis method (parts + meanings + linking story) produced significantly higher retention than whole-kanji memorization in both JSL and JFL settings. Paivio's dual coding (verbal + visual). | "Built from" parts, memory hook, and `Store.partsFirst` (休 is taught after 木, 男 after 田). |
| **Phono-semantic compounds** | Roughly 4 in 5 kanji pair a meaning part with a sound part; phonetic families are about two-thirds consistent. | `kind: phonetic` + "交 (コウ) gives the sound コウ" hints. |
| **Generation effect** | Self-generated cues are recalled better than provided ones. | "Write your own hook" on every kanji; your hook replaces the default one in reviews. |
| **Noticing hypothesis / input enhancement** | Schmidt 1990; Sharwood Smith 1993. A 2025 meta-analysis (29 studies, 1,749 participants) found small-to-medium effects of textual enhancement, equal for vocabulary and grammar, and **no extra benefit from stacking techniques**. | The target kanji is set in accent color + heavier weight wherever it appears — one technique, used consistently. Near-miss hints direct attention to small っ, long vowels and voicing. |
| **Output hypothesis + motor memory** | Swain 1985. Naka & Naoi 1995: repeated writing improved recall of kanji forms over visual-only study. Caveat: writing costs time, so it's gated. | Writing facet unlocks after recognition reaches ~3 days' stability; "Trace it once" in every lesson. |
| **Receptive before productive** | Recognition is easier than recall (Johnson, *Designing with the Mind in Mind*; vocabulary research). | Facet order: meaning → reading → writing. |
| **Comprehensible input (i+1)** | Krashen 1985. Research on furigana shows a negative correlation between habitual furigana use and kanji reading ability, while furigana helps lexical inference on unknown words. | **Adaptive furigana**: readings appear only above kanji you haven't learned, and fade as each one becomes Familiar. Passage cards show "% familiar" so you can pick texts just above your level. |
| **CLIL** | Coyle, Hood & Marsh 2010 — content and language learned together. | Passages teach something real (train etiquette, seasons, restaurant service, diaries, school email) with a comprehension question. |
| **Sociolinguistics / register** | Choice of form depends on relationship and setting. | "Register" notes (keigo in announcements, plain form in diaries, 友だち vs 友人), "In real life" usage notes. |
| **Discourse analysis** | How texts are organized by genre. | "Discourse" notes: nominal style of signs, topic frames in expository text, the fixed structure of formal email. |
| **Conversation analysis** | Adjacency pairs, turn-taking, preference organisation. | Dialogue passages with colored turn markers and "Conversation" notes (いらっしゃいませ expects no reply; question–answer pairs). |
| **Intercultural pragmatics** | Politeness and face differ across cultures. | "Intercultural" notes (apologising to maintain relationships; modest replies to 上手ですね). |
| **Language Management Theory** | Neustupný & Jernudd 1987: noting a deviation → evaluating it → designing an adjustment → implementing it. | After a missed reading: optional "What tripped you up?" chips. Progress → *What trips you up* aggregates the tags and gives the matching adjustment (compare look-alikes, say words aloud, rewrite the hook, slow down). |
| **Desirable difficulties** | Bjork. Effortful retrieval strengthens memory. | Summary copy reframes a hard session: "Effortful recall now builds stronger memories later." |
| **Self-determination theory** | Deci & Ryan: autonomy, competence, relatedness sustain motivation; controlling rewards undermine it. | Learner-chosen pace, skipping, practice mode; competence feedback via stages; no punitive mechanics. |
| **Sleep and the study day** | Consolidation happens overnight. | Day boundary at 4 AM so late sessions count as "today"; reviews land in the morning. |

## 3. The scheduler

### FSRS-6

Default parameters `w₀…w₂₀` (published FSRS-6 defaults):

```
0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666,
0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
```

- Retrievability: `R(t, S) = (1 + factor · t / S) ^ (−w₂₀)`, where `factor = 0.9^(−1/w₂₀) − 1`, so `R(S, S) = 0.9`.
- Interval for desired retention `r`: `I = S / factor · (r^(1/decay) − 1)`, rounded, clamped to 1…3650 days.
- Initial stability `S₀(G) = w[G−1]`; initial difficulty `D₀(G) = w₄ − e^(w₅(G−1)) + 1`, clamped 1…10.
- Difficulty update: linear damping `ΔD·(10 − D)/9`, then mean reversion toward `D₀(4)` with weight `w₇`.
- Success: `S′ = S · (1 + e^w₈ · (11 − D) · S^(−w₉) · (e^((1−R)w₁₀) − 1) · hardPenalty · easyBonus)`.
- Lapse: `S′ = min(w₁₁ · D^(−w₁₂) · ((S+1)^w₁₃ − 1) · e^((1−R)w₁₄), S / e^(w₁₇·w₁₈))`.
- Same-day review: `S′ = S · e^(w₁₇(G − 3 + w₁₈)) · S^(−w₁₉)`, never decreasing on a pass.

### Learning steps

Lesson quiz (first rating) → check after **4 hours** (an early consolidation
review, like WaniKani's first interval) → FSRS takes over. A miss at any point
is re-asked within the session until correct. With FSRS-6 defaults, a kanji
you always remember is then seen after about **2, 12, 50 and 174 days** —
four reviews in its first six months.

### Target retention vs workload

| Target recall | Reviews vs 90% | Intervals vs 90% |
|---|---|---|
| 80% | 0.30× | 3.3× longer |
| 85% | 0.52× | 1.9× longer |
| **90% (default)** | 1.00× | — |
| 93% | 1.63× | 0.61× |
| 95% | 2.48× | 0.40× |

The Settings footer computes this live, so the cost of chasing 95% is visible
before it's chosen.

### Leeches

A card that lapses 6 times is flagged *Tricky*. Unlike Anki, it is **not
suspended** (suspended cards are easy to forget about). It appears on Today
and Progress with a nudge to compare look-alikes or write a new hook, and the
flag clears once the card is stable for 3 weeks.

### Grading

Two buttons by default (Forgot / Remembered) — pass/fail is sufficient for
FSRS and removes a decision from every card (Schwartz, *The Paradox of
Choice*). Detailed grading (Again/Hard/Good/Easy) is one toggle away for
power users. Readings are graded objectively from typed kana.

## 4. UX principles applied

| Source | Principle | Decision |
|---|---|---|
| Cooper et al., *About Face* | Design for **perpetual intermediates**; reduce excise | Defaults that work on day one; power features (keyboard shortcuts, detailed grading, practice mode, import/export) present but never in the way. No confirmation dialogs except for destructive actions. |
| Krug, *Don't Make Me Think* | Self-evident screens; people scan, they don't read; conventions | One primary action per screen; Eyebrow labels for scanning; standard iOS tab bar, sheets and navigation. |
| Krug, *Rocket Surgery Made Easy* | Small, frequent usability tests | Test plan in §7. |
| Norman, *The Design of Everyday Things* | Signifiers, feedback, mapping, conceptual model; slips vs mistakes | Grade buttons show their consequence; instant haptic + color feedback; the 4-step "Learn → Recall → Review → Read" model in onboarding; slips (typos) get an override, mistakes get a hint. |
| Johnson, *Designing with the Mind in Mind* | Recognition over recall; attention is limited; response-time deadlines | Kanji pages surface everything needed in one scroll; feedback within 100 ms; session focus mode (full-screen, no tab bar). |
| Weinschenk, *100 Things Every Designer Needs to Know About People* | People process ~4 chunks; progress motivates; peripheral vision; avoid manipulation | Lessons in batches of 5; progress meter in every session; numbers paired with labels; no dark patterns. |
| Schwartz, *The Paradox of Choice* | More options, less satisfaction | 3 paces in onboarding; 11 settings total; 2-button grading. |
| Colborne, *Simple and Usable* | Remove, organize, hide, displace | Wrap-up and other rare actions live in a menu; detailed stats live in Progress, not Today. |
| Tidwell et al., *Designing Interfaces* | Patterns: multilevel undo, forgiving format, good defaults, input hints, progress indicator, cancelability | ⌘Z undo stack (30 deep); romaji or kana input; placeholder "Type the reading — romaji or kana"; every session can be closed with progress saved. |
| Evans, *Bottlenecks* | Attention, memory and motivation bottlenecks | One task on screen at a time; memory offloaded to the app (it decides what's due); calm motivation. |
| Gothelf & Seiden, *Lean UX* | Hypotheses and outcomes over outputs | Hypotheses in §7. |
| Hall, *Just Enough Research*; Marsh, *User Research*; Travis & Hodgson, *Think Like a UX Researcher*; Buley, *The UX Team of One* | Research proportionate to risk; observe behaviour over opinion | §7 research plan: diary study + task-based tests, small and repeated. |
| Rosenberg, *UX Magic*; Kelley & Kelley, *Creative Confidence* | Design-led thinking; prototype and iterate | Shipped as a working prototype to put in front of learners immediately. |
| Nielsen's heuristics | Visibility of status, user control, error prevention, recovery, help | Due counts, next-review times, undo, near-miss hints, confirmations for resets, "How Sumi teaches". |
| Laws of UX | Fitts, Hick, Jakob, Von Restorff, goal-gradient, peak-end, Doherty | Bottom-anchored full-width answer buttons (thumb zone, Fitts); few choices (Hick); iOS conventions (Jakob); a single accent-filled CTA (Von Restorff); session progress (goal-gradient); a hanko "済" stamp and forward-looking message at the end (peak-end); instant feedback (Doherty). |

## 5. Visual design system

### Color

One accent carries every primary action; other hues only ever encode
meaning. Names are traditional Japanese colors. All text pairs meet WCAG AA;
Increase Contrast swaps in darker/lighter variants.

| Token | Light | Dark | Role |
|---|---|---|---|
| paper 和紙 | `#F7F5F0` | `#121211` | Background — warm, low-glare |
| surface | `#FFFFFF` | `#1D1C1A` | Cards (elevated in dark mode) |
| ink 墨 | `#1B1A18` | `#F3F1EC` | Primary text |
| ink2 | `#5C5850` (≈6.5:1 on paper) | `#ABA69C` | Secondary text |
| accent 藍 | `#2D4F9E` (≈7.7:1 on white) | `#93ABEB` | Actions, focus, highlighted kanji |
| shu 朱 | `#C2412D` | `#F08A74` | Forgot / wrong |
| matcha 抹茶 | `#3F7A3A` | `#94C98A` | Remembered / correct |
| kohaku 琥珀 | `#9A6A0B` | `#E5B65A` | Learning stage, hints |
| asagi 浅葱 | `#2A7F8F` | `#7CC4D1` | Familiar stage, reading coverage |
| murasaki 紫 | `#6B4E9B` | `#B79BE0` | Mastered — purple was the highest court rank color in Japan |

Emotional intent: indigo reads calm and trustworthy for a study tool;
vermilion (the color of seals) signals "stop and look" without the alarm of
pure red; green confirms. Stage colors always come with a text label
(Differentiate Without Color).

### Typography

- **Latin:** SF Pro via Dynamic Type text styles; SF Rounded for statistics.
  SF's built-in optical tracking is left untouched.
- **Japanese:** always Hiragino (Sans W3/W6, Mincho ProN, Maru Gothic). Kanji
  inside English sentences are switched to Hiragino run by run
  (`MixedText`), because with a non-Japanese device language iOS can fall
  back to Chinese glyph shapes (Han unification).
- **Line height:** Japanese has no x-height — every character sits at full
  "H-height" — so it needs more leading than Latin text. Body Japanese uses
  ≥1.5× line height; furigana runs reach ~1.9× including the ruby line.
- **Furigana** at 50% of the base size (the JIS ruby convention), centered
  over its word, with a reserved ruby line on every row so revealing
  readings never shifts the layout.
- **Line breaking** follows kinsoku rules: 。、」 and small kana never start a
  line; 「 never ends one.
- **Kanji typeface** is user-selectable (Gothic / Mincho / Rounded) because
  real print varies and handwriting shapes differ from Gothic.
- **Hero glyphs** scale with Dynamic Type but are clamped (≤168–180 pt) so
  nothing spills off small screens; long words scale down to fit one line.

### Space, shape and touch

- 4-pt grid (4, 8, 12, 16, 20, 24, 32, 48). Screen margins 20 pt; card
  padding 20 pt; related items 4–12 pt apart, sections 20 pt apart (Gestalt
  proximity).
- Continuous-corner radii: 10 (chips), 14 (controls), 20 (cards). Rounded
  forms are preferred to sharp ones and read as approachable (Bar & Neta 2006).
- Cards use a 1-pt hairline instead of heavy shadows (content over chrome).
- Every tap target ≥ 44 × 44 pt; primary buttons 52 pt tall, grade buttons 60 pt.
- Reading column capped at 680 pt on iPad (~35–40 Japanese characters per line).

### Layout and scanning

- **Today** follows a top-to-bottom priority stack (F-pattern): status →
  one primary action → secondary actions → reflection.
- **Sessions** put the question in the upper-middle (where the eye lands) and
  every answer control in the bottom thumb zone.
- **Gestalt:** common region (cards), proximity (label + value), similarity
  (all chips share a style), figure–ground (hero glyph on practice-grid paper).

### Motion and haptics

Short springs (0.22–0.35 s) for state changes, a shake for "try again", a
stamp for completion. Reduce Motion swaps springs for fades. Haptics: light
tap on reveal and self-grade, success/error on typed answers — all optional.

### Accessibility

Dynamic Type everywhere (including Japanese via `relativeTo:`), VoiceOver
labels on glyphs, tiles, meters and charts, `isSelected` traits on chips,
Increase Contrast palette variants, Reduce Motion, keyboard shortcuts on iPad.

## 6. Architecture notes

- One file (`Sumi.swiftpm/Sources/ContentView.swift`) by request, organized into eight
  marked sections. `ContentView` owns the store, so `WindowGroup {
  ContentView() }` is all an app needs.
- iOS 17+, SwiftUI, Swift 5.9 language mode. No SwiftData/`@Observable`
  macros, to stay compatible with every Swift Playgrounds build.
- Progress is a single JSON file in Application Support, saved with a 0.5 s
  debounce and on backgrounding. An unreadable file is copied aside, never
  overwritten. Settings decode leniently so future versions keep old
  preferences.
- Content is JSON with lenient decoding; packs import without a rebuild.

## 7. Validating it with learners

### Hypotheses (Lean UX)

1. *Two-button grading* lets learners review ~15% faster than four buttons
   with no drop in 30-day accuracy. Measure: seconds per review, accuracy.
2. *Catch-up mode* brings back learners after a 7+ day gap more often than a
   plain backlog. Measure: sessions within 3 days of returning.
3. *Readings in words* reduce "which reading?" errors. Measure: share of
   misses tagged *Reading* and hint-triggered retries.
4. *Adaptive furigana* increases passage completion without hurting
   comprehension. Measure: question accuracy, passages read.
5. *Asking why* is used often enough to be worth the screen space. Measure:
   tag rate per miss; drop the chips if it's consistently under ~20%.

All metrics are already stored locally (day stats, review log with timings
and miss tags). Any future analytics must be opt-in.

### Test plan (Krug style)

Three learners per round, monthly, 30 minutes each, think-aloud:

1. Finish onboarding as someone who already knows 20 kanji.
2. Complete a lesson and its quiz.
3. You mistyped a reading — fix it.
4. Find the kanji read *mizu*.
5. Read *At the station* and look up 電車.
6. Make reviews less frequent.
7. Import a content pack (file provided).

Watch for hesitation, wrong taps and misread labels; fix the top three
issues before the next round. Pair with a two-week diary study for
motivation and habit questions (Hall; Marsh).

## 8. Honest limits

- **"JLPT approved" isn't possible.** The JLPT (Japan Foundation and JEES)
  doesn't endorse apps and hasn't published official kanji lists since 2010.
  The app says "JLPT levels are a study guide" and disclaims affiliation.
  Market it as *JLPT-aligned*.
- Starter content covers 59 N5 + 5 N4 kanji and 5 passages. Etymology
  (`kind`) is only given where it's well established.
- No stroke-order animation yet (KanjiVG, CC BY-SA 3.0, is the natural
  source) and no handwriting recognition — writing is self-checked against
  the model glyph.
- Speech uses the system Japanese voice, fed kana so it never misreads kanji.
- FSRS parameters are the global defaults; per-user optimization from the
  review log is a natural next step once learners have ~1,000 reviews.

## References

- Adesope, Trevisan & Sundararajan (2017). Rethinking the use of tests: a meta-analysis of practice testing. *Review of Educational Research*. https://journals.sagepub.com/doi/10.3102/0034654316689306
- Cepeda, Pashler, Vul, Wixted & Rohrer (2006). Distributed practice in verbal recall tasks. *Psychological Bulletin*. https://pubmed.ncbi.nlm.nih.gov/16719566/
- Open Spaced Repetition — The FSRS algorithm (FSRS-6). https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm
- Anki manual — FSRS FAQ. https://docs.ankiweb.net/faqs/frequently-asked-questions-about-fsrs
- Anki forums — review order ("relative overdueness") and desired retention discussions. https://forums.ankiweb.net/t/ordering-request-reverse-relative-overdueness/50051
- Effectiveness of different approaches to kanji education for second language learners. *JALT Journal* 20.2. https://jalt-publications.org/sites/default/files/pdf-article/jj-20.2-art4.pdf
- Effects of textual enhancement on L2 development: a meta-analysis (2025). *IRAL*. https://www.degruyterbrill.com/document/doi/10.1515/iral-2025-0118/pdf
- Furigana use and kanji reading ability. *Hikari* (UNESA). https://ejournal.unesa.ac.id/index.php/hikari/article/view/67748
- Phono-semantic compounds and phonetic-component consistency. https://mojimori.app/blog/phono-semantic-compounds-the-80-percent-rule
- Naka & Naoi (1995) on writing and kanji recall, summarised at https://blog.skritter.com/2016/02/why-writing-helps-you-remember-better-than-reading/
- Heinrich & Sugita — Teaching Japanese interaction as a process of language management. DIJ Tokyo. https://www.dijtokyo.org/wp-content/uploads/2016/09/139-163_TEACHING-JAPANESE-INTERACTION-AS-A-PROCESS-OF-LANGUAGE-MANAGEMENT_43-Heinrich_Sugita-10.pdf
- About JLPT kanji lists (no official lists since 2010). https://kanjikana.com/en/kanji/jlpt
- WaniKani community: "Why I'm quitting WaniKani" and "I'm giving up on WK… feedback after level 20". https://community.wanikani.com/t/why-i%E2%80%99m-quitting-wanikani/35254 · https://community.wanikani.com/t/im-giving-up-on-wk-and-heres-some-feedback-after-making-it-to-level-20-in-three-ish-years/65757
- WaniKani Double-Check userscript. https://community.wanikani.com/t/userscript-double-check-version-2x/31456
- Duolingo kanji and streak critiques. https://www.clozemaster.com/blog/?p=7870 · https://uxdesign.cc/3-reframing-streaks-on-duolingo-5-ideas-for-a-more-healthy-and-flexible-approach-to-language-8fd89545771e · https://lup.lub.lu.se/student-papers/record/9238652
- Anki learning curve and backlog. https://nibble-app.com/blog/anki-review
- Japanese line height and internationalization guidance. https://designinternet-qaeusw1green.americanexpress.com/guidelines/japan-internationalization/overview
- Han unification and Japanese font selection. https://framagit.org/nani-project/nani-app/-/merge_requests/5
- Swift Playgrounds app package structure. https://github.com/alemohamad/swift-playground-app-structure
- Apple Human Interface Guidelines — Typography, Color, Layout, Accessibility. https://developer.apple.com/design/human-interface-guidelines
- Krashen (1985) *The Input Hypothesis*; Schmidt (1990) noticing; Sharwood Smith (1993) input enhancement; Swain (1985) output; Paivio (1971) dual coding; Rohrer & Taylor (2007) interleaving; Roediger & Karpicke (2006) testing effect; Neustupný & Jernudd (1987) language management; Coyle, Hood & Marsh (2010) CLIL; Deci & Ryan, self-determination theory; Bar & Neta (2006) preference for curved objects.
- UX books: Cooper et al., *About Face*; Krug, *Don't Make Me Think* and *Rocket Surgery Made Easy*; Norman, *The Design of Everyday Things*; Johnson, *Designing with the Mind in Mind*; Weinschenk, *100 Things Every Designer Needs to Know About People*; Schwartz, *The Paradox of Choice*; Colborne, *Simple and Usable*; Tidwell, Brewer & Valencia, *Designing Interfaces*; Evans, *Bottlenecks*; Gothelf & Seiden, *Lean UX*; Hall, *Just Enough Research*; Marsh, *User Research*; Travis & Hodgson, *Think Like a UX Researcher*; Buley, *The UX Team of One*; Rosenberg, *UX Magic*; Kelley & Kelley, *Creative Confidence*.
- Sailer & Homner (2020). The gamification of learning: a meta-analysis. *Educational Psychology Review* 32, 77–112. https://link.springer.com/article/10.1007/s10648-019-09498-w
- Smith, Roediger & Karpicke (2013). Covert retrieval practice benefits retention as much as overt retrieval practice. *Journal of Experimental Psychology: Learning, Memory, and Cognition* 39(6).
- Apple Human Interface Guidelines — Gestures. https://developer.apple.com/design/human-interface-guidelines/gestures
- Apple Human Interface Guidelines — Designing for iPhone Duo. https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- KanjiVG stroke order data (CC BY-SA 3.0). https://kanjivg.tagaini.net
