# Fedora Twilight — Failed, Removed, and Reverted Experiments

This file exists so future Codex/ChatGPT sessions do not repeat already-failed approaches.

## Blur My Shell

Status:

```text
removed / rejected
```

Reason:

- user prefers sharp UI
- blur did not fit the final visual direction

Do not reinstall unless explicitly requested.

## Old Rounded Window Corners Reborn

Extension:

```text
rounded-window-corners@fxgn
```

Status:

```text
removed
```

Problem:

- GNOME Overview previews became blurry / low quality

Replacement:

```text
rounded-windows@marcosgt.github.io
```

## Desktop clock widget (Desktop Widgets / azclock)

Status:

```text
removed
```

Reason:

- redundant with the chosen panel/clock setup

## Lockscreen Studio

Status:

```text
superseded
```

An earlier lock-screen restyle, replaced by WACK Sonoma Lockscreen.

## Editing Colloid inside `~/.themes`

Status:

```text
abandoned
```

Any theme rebuild silently lost the edits. All Twilight CSS is now layered between
markers (`~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css`, the Shell CSS)
and reapplied by `install.sh`.

## Named workspaces

Status:

```text
removed
```

Returned to dynamic workspaces.

## Power-profile helper

Status:

```text
removed / declined
```

A helper such as:

```text
~/.local/bin/power-mode
```

may have existed temporarily.

Do not restore it.

## Kitty / Fastfetch / Starship / Zsh experiment

Status:

```text
removed
```

Final terminal remains Ptyxis + Bash.

## Universal Twilight window-control overlay

Extension:

```text
twilight-window-controls@vaibhav.local
```

Status:

```text
removed
```

Removal:

```bash
gnome-extensions disable twilight-window-controls@vaibhav.local 2>/dev/null || true
rm -rf "$HOME/.local/share/gnome-shell/extensions/twilight-window-controls@vaibhav.local"
```

Reason:

- looked ugly
- native controls are preferred

## LibreOffice GTK3 recoloring

Status:

```text
failed / abandoned
```

`libreoffice-gtk3` was installed and several CSS approaches were tried.

Failed blocks included:

```text
/* ===== TWILIGHT GTK3 WINDOW BUTTONS ===== */
/* ===== TWILIGHT GTK3 IMAGE BUTTONS ===== */
/* ===== TWILIGHT GTK3 EXACT CONTROLS ===== */
```

Selectors inspected included:

```css
button.titlebutton:not(.suggested-action):not(.destructive-action)
button.minimize.titlebutton:not(.suggested-action):not(.destructive-action)
button.maximize.titlebutton:not(.suggested-action):not(.destructive-action)
button.close.titlebutton:not(.suggested-action):not(.destructive-action)
```

Even exact-selector overrides did not recolor LibreOffice's visible controls.

Do not repeat this route.

## LibreOffice GTK4 backend

Test:

```bash
SAL_USE_VCLPLUGIN=gtk4 libreoffice --calc &
```

Result:

- Twilight controls worked
- LibreOffice UI showed an ugly white/incorrect toolbar strip

Status:

```text
rejected
```

Do not make GTK4 the default LibreOffice backend.

## LibreOffice stock Qt6 / KF6

Tests:

```bash
SAL_USE_VCLPLUGIN=qt6 libreoffice --calc &
SAL_USE_VCLPLUGIN=kf6 libreoffice --calc &
```

Result:

- UI rendered correctly
- stock Qt Adwaita decoration produced dark controls

Status:

```text
superseded by custom QAdwaitaColorfulDecorations
```

## Early QAdwaita source patch attempts

Two automated source replacements failed safely.

Errors:

```text
Expected paintButton block was not found. Source has changed; nothing was modified.
```

and:

```text
Could not uniquely locate paintButton(); replacements=0. Nothing was written.
```

Successful strategy:

- inspect the actual source
- locate `paintButton()` by brace counting
- patch that exact function

## Qt titlebar white/dark issue

After the custom button patch worked:

- colored buttons were correct
- active titlebar became white
- inactive titlebar became too dark

Cause:

- titlebar background is painted separately from the control circles

Final fix:

```text
active background      #2C2E45
inactive background    #25273A
active border          #434553
inactive border        #34364D
active foreground      #F1EDF7
inactive foreground    #A6A3BD
```

## VS Code titlebar patch

Status:

```text
fully reverted
```

The visual patch worked, but editing `/usr/share/code` caused:

```text
installation appears corrupt
```

Reversion included:

- removing titlebar-related settings
- reinstalling VS Code with DNF
- deleting Twilight backup artifacts under `/usr/share/code/resources/app/out`
- removing temporary CSS

Do not patch VS Code installation files again.

## Chromium / Electron decoration flags

Tried on Brave and Discord:

```text
--enable-features=WaylandWindowDecorations
--use-system-title-bar
```

Status:

```text
rejected
```

Results were inconsistent. Brave was solved differently: its GTK theme mode
(`extensions.theme.system_theme = 1`) draws the Twilight GTK 4 buttons natively.

## Discord

Status:

```text
stock
```

Temporary inspection and launch flags were used.

No persistent changes remain.

## Firefox

Status:

```text
uninstalled intentionally
```

Do not include it in the final desktop setup.

## LibreOffice wrapper launchers

Status:

```text
retired (2026-09-29)
```

`~/.local/bin/libreoffice-twilight` and copies of the LibreOffice `.desktop` files
set the Qt variables per launch. They worked, but the copies hid updates to the
system launchers, and the session-wide `environment.d` file already sets the same
variables. Moved to `.twilight/legacy/`.
