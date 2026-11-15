# Research and design rationale

This document records *why* Sumi works the way it does: what learners
struggle with in existing apps, what the learning-science and linguistics
research says, which UX principles were applied, and how each one maps to a
concrete decision in `Sumi.swiftpm/Sources/ContentView.swift`. It also lists the open
questions that only testing with real learners can answer.

---

## 0g. Revision 9 — ink, light and water: one bar, a menu, washes of colour and lines that draw themselves

The brief for this revision asked for the look to go much further — more
creative, more alive, "as if the whole thing were talking to you" — while
staying minimal and keeping to Apple's guidelines: line animations, soft
pastels, scroll-triggered detail, small toggles that make learning more
immersive, a clean pop-up menu, a pill-shaped navigation bar that offers
only what the moment needs, simple page transitions, and every effect
(glass, shadows, inner shadows, bloom, strokes) used with intent.

Revision 8 gave the app *light* — one ladder of surfaces. This one adds
*water*: things flow. The whole design is one sentence:

> Every screen is a sheet of washi with a wash of soft colour behind it;
> whatever is alive is written in ink; whatever floats is glass.

### Sources

Read for this revision, in addition to the books listed in §0f:

| Source | What it says | What it changed |
|---|---|---|
| Apple, [*Adopting Liquid Glass*](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [*Applying Liquid Glass to custom views*](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) | Glass is the functional layer above content; use it sparingly, on "the most important functional elements"; put custom glass shapes in one container so they render and morph together; half-height sheets are glass and inset; remove custom backgrounds from bars and sheets. | Glass appears in four places only (the bar, the menu, the ✕, the pill buttons). The bar's shapes share one `GlassEffectContainer`. The menu sets no background of its own on iOS 26. |
| HIG — [*Tab bars*](https://developer.apple.com/design/human-interface-guidelines/tab-bars) | "Use a tab bar to support navigation, not to provide actions"; keep labels; a tab bar can minimize as people scroll, with its accessory moving inline. | The places are always labelled and never hidden behind a menu. A screen's own controls appear only where the HIG puts a toolbar — on a pushed screen — and in the shape iOS 26 gives a minimized tab bar and its accessory. |
| HIG — [*Materials*](https://developer.apple.com/design/human-interface-guidelines/materials), [*Color*](https://developer.apple.com/design/human-interface-guidelines/color) | "Don't use Liquid Glass in the content layer." Colour on glass sparingly, for a primary action's background; "avoid using similar colors in control labels if your app has a colorful background"; never rely on colour alone. | Cards, tiles and rows stay paper. Only the one primary action in the bar is tinted. The washes are kept within a few percent of paper so ink and the indigo accent always read against them, and a level is always written as well as coloured. |
| HIG — [*Motion*](https://developer.apple.com/design/human-interface-guidelines/motion) | Motion with a purpose; brief; cancelable; "avoid adding motion to UI interactions that occur frequently"; never the only carrier of information. | Arrival animations run once per screen, never on a return visit; switching places is instant; every scroll effect is tied 1:1 to the finger, so it can be stopped or scrubbed back; Reduce Motion removes all of it. |
| HIG — [*Sheets*](https://developer.apple.com/design/human-interface-guidelines/sheets), [*Layout*](https://developer.apple.com/design/human-interface-guidelines/layout) | Support the medium detent "to allow progressive disclosure of the sheet's content"; include a grabber; one sheet at a time; order by importance, group, align. | The menu opens at half height with the three things most often changed and expands into the rest. |
| WWDC25 — *Meet Liquid Glass* (219), *Get to know the new design system* (356), *Build a SwiftUI app with the new design* (323) | Concentric shapes; capsules for controls near the edge of an iPhone; surfaces "emerge from their source"; a sheet can morph out of the button that presents it; primary actions separate and tinted; don't mix text and symbols in one group. | Capsules throughout the bar, the thumb concentric with its capsule (29 − 5 = 24 pt). The menu grows out of the 三 button (`matchedTransitionSource` + zoom). Save/Write share a capsule; Practice has its own, in the accent. |
| WWDC18 — *Designing Fluid Interfaces* | Motion starts from the current value, inherits velocity, can be interrupted; bounce only when a gesture carried momentum. | The bar and the switch use a spring with a little overshoot (`Motion.liquid`, 0.5 s, bounce 0.2) because glass that changes shape should read as a drop; everything else stays critically damped. |
| Nielsen Norman Group, [*Hamburger Menus and Hidden Navigation Hurt UX Metrics*](https://www.nngroup.com/articles/hamburger-menus/) (179 participants, 6 sites) | Hidden navigation cut discoverability by more than 20 %, was used in 57 % of mobile cases against 86 % for visible-plus-hidden, and made tasks 15 % slower on mobile. With four or fewer top-level links, show them. | The three places stay visible. The 三 button holds only what is secondary — settings, data, how it works — which is the case the study allows. |
| [Laws of UX](https://lawsofux.com) | Fitts, Hick, Jakob, Tesler, Von Restorff, goal-gradient, Zeigarnik, peak–end, Doherty threshold, common region, proximity, uniform connectedness, aesthetic–usability. | Mapped below, one decision each. |
| Valdez & Mehrabian (1994), *Effects of color on emotions*, J. Exp. Psych.: General 123(4) | Pleasure rises with brightness and (less) with saturation; arousal rises with saturation and falls with brightness. | Washes are bright and barely saturated — pleasant, low arousal. The only saturated colours left are vermilion ("forgot", the seal) and the accent, where attention is wanted. |
| Bar & Neta (2006), *Humans prefer curved visual objects*, Psych. Science 17(8); a 2025 *Journal of User Experience* study of rounded corners in a mobile app | Curved contours are preferred and read as safer; rounded interfaces are rated more attractive (the journal notes earlier work confounded curvature with other attributes). | Continuous corners everywhere, capsules for everything that floats; no sharp corner in the app. |
| Kurosu & Kashimura (1995); Tractinsky, Katz & Ikar (2000) | The aesthetic–usability effect: what looks good is judged easier to use — and forgiven more. | A reason to polish, and a warning: a beautiful screen can hide a usability problem from its own designer. Hence the tests at the end of this section. |
| Kivetz, Urminsky & Zheng (2006); Kahneman et al. (1993) | Effort increases as a goal nears (goal-gradient); an experience is remembered by its peak and its end. | The day seal and each level's rule show the distance left. The end of a session is designed: the seal, the amber light, the numbers rolling up. |
| [Colordic — 日本の伝統色](https://www.colordic.org/w) | The traditional palette with reference values: 桜 `#FEF4F4`, 洗柿 `#F2C9AC`, 月白 `#EAF4FC`, 白群 `#83CCD2`, 鳥の子 `#FFF1CF`, 藤 `#BBBCDE`, 白緑 `#D6E9CA`. | The washes are these hues thinned with paper (below). |

And from the books, the ideas that decided something this time:

- **Cooper, *About Face*** — *excise* is work that doesn't serve the goal.
  Reaching to the top corner for Save, or opening a menu to hear a text,
  was excise; those controls now sit where the thumb already is. Feedback
  stays modeless: the bar changes, nothing interrupts.
- **Colborne, *Simple and Usable*** — remove, organise, hide, displace.
  *Removed:* search on Read (five texts), the Save button in the kanji
  toolbar, the count block under the deck. *Organised:* the menu's rows
  by how often they're changed. *Hidden:* everything rare, one level down
  (the menu's lower half, the ellipsis). *Displaced:* a screen's controls
  into the bar.
- **Tidwell, Brewer & Valencia, *Designing Interfaces*** — Center Stage
  (one focal object), Visual Framework (one header, one rule, one bar on
  every screen), Titled Sections, Bottom Navigation, Touch Tools (controls
  that appear when their object is on screen), Filmstrip (the stroke-order
  strip), Responsive Disclosure, Hairlines, Few Hues Many Values.
- **Norman, *The Design of Everyday Things* / *Emotional Design*** —
  signifiers and mapping: nothing in the bar is an unlabelled icon, and a
  control sits next to what it changes. Visceral, behavioural, reflective:
  the wash and the paper; the springs and the bar that follows you; the
  seal, the ring and a library that visibly fills with ink.
- **Krug, *Don't Make Me Think*** — the trunk test: on any screen, where
  am I, where can I go, how do I get back? The title, the labelled bar and
  the back gesture answer all three; the level's colour answers the first
  a second way.
- **Johnson, *Designing with the Mind in Mind*** — we notice change in the
  periphery and read structure before words: the bar's change of shape is
  seen without being looked at, and sections are told apart by a numeral, a
  caption and a rule before a word of them is read. Responsiveness: 0.1 s
  for cause and effect — every control answers on touch-down.
- **Evans, *Bottlenecks*** — attention is the first bottleneck: one moving
  thing at a time. A screen never has an arrival, a scroll effect and a
  drifting wash competing; reading screens hold the wash still.
- **Weinschenk, *100 Things*** — people process information best as a
  story, and are moved by progress and mastery more than by reward. The
  kanji page is told in order — meet it, mean it, remember it, write it,
  use it, read it — and progress is shown as ink, not points.
- **Schwartz, *The Paradox of Choice*** — the menu's top half is three
  choices; Today is still one button.
- **Rosenberg, *UX Magic*** — design from the objects and the actions on
  them. The bar is literally that grammar: an object on screen (a kanji, a
  text), and beside it the verbs that apply to it.
- **Hall; Travis & Hodgson; Marsh; Buley; Gothelf & Seiden; Krug, *Rocket
  Surgery*; T. & D. Kelley** — decisions made by reasoning are hypotheses
  until five people have tried them. The ones this revision adds are at the
  end.

### What a UI element says before it's read

The brief asked for an analysis of the emotion each kind of element
carries. This is the reading the app is built on, with the evidence where
there is some and "practice" where there isn't.

| Element | What it communicates | Basis | In Sumi |
|---|---|---|---|
| Corner radius, capsules | Safe, soft, touchable; sharp corners read as hard and a little threatening | Bar & Neta 2006; JUX 2025 | Continuous corners on every surface; capsules for everything that floats |
| Light, unsaturated colour | Calm, pleasant, low arousal | Valdez & Mehrabian 1994 | The washes |
| Saturated warm colour | Urgency, attention | same | Vermilion only for "forgot" and the seal |
| One accent among neutrals | "This one is different — act on it" | Von Restorff | Indigo only on what can be acted on, and on what is alive |
| Soft, warm, top-lit shadow | A real object, lying there, liftable — trust | Norman (visceral); one light source (Evans) | Sheets; a pressed sheet's shadow tightens |
| Inner shadow | A recess: put something in | Norman (signifier) | Fields, the switch's track, tiles not yet started |
| Translucent glass | Light, floating, provisional — "above" rather than "part of" | HIG Materials | The bar and the menu only; text on it never lighter than ink2 |
| A line drawing itself | Something is being made, now, for you; anticipation | Gestalt continuity and common fate; practice | Rules, rings, the progress line, kanji |
| Spring with overshoot | Alive, elastic, playful | WWDC18; practice (little controlled evidence) | Only glass changing shape and things that were thrown |
| Critically damped motion | Calm, exact, dependable | same | Everything else |
| Slow drift | Stillness with life — a room, not a picture | practice; HIG warns against sustained oscillation, so it never repeats | The wash, 30 fps, a few percent of travel |
| Serif display type | Literary, warm, considered | practice | New York for titles and greetings |
| Rounded numerals | Friendly, approximate, countable | practice | SF Rounded for every count |
| A ring or bar filling | Nearness to a goal; pulls effort forward | goal-gradient; Zeigarnik | The day seal; a level's rule |
| A stamp at the end | Closure; "this is finished and it counted" | peak–end rule | The hanko |
| A labelled symbol | Certainty | Norman; HIG | Every item in the bar |
| A switch that slides | Control: immediate, visible, reversible | direct manipulation (About Face) | One sliding switch for every either-or |

### The bar

One floating bar holds only what the moment needs.

| Where you are | Leading | Trailing |
|---|---|---|
| The top of a place | The three places — symbol over label, the current one on an accent-tinted thumb | 三, the menu |
| Scrolled down, reading | The current place, as one circle | 三, as one circle |
| A kanji's page | The current place, as one circle (tap: the places return) | Save · Write in one capsule; Practice (or Learn next) in the accent |
| A text | The current place, as one circle | Listen · Furigana · English |
| Studying, onboarding, typing | Nothing — the bar is gone | |

- It is the *same object* in every state: the leading capsule narrows to a
  circle while the trailing one widens, on one spring, so the eye follows
  a change of shape instead of a swap (uniform connectedness, common
  fate). On iOS 26 both are Liquid Glass in one container; before, frosted
  material with a lit rim.
- Scroll direction is read with hysteresis — 22 pt of travel, and nothing
  within 28 pt of the top — so it never flickers under a resting thumb.
- Every item is a symbol *over* a label (HIG: include tab labels; Norman:
  signifiers), and each offers the system's large-content viewer, since a
  10-pt label can't grow with Dynamic Type.
- The menu button is three strokes of unequal length — the kanji 三,
  "three" — which even out under a finger.
- The system's own tab bar is still there underneath, hidden; the places
  keep their own navigation stacks, and tapping the current place goes
  back to its first screen, as a tab bar does.
- It sits 20 pt above the bottom edge, where iOS 26 puts its own, and
  leaves when the keyboard arrives.

### The menu

The pop-up behind 三 is a sheet at half height. Its top half is what is
changed in the middle of a session — appearance, furigana, typeface, sound
— and it scrolls or pulls up into pace, reminders, data, how Sumi works,
privacy and reset. Rows are plain titles on a tint of ink (no icon tiles,
as before); a group's footer explains it. On iOS 26 it is the system's
glass sheet and grows out of its button; earlier it is a sheet of the
app's own paper.

### Colour that means something

Colour is ambient, and it means one of two things, never both:

| Wash | When | Tints (thinned with paper) |
|---|---|---|
| dawn / day / dusk / night | Today, by the hour (5, 10, 16, 20) | persimmon and cherry over moon-white; pale blue and eggshell; amber falling to wisteria; wisteria and plum |
| focus | Studying | indigo mist gathering at the top |
| done | The day finished; a session's recap | amber settling at the bottom |
| read | The Read place | parchment |
| level | A level's kanji and texts; the library takes the level you're working on | N5 pale blue 白群 · N4 pale green 白緑 · N3 eggshell 鳥の子 · N2 cherry 桜 · N1 wisteria 藤 |

Every tint keeps a luminance above 0.8, so ink2 (the quietest text that
carries meaning) stays at 4.9:1 or better against the deepest of them and
the accent at 6.4:1. By night the same hues sit a few percent above black.
A change of wash is eased channel by channel over about two seconds
(`WashDriver`), so the hour turning, a session starting or a day ending is
a ramp and never a cut. A level is never *only* a colour: its chip always
carries its name.

### Lines that draw themselves

The subject of the app is writing, so the motif is the line being drawn.

| Line | When it draws |
|---|---|
| The top card of the deck on Today | Once for each new kanji that lands there |
| The glyph on a kanji's page | Once, in silence, when the page first opens (sound and haptics stay opt-in: Write, or hold) |
| The stroke-order strip (筆順) | A new section: the kanji built up one stroke per cell, the newest in the accent with a dot where the brush lands |
| A section's rule | From its leading edge, when its screen arrives and again as it scrolls into view |
| A level's rule | The same line is its progress: the known part in the accent |
| The day seal, coverage rings | Round, as they arrive |
| The session's progress line | Dry ink behind, a wet accent tip where the brush is |
| The line between question and answer | From its centre, on reveal |
| The forgetting curve in *How Sumi works* | Scrubbed by the scroll itself: forward as the page moves up, back as it moves down |

Sections on a kanji's page are numbered in kanji — 一 二 三 四 五 六 — and
the day seal carries the day's own kanji (日 月 火 水 木 金 土): seven of
the first characters anyone learns, met in use.

### Transitions

- A tile opens *into* its kanji and a row into its text, and each folds
  back to where it came from (the system's zoom transition, iOS 18 and
  later; a plain push before). One transition for every way in.
- Places switch instantly. Sheets and the study cover keep the system's
  own motion.
- Holding a library tile lifts a glance at the kanji out of it — glyph,
  meaning, readings, level — with the two things most often done to one
  (save; practice or learn next). It is the touch screen's hover: a look
  without a commitment, and the system's own context menu.
- The first time a screen appears its pieces settle in order, 80 ms apart,
  out of a 6-pt blur (`Arrive`). Never again on a return visit.

### The effects, re-budgeted

| Effect | Job | Where | Never |
|---|---|---|---|
| Liquid Glass / frosted glass | The floating layer | The bar, the menu, the ✕, the pill buttons | Content; glass on glass |
| Pastel wash | The hour, or the level | Behind every screen | Text, controls, sheets |
| A drawn line | "This is being written" | The table above | Decoration with no referent |
| Bloom | "This is alive" | The seal as it closes, the prominent button, wet ink (a stroke, the progress tip) | Anything static |
| Scroll reveal (rise out of a blur) | Arrival of a small thing | Rows, tiles, note lines, strip cells | A whole section — a tall block dimmed until it is fully on screen reads as a fault |
| Arrival stagger | First meeting | Today, the menu | Return visits; tab switches |
| Two-layer shadow, lit edge, inner shadow, grain, vignette, tilt | As in §0f | As in §0f | As in §0f |

### How it is checked

The code is written without a Mac, so a change is pushed to a `try/…`
branch first. There the workflow compiles it for the device and also runs
it in an iPhone simulator, opening it on each screen in turn with sample
progress (`Showcase`, driven by an environment variable only a simulator
can set) and photographing it in light and dark. Layout, colour and
legibility can be judged on those pictures; motion, haptics and sound
cannot be, and are the first things to look at on a device. The palette
itself was checked by rendering every wash, light and dark, with sample
ink, a sheet and the bar on top.

### What only testing can settle

- **H4 — finding the places again.** From a kanji's page, five people are
  asked to go to Read. If fewer than four tap the circle within five
  seconds, the places stay visible on pushed screens and the controls move
  above them.
- **H5 — 三 as a menu.** A first-click test: "change the appearance". If
  the first tap isn't the three strokes for four of five, it becomes the
  conventional three equal lines.
- **H6 — the washes.** As H2: asked afterwards, people shouldn't be able
  to say the colour changed, but should rate a session started at dusk and
  one started at noon as equally easy to read.
- **H7 — kanji numerals.** Beginners shouldn't mistake 一 二 三 for content
  to learn. If anyone asks what they are, they become plain numerals.
- **H8 — the strip.** Do people run a finger along the stroke-order strip,
  or is Write enough? If it goes unused in five sessions, it is removed.

## 0f. Revision 8 — one ladder of light: colour, space, hierarchy and the effects, budgeted

The brief for this revision was the look itself: the best colours and
spacing for the eye, hierarchy, Gestalt, alignment, and a confident use of
depth — glass, shadows, inner shadows, strokes, bloom — that still reads as
minimal. The method was to go back to the literature on perception and
interface design, extract what is actually actionable for a card-based
learning app, and then give every effect a job and a budget.

### What the literature says, and what it changed

| Source | Principle | What it changed in Sumi |
|---|---|---|
| Johnson, *Designing with the Mind in Mind* (ch. 2–4) | We see structure before content: proximity, similarity, common region and figure/ground organise a screen before a word is read. Colour vision is limited — small differences in hue or saturation are hard to see; differences in *lightness* are not. | Surfaces are told apart by lightness alone, on one ladder (page, sheet, well), never by hue or by a border. Groups are 8 pt apart inside and 24–32 pt apart between, so grouping is done by space before any line is drawn. |
| Evans, *Bottlenecks* (attention, perception) | Foveal acuity covers about two degrees; everything else is seen in low resolution. Depth is read from shadow, occlusion and relative size, and the eye assumes one light source from above. | One focal object per screen at the fovea — the kanji, the deck, the seal — with every other element lower in contrast. Every shadow, lit edge and inner shadow assumes the same light from above, so the whole app is one scene. |
| Weinschenk, *100 Things Every Designer Needs to Know About People* | Peripheral vision decides where the eye goes next; people see in patterns and identify things by shape; working memory holds three or four items; stories are remembered. | A 4 % vignette keeps the eye in the middle of the page; the ribbon, the badge and the seal are shapes, not words; one primary action per screen; onboarding is a story told in the app's own gesture. |
| Norman, *The Design of Everyday Things* | Affordances need signifiers; the physical world is the metaphor people already have; feedback must be immediate and proportionate. | Light along a sheet's top edge signifies "this lies on the page and can be lifted"; an inner shadow signifies "this is a recess you can put something into" (fields, the word list). The ring blooms when it closes; the prominent button blooms because it is the one live thing. |
| Krug, *Don't Make Me Think* | Make it obvious; create a clear visual hierarchy; keep conventions; omit needless words. | One section-header component (a caption and a count on one baseline) is used in exactly the same place and size on every screen, so it is learned once. |
| Colborne, *Simple and Usable* | Remove, organise, hide, displace. Simplicity is a budget, not an absence. | Every effect has a list of where it is allowed and where it is not (table below). Bloom appears in three places in the whole app, so it still means something. |
| Tidwell, Brewer & Valencia, *Designing Interfaces* | "Few hues, many values"; titled sections; a card stack and a thumbnail grid are patterns people already read. | One hue family (warm paper and ink) with a single accent; everything else is a value of the same warm grey. The library grid encodes progress in the tile's depth, not in a legend. |
| Cooper et al., *About Face* | Reduce excise; prefer modeless feedback; a sovereign posture for the main task, a transient one for the rest. | Study is a full-screen, chrome-free sovereign screen; Settings is a transient sheet. The ring, the combo and the badge are modeless. |
| Schwartz, *The Paradox of Choice* | More options cost more than they give. | Still one button per screen; the rest state offers at most three quiet ones. |
| Rosenberg, *UX Magic*; Hall, *Just Enough Research*; Travis & Hodgson; Marsh; Buley; Gothelf & Seiden | Name things by what they are; test the assumptions you can't reason out. | The three hypotheses at the end of this section are written as tests, not decisions. |
| Norman, *Emotional Design*; Bar & Neta (2006) | Visceral, behavioural and reflective layers; people prefer curved forms. | Visceral: warm paper, soft light, continuous corners. Behavioural: springs that inherit the finger. Reflective: the hanko, the saved collection, the ring closed for the day. |
| Apple HIG — *Materials*, *Color*, *Dark Mode*, *Typography*, *Layout*; WWDC25 *Meet Liquid Glass*; WWDC20 *The details of UI typography* | Liquid Glass belongs to the navigation and control layer, never to content, and takes colour sparingly. In dark mode, surfaces lighten as they rise. Tracking is set per size. Group, align and space before you decorate. | Glass only on the ✕ and the pill buttons (tinted indigo for the prominent one), never on a card. Dark mode inverts the ladder: black page, a lighter sheet, a darker well. Display type closes up (−0.7 pt), captions open out (+1.1 pt), body is untouched. |

### The ladder of light

Every surface is a step on one ladder, and the steps are a few percent of
lightness apart — enough for the eye to read "lying on" and "pressed in"
without a border, not enough to notice as colour.

| Token | Light | Dark | What it is |
|---|---|---|---|
| paper | `#F6F3EC` | `#000000` | The page |
| card | `#FFFEFB` | `#1B1A18` | A sheet lying on the page (cards, rows, tiles once started) |
| surface | `#F0ECE3` | `#262523` | A raised control (chip, pill) |
| well | `#EFEBE2` | `#0F0F0E` | A recess: fields, the word list, tiles not yet started |
| fill / fill2 | ink at 6 % / 10 % | white at 8 % / 13 % | Translucent ink for small fills, so they work on any step |
| edge | ink at 8 % | white at 10 % | The hairline round every sheet and well |
| edgeLight | white at 90 % | white at 14 % | The light along a sheet's top edge |
| shadow | `#3A2C1C` | `#000000` | Shadows carry the paper's warmth by day |
| ink / ink2 / ink3 | `#1E1C19` / `#67625A` / `#968F83` | `#F3F0E9` / `#A8A399` / `#7A766F` | Three steps of text; ink3 only for glyphs that are never the only cue |
| accent 藍 | `#2D4F9E` | `#9DB3EE` | The one colour that means "act on this" |
| accentDeep | `#24418A` | `#7D97DC` | The base of a filled control |

Contrast, light: ink2 on paper 5.5:1, accent on paper 7.0:1, white on
accent 7.7:1. Dark: ink2 on card 6.9:1, accent on card 8.4:1. Increase
Contrast swaps every pair for a deeper one.

By day the ladder descends into the paper; by night it inverts — the page
is black and a surface lightens as it rises — which is what the HIG asks
of dark mode and what a lamp does to real objects. Shadows are the colour
of the paper's own shade rather than grey, so they never go muddy.

### Space, alignment and rhythm

- A 4-pt grid with one rhythm everywhere: 8 inside a group, 12 between
  related rows, 24 between groups, 32 between sections, 48 to the end of a
  screen. Page margin 20; sheet padding 20.
- One alignment axis per screen. Reading screens (Kanji page, Read,
  Settings) are left-aligned and scan as an F; stage screens (Today, the
  study card, the recap, onboarding) are centred on their one focal object.
- Section headers sit on a 4-pt inset so the caption's first letter aligns
  optically with the text inside the sheet below it (a sheet's hairline is
  drawn 1 pt outside its content).
- The primary action stays in the thumb's zone and is capped at 420 pt on
  iPad, as the HIG asks (*avoid full-width buttons*).
- Radii are concentric with the device: 10 chips, 14 controls, 16 wells,
  18 tiles, 24 cards, 32 sheets.

### Hierarchy

Five levels, each one step down in size *and* one step quieter in colour,
never both bold and large at once:

1. Display — New York, tracking −0.7 (the large titles, "All done", a
   kanji's meaning).
2. Title — New York, tracking −0.3 (section titles, the answer on a card).
3. Body — San Francisco, ink.
4. Secondary — San Francisco, ink2 (readings, hooks, counts).
5. Caption — small capitals, tracking +1.1, ink2 (what a card asks, a
   section's name).

Numbers are set in SF Rounded with tabular figures so they roll without
jittering.

### The effects, budgeted

Each effect has one job, a list of places, and a list of places it must
never appear. That is what keeps a screen with shadows, strokes, inner
shadows, bloom and glass reading as quiet.

| Effect | Job | Where | Never |
|---|---|---|---|
| Two-layer shadow (contact + ambient, warm) | "This lies on the page" | Every sheet: cards, rows, tiles once started, the deck, the hero | Text, icons, wells |
| Lit top edge over a hairline | "This can be lifted" | Every sheet | Wells — a recess has a plain rim, because light lands on what rises |
| Inner shadow | "This is a recess" | Fields, the word list on a lesson card, tiles not yet started, the mark's well in Settings | Sheets |
| Bloom | "This is alive" | The ring as it closes, the prominent button, the wet stroke being written | Static text; more than three places |
| Liquid Glass (iOS 26) | The floating control layer | The ✕, the pill buttons (the prominent one tinted indigo), the system bars | Cards or any content (HIG) |
| Paper grain | "This is paper" | The deck, the hero sheet, the study card (at 45 %), the learned mini-cards | Controls, wells, text |
| Mood tint | Context, felt not seen | Indigo gathering at the top during study; amber settling at the bottom when the day is done; 1.4 s ramp | More than 10 % |
| Vignette | Keeps the eye in the middle | 4.5 % at the edges by day; none by night | — |
| Tilt and sheen | Depth you can feel | The deck on Today, the hero on a kanji page | The study card — a card that leans while you read it is a distraction |

Before iOS 26 the prominent pill is lit from above, deepens toward its
base and blooms onto the page; on iOS 26 it is tinted glass, and the quiet
pill is clear glass. The tab bar minimises as you scroll a list on iOS 26,
as the system's own apps do.

### Dark mode

The ladder inverts; the grain inverts (white specks on black); the lit edge
drops to 14 %; shadows go black and deeper, because a shadow on black needs
more to read; bloom reads as a glow because it is composited additively.
Reduce Transparency makes the glass solid; Increase Contrast deepens every
text pair.

### What only testing can settle

- **H1 — depth as progress.** Five learners, Krug-style, are asked what
  the difference between a raised tile and a pressed one means. If fewer
  than four say "learned / not yet" unprompted, the tiles need a legend.
- **H2 — the mood tint.** Asked after a session whether anything about the
  background changed, learners should say no; asked whether study felt
  focused, they should say yes. If the tint is noticed, it is too strong.
- **H3 — the lit edge.** Stills with and without the edge, shown in random
  order: the edge should be preferred as "higher quality" without being
  named. If it is named, it is too strong.

## 0e. Revision 7 — navigation people already know, cards worth looking at

Device testing after revision 6 found four things: saved and liked cards
showed only a vague translucent blob at the top; sideways swipes rarely
registered; the app was hard to find your way around; and the cards, the
animations and the settings screen didn't look like one app. This revision
takes each back to first principles.

### Navigation: the task flows, then the structure

A casual learner has four tasks, in this order of frequency: do today's
cards; look a kanji up; read something; revisit the kanji they've kept.
The previous structure hid two of them behind a grid icon on Home and a
third inside a segmented control inside that, and offered the first only
as a gesture on a line of text. Measured against the usual guides:

| Principle | Source | What was wrong | What changed |
|---|---|---|---|
| Jakob's law — people spend most of their time in other apps and expect yours to work the same | Nielsen | A grid icon for "Library", a gesture for "start" | A bottom tab bar — Today · Kanji · Read — the one iOS navigation every user already knows (HIG, *Tab bars*) |
| Recognition over recall | Nielsen heuristic 6 | Sections had to be remembered | Every top-level place is always visible, named and iconed |
| Fitts's law and reachability | HIG, *Layout* | Primary actions at the top, or nowhere | Tabs and the one primary button (Review / Learn / Done / Begin) sit in the thumb's zone at the bottom |
| Hick's law — decision time grows with choices | — | Library mixed kanji, saved and texts | Three tabs, each with one job; Saved is a filter inside Kanji |
| Visibility of system status | Nielsen heuristic 1 | A bare progress line | "12/23" beside the line, the combo in its place when there is one, a ring on Today that fills as the day is done |
| User control and freedom | Nielsen heuristic 3; HIG, *Modality* | Study could only be left by pinch or pull | A visible ✕ on the study screen; pinch and pull remain as shortcuts |
| One primary action per screen | HIG, *Designing for iOS* | A shimmering text line as the only affordance | A filled pill button; the swipe-up and the tappable deck stay for people who'd rather not aim |
| Consistency and standards | Nielsen heuristic 4 | Settings used system grey, Home used paper | Every screen shares the same paper, sheets, type and controls (below) |

Study stays a full-screen modal — the HIG's reserved case for a focused
task that shouldn't be interrupted — and the cards stay button-free; a
dismiss control is navigation, not an action on the card.

### Why the sideways swipes failed

The swipe locked to an axis on its very first sample, about ten points in.
A thumb beginning a sideways swipe moves in an arc, so that first sample
was often more vertical than horizontal and the swipe became a short
vertical drag. The lock now waits until the finger has moved fourteen
points and judges the direction then — the same hysteresis UIScrollView
uses for its directional lock.

### What a saved or marked card shows

Translucent chips over a card read as smudges; they carried no metaphor.
Each state now has a signifier with a real-world referent:

- **Saved** — a bookmark ribbon hangs from the card's top edge, as a
  ribbon hangs from a page. It slides down when a card is saved and
  withdraws when it isn't.
- **Forgot** / **Easy** — a small tinted badge top right ("Forgot" in
  vermilion, "Easy" in sakura), the way iOS marks state on a list row.
- **The action behind the card** — pushing the card right uncovers a
  vermilion panel with the Forgot icon; pushing it left uncovers an indigo
  Save panel, as in Mail. The icon grows and the colour deepens at the
  commit point, and a tick confirms it.

### The card, rebuilt

The card is now a clean sheet — card colour, a hairline edge, two soft
shadows — with nothing drawn on it that isn't information. Grain, tilt,
sheen and the finger glow were removed from study cards: textures compete
with ideographs, and a card that leans while you read it is a distraction.
The layout follows the reading order a learner needs:

```
MEANING ·························· [Forgot]   ← what's asked / what's marked (12 pt caps, tracked)
                                   ⌐ ribbon
              日                              ← the kanji, optical centre (≤ 200 pt)
            Day, sun                           ← New York, title (28 pt), semibold
           ニチ・ジツ　ひ                        ← Hiragino 17 pt, secondary
   A hook, one or two lines, line height 1.4   ← callout 16 pt, secondary
                                 Swipe up for next   ← footnote 13 pt, tertiary
```

Groups are separated by 24 pt and lines within a group by 8 pt (proximity
tells the eye what belongs together); the column is centred and capped at
380 pt so lines stay around 35 characters; each level of the hierarchy is
one step down in size *and* one step quieter in colour (ink, ink2), never
both bold and large at once. Every line has a limit and a minimum scale,
and the card's content is capped at accessibility size 2, so nothing can
spill. Writing cards are gone: they slowed the flow for everyone and the
stroke animation already shows the strokes.

### Animation

- Page turns: the spring's starting velocity is the finger's, relative to
  the distance left, capped at 6 — a card released near the edge used to
  shoot. The turn runs 0.42 s, critically damped.
- The deck: a fourth, invisible card now fades in from below as the deck
  rises, so a new card never pops into the bottom of the stack.
- Settle and flick springs keep 0 and 0.15 bounce; controls answer a touch
  in 0.22 s with no overshoot.
- Reveal: the answer materializes from a blur; the glyph eases to 66 % and
  up in the same spring, so the two motions read as one.
- Reduce Motion: every slide becomes a crossfade, as before.

### One system for every screen

Paper (`#F6F3EC` / black) everywhere; sheets in card colour with a
hairline edge; captions as tracked small caps; New York for display lines,
San Francisco for everything else, SF Rounded for numbers; the same pill
buttons; separators and fills from the same warm palette. Settings moved
from the system grouped grey to the same paper and sheets, lost its icon
tiles (nothing else in the app has them), and gained plain row titles.

## 0d. Revision 6 — touch that works, a lesson that makes sense, a ring to close

Testing on the device showed the gestures failing most of the time, and
the flow of a lesson feeling arbitrary. This revision fixes the first at
its root, straightens the second against the research in sections 2–3, and
adds the one piece of gamification that was still missing.

### Why the gestures failed

The card stacked five SwiftUI gesture modifiers on one view: a zero-distance
drag for the finger glow, the page drag, a double-tap, a single tap and a
long press. SwiftUI arbitrates such a stack by position and precedence
rather than by intent, and the result is fragile: a drag that recognizes at
zero distance can claim the touch before a tap or a hold has a chance, a
double-tap can delay or swallow the single tap, and the behaviour has
changed between iOS releases. The fix is to recognize touch the way the
system's own apps do — with UIKit's gesture recognizers, whose
disambiguation is explicit and deterministic (`GestureSurface`):

| Gesture | Recognizer | Rule |
|---|---|---|
| Tap | `UITapGestureRecognizer` (1) | Acts immediately — no waiting for a possible double-tap, as in Instagram, where a single tap never lags |
| Double-tap | `UITapGestureRecognizer` (2) | Allowed to recognize *together* with the single tap; the second tap of a double is filtered out by time, so the first tap has already revealed and the double marks Easy |
| Hold | `UILongPressGestureRecognizer` | 0.3 s within 12 pt; once it begins, a pan can't start (hold wins), and lifting ends it |
| Swipe | `UIPanGestureRecognizer` | One finger, the system's 10 pt hysteresis, then locked to an axis; once it begins, taps and the hold fail |
| Pinch | `UIPinchGestureRecognizer` | May run alongside a pan; the pan then yields |
| Pointer | `UIHoverGestureRecognizer` | Lights the card under the iPad pointer, never blocks |
| Press | raw touches | Finger down/up for the card's own feedback, whatever the touch becomes |

Translation and velocity are measured on screen rather than in the card,
so a card moving 1:1 with the finger doesn't zero its own drag. The surface
is a clear view over the card; it reports what the fingers did, and SwiftUI
decides what it means. Home uses the same surface; onboarding, the recap
and the kanji page keep SwiftUI's own gestures, which are simple enough
there (one drag, or a double-tap and a hold).

The tilt is also switched off while a finger is on a card, so a hold is
never jogged by the card moving under it, and motion updates run only for
the card on top.

### The lesson, as expanding retrieval

Before, a lesson taught all five kanji and then quizzed them, so the first
retrieval of the first kanji came five pages later and often failed — the
opposite of what the testing-effect literature recommends (an early,
*successful* retrieval, then growing gaps; Karpicke & Roediger 2007;
Roediger & Karpicke 2006). The session now weaves pages and checks:

```
New 日 · New 月 · Check 日 · New 火 · Check 月 · Check 日(reading) ·
New 水 · Check 火 · Check 月(reading) · New 金 · Check 水 · Check 火(reading) ·
Check 金 · Check 水(reading) · Check 金(reading)
```

Each kanji is recalled one page after it's shown (meaning), then again a
little later (reading), with other kanji in between (interleaving, Rohrer &
Taylor 2007). Checks are labelled *Check · Meaning*, so a card about a
kanji seen a moment ago reads as what it is. The scheduler's learning steps
are unchanged: a check passed in the lesson comes back after about four
hours, then FSRS takes over.

### Context as feedback

Reviews used to insert a sentence page after every seventh card. Now the
sentence appears *right after a miss* — the kanji at work, while the
correction is fresh (elaborative feedback; Butler, Godbole & Marsh 2013) —
with the card itself returning a few cards later, and otherwise only after
a run of ten first-try successes, for variety and input. Each kanji's
sentence appears at most once per session.

### The ring

Sailer & Homner (2020) find that what helps learning is feedback and
visible competence; what learners resent is loss (streaks, lives). Apple's
Activity rings are the clearest example of the first without the second:
a goal to close, nothing to lose. Home now carries a small ring beside the
date that fills as the day's cards are done (`todayProgress`), and the rest
state says what the day held — "23 answered · 5 new kanji today". The
recap's closing line becomes "That's everything for today." when nothing
is left. The combo, the heart and the saved collection stay; there are
still no streaks, lives or leaderboards.

### For power users and for everyone

The same surface serves both: a general user taps and swipes up, and the
first five cards teach one gesture each; a power user double-taps for
Easy, swipes left to build a collection, types readings, picks a voice,
and drives everything from a hardware keyboard. Nothing is added to the
screen for either.

## 0c. Revision 5 — the look: ink on washi

Revision 4 settled how the app moves. Revision 5 is about how it looks. The
brief asked for a much more visual, modern Apple aesthetic, with ideas from
immersive websites (2.5D stacked cards, pointer effects, WebGL light,
scroll storytelling, 3D carousels, an animated logo). Each idea is
translated into what iOS does natively, and kept only where it serves the
task.

**One material idea, everywhere.** Everything is paper. The page is washi:
warm off-white `#F6F3EC` by day and true black by night. Cards, tiles and
sheets are a lighter sheet `#FFFEFB` lying on it, each with a faint grain,
a one-pixel edge (a shadow line by day, a lit edge by night) and two
shadows: a tight contact shadow and a wide ambient one. Gestalt does the
rest: *common region* groups what belongs together on one sheet;
*figure–ground* is a sheet on the page; the stack's *continuity* tells you
there's more beneath.

| Website idea | What it became on iPhone | Where |
|---|---|---|
| 2.5D stackable cards | The study feed is a deck: the next two cards peek out beneath the top one, and the deck rises as the top card lifts away | Study |
| 3D tilt and light tracing | Cards lean up to 3.5° with the phone (Core Motion, measured from how you hold it) and a sheen slides across them | Study, Home, kanji page |
| Cursor glow and hover states | A soft light follows the finger on a card; on iPad the pointer gets lift and highlight hover effects | Study, Library, kanji page |
| WebGL ambient background | A slow ink wash: a mesh gradient on iOS 18, hand-drawn radial clouds before, both still under Reduce Motion | Home, study, recap, onboarding |
| Scroll storytelling | Onboarding is four pages you swipe up through: 墨 writes itself, a forgetting curve draws as its page arrives, the gestures arrive one by one | Onboarding |
| Scroll-triggered reveals | Library tiles rise and sharpen as they scroll in (`scrollTransition`); the kanji page's hero recedes as you scroll past it (`visualEffect`) | Library, kanji page |
| 3D carousel with ramps | Daily pace is a horizontal wheel: the centred number is chosen, the rest turn away in 3D, shrink and blur | Onboarding |
| Animated logo | The 墨 mark writes itself stroke by stroke from KanjiVG paths, the wet stroke in indigo with a bloom | Onboarding, Settings, About |
| Glassmorphism | Liquid Glass (iOS 26) for chips, pills and swipe badges only; before iOS 26 a frosted material with a lit edge | Floating controls |
| Skeuomorphism | Restrained: paper grain, the 田 practice grid, a hanko seal. No leather, no stitching | Throughout |
| Neumorphism, Bauhaus | Not used. Neumorphism's low-contrast edges fail accessibility; a Bauhaus grid fights the quiet, centred study screen | — |
| WebGL 3D room, custom cursors | Not used. No iPhone equivalent that helps a learner, and a 3D room would compete with the one thing on screen | — |

**Typography.** San Francisco for text, so Dynamic Type, optical sizes and
tracking come from the system. New York (Apple's serif) for a few display
lines — the meaning of a kanji, page headlines, the recap — gives an
editorial voice that suits ink and paper. SF Pro Rounded for numbers you
read at a glance (the review count, combo, stats) — the same mix Apple uses
in Fitness and Books. Japanese stays in Hiragino, with looser leading
wherever furigana can appear. Captions are small caps with tracking that
opens as they get small. Every long line has a line limit with
`minimumScaleFactor`, and the study card's content is capped at
accessibility size 2 so it can never spill off the card.

**Color.** Warm greys instead of neutral ones, so text sits *in* the paper.
Every text pair keeps at least 4.5:1 contrast (WCAG AA), and Increase
Contrast deepens all of them. Indigo marks what can be acted on, vermilion
only means Forgot, matcha only Right, sakura only Easy. Dark mode is true
black (OLED, and calm at night), with cards one step up so the deck stays
visible.

**Layout and scanning.** Study cards are centred on a vertical axis: the
eye lands on the glyph, drops to the answer, and finds the gesture hint at
the bottom. Reference pages (the kanji page, reading texts) are
leading-aligned for top-to-bottom scanning: label, value, label, value.
Corner radii are concentric with the display's corners (WWDC25, *Get to
know the new design system*), and every tappable element is at least 44 pt.

**Settings looks like Settings.** Grouped sections with colored icon tiles,
an account-style header with the mark and your progress, and a footer that
explains each section. A new Appearance option offers Automatic, Light or
Dark.

**Motion for the new pieces.** Sheets materialize from a blur rather than
just fading. Numbers roll (`numericText`) and symbols bounce or swap
(`symbolEffect`). The swipe badges fill with color at the commit point, the
heart pops with a spreading ring, and the hanko stamps. All of it uses the
same springs as revision 4, and Reduce Motion replaces it with fades.

**Performance.** Grain is rendered once into a small tile that repeats.
Device tilt runs only while a tilting view is on screen. The ink wash is
capped at 30 fps. Home works out what's due once per minute and redraws
only the deck while you drag.

**Known limits.** The mesh-gradient wash needs iOS 18, and Liquid Glass
needs iOS 26 and a Swift 6.2 toolchain; both fall back automatically. None
of this has been compiled yet (see Verification status in the README).

## 0b. Revision 4 — no buttons, and an Apple feel

Revision 3 put a Reels-style rail of buttons beside every card. Revision 4
removes it: the page is the only control. This revision's gesture map
replaces the one in 0a.

| Gesture | Action | Why this gesture |
|---|---|---|
| Tap | Reveal; then hear it again | HIG: tap activates; tap to play |
| Swipe ↑ | Next (counts as known) | Reels, TikTok, Shorts: up = next |
| Swipe ↓ | Previous, its answer undone; on the first card, close | Down = previous; pulling a photo down dismisses it |
| Swipe → | Forgot | A swipe action, as in Mail; one deliberate movement for the rarer outcome |
| Swipe ← | Save for later | A swipe action, as in Mail ("flag for later") |
| Double-tap | Easy (a heart); on a new kanji, "I already know this" | Double-tap = "like": this one is effortless |
| Hold | Stroke order and sound together | Pressing a Live Photo plays it |
| Pinch in | Close | Pinching a photo closed |

**Easy comes back.** Revision 2 cut grading to pass/fail to remove a
decision from every card. That stays true: doing nothing extra still means
*Good*. Double-tap adds FSRS's *Easy* grade only when it's effortless, so
the cost of the extra option is paid only by someone who wants it, and
FSRS uses it to stretch that card's next interval.

### What makes an interface feel like Apple made it

Studying Apple's own design talks and guidelines, the "feel" comes from a
handful of properties that combine. Each is applied here:

| Property | Apple's source | In Sumi |
|---|---|---|
| **Response** — feedback the instant a finger lands | *Designing Fluid Interfaces* (WWDC18) | The card dips (98%) on touch-down; drags track 1:1 from the first point |
| **Springs, not curves** — motion described by duration and bounce, critically damped by default, bounce only after momentum | *Animate with springs* (WWDC23) | `Motion.settle` (bounce 0), `Motion.flick` (0.2) after a released drag, `Motion.reveal` (0.08) |
| **Velocity handoff** — the animation starts at the finger's speed, so there is no seam between dragging and animating | WWDC18; WWDC23 | Page turns use `interpolatingSpring(initialVelocity:)` with the release velocity relative to the distance left |
| **Momentum projection** — decide by where a flick is going, not where it let go | WWDC18 sample code | `Motion.project` (UIScrollView's deceleration formula) decides every swipe |
| **Rubber-banding** — resist progressively at boundaries instead of stopping dead | WWDC18; UIScrollView | Apple's curve `(x·d·c)/(d + c·x)`, c = 0.55, on unavailable directions and past side-swipe limits |
| **Spatial consistency** — things leave the way they came | WWDC18 | The session rises on the swipe up that starts it; the first page pulled down falls back into Home; recap and onboarding lift away upward |
| **Depth** — what's underneath recedes, dims and rounds, as with stacked sheets | iOS sheet presentation | The outgoing page scales to 92%, dims and takes the display's corner radius while the next slides over it |
| **Haptics with meaning** — causality, harmony, utility; system patterns used by their documented meaning | HIG *Playing haptics*; *Designing Audio-Haptic Experiences* (WWDC19) | Selection tick at commit points, soft detent on page landing, notification success only for real milestones; Core Haptics patterns for strokes, heart, forgot, save — each started on the frame of its visual |
| **Materials for the functional layer only** | *Meet Liquid Glass* (WWDC25); HIG *Materials* | Glass on the floating status chips and the combo chip, never on the content |
| **The best voice available** | AVSpeechSynthesizer voice quality | Premium, then Enhanced, then default Japanese voice; a picker lists what's installed and plays each when chosen |
| **Audio etiquette** | HIG *Playing audio* | Automatic speech is ambient (honors Silent, mixes with music); speech you ask for plays and ducks other audio |
| **Restraint** | HIG; "utility" in WWDC19 | No sounds of our own, no confetti; the one celebratory moment (the heart) is tied to a real judgment |
| **Accessibility as part of the feel** | HIG *Accessibility*, *Motion* | Reduce Motion turns every slide into a crossfade and stops the shimmer; every gesture is a VoiceOver action; the hidden keyboard keys cover all of them |

### Gestures without buttons — the trade-off, handled

The HIG warns that custom gestures are hard to discover and asks for more
than one way to do things. Hiding every control trades discoverability for
calm, so the cost is paid back three ways:

1. **Familiar vocabulary first.** Swipe up and tap need no teaching; the
   first screen of the app (*Swipe up to begin*) is itself the first lesson,
   and Home uses the same gesture.
2. **One gesture per card, once.** The first five cards each carry one line —
   *Swipe up for next*, *Forgot it? Swipe right*, *Knew it instantly?
   Double-tap*, *Swipe left to save · hold for strokes and sound*, *Pinch to
   close* — then disappear for good (Krug: teach in context, then get out of
   the way). Swipe hints shimmer like the old *slide to unlock*.
3. **Other ways in.** VoiceOver users get named actions (Next, Forgot, Easy,
   Save, Previous, Play stroke order and sound, Close) and the escape
   gesture; keyboard users get Space/Return, the arrows, E, P and Esc;
   *How Sumi works* lists every gesture.

Swipes that would do nothing resist and spring back, and side swipes show
the action they will take before you let go, so a gesture never has a
surprising result.

### Known limits of this revision

- A page turn in flight (about 0.4 s) can't be grabbed and reversed —
  SwiftUI's completion-based page swap ignores input until it lands. Apple's
  ideal is full interruptibility.
- The hold-to-play haptic pattern plays each stroke once while the
  animation loops; it stops when the finger lifts.
- iPad has no Taptic Engine, so Settings hides the Haptics switch there.
- Liquid Glass needs the iOS 26 SDK; on older toolchains the same chips use
  a thin material.

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
| paper 和紙 | `#F6F3EC` | `#000000` | The page — warm by day, true black by night |
| card | `#FFFEFB` | `#1B1A18` | A sheet lying on the page (lighter than the page in dark mode) |
| well | `#EFEBE2` | `#0F0F0E` | A recess pressed into a surface |
| ink 墨 | `#1E1C19` | `#F3F0E9` | Primary text |
| ink2 | `#67625A` (≈5.5:1 on paper) | `#A8A399` (≈6.9:1 on card) | Secondary text |
| accent 藍 | `#2D4F9E` (≈7.0:1 on paper) | `#9DB3EE` | Actions, focus, highlighted kanji |
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
- Continuous-corner radii: 10 (chips), 14 (controls), 16 (wells), 18
  (tiles), 24 (cards), 32 (sheets). Rounded forms are preferred to sharp
  ones and read as approachable (Bar & Neta 2006).
- Sheets carry a hairline, a lit top edge and two warm shadows; wells an
  inner shadow (see section 0f for the full ladder and the effects budget).
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

Springs described by duration and bounce (critically damped by default,
a little bounce only after a released drag), page turns that inherit the
finger's velocity, a shake for "try again", a stamp for completion. Reduce
Motion swaps every slide for a crossfade. Haptics follow the system's
meanings plus a few Core Haptics patterns (strokes, heart, forgot, save) —
all optional. Details in section 0b.

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
- Stroke order animates from KanjiVG (CC BY-SA 3.0), but there's no
  handwriting recognition — writing is self-checked against the animation.
- Speech uses the best installed Japanese system voice, fed kana so it
  never misreads kanji. Premium and Enhanced voices must be downloaded by
  the learner in Settings › Accessibility › Spoken Content.
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
- Apple — Designing Fluid Interfaces (WWDC18). https://developer.apple.com/videos/play/wwdc2018/803/
- Apple — Animate with springs (WWDC23). https://developer.apple.com/videos/play/wwdc2023/10158/
- Apple — Designing Audio-Haptic Experiences (WWDC19). https://developer.apple.com/videos/play/wwdc2019/810/
- Apple Human Interface Guidelines — Playing haptics. https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Apple Human Interface Guidelines — Materials. https://developer.apple.com/design/human-interface-guidelines/materials
- Apple — Meet Liquid Glass (WWDC25). https://developer.apple.com/videos/play/wwdc2025/219/
- Apple — Applying Liquid Glass to custom views. https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- Apple Developer Documentation — AVSpeechSynthesisVoice and voice quality. https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice
- Apple Design Resources. https://developer.apple.com/design/resources/
- Apple Developer Documentation — SwiftUI animations. https://developer.apple.com/documentation/swiftui/animations
- Apple — Beyond scroll views (WWDC23): `scrollTransition`, `visualEffect`, `scrollTargetBehavior`. https://developer.apple.com/videos/play/wwdc2023/10159/
- Apple — Create custom visual effects with SwiftUI (WWDC24): mesh gradients and visual effects. https://developer.apple.com/videos/play/wwdc2024/10151/
- Apple — Get to know the new design system (WWDC25): concentric shapes and Liquid Glass hierarchy. https://developer.apple.com/videos/play/wwdc2025/356/
- Apple — The details of UI typography (WWDC20): optical sizes, tracking and leading per size. https://developer.apple.com/videos/play/wwdc2020/10175/
- Apple — Principles of great design (WWDC26); Designing with Liquid Glass. https://developer.apple.com/videos/
- Norman, *Emotional Design* (2004): visceral, behavioural and reflective design.
- Evans, *Bottlenecks: Aligning UX Design with User Psychology* (Apress, 2017) — attention, perception and memory bottlenecks. https://link.springer.com/book/10.1007/978-1-4842-2580-6
- Johnson, *Designing with the Mind in Mind*, 3rd ed. (Morgan Kaufmann, 2020), chapters 2–4 on perception, structure and colour.
- Weinschenk, *100 Things Every Designer Needs to Know About People*, 2nd ed. (New Riders, 2020).
- Tidwell, Brewer & Valencia, *Designing Interfaces*, 3rd ed. (O'Reilly, 2020) — visual hierarchy, "few hues, many values".
- Colborne, *Simple and Usable Web, Mobile, and Interaction Design*, 2nd ed. (New Riders, 2017) — remove, organise, hide, displace.
- GitHub — actions/runner-images, macOS 15 image (Xcode 26.3 is the newest released toolchain used by the iOS build). https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
- Apple Human Interface Guidelines — Color, Dark Mode, Typography, Motion, Pointing devices. https://developer.apple.com/design/human-interface-guidelines/color · https://developer.apple.com/design/human-interface-guidelines/dark-mode · https://developer.apple.com/design/human-interface-guidelines/typography · https://developer.apple.com/design/human-interface-guidelines/motion · https://developer.apple.com/design/human-interface-guidelines/pointing-devices
- W3C — WCAG 2.2, contrast (minimum). https://www.w3.org/TR/WCAG22/#contrast-minimum
- Apple Developer Documentation — UIGestureRecognizer and coordinating multiple gesture recognizers. https://developer.apple.com/documentation/uikit/uigesturerecognizer · https://developer.apple.com/documentation/uikit/touches_presses_and_gestures/coordinating_multiple_gesture_recognizers
- Karpicke & Roediger (2007). Expanding retrieval practice promotes short-term retention, but equally spaced retrieval enhances long-term retention. *Journal of Experimental Psychology: Learning, Memory, and Cognition* 33(4).
- Butler, Godbole & Marsh (2013). Explanation feedback is better than correct answer feedback for promoting transfer of learning. *Journal of Educational Psychology* 105(2).
- Apple Human Interface Guidelines — Tab bars, Modality, Layout, Navigation bars. https://developer.apple.com/design/human-interface-guidelines/tab-bars · https://developer.apple.com/design/human-interface-guidelines/modality · https://developer.apple.com/design/human-interface-guidelines/layout
- Nielsen (1994). 10 Usability Heuristics for User Interface Design. https://www.nngroup.com/articles/ten-usability-heuristics/
- Nielsen Norman Group — Jakob's Law of Internet User Experience; Fitts's law; Hick's law. https://www.nngroup.com/videos/jakobs-law-internet-ux/ · https://www.nngroup.com/articles/fitts-law/
- Yablonski, *Laws of UX*. https://lawsofux.com
