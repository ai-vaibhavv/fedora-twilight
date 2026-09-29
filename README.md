# Fedora Twilight

A soft purple / blue / pink GNOME setup for Fedora, built around a dusk wallpaper,
and reproducible with one command. Recolour it for **your** wallpaper by changing
one file.

**Website:** https://ai-vaibhavv.github.io/fedora-twilight/

![Desktop](docs/screenshots/desktop.png)

![Lock screen](docs/screenshots/lockscreen.png)

## What you get

| Piece | What it does |
| --- | --- |
| **Colloid (Catppuccin) + Twilight top bar** | Transparent top bar with floating "pill" indicators |
| **Macaron window buttons** | Pink close, peach minimise, blue maximise; the symbol shows on hover. Works in GTK 3, GTK 4/libadwaita **and Qt/LibreOffice** |
| **Lock & login screen** | WACK Sonoma-style lock screen with a handwritten date and glass password field, also shown on the GDM login screen |
| **Icons & cursor** | Papirus Dark with violet folders, Catppuccin Mocha Lavender cursor |
| **Shell extensions** | Dash to Dock, Just Perfection, Tiling Shell, Rounded Windows, Burn My Windows (glide), Clipboard Indicator, Caffeine, Weather O'Clock |
| **Shortcuts** | `Super+T` terminal, `Super+E` Files, `Super+Q` close, `Super+V` clipboard, `Super+M` notifications, `Super+Ctrl+←/→` workspaces (add `Shift` to move the window), `Super+Shift+C` caffeine. Edit them in [`dconf/shortcuts.ini`](dconf/shortcuts.ini) |
| **Fonts & sounds** | Inter, JetBrains Mono, Sacramento; a soft "Twilight" sound theme |
| **Self-repair** | A small login service puts back anything an update undid |

## Install

Fedora Workstation 44 (GNOME 50) was used to build and test this.

```bash
sudo dnf install git python3 python3-pillow rsync
git clone https://github.com/ai-vaibhavv/fedora-twilight.git
cd fedora-twilight
./install.sh --wallpaper ~/Pictures/your-wallpaper.jpg --auto-palette --dry-run
./install.sh --wallpaper ~/Pictures/your-wallpaper.jpg --auto-palette
```

Run from a terminal in your GNOME session, as your normal user. The first command
previews the steps without changing anything; the second installs. It needs network
access and asks for sudo for packages, system fonts and the login-screen extension.
Log out and back in, then run `./install.sh --check`.

The installer changes appearance settings and, in the shortcuts step, built-in key
bindings. Conflicting custom launcher shortcuts are preserved. Use `--only` to
choose components; `--no-sudo` skips packages and login-screen installation (required
packages must already be installed).

### Make it yours

Use `--wallpaper FILE --auto-palette` to extract colours and install in one command.
Omit `--auto-palette` to use the repository's `palette.conf` instead. Generating during
installation saves the palette in `.twilight/palette.conf`; it does not
edit the checkout. Repeat the same command for a new wallpaper. Re-running from the
checkout without `--auto-palette` restores the checkout's palette. Use
`--keep-palette` for partial reinstalls that should keep your generated colours.

Changing the wallpaper in GNOME Settings alone **does not recolour Twilight**.
There is no background watcher. Colours apply to Twilight's custom surfaces,
controls and lock-screen styles; Colloid, folder icons and GNOME accents use the
nearest available named variant. The cursor stays lavender, the theme stays dark,
and apps with their own styling may not follow it. The clock position remains a
manual `LOCK_CLOCK_X` setting; colour extraction cannot detect the wallpaper subject.

To preview colours or save a palette for manual editing:

```bash
./scripts/palette-from-wallpaper.py ~/Pictures/your-wallpaper.jpg           # preview
./scripts/palette-from-wallpaper.py ~/Pictures/your-wallpaper.jpg --write   # save to palette.conf
./install.sh --wallpaper ~/Pictures/your-wallpaper.jpg
```

Every colour lives in [`palette.conf`](palette.conf); edit it by hand to fine-tune,
then re-run `./install.sh`. You can also re-run single parts:

```bash
./install.sh --list                  # packages theme gtk icons cursor fonts sounds extensions qt lockscreen settings shortcuts heal
./install.sh --keep-palette --only gtk,qt # reapply current window-button colours
./install.sh --no-sudo               # everything that doesn't need root
```

### Where files live

