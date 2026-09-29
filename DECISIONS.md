# Fedora Twilight — Decisions

## Keep Colloid and customize it

The user explicitly preferred modifying Colloid instead of switching to another theme.

Final base: Colloid built with `-t purple -c dark --tweaks catppuccin normal`,
installed as `Colloid-Twilight-Dark`. Twilight's own CSS is layered on top between
markers; Colloid's files are never edited in place.

## Wallpaper-driven palette

Twilight should be treated as one example of a wallpaper-driven desktop.

For public documentation, the current colors should be described as **my palette**, not **the palette**.

Readers should be encouraged to choose their own wallpaper and derive a compatible palette.

`./install.sh --wallpaper FILE --auto-palette` generates it into `.twilight/palette.conf`
without editing the checkout. Partial runs keep a wallpaper palette so no piece ends
up in different colours; a full run restores `palette.conf`.

## No blur

Blur My Shell was tested and rejected.

The user prefers a sharp interface.

## Window controls stay on the right

Final layout:

```text
:minimize,maximize,close
```

## Native controls are preferred

Do not use a universal fake overlay.

Where possible, theme the application's original controls through:

- GTK
- Qt
- system-theme integration

This worked for GTK 4, Brave, Qt 6 and (through `flatpak override`) Flatpak apps.

## GTK4

Use the exact Colloid selector structure and specificity.

The visible control circle is on the inner `image` node.

Use the `Twilight-Controls` icon overlay for the centered minimize glyph.

## Qt6

Use the custom `QAdwaitaColorfulDecorations` build.

Do not replace Fedora's system Qt plugin.

Install the custom plugin user-locally:

```text
~/.local/lib/qt6/plugins/wayland-decoration-client/
```

This keeps rollback easy.

## LibreOffice

Preferred:

```text
Qt6 VCL backend
```

Do not repeat the GTK3 recoloring route.

Do not use the experimental GTK4 backend as the default because it produced broken/white toolbar rendering.

Set the backend session-wide in `~/.config/environment.d/90-twilight-qt.conf`, not
through wrapper scripts or copied `.desktop` files (those hide launcher updates).

## Rounded windows

Do not restore:

```text
rounded-window-corners@fxgn
```

Use:

```text
rounded-windows@marcosgt.github.io
```

## Animations

Keep Burn My Windows with the restrained Glide effect.

## Workspaces

Keep dynamic workspaces.

Do not restore custom workspace names.

## Terminal

Ptyxis with Bash. The `twilight` palette is rendered from the active palette
(background, text, cursor); the 16 ANSI colours stay fixed for readability.

## Power profiles

Do not build a custom power-profile workflow unless explicitly requested.

## VS Code and Discord

Keep them stock.

Do not patch VS Code's installation files again.

## Firefox

Firefox is intentionally removed.

Brave is the active browser.

## Lockscreen

WACK Sonoma Lockscreen is part of the intended desktop and must be included in backup/recovery planning.

However, GDM changes are version-sensitive and must not be blindly replayed on unknown future Fedora/GNOME/GDM versions.

## Recovery project

The repository serves three roles:

1. disaster recovery
2. update verification and repair
3. public tutorial source

How each part is covered:

| Need | Where |
| --- | --- |
| Install / reapply | `./install.sh` (idempotent steps, `--only`, `--dry-run`) |
| Verify | `./install.sh --check` (installation and rendered colours) |
| Update repair | `twilight-heal.service` → `./install.sh --heal` |
| Qt rebuild | heal service, after `qt6-qtbase` / `qt6-qtwayland` updates |
| Snapshot | automatic backup in `.twilight/backups/` before each install |
| Restore | manual, from those backups (see README); no automatic rollback yet |
| Package lists | `packages/` |
| Settings | `dconf/twilight.ini`, `dconf/shortcuts.ini` |
| Theme patches | `templates/` |
| Failed experiments | `FAILED_EXPERIMENTS.md`, `JOURNEY.md` |

Upstream projects are pinned to tested commits. The WACK/GDM step is not replayed
blindly: bump `WACK_REF` only after checking the new GNOME/GDM version.

A failing install step is traced and reported, and the remaining steps still run;
a failed `packages` step stops the run.

Do not back up credentials, browser sessions, SSH keys, tokens, or unrelated personal data.
