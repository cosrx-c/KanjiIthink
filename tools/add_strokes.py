"""Add KanjiVG stroke-order paths to content/core-n5.json.

For every kanji in the pack, downloads its SVG from KanjiVG
(https://github.com/KanjiVG/kanjivg) and stores the stroke paths, in stroke
order, as a "strokes" array of SVG path strings (109 x 109 coordinate space).

KanjiVG is © Ulrich Apel and contributors, licensed CC BY-SA 3.0. The app
credits it in How Sumi works; the stroke data stays under that license.

    python tools/add_strokes.py            # only kanji without strokes
    python tools/add_strokes.py --refresh  # re-download everything

Then validate and re-embed:

    python tools/validate_content.py content/core-n5.json
    python tools/embed_content.py
"""
import json
import pathlib
import re
import sys
import time
import urllib.request

root = pathlib.Path(__file__).resolve().parent.parent
pack_path = root / "content" / "core-n5.json"
BASE = "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/{:05x}.svg"
STROKE = re.compile(r'<path\b[^>]*\bid="kvg:[0-9a-f]+-s(\d+)"[^>]*\bd="([^"]+)"', re.S)
STROKE_ALT = re.compile(r'<path\b[^>]*\bd="([^"]+)"[^>]*\bid="kvg:[0-9a-f]+-s(\d+)"', re.S)


def strokes_for(glyph):
    url = BASE.format(ord(glyph))
    with urllib.request.urlopen(url, timeout=30) as response:
        svg = response.read().decode("utf-8")
    found = {int(n): d for n, d in STROKE.findall(svg)}
    found.update({int(n): d for d, n in STROKE_ALT.findall(svg)})
    if not found:
        raise ValueError(f"no strokes found for {glyph}")
    ordered = [" ".join(found[i].split()) for i in sorted(found)]
    if sorted(found) != list(range(1, len(found) + 1)):
        raise ValueError(f"stroke numbering gap for {glyph}: {sorted(found)}")
    return ordered


def main():
    refresh = "--refresh" in sys.argv
    pack = json.loads(pack_path.read_text(encoding="utf-8"))
    changed = 0
    for kanji in pack["kanji"]:
        if kanji.get("strokePaths") and not refresh:
            continue
        paths = strokes_for(kanji["glyph"])
        kanji["strokePaths"] = paths
        note = "" if len(paths) == kanji.get("strokes", len(paths)) else f"  (pack says {kanji.get('strokes')})"
        print(f"{kanji['glyph']}  {len(paths)} strokes{note}")
        changed += 1
        time.sleep(0.1)
    pack_path.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"updated {changed} kanji")


if __name__ == "__main__":
    main()
