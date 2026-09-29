# Fedora Twilight — Current Known-Good State

Checked against the live system on 2026-09-29. `./install.sh --check` verifies
most of this automatically.

## Platform

- Fedora 44, GNOME Shell 50.5 (exact versions in `versions.txt`)
- Bash in Ptyxis, Brave as the browser
- dark theme, window controls on the right, no blur
- terminal-first workflow

## Palette

Colours come from a palette file and are rendered into every template.

- Default: [`palette.conf`](palette.conf), the purple/blue/pink palette made for the
  lo-fi wallpaper with a hooded person and cat.
- Active: `.twilight/palette.conf`. Either a copy of the default or generated from a
  wallpaper with `--auto-palette`; `.twilight/state/palette-source` records which.
  Partial runs (`--only`) keep a wallpaper palette.

Default values:

```text
BASE          #1E2030      TEXT          #F1EDF7      CLOSE     #EAA0BC
SURFACE       #2C2E45      TEXT_BRIGHT   #F7F3FC      MINIMIZE  #F2B49C
SURFACE_DIM   #25273A      TEXT_DIM      #A6A3BD      MAXIMIZE  #8EACED
BORDER        #434553      SUBTEXT       #D8C7F5
BORDER_DIM    #34364D      ACCENT        #B4A1E5
```

## GTK and GNOME Shell

- Theme `Colloid-Twilight-Dark`, built from Colloid (`purple`, dark,
  `--tweaks catppuccin normal`) and used for both GTK and the Shell (User Themes).
- The top bar's floating pills come from Twilight's Shell CSS, not Colloid's float tweak.
- GTK 4 / libadwaita: `~/.config/gtk-4.0/gtk.css` holds Colloid's CSS in a
  `colloid (managed by fedora-twilight)` block, then any user rules, then the
  `fedora-twilight` button block.
- GTK 3: button block in `~/.config/gtk-3.0/gtk.css`.
- Flatpak apps can read both folders (`flatpak override --user`).

## Window controls

- Layout `:minimize,maximize,close`.
- Coloured circles (close/minimise/maximise from the palette); the symbol shows on
  hover; unfocused windows are dimmed.
- GTK 4: Colloid paints the circle on the inner `image` node, so selectors must
  target `windowcontrols > button.X > image` with matching specificity, and the
  `:hover` rules repeat the fill.
- `Twilight-Controls` icon theme (inherits `Papirus-Twilight`, `Papirus-Dark`,
  `hicolor`) supplies a centred minimise glyph.

## Apps

| App | State |
| --- | --- |
| Brave (RPM) | GTK theme (`extensions.theme.system_theme = 1`); Chromium draws the GTK 4 buttons, including the `image` background |
| Qt 6 apps | `QAdwaitaColorfulDecorations`, patched from `templates/qt/qadwaita-twilight.patch`, installed to `~/.local/lib/qt6/plugins/wayland-decoration-client/` |
| LibreOffice | Qt 6 VCL (`SAL_USE_VCLPLUGIN=qt6`) with the Qt plugin above; system launchers |
| Ptyxis | `twilight` palette rendered from the active palette, opacity 0.94, line height 1.1, JetBrains Mono 12 |
| VLC | Runs on X11 (Fedora's VLC forces it); GNOME draws the title bar. Unmodified |
| VS Code, Discord | Stock |
| Firefox | Removed on purpose |

Session environment, `~/.config/environment.d/90-twilight-qt.conf`:

```text
QT_PLUGIN_PATH=${HOME}/.local/lib/qt6/plugins
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DECORATION=adwaita-colorful
SAL_USE_VCLPLUGIN=qt6
```

The Qt plugin uses Qt private APIs; `twilight-heal.service` rebuilds it when
`qt6-qtbase` or `qt6-qtwayland` change.

The earlier `~/.local/bin/libreoffice-twilight` wrapper and its `.desktop` copies
were retired on 2026-09-29 (kept in `.twilight/legacy/`); the environment file
does the same job.

## Icons, cursor, fonts, sounds

- Papirus Dark with folders in the palette's `PAPIRUS_FOLDER` colour (`Papirus-Twilight`)
- Catppuccin Mocha Lavender cursor
- Inter 11 (interface and documents), JetBrains Mono 11 (monospace), Sacramento
  (lock-screen date, also in `/usr/local/share/fonts/Twilight/` for GDM)
- Twilight sound theme

## Extensions

User Themes, Dash to Dock, Just Perfection, Caffeine (Fedora packages);
Burn My Windows, Clipboard Indicator, Tiling Shell, Weather O'Clock
(extensions.gnome.org); Rounded Windows and WACK (pinned git commits);
Background Logo.

- Dash to Dock: bottom, centred, 48 px icons, intelligent hiding, 88 % surface, hotkeys off
- Burn My Windows: restrained Glide profile only
- Clipboard Indicator: `open-at-cursor=true`, `Super+V`
- Weather O'Clock: weather after the clock in the centre pill
- Rounded Windows (`rounded-windows@marcosgt.github.io`) keeps Overview previews sharp
- Workspaces: dynamic, no names
- Battery percentage shown

## Lock and login screen

- WACK `wack-lockscreen-clock@rinzler69-wastaken.github.com`, 2.0.3 PRO, pinned to
  `d1d3209`, installed to `/usr/share/gnome-shell/extensions/` and enabled for GDM
  through `/etc/dconf/db/gdm.d/99-wack-lockscreen`.
- Settings: `lockscreen-mode='wack'`, fade clock, rise prompt, full date.
- Installer tweaks: clock at `LOCK_CLOCK_X` (0.76), top fraction 0.075, date height
  42, softer prompt/notification blur, 18 px notification cards, Twilight CSS in
  `stylesheet.css` and `src/pro/gdm.css`.
- The Fedora 44 / GDM 50 fix in `src/pro/gdmThemePipeline.js` is part of the pinned
  upstream commit; no local patch is needed.
- Sharp wallpaper at rest, blurred while authenticating, Esc returns to sharp.
- Known issue: with an extra monitor connected the WACK background can turn black;
  unplugging it restores normal behaviour.

## Keyboard shortcuts

```text
Super+T                       Ptyxis                      (Twilight)
Super+E                       Files                       (Twilight)
Super+Q                       Close window                (Twilight)
Super+V                       Clipboard                   (Twilight)
Super+M                       Notifications               (Twilight)
Super+Shift+C                 Caffeine                    (Twilight)
Super+Ctrl+Left/Right         Switch workspace            (Twilight)
Super+Ctrl+Shift+Left/Right   Move window to workspace    (Twilight)
Super+Shift+Left/Right        Move window to monitor      (GNOME default)
Super+Up/Down                 Maximise / restore          (Tiling Shell)
Super+L                       Lock                        (GNOME default)
Print                         Screenshot                  (GNOME default)
```

## Files, backups, repair

- Build workspace: `.twilight/` in the checkout (`src/`, `build/`, `state/`,
  `backups/`, `legacy/`). The checkout must stay in place.
- Each install backs up GTK config, Twilight files and a dconf dump to
  `.twilight/backups/` (ten newest kept).
- `twilight-heal.service` runs `install.sh --heal` at login.
- `install.sh --uninstall` removes Twilight (it backs up first). The old locations
  listed below are not touched.
- Older, pre-repository locations still on this machine and no longer used:
  `~/.local/share/theme-sources/`, `~/.local/share/desktop-backups/`,
  `~/.local/share/twilight/`.