All upstream checkouts, builds, downloads, temporary build files, state, generated
palettes and backups stay in the ignored `.twilight/` directory inside this repo.
GNOME still loads installed assets from `~/.themes`, `~/.config` and `~/.local`;
the login extension and system fonts require system installation. Those are
installation destinations, not build directories. The repair service runs the
installer from this checkout: **keep the repo in place**. After moving it, run
`./install.sh --keep-palette --only heal` to update the service path.
Older installations may still have a previous workspace at
`~/.local/share/twilight`; this installer no longer builds there.

### Backups and recovery

Before installation, user GTK configuration, Twilight's environment and service
files, Burn My Windows configuration, the installed palette and a dconf snapshot
are saved under `.twilight/backups/<timestamp>-<pid>/`.
This is a configuration backup, **not a complete uninstall or a backup of system
packages/GDM**. Keep the printed path. To recover a particular file, copy its
matching backup back into your home directory. Stop self-repair before recovering:

```bash
systemctl --user disable --now twilight-heal.service
```

The `dconf.ini` snapshot contains all your dconf preferences. Inspect it first;
`dconf load / < /path/to/backup/dconf.ini` restores saved keys but also overwrites
later preference changes and does not remove newly added keys. Full automatic
rollback, including GDM, is not implemented.

## Verify

```bash
./install.sh --check
```

Compares rendered Shell/GTK/lock/login colours with the active palette and
prints a ✓/✗ line for every piece (theme, buttons, Qt plugin, fonts, lock/login screen,
extensions, self-repair) and tells you the exact command that fixes each ✗.

For local checks that do not change the desktop:

```bash
./install.sh --dry-run
python3 -m unittest discover -s tests -v
```

For the full reinstall test, install Fedora Workstation in a GNOME Boxes VM, clone the repo
there, run `./install.sh`, log out and back in, then run `./install.sh --check`.

## Update resilience and limitations

Most "rice" guides edit files that the next update overwrites. Twilight avoids that:

- **Upstream projects are pinned** (exact commits of Colloid, QAdwaitaColorfulDecorations,
  WACK lockscreen, Rounded Windows), to reduce upstream drift. Fedora packages and extension-store downloads still change;
  new GNOME/Qt releases require testing.
- **Edits are layered, not patched in place.** GTK 3 buttons live in `~/.config/gtk-3.0/gtk.css`,
  which GTK applies on top of *any* theme. The Shell and GTK 4 tweaks are appended between
  `/* >>> fedora-twilight >>> */` markers, which the installer can re-apply any number of times.
- **Nothing in `/usr` that dnf owns is modified.** The login-screen extension lives in a
  directory no package owns, and fonts go in `/usr/local`.
- **`twilight-heal.service`** runs at every login and:
  - rebuilds the Qt title-bar plugin when `qt6-qtbase`/`qt6-qtwayland` update (the plugin uses
    Qt private APIs and must match the exact Qt build);
  - restores the theme or GTK button styles if something replaced them;
  - notifies you if the login-screen styling is gone or an extension stopped working after a
    GNOME upgrade.

  Check it with `journalctl --user -u twilight-heal`.

## Reinstalling Fedora

1. Install Fedora Workstation, enable RPM Fusion if you use it.
2. `git clone` this repo and run `./install.sh --wallpaper …`.
3. Optional: reinstall your apps with `sudo dnf install $(cat packages/dnf-all.txt)` and
   `flatpak install $(cat packages/flatpak.txt)`.

## Heads-up for the next Fedora release

The WACK lock screen currently declares support up to GNOME 50. When Fedora moves to
GNOME 51, the lock screen falls back to GNOME's default until WACK publishes an update;
bump `WACK_REF` in `install.sh` then and re-run `./install.sh --only lockscreen`. Your login still
works in the meantime. The heal service will tell you when this happens.

## Credits

- Wallpaper: illustration by **Rajie** (signed on the artwork); not redistributed here, please support the artist.
- [Colloid GTK theme](https://github.com/vinceliuice/Colloid-gtk-theme) by vinceliuice (GPL-3.0)
- [QAdwaitaColorfulDecorations](https://github.com/acd407/QAdwaitaColorfulDecorations) (LGPL-2.1)
- [WACK Sonoma Lockscreen](https://github.com/rinzler69-wastaken/wack-sonoma-lockscreen) by rinzler69-wastaken
- [Rounded Windows](https://github.com/Nathanaelrc/rounded-windows), [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme),
  [Catppuccin cursors](https://github.com/catppuccin/cursors), [Sacramento](https://fonts.google.com/specimen/Sacramento) (OFL)
- The build history, including what didn't work, is in [JOURNEY.md](JOURNEY.md).

Scripts and templates in this repository: MIT.
