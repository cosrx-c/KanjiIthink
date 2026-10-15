"""Re-embed content/core-n5.json into Sources/ContentView.swift.

The app ships its starter content as a JSON string inside ContentView.swift
(so the Swift file stays self-contained). Edit content/core-n5.json, run

    python tools/validate_content.py content/core-n5.json
    python tools/embed_content.py

and commit both files. Packs can also be imported in the app instead
(Settings → Content & data), with no rebuild at all.
"""
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
content = json.loads((root / "content" / "core-n5.json").read_text(encoding="utf-8"))


def line(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(", ", ": "))


def block(key, items, last=False):
    rows = ",\n".join("    " + line(item) for item in items)
    return '  "' + key + '": [\n' + rows + "\n  ]" + ("" if last else ",")


pretty = (
    "{\n"
    + '  "name": ' + line(content["name"]) + ",\n"
    + block("kanji", content["kanji"]) + "\n"
    + block("passages", content.get("passages", [])) + "\n"
    + block("confusions", content.get("confusions", []), last=True) + "\n}"
)
assert json.loads(pretty) == {**content, "passages": content.get("passages", []), "confusions": content.get("confusions", [])}
if '"""' in pretty or "\\" in pretty:
    raise SystemExit('Content may not contain """ or backslashes (they would break the Swift raw string).')

swift_path = root / "Sources" / "ContentView.swift"
swift = swift_path.read_text(encoding="utf-8")
pattern = re.compile(r'(let builtInContentJSON = #""")\n[\s\S]*?\n("""#)')
if not pattern.search(swift):
    raise SystemExit("Couldn't find builtInContentJSON in ContentView.swift")
swift = pattern.sub(lambda m: m.group(1) + "\n" + pretty + "\n" + m.group(2), swift, count=1)
swift_path.write_text(swift, encoding="utf-8", newline="\n")
print(f"Embedded {len(content['kanji'])} kanji, {len(content.get('passages', []))} passages into {swift_path.name}")
