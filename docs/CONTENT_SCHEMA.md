# Content packs

All kanji, words, reading passages and look-alike sets are plain JSON. The
starter pack lives in [`content/core-n5.json`](../content/core-n5.json) and is
embedded in `Sources/ContentView.swift`. Anything else can be added two ways:

1. **In the app, no rebuild:** Settings → Content & data → *Import content
   pack or backup*, then pick a `.json` file. A pack with the same `name`
   replaces the earlier one; a kanji with the same `glyph` overrides the
   built-in entry, so a pack can also correct the starter content.
2. **Built in:** edit `content/core-n5.json`, then run

   ```bash
   python tools/validate_content.py content/core-n5.json
   ```

   ```bash
   python tools/embed_content.py
   ```

   and commit both files.

## Top level

```json
{
  "name": "Core N4",
  "kanji": [ ... ],
  "passages": [ ... ],
  "confusions": [ ... ]
}
```

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Unique per pack. Shown in Settings. |
| `kanji` | yes | May be empty if the pack only adds passages. |
| `passages` | no | Reading texts for the Read tab. |
| `confusions` | no | Look-alike sets shown on kanji pages. |

## Kanji

```json
{
  "glyph": "休",
  "level": 5,
  "strokes": 6,
  "meanings": ["rest", "day off"],
  "on": ["キュウ"],
  "kun": ["やす.む"],
  "kind": "compound",
  "parts": [{"glyph": "亻", "meaning": "person"}, {"glyph": "木", "meaning": "tree"}],
  "phonetic": null,
  "mnemonic": "A person (亻) leaning against a tree (木): taking a rest.",
  "words": [
    {"word": "休む", "reading": "やすむ", "meaning": "to rest; to take time off"},
    {"word": "夏休み", "reading": "なつやすみ", "meaning": "summer vacation"}
  ],
  "sentence": "{少|すこ}し{休|やす}みましょう。",
  "translation": "Let's take a short break.",
  "usage": "Shop signs: 定休日 is the regular closing day."
}
```

| Field | Required | Notes |
|---|---|---|
| `glyph` | yes | One kanji. The unique key. |
| `level` | no (default `0`) | `5`–`1` for N5–N1, `0` for "Beyond" (jōyō, kanken, names). |
| `strokes` | no | Stroke count. |
| `meanings` | yes | Most important first — the first one is used on tiles. |
| `on` | no | On'yomi in **katakana**. |
| `kun` | no | Kun'yomi in **hiragana**. Use `.` before okurigana (`やす.む`), `-` for prefix/suffix forms (`-び`, `こ-`). |
| `kind` | no | Formation type: `pictograph` 象形, `indicative` 指事, `compound` 会意, `phonetic` 形声, `borrowed` 仮借. Omit when the etymology is disputed. |
| `parts` | no | Visual building blocks used by the memory hook. Parts that are themselves kanji in the library are taught first automatically. |
| `phonetic` | no | For `phonetic` kanji: which part gives the sound, e.g. `"交 (コウ) gives the sound コウ"`. |
| `mnemonic` | no | A short memory hook. Learners can add their own on top. |
| `words` | yes for reading reviews | Reading reviews rotate through these. `reading` is hiragana; give alternatives with `/` (`にほん/にっぽん`). Every word must contain the glyph. |
| `sentence` | no | Furigana markup (below). Must contain the glyph inside an annotated word. |
| `translation` | no | English for `sentence`. |
| `usage` | no | Where you meet it in real life: signs, register, culture. |

Kanji without `words` still get meaning and writing reviews but no reading
review.

## Furigana markup

Wrap every word containing kanji as `{base|reading}`:

```
{今日|きょう}は{雨|あめ}が{降|ふ}っています。
```

- Every kanji must be inside a `{…|…}` group (the validator checks this) so
  the speech voice always gets the right reading.
- Group whole words when the reading belongs to the word (`{今日|きょう}`,
  `{大人|おとな}`); annotate only the kanji part and leave okurigana outside
  (`{食|た}べる`).
- Don't put spaces between words — real Japanese doesn't have them, and line
  breaking already follows Japanese rules.

## Passages

```json
{
  "id": "restaurant",
  "title": "レストランで",
  "titleEN": "At a restaurant",
  "genre": "Dialogue",
  "topic": "Food & service",
  "level": 5,
  "lines": [
    {"speaker": "{店員|てんいん}", "jp": "いらっしゃいませ。", "en": "Welcome!"},
    {"speaker": "{客|きゃく}", "jp": "{二人|ふたり}です。", "en": "Two."}
  ],
  "notes": [
    {"lens": "Conversation", "text": "いらっしゃいませ expects no reply."}
  ],
  "question": {
    "prompt": "How many people are in the group?",
    "options": ["One", "Two", "Three"],
    "answer": 1,
    "explanation": "二人 is read ふたり."
  }
}
```

- `speaker` is optional; dialogue lines get a colored turn marker.
- `lens` can be anything. These get a matching icon: `Culture`, `Register`,
  `Discourse`, `Conversation`, `Intercultural`, `Word building`.
- `question.answer` is the zero-based index of the correct option.
- Aim for passages where learners at that level know most of the kanji; the
  app shows a "familiar" percentage and adds furigana for the rest.

## Look-alikes

```json
{"glyphs": ["土", "士"], "tip": "土 (earth): the bottom line is longer. 士 (samurai): the top line is longer."}
```

At least one glyph should be in the library; the set appears on every listed
kanji's page.

## Constraints

- No backslashes and no `"""` anywhere (the starter pack is embedded in a
  Swift raw string).
- UTF-8, NFC. Use Japanese punctuation (`。、「」`) in Japanese text.

## A note on JLPT levels

The JLPT has not published official kanji lists since the 2010 revision.
Level assignments follow the widely used pre-2010 lists and prep materials,
so treat them as a study order rather than an exam guarantee. Rough
cumulative targets used by most materials: N5 ≈ 80–100, N4 ≈ 250–300,
N3 ≈ 650, N2 ≈ 1,000, N1 ≈ 2,000 (close to the 2,136 jōyō kanji).

Stroke-order data, if you add it later, is available from
[KanjiVG](https://kanjivg.tagaini.net/) under CC BY-SA 3.0 (attribution
required).
