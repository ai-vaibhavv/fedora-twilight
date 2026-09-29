# Fedora Twilight — Codex Instructions

This repository reproduces and maintains a customized Fedora GNOME desktop called **Twilight**.

Before changing any desktop configuration:

1. Read `CURRENT_STATE.md`.
2. Read `DECISIONS.md`.
3. Read `FAILED_EXPERIMENTS.md` before proposing an approach that may already have been attempted.
4. Treat the current known-good desktop as authoritative.
5. Preserve rollback capability for every system-level modification.
6. Prefer user-local configuration under `~/.config`, `~/.local`, and `~/.themes`.
7. Do not overwrite Fedora-owned files unless the change is explicitly version-checked, backed up, and documented.
8. Treat GDM/WACK modifications and the Qt decoration plugin as version-sensitive.
9. Make scripts idempotent whenever practical.
10. Prefer terminal-first workflows and exact commands.
11. Do not resurrect removed experiments unless explicitly requested.
12. Do not change the current right-side window-button layout unless explicitly requested.

## Working in this repository

- `install.sh` is the source of truth: every desktop change belongs in a step,
  template (`templates/`), setting (`dconf/`) or file (`files/`), not a one-off command.
- Colours come from placeholders such as `{{CLOSE}}`, rendered from the active palette
  (`.twilight/palette.conf`); do not hard-code palette colours in templates.
- Builds, upstream checkouts, state and backups live in the ignored `.twilight/`.
- Before finishing a change, run:

  ```bash
  bash -n install.sh
  python3 -m unittest discover -s tests -v
  ./install.sh --dry-run
  ./install.sh --check
  ```

- Update `CURRENT_STATE.md`, `DECISIONS.md` or `FAILED_EXPERIMENTS.md` when the
  change affects them.

## Platform

- Fedora 44
- GNOME 50
- Bash
- Ptyxis
- Brave
- dark desktop
- no blur aesthetic
- wallpaper-driven bluish/pink/purple Twilight palette

## Important implementation rules

- Keep **Colloid** as the GTK/Shell base and customize it rather than replacing it.
- Keep **Twilight-Controls** as the icon-theme overlay for the centered minimize glyph.
- Keep the custom **QAdwaitaColorfulDecorations** plugin for Qt6 Wayland apps.
- LibreOffice should use the **Qt6 VCL backend** with the custom Qt decoration, set
  in `~/.config/environment.d/90-twilight-qt.conf` (no wrapper scripts or copied launchers).
- Do not use the failed LibreOffice GTK3 CSS route.
- Do not use LibreOffice's GTK4 backend as the default; it produced broken/white toolbar rendering.
- Do not patch VS Code installation files again.
- Leave Discord stock unless explicitly requested.
- Do not reinstall Blur My Shell unless explicitly requested.
- Do not restore `rounded-window-corners@fxgn`; use `rounded-windows@marcosgt.github.io`.
- WACK/GDM changes must be compatibility-checked before replaying them on a future Fedora/GNOME/GDM version.

See `CURRENT_STATE.md` for the exact known-good state.
