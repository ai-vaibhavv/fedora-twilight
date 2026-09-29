#!/usr/bin/env python3
"""Suggest a Twilight palette from any wallpaper.

    ./scripts/palette-from-wallpaper.py ~/Pictures/wall.jpg           # preview only
    ./scripts/palette-from-wallpaper.py ~/Pictures/wall.jpg --write   # update palette.conf

The palette keeps Twilight's structure (dark tinted surfaces, pastel window
buttons) but takes its hues from the picture. Tweak the result by hand in
palette.conf if a colour doesn't feel right; the installer only reads that file.
"""
import argparse
import colorsys
import math
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Needs Pillow:  sudo dnf install python3-pillow")

PALETTE = Path(__file__).resolve().parent.parent / "palette.conf"

# Named variants offered by the upstream themes, by hue (degrees).
COLLOID = {"default": 215, "purple": 270, "pink": 330, "red": 0, "orange": 30,
           "yellow": 50, "green": 120, "teal": 175}
PAPIRUS = {"blue": 215, "indigo": 240, "violet": 270, "magenta": 300, "pink": 330,
           "red": 0, "orange": 30, "yellow": 50, "green": 120, "teal": 175, "cyan": 190}
GNOME = {"blue": 215, "teal": 180, "green": 130, "yellow": 50, "orange": 30,
         "red": 0, "pink": 330, "purple": 275}


def hexcol(h, l, s):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, max(0, min(1, l)), max(0, min(1, s)))
    return "#{:02X}{:02X}{:02X}".format(round(r * 255), round(g * 255), round(b * 255))


def hue_dist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def nearest(table, hue):
    return min(table, key=lambda k: hue_dist(table[k], hue))


def clusters(path, n=16):
    with Image.open(path) as source:
        source.thumbnail((320, 320))
        img = source.convert("RGB")
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()
    out = []
    for count, idx in sorted(q.getcolors(), reverse=True):
        r, g, b = (c / 255 for c in pal[idx * 3: idx * 3 + 3])
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        out.append({"w": count, "h": h * 360, "l": l, "s": s})
    return out


def suggest(path):
    cs = clusters(path)
    total = sum(c["w"] for c in cs)

    # Dominant hue: population-weighted circular mean of reasonably coloured clusters.
    x = y = 0.0
    for c in cs:
        wt = c["w"] * c["s"]
        x += wt * math.cos(math.radians(c["h"]))
        y += wt * math.sin(math.radians(c["h"]))
    base_h = math.degrees(math.atan2(y, x)) % 360 if math.hypot(x, y) > 1e-6 else 270

    # Colourful candidates, strongest first; pick three well-separated hues.
    vivid = sorted((c for c in cs if c["s"] > 0.25 and 0.2 < c["l"] < 0.85),
                   key=lambda c: c["s"] * math.sqrt(c["w"] / total), reverse=True)
    hues = []
    for c in vivid:
        if all(hue_dist(c["h"], h) > 35 for h in hues):
            hues.append(c["h"])
        if len(hues) == 3:
            break
    for offset in (0, 60, -60, 180, 120, -120):
        if len(hues) == 3:
            break
        candidate = (base_h + offset) % 360
        if all(hue_dist(candidate, h) > 35 for h in hues):
            hues.append(candidate)

    accent_h = hues[0]
    close_h = min(hues, key=lambda h: hue_dist(h, 335))
    rest = [h for h in hues if h != close_h]
    max_h = min(rest, key=lambda h: hue_dist(h, 220))
    min_h = [h for h in rest if h != max_h][0]

    return {
        "BASE": hexcol(base_h, 0.15, 0.22),
        "SURFACE": hexcol(base_h, 0.22, 0.22),
        "SURFACE_DIM": hexcol(base_h, 0.19, 0.21),
        "BORDER": hexcol(base_h, 0.30, 0.10),
        "BORDER_DIM": hexcol(base_h, 0.25, 0.18),
        "TEXT": hexcol(base_h, 0.95, 0.40),
        "TEXT_BRIGHT": hexcol(base_h, 0.97, 0.55),
        "TEXT_DIM": hexcol(base_h, 0.69, 0.15),
        "SUBTEXT": hexcol(accent_h, 0.87, 0.65),
        "ACCENT": hexcol(accent_h, 0.76, 0.58),
        "CLOSE": hexcol(close_h, 0.77, 0.65),
        "MINIMIZE": hexcol(min_h, 0.78, 0.75),
        "MAXIMIZE": hexcol(max_h, 0.74, 0.72),
        "PANEL_PILL": hexcol(base_h, 0.17, 0.19),
        "PANEL_HOVER": hexcol(base_h, 0.29, 0.09),
        "PANEL_ACTIVE": hexcol(base_h, 0.37, 0.08),
        "COLLOID_COLOR": nearest(COLLOID, accent_h),
        "PAPIRUS_FOLDER": nearest(PAPIRUS, accent_h),
        "GNOME_ACCENT": nearest(GNOME, accent_h),
    }


def swatch(value):
    if not value.startswith("#"):
        return ""
    r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
    return f"\x1b[48;2;{r};{g};{b}m      \x1b[0m"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("wallpaper")
    ap.add_argument("--write", action="store_true", help=f"update {PALETTE.name} in place")
    ap.add_argument("--output", type=Path, help="write a generated palette to this file without editing the default")
    args = ap.parse_args()
    if args.write and args.output:
        ap.error("Use --write or --output, not both")

    try:
        pal = suggest(args.wallpaper)
    except (OSError, ValueError, Image.DecompressionBombError) as exc:
        ap.exit(2, f"Cannot read wallpaper: {exc}\n")
    tty = sys.stdout.isatty()
    for k, v in pal.items():
        print(f"{swatch(v) + ' ' if tty else ''}{k}={v}")

    if args.write or args.output:
        text = PALETTE.read_text()
        for k, v in pal.items():
            text = re.sub(rf"(?m)^{k}=.*$", f"{k}={v}", text)
        target = args.output or PALETTE
        if target.exists():
            target.with_suffix(target.suffix + ".bak").write_text(target.read_text())
        target.write_text(text)
        print(f"\nSaved palette: {target}")


if __name__ == "__main__":
    main()
