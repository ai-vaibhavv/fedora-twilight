#!/usr/bin/env python3
"""Render a template with colours from palette.conf.

Placeholders:
  {{NAME}}      -> #RRGGBB          (e.g. {{CLOSE}})
  {{NAME_RGB}}  -> R, G, B          (for rgba(...) with custom alpha)

Usage: render.py PALETTE TEMPLATE [OUTPUT]   (stdout when OUTPUT is omitted)
"""
import re
import sys
from pathlib import Path


def load_palette(path):
    palette = {}
    for line in Path(path).read_text().splitlines():
        m = re.match(r"^\s*([A-Z_]+)\s*=\s*(\S+)", line)
        if m:
            palette[m.group(1)] = m.group(2)
    return palette


def render(text, palette):
    def sub(m):
        name = m.group(1)
        if name.endswith("_RGB") and name[:-4] in palette:
            h = palette[name[:-4]].lstrip("#")
            return ", ".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))
        if name in palette:
            return palette[name]
        sys.exit(f"render.py: unknown placeholder {{{{{name}}}}}")

    return re.sub(r"\{\{([A-Z_]+)\}\}", sub, text)


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    out = render(Path(sys.argv[2]).read_text(), load_palette(sys.argv[1]))
    if len(sys.argv) == 4:
        Path(sys.argv[3]).parent.mkdir(parents=True, exist_ok=True)
        Path(sys.argv[3]).write_text(out)
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
