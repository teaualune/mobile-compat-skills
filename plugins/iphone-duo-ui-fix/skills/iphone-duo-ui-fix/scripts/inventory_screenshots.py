#!/usr/bin/env python3
"""
inventory_screenshots.py — list the iPhone Duo screenshots the skill caller provided,
with any hints they attached, so Phase 1 starts from a table instead of a pile of PNGs.

Usage:
    python3 scripts/inventory_screenshots.py <screenshots_root> [--json out.json]

Expected layout (any folder may be missing). Names follow Apple's terms:
    <root>/outer/              outer display (closed), 466 x 678 pt
    <root>/inner/              inner display as it opens: Apple's inner landscape, 951 x 669 pt
    <root>/inner_portrait/     inner display rotated: Apple's inner portrait, 669 x 951 pt (rarely broken)
    <root>/inner_landscape/    accepted as an alias of inner/ (common name for the default open mode)

Hints (all optional, all merged, later wins):
    <root>/manifest.json       {"inner/home.png": {"screen": "lib/home_page.dart", "hint": "..."}}
    <root>/manifest.yaml       same shape, simple 2-level YAML (no PyYAML needed)
    <root>/inner/home.md       sidecar: free-text hint for inner/home.png (also .txt)
    <root>/README.md           read by the caller of this script, not parsed here

Stdlib only; works with the python3 that ships with Xcode Command Line Tools.
"""
import json
import os
import re
import struct
import sys

FOLDERS = ("outer", "inner", "inner_landscape", "inner_portrait")  # inner_landscape = alias of inner
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".heic", ".webp"}
HINT_EXT = {".md", ".txt"}

# Reference pixel sizes, width x height, @3x. Values come from
# references/duo-device-facts.md — update both places if Apple changes them.
# They are used only to sanity-check that a file is in the right folder.
#   outer            466 x 678 pt  -> 1398 x 2034 px
#   inner landscape  951 x 669 pt  -> 2853 x 2007 px   (default when opened; fold runs vertically)
#   inner portrait   669 x 951 pt  -> 2007 x 2853 px   (rotated; fold runs horizontally)
# Outer and inner portrait have almost the same aspect ratio (0.69 vs 0.70), so the
# check uses absolute pixel sizes, not just aspect.
DISPLAYS = {
    "outer":           (1398, 2034),
    "inner landscape": (2853, 2007),
    "inner portrait":  (2007, 2853),
}
SIZE_TOLERANCE = 0.06                 # ±6 % on each axis still counts as that display
ASPECT_TOLERANCE = 0.05               # fallback when the file was resized


def image_size(path):
    """Return (width, height) for PNG/JPEG without PIL; None if unknown."""
    try:
        with open(path, "rb") as f:
            head = f.read(32)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                w, h = struct.unpack(">II", head[16:24])
                return w, h
            if head[:2] == b"\xff\xd8":  # JPEG: walk segments to SOFn
                f.seek(2)
                while True:
                    marker = f.read(2)
                    if len(marker) < 2 or marker[0] != 0xFF:
                        return None
                    if marker[1] in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                        f.read(3)
                        h, w = struct.unpack(">HH", f.read(4))
                        return w, h
                    seg_len = struct.unpack(">H", f.read(2))[0]
                    f.seek(seg_len - 2, os.SEEK_CUR)
    except (OSError, struct.error):
        return None
    return None


def load_simple_yaml(path):
    """Parse the 2-level 'file: {key: value}' subset used by manifest.yaml."""
    data, current = {}, None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            indent = len(line) - len(line.lstrip(" "))
            key, _, value = line.strip().partition(":")
            key = key.strip().strip('"').strip("'")
            value = value.strip()
            if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
                value = value[1:-1]
            if indent == 0:
                current = key
                data.setdefault(current, {})
                if value:
                    data[current]["hint"] = value
            elif current is not None:
                data[current][key] = value
    return data


def load_manifest(root):
    merged = {}
    jp = os.path.join(root, "manifest.json")
    yp = os.path.join(root, "manifest.yaml")
    if os.path.isfile(jp):
        with open(jp, encoding="utf-8") as f:
            merged.update(json.load(f))
    if os.path.isfile(yp):
        merged.update(load_simple_yaml(yp))
    # normalise keys to forward slashes relative to root
    return {k.replace("\\", "/").lstrip("./"): v for k, v in merged.items()}


