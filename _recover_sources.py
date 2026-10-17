import json
import os
from pathlib import Path

base = r"C:\Users\parma\.cursor\projects\c-Users-parma-OneDrive-Desktop-carefind\agent-transcripts"
root = Path(r"C:\Users\parma\OneDrive\Desktop\carefind")
allowed_prefixes = (
    str(root / "lib"),
    str(root / "pubspec.yaml"),
    str(root / "analysis_options.yaml"),
    str(root / "android"),
    str(root / "README.md"),
    str(root / "test"),
)


def walk(obj, acc):
    if isinstance(obj, dict):
        name = obj.get("name")
        inp = obj.get("input") or obj.get("arguments")
        if name in ("Write", "ApplyPatch", "StrReplace") and isinstance(inp, dict):
            acc.append((name, inp))
        for v in obj.values():
            walk(v, acc)
    elif isinstance(obj, list):
        for i in obj:
            walk(i, acc)


ops = []
jsonl_files = []
for dirpath, _, files in os.walk(base):
    for f in files:
        if f.endswith(".jsonl"):
            jsonl_files.append(os.path.join(dirpath, f))
jsonl_files.sort()

for path in jsonl_files:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            acc = []
            walk(obj, acc)
            for name, inp in acc:
                p = inp.get("path") or ""
                p_norm = os.path.normpath(p)
                if not any(p_norm.lower().startswith(pref.lower()) for pref in allowed_prefixes):
                    continue
                ops.append((path, lineno, name, inp))

print(f"ops to replay: {len(ops)}")
written = 0
patched = 0
failed = []
files = set()

for src, lineno, name, inp in ops:
    p = Path(inp["path"])
    if name == "Write":
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(inp["contents"], encoding="utf-8")
        written += 1
        files.add(str(p))
    elif name == "StrReplace":
        if not p.exists():
            failed.append((name, str(p), "missing", src, lineno))
            continue
        text = p.read_text(encoding="utf-8")
        old = inp["old_string"]
        new = inp["new_string"]
        replace_all = bool(inp.get("replace_all"))
        if replace_all:
            if old not in text:
                failed.append((name, str(p), "old not found", src, lineno))
                continue
            p.write_text(text.replace(old, new), encoding="utf-8")
        else:
            count = text.count(old)
            if count != 1:
                failed.append((name, str(p), f"count={count}", src, lineno))
                continue
            p.write_text(text.replace(old, new, 1), encoding="utf-8")
        patched += 1
        files.add(str(p))
    elif name == "ApplyPatch":
        failed.append((name, str(p), "unsupported", src, lineno))

print(f"written={written} patched={patched} failed={len(failed)} files={len(files)}")
for item in failed[:40]:
    print("FAIL", item)
if len(failed) > 40:
    print("... more", len(failed) - 40)
print("FILES:")
for f in sorted(files):
    print(" ", f)
