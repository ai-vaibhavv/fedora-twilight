# Fedora Twilight

A soft purple / blue / pink GNOME setup for Fedora, built around a dusk wallpaper,
and reproducible with one command. Recolour it for **your** wallpaper by changing
one file.

**Website:** https://ai-vaibhavv.github.io/fedora-twilight/

![Desktop](docs/screenshots/desktop.png)

## What you get

| Piece | What it does |
| --- | --- |
| **Colloid (Catppuccin) + Twilight top bar** | Transparent top bar with floating "pill" indicators |
| **Macaron window buttons** | Pink close, peach minimise, blue maximise; the symbol shows on hover. Works in GTK 3, GTK 4/libadwaita **and Qt/LibreOffice** |
| **Lock & login screen** | WACK Sonoma-style lock screen with a handwritten date and glass password field, also shown on the GDM login screen |
| **Icons & cursor** | Papirus Dark with violet folders, Catppuccin Mocha Lavender cursor |
| **Shell extensions** | Dash to Dock, Just Perfection, Tiling Shell, Rounded Windows, Burn My Windows (glide), Clipboard Indicator, Caffeine, Weather O'Clock |
| **Fonts & sounds** | Inter, JetBrains Mono, Sacramento; a soft "Twilight" sound theme |
| **Self-repair** | A small login service puts back anything an update undid |

## Install

Fedora Workstation 44 (GNOME 50) was used to build and test this.

```bash
git clone https://github.com/ai-vaibhavv/fedora-twilight.git
cd fedora-twilight
./install.sh --wallpaper ~/Pictures/your-wallpaper.jpg
```

Log out and back in. That's it. The script asks for your password when it installs
packages and the login-screen extension.

### Make it yours

```bash
./scripts/palette-from-wallpaper.py ~/Pictures/your-wallpaper.jpg           # preview
./scripts/palette-from-wallpaper.py ~/Pictures/your-wallpaper.jpg --write   # save to palette.conf
./install.sh --wallpaper ~/Pictures/your-wallpaper.jpg
```

Every colour lives in [`palette.conf`](palette.conf); edit it by hand to fine-tune,
then re-run `./install.sh`. You can also re-run single parts:

```bash
./install.sh --list                  # packages theme gtk icons cursor fonts sounds extensions qt lockscreen settings heal
./install.sh --only gtk,qt           # just re-colour the window buttons
./install.sh --no-sudo               # everything that doesn't need root
```

## Why it won't break after updates

Most "rice" guides edit files that the next update overwrites. Twilight avoids that:

- **Upstream projects are pinned** (exact commits of Colloid, QAdwaitaColorfulDecorations,
  WACK lockscreen, Rounded Windows), so a re-install gives the same result a year from now.
- **Edits are layered, not patched in place.** GTK 3 buttons live in `~/.config/gtk-3.0/gtk.css`,
  which GTK applies on top of *any* theme. The Shell and GTK 4 tweaks are appended between
  `/* >>> fedora-twilight >>> */` markers, which the installer can re-apply any number of times.
- **Nothing in `/usr` that dnf owns is modified.** The login-screen extension lives in a
  directory no package owns, and fonts go in `/usr/local`.
- **`twilight-heal.service`** runs at every login (in under a second when nothing changed) and:
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