def identify_display(size):
    """Return (label, exact) — which Duo display a capture most likely came from."""
    if size is None:
        return None, False
    w, h = size
    for name, (ew, eh) in DISPLAYS.items():
        if abs(w - ew) <= ew * SIZE_TOLERANCE and abs(h - eh) <= eh * SIZE_TOLERANCE:
            return name, True
    # resized/cropped file: fall back to aspect ratio, which cannot tell outer from inner portrait
    ratio = w / h if h else 0
    for name, (ew, eh) in DISPLAYS.items():
        if abs(ratio - ew / eh) <= ASPECT_TOLERANCE:
            return ("outer or inner portrait" if name in ("outer", "inner portrait") else name), False
    return None, False


def classify(folder, size):
    """Say whether the pixel size agrees with the folder the caller put it in."""
    label, exact = identify_display(size)
    if label is None:
        return "size unknown" if size is None else "%dx%d does not match a Duo display" % size
    # What each folder is expected to hold (Apple's orientation terms).
    expected = {
        "outer": ("outer", "outer or inner portrait"),
        "inner": ("inner landscape",),
        "inner_landscape": ("inner landscape",),
        "inner_portrait": ("inner portrait", "outer or inner portrait"),
    }.get(folder, ())
    ok = label in expected
    note = label if exact else label + " (resized?)"
    if ok:
        return "ok: " + note
    home = {"outer": "outer/", "inner landscape": "inner/", "inner portrait": "inner_portrait/",
            "outer or inner portrait": "outer/ or inner_portrait/"}.get(label, "?")
    return "MISMATCH: %s — belongs in %s" % (note, home)


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 2
    root = os.path.abspath(argv[1])
    out_json = None
    if "--json" in argv:
        out_json = argv[argv.index("--json") + 1]
    if not os.path.isdir(root):
        print("not a directory: %s" % root, file=sys.stderr)
        return 2

    manifest = load_manifest(root)
    rows = []
    for folder in FOLDERS:
        fdir = os.path.join(root, folder)
        if not os.path.isdir(fdir):
            continue
        for name in sorted(os.listdir(fdir)):
            stem, ext = os.path.splitext(name)
            if ext.lower() not in IMAGE_EXT:
                continue
            rel = "%s/%s" % (folder, name)
            path = os.path.join(fdir, name)
            size = image_size(path)
            entry = dict(manifest.get(rel, {}))
            # sidecar hint files
            for hext in HINT_EXT:
                hp = os.path.join(fdir, stem + hext)
                if os.path.isfile(hp):
                    with open(hp, encoding="utf-8", errors="replace") as f:
                        txt = f.read().strip()
                    entry["hint"] = (entry.get("hint", "") + "\n" + txt).strip()
            rows.append({
                "file": rel,
                "folder": folder,
                "pixels": "%dx%d" % size if size else "?",
                "check": classify(folder, size),
                "screen": entry.get("screen", ""),
                "hint": entry.get("hint", ""),
            })

    # anything in the manifest that has no file
    for key in manifest:
        if not any(r["file"] == key for r in rows):
            rows.append({"file": key, "folder": key.split("/")[0], "pixels": "MISSING FILE",
                         "check": "listed in manifest but not found", "screen": manifest[key].get("screen", ""),
                         "hint": manifest[key].get("hint", "")})

    if not rows:
        print("No screenshots found under %s (expected outer/, inner/, inner_portrait/)." % root)
        return 1

    print("| # | file | pixels | folder check | mapped screen/code | caller hint |")
    print("|---|------|--------|--------------|--------------------|-------------|")
    for i, r in enumerate(rows, 1):
        hint = r["hint"].replace("\n", " ").replace("|", "\\|")
        print("| %d | %s | %s | %s | %s | %s |" % (i, r["file"], r["pixels"], r["check"],
                                                 r["screen"] or "_(unknown — ask caller or infer)_",
                                                 hint or "_(none — propose a fix)_"))
    missing_screen = [r["file"] for r in rows if not r["screen"]]
    missing_hint = [r["file"] for r in rows if not r["hint"]]
    print()
    print("screens still unmapped: %d/%d" % (len(missing_screen), len(rows)))
    print("screenshots without caller hints: %d/%d" % (len(missing_hint), len(rows)))

    if out_json:
        with open(out_json, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2)
        print("wrote %s" % out_json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
