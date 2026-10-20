# KanjiVG stroke data

The `strokePaths` arrays in `content/core-n5.json` — and the copy embedded in
`Sumi.swiftpm/Sources/ContentView.swift` — and the `sumiMarkPaths` array for
the app's 墨 mark (also in `ContentView.swift`) are derived from **KanjiVG**
(<https://kanjivg.tagaini.net>, <https://github.com/KanjiVG/kanjivg>),
© Ulrich Apel and contributors.

KanjiVG is licensed under the Creative Commons Attribution-Share Alike 3.0
license: <https://creativecommons.org/licenses/by-sa/3.0/>.

**Changes made:** only the stroke path data (`d` attributes) was extracted, in
stroke order, from each kanji's SVG file by `tools/add_strokes.py`. Stroke
groups, element metadata and stroke-number labels were not kept. The
extracted stroke data remains under CC BY-SA 3.0.

The app credits KanjiVG on its **How Sumi works** screen.
