import json, re, sys, unicodedata

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
errors = []

def is_kanji(ch):
    o = ord(ch)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF

def is_hira(ch):
    return 0x3041 <= ord(ch) <= 0x3096 or ch in "ー"

def is_kata(ch):
    return 0x30A1 <= ord(ch) <= 0x30FA or ch in "ー"

RUBY = re.compile(r"\{([^{}|]+)\|([^{}|]+)\}")

def check_markup(text, where, must_contain=None):
    # every kanji (and 々) must sit inside a ruby base
    stripped = RUBY.sub("", text)
    for ch in stripped:
        if is_kanji(ch) or ch == "々":
            errors.append(f"{where}: unannotated kanji {ch!r} in {text}")
    if text.count("{") != text.count("}"):
        errors.append(f"{where}: unbalanced braces in {text}")
    for base, reading in RUBY.findall(text):
        if not any(is_kanji(c) or c == "々" for c in base):
            errors.append(f"{where}: ruby base without kanji {base!r}")
        if not all(is_hira(c) for c in reading):
            errors.append(f"{where}: ruby reading not hiragana {reading!r}")
    if must_contain:
        bases = "".join(b for b, _ in RUBY.findall(text))
        if must_contain not in bases:
            errors.append(f"{where}: target {must_contain} missing from sentence {text}")

glyphs = set()
for k in data["kanji"]:
    g = k["glyph"]
    w = f"kanji {g}"
    if len(g) != 1 or not is_kanji(g):
        errors.append(f"{w}: bad glyph")
    if g in glyphs:
        errors.append(f"{w}: duplicate")
    glyphs.add(g)
    if k["level"] not in (0, 1, 2, 3, 4, 5):
        errors.append(f"{w}: bad level")
    if not k["meanings"]:
        errors.append(f"{w}: no meanings")
    for r in k["on"]:
        if not all(is_kata(c) for c in r):
            errors.append(f"{w}: on reading not katakana {r!r}")
    for r in k["kun"]:
        if not all(is_hira(c) or c in ".-" for c in r):
            errors.append(f"{w}: kun reading malformed {r!r}")
    if k.get("kind") not in (None, "pictograph", "indicative", "compound", "phonetic", "borrowed"):
        errors.append(f"{w}: bad kind")
    for p in k["parts"]:
        if not p["glyph"] or not p["meaning"]:
            errors.append(f"{w}: empty part")
    if not k["words"]:
        errors.append(f"{w}: no words")
    for word in k["words"]:
        if g not in word["word"]:
            errors.append(f"{w}: word {word['word']} lacks glyph")
        for alt in word["reading"].split("/"):
            if not alt or not all(is_hira(c) for c in alt):
                errors.append(f"{w}: word reading malformed {word['reading']!r}")
    check_markup(k["sentence"], w, must_contain=g)
    if not k["translation"]:
        errors.append(f"{w}: no translation")

ids = set()
for p in data["passages"]:
    w = f"passage {p['id']}"
    if p["id"] in ids:
        errors.append(f"{w}: duplicate id")
    ids.add(p["id"])
    check_markup(p["title"], w + " title")
    for i, line in enumerate(p["lines"]):
        check_markup(line["jp"], f"{w} line {i}")
        if "speaker" in line:
            check_markup(line["speaker"], f"{w} speaker {i}")
        if not line["en"]:
            errors.append(f"{w} line {i}: no translation")
    q = p.get("question")
    if q and not (0 <= q["answer"] < len(q["options"])):
        errors.append(f"{w}: answer out of range")

for c in data["confusions"]:
    if len(c["glyphs"]) < 2:
        errors.append(f"confusion {c}: needs two glyphs")
    if not any(g in glyphs for g in c["glyphs"]):
        errors.append(f"confusion {c['glyphs']}: none in library")

levels = {}
for k in data["kanji"]:
    levels[k["level"]] = levels.get(k["level"], 0) + 1
print("kanji:", len(data["kanji"]), "by level:", levels)
print("passages:", len(data["passages"]), "confusions:", len(data["confusions"]))
if errors:
    print("\n".join(errors))
    sys.exit(1)
print("OK")
