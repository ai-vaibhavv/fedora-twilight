# How Twilight was built

A day of customising Fedora 44 / GNOME 50, reconstructed from shell history and the files
left on disk. It's here so nobody (including future me) repeats the dead ends.

## Kept

| Area | What ended up working |
| --- | --- |
| Base theme | Colloid, `-t purple -c dark --tweaks catppuccin normal` (pinned commit `6c2dc65`) |
| Top bar | Transparent `#panel`, each indicator a rounded "pill" (`#232634`), with faint glass pills on the lock and login screens |
| Window buttons | Pastel close/minimise/maximise circles (`#EAA0BC` / `#F2B49C` / `#8EACED`), glyph visible only on hover, dimmed on unfocused windows |
| GTK 4 / libadwaita | Colloid's GTK 4 CSS copied to `~/.config/gtk-4.0` plus the button block |
| Qt apps | [QAdwaitaColorfulDecorations](https://github.com/acd407/QAdwaitaColorfulDecorations) patched to draw the same pastel buttons and a `#2C2E45` title bar, loaded through `QT_WAYLAND_DECORATION=adwaita-colorful` |
| LibreOffice | Forced onto its Qt 6 UI (`SAL_USE_VCLPLUGIN=qt6`) so it gets the Qt title bar above |
| Icons | Papirus Dark + a tiny `Papirus-Twilight` theme holding only violet folders; `Twilight-Controls` on top for a cleaner minimise glyph |
| Cursor | Catppuccin Mocha Lavender |
| Lock screen | WACK Sonoma lockscreen: Inter clock nudged to the right (`factor 0.76`), handwritten Sacramento date in dusty pink, glass password pill, softer blur |
| Login screen (GDM) | The same WACK extension installed system-wide and enabled for the `gdm` user via `/etc/dconf/db/gdm.d`; its bright white click-glow toned down to lavender |
| Extensions | Dash to Dock (autohide, `#2C2E45` at 88%), Just Perfection, Tiling Shell, Rounded Windows (16 px), Burn My Windows ("glide" only), Clipboard Indicator (`Super+V`), Caffeine, Weather O'Clock |
| Fonts | Inter 11 for the UI, JetBrains Mono for code/terminal, Sacramento for the date |
| Sounds | A soft "Twilight" sound theme |

## Tried and dropped

- **A custom Shell extension that drew window buttons on top of every window**
  (`twilight-window-controls@vaibhav.local`). It needed constant position fixes and
  fought with apps that draw their own title bars. Replaced with per-toolkit styling
  (GTK 3, GTK 4, Qt), which is native and update-safe.
- **Patching VS Code's bundled CSS** under `/usr/share/code/…` to get the pastel buttons.
  It worked, but every VS Code update overwrites those files (it has already been undone
  on this machine). Not worth it; VS Code uses its own title bar.
- **Discord / Brave native decorations** (`--enable-features=WaylandWindowDecorations`,
  `--use-system-title-bar`). Electron/Chromium apps draw their own controls; results were
  inconsistent, so they were left as-is.
- **Desktop Widgets (azclock) and Lockscreen Studio**. Earlier attempts at a desktop clock and
  a lock-screen restyle; superseded by WACK.
- **Blur My Shell**. Installed but not used with the transparent-pill top bar.
- **Editing Colloid's files in `~/.themes` directly**. Any theme rebuild would silently lose
  the edits. Now layered via `~/.config/gtk-3.0/gtk.css` and marker blocks.

## Bugs found while packaging this

- The lock-screen stylesheet had a comment missing its opening `/*`
  (`Main clock. * No background…`), which broke the `.wack-time` rule after it.
  Fixed in `templates/lockscreen/stylesheet.css`.
- The package export wrote every name on one line (`packages/dnf.txt`). Regenerated as
  `packages/dnf-all.txt`, one package per line.
- The Qt plugin is compiled against Qt's **private** headers, so any `qt6-qtbase` or
  `qt6-qtwayland` update can make it silently stop loading. `twilight-heal.service` now
  rebuilds it automatically.

## Live PC audit (2026-09-29)

Compared the repository with the running Fedora 44 / GNOME 50 session before
changing colours. Rendered GTK 3, GTK 4, Shell, WACK lock-screen and GDM CSS all
matched the installed purple customisation. All expected extensions and the Qt
environment were active. The kept/discarded list above matches the enabled
extensions; saved settings for old experiments are not evidence that they run.
Rounded Window Corners Reborn also has leftover settings but is not enabled;
Rounded Windows is the selected implementation.

Added missing portable preferences: battery percentage, weather after the clock,
and disabled Dash to Dock hotkeys/shortcut binding. Personal weather locations,
widget positions from discarded experiments and app-specific settings are not
exported into the installer.

The wallpaper palette was tested with a dark yellow wallpaper: it selects yellow for
Colloid, Papirus folders and the GNOME accent, and the default purple `palette.conf`
stays unchanged. Build workspaces moved into the checkout's ignored `.twilight/`
directory; installed files stay in GNOME's normal locations.

`--check` compares rendered colours, not only installation markers, so a lock or
login screen still in the old palette fails the check.

LibreOffice launchers from the first manual setup (`~/.local/bin/libreoffice-twilight`
and copies of its `.desktop` files) were retired: the session-wide
`environment.d` file already gives LibreOffice the Qt 6 title bar, and the copies
would have hidden updates to the system launchers.
