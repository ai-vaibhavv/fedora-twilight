#!/usr/bin/env bash
# Twilight for Fedora GNOME: one idempotent installer.
#
#   ./install.sh                       install / re-apply everything
#   ./install.sh --wallpaper FILE      also set FILE as desktop wallpaper
#   ./install.sh --wallpaper FILE --auto-palette  match colours to FILE
#   ./install.sh --keep-palette        reuse the last applied palette
#   ./install.sh --dry-run             preview steps without changing anything
#   ./install.sh --only gtk,qt         run selected steps only
#   ./install.sh --no-sudo             skip steps that need root
#   ./install.sh --check               verify every piece is installed and active
#   ./install.sh --heal                quiet self-repair (run at every login)
#   ./install.sh --list                show steps
#
# Safe to re-run at any time. Edit palette.conf and re-run to recolour.

set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DATA="$REPO"                                # scripts and templates stay in the checkout
WORK="$REPO/.twilight"                      # ignored local workspace
SRC="$WORK/src"
BUILD="$WORK/build"
STATE="$WORK/state"
ACTIVE_PALETTE="$WORK/palette.conf"

# Upstream projects, pinned to the commits Twilight was built and tested on.
COLLOID_URL=https://github.com/vinceliuice/Colloid-gtk-theme.git
COLLOID_REF=6c2dc65865628bda9fdc8157a30cd5eda6fd41f9
QADW_URL=https://github.com/acd407/QAdwaitaColorfulDecorations.git
QADW_REF=7ba31cfca08f12e72aca94fff87f46a042a73b9a
WACK_URL=https://github.com/rinzler69-wastaken/wack-sonoma-lockscreen.git
WACK_REF=d1d3209bb71c5f05427f8c71e10e4874f3a89e12
WACK_UUID=wack-lockscreen-clock@rinzler69-wastaken.github.com
ROUNDED_URL=https://github.com/Nathanaelrc/rounded-windows.git
ROUNDED_REF=9d9eb77013b24e45ae75fc92a85a9b6d82e052f6
ROUNDED_UUID=rounded-windows@marcosgt.github.io
CURSOR_VERSION=v2.0.0

THEME_NAME=Colloid-Twilight-Dark

# Extensions that Fedora packages (they update with the system, so prefer them).
DNF_EXTENSIONS=(
  user-theme@gnome-shell-extensions.gcampax.github.com
  dash-to-dock@micxgx.gmail.com
  just-perfection-desktop@just-perfection
  caffeine@patapon.info
)
# Extensions fetched from extensions.gnome.org.
EGO_EXTENSIONS=(
  burn-my-windows@schneegans.github.com
  clipboard-indicator@tudmotu.com
  tilingshell@ferrarodomenico.com
  weatheroclock@CleoMenezesJr.github.io
)

PACKAGES=(
  git curl unzip rsync python3 python3-pillow sassc gtk-murrine-engine glib2-devel
  gnome-tweaks gnome-extensions-app
  gnome-shell-extension-user-theme gnome-shell-extension-dash-to-dock
  gnome-shell-extension-just-perfection gnome-shell-extension-caffeine
  rsms-inter-fonts jetbrains-mono-fonts papirus-icon-theme-dark
  cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel
  qt6-qtsvg-devel qt6-qtwayland-devel
  libreoffice-kf6 libnotify
)

ALL_STEPS=(packages theme gtk icons cursor fonts sounds extensions qt lockscreen settings shortcuts heal)
ROOT_STEPS=" packages lockscreen "

# ---------------------------------------------------------------- helpers ---

if [[ -t 1 ]]; then B=$'\e[1m'; P=$'\e[35m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B= P= Y= R= N=; fi
HEAL=false
say()  { $HEAL || echo "${P}${B}::${N} $*"; }
warn() { echo "${Y}!!${N} $*" >&2; }
die()  { echo "${R}xx${N} $*" >&2; exit 1; }

notify() {
  warn "$*"
  command -v notify-send >/dev/null && notify-send -a Twilight -i preferences-desktop-theme "Twilight" "$*" || true
}

# ERR trap: print the failing command and the function stack that led to it.
# set -E makes functions and subshells inherit it.
trace() {
  local rc=$? i
  warn "Failed (exit $rc): $BASH_COMMAND"
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    warn "  at ${FUNCNAME[i]} (${BASH_SOURCE[i]##*/}:${BASH_LINENO[i-1]})"
  done
}

render() { python3 "$DATA/scripts/render.py" "$ACTIVE_PALETTE" "$1" "${2:-}"; }

# upsert_block FILE CONTENT_FILE: put CONTENT between Twilight markers in FILE,
# replacing any previous copy and leaving the rest of FILE untouched.
upsert_block() {
  local file=$1 content=$2 tmp
  local start='/* >>> fedora-twilight >>> */' end='/* <<< fedora-twilight <<< */'
  mkdir -p "$(dirname "$file")"; touch "$file"
  tmp=$(mktemp)
  awk -v s="$start" -v e="$end" '$0==s{skip=1;next} $0==e{skip=0;next} !skip' "$file" > "$tmp"
  { cat "$tmp"; echo "$start"; cat "$content"; echo "$end"; } > "$file"
  rm -f "$tmp"
}

has_block() { grep -qF '/* >>> fedora-twilight >>> */' "$1" 2>/dev/null; }

# checkout NAME URL REF: clone or update an upstream repo at a pinned commit.
checkout() {
  local dir="$SRC/$1"
  if [[ ! -d "$dir/.git" ]]; then
    git clone --quiet "$2" "$dir"
  fi
  git -C "$dir" fetch --quiet origin 2>/dev/null || true
  git -C "$dir" checkout --quiet --force "$3"
  git -C "$dir" clean --quiet -fdx
}

shell_major() { gnome-shell --version | grep -oE '[0-9]+' | head -1; }

# -------------------------------------------------------------------- steps ---

step_packages() {
  say "Installing packages (dnf)…"
  sudo dnf install -y "${PACKAGES[@]}"
  if command -v flatpak >/dev/null; then
    flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager || true
  fi
}

step_theme() {
  say "Building Colloid ($COLLOID_COLOR, dark, ${COLLOID_TWEAKS:-no tweaks}) and adding the Twilight top bar…"
  checkout Colloid-gtk-theme "$COLLOID_URL" "$COLLOID_REF"
  local stage="$BUILD/colloid" args=(-d "$BUILD/colloid" -t "$COLLOID_COLOR" -c dark)
  [[ -n "${COLLOID_TWEAKS:-}" ]] && args+=(--tweaks $COLLOID_TWEAKS)
  rm -rf "$stage"; mkdir -p "$stage"
  (cd "$SRC/Colloid-gtk-theme" && ./install.sh "${args[@]}" >/dev/null)

  local built
  built=$(find "$stage" -mindepth 1 -maxdepth 1 -type d -name 'Colloid*Dark*' ! -name '*hdpi' | head -1)
  [[ -n "$built" ]] || die "Colloid build produced no theme in $stage"

  local dest="$HOME/.themes/$THEME_NAME"
  rm -rf "$dest"; mkdir -p "$HOME/.themes"; cp -a "$built" "$dest"
  sed -i "s/^Name=.*/Name=$THEME_NAME/; s/^GtkTheme=.*/GtkTheme=$THEME_NAME/; s/^MetacityTheme=.*/MetacityTheme=$THEME_NAME/" "$dest/index.theme"

  render "$DATA/templates/gnome-shell/twilight.css" "$BUILD/shell.css"
  upsert_block "$dest/gnome-shell/gnome-shell.css" "$BUILD/shell.css"

  # libadwaita (GTK 4) apps read ~/.config/gtk-4.0 instead of the theme folder.
  # Colloid's CSS goes first, between its own markers; anything else the user
  # keeps in gtk.css stays after it, and step_gtk adds Twilight's block last.
  local gtk4="$HOME/.config/gtk-4.0/gtk.css" rest
  local start='/* >>> colloid (managed by fedora-twilight) >>> */' end='/* <<< colloid (managed by fedora-twilight) <<< */'
  mkdir -p "$HOME/.config/gtk-4.0"
  rm -rf "$HOME/.config/gtk-4.0/assets"
  cp -a "$dest/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
  rest=$(mktemp)
  # Before these markers existed the whole file was Colloid's, so there is
  # nothing of the user's to carry over.
  if grep -qxF "$start" "$gtk4" 2>/dev/null; then
    awk -v s="$start" -v e="$end" '$0==s{skip=1;next} $0==e{skip=0;next} !skip' "$gtk4" > "$rest"
  fi
  { echo "$start"; cat "$dest/gtk-4.0/gtk.css"; echo "$end"; cat "$rest"; } > "$gtk4"
  rm -f "$rest"
  step_gtk
}

step_gtk() {
  say "Applying Twilight window buttons to GTK 3 and GTK 4…"
  render "$DATA/templates/gtk-3.0/twilight.css" "$BUILD/gtk3.css"
  render "$DATA/templates/gtk-4.0/twilight.css" "$BUILD/gtk4.css"
  # GTK 3 layers ~/.config/gtk-3.0/gtk.css over any theme, so updates can't remove it.
  upsert_block "$HOME/.config/gtk-3.0/gtk.css" "$BUILD/gtk3.css"
  upsert_block "$HOME/.config/gtk-4.0/gtk.css" "$BUILD/gtk4.css"
  # Flatpak apps are sandboxed from ~/.config; let them read these two folders.
  if command -v flatpak >/dev/null; then
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
  fi
}

step_icons() {
  say "Creating Papirus-Twilight ($PAPIRUS_FOLDER folders) and Twilight-Controls…"
  local papirus=/usr/share/icons/Papirus/48x48/places
  [[ -d $papirus ]] || die "Papirus is not installed (run the 'packages' step)."
  local out="$HOME/.local/share/icons/Papirus-Twilight"
  rm -rf "$out"; mkdir -p "$out/scalable/places"
  local f name
  for f in "$papirus"/{folder,user}-"$PAPIRUS_FOLDER"*.svg; do
    [[ -e $f ]] || continue
    name=$(basename "$f"); name=${name/-$PAPIRUS_FOLDER/}
    cp -L "$f" "$out/scalable/places/$name"
  done
  cat > "$out/index.theme" <<EOF
[Icon Theme]
Name=Papirus Twilight
Comment=$PAPIRUS_FOLDER folders with Papirus Dark application icons
Inherits=Papirus-Dark,hicolor
Directories=scalable/places
Example=folder

[scalable/places]
Size=48
Type=Scalable
MinSize=16
MaxSize=512
Context=Places
EOF
  rm -rf "$HOME/.local/share/icons/Twilight-Controls"
  cp -a "$DATA/files/icons/Twilight-Controls" "$HOME/.local/share/icons/"
  gtk-update-icon-cache -qf "$out" 2>/dev/null || true
  gtk-update-icon-cache -qf "$HOME/.local/share/icons/Twilight-Controls" 2>/dev/null || true
}

step_cursor() {
  if [[ -d $HOME/.local/share/icons/$CURSOR || -d $HOME/.icons/$CURSOR ]]; then
    say "Cursor $CURSOR already installed."; return
  fi
  say "Downloading cursor $CURSOR ($CURSOR_VERSION)…"
  local zip; zip=$(mktemp --suffix=.zip)
  curl -fsSL -o "$zip" "https://github.com/catppuccin/cursors/releases/download/$CURSOR_VERSION/$CURSOR.zip"
  mkdir -p "$HOME/.local/share/icons"
  unzip -qo "$zip" -d "$HOME/.local/share/icons"
  rm -f "$zip"
}

step_fonts() {
  say "Installing Sacramento (handwritten date font)…"
  mkdir -p "$HOME/.local/share/fonts/Twilight"
  cp "$DATA/files/fonts/"* "$HOME/.local/share/fonts/Twilight/"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null
  # The login screen runs as the gdm user, so it needs a system-wide copy.
  if ! $NO_SUDO && [[ ! -f /usr/local/share/fonts/Twilight/Sacramento-Regular.ttf ]]; then
    sudo install -Dm644 "$DATA/files/fonts/Sacramento-Regular.ttf" /usr/local/share/fonts/Twilight/Sacramento-Regular.ttf
    sudo install -Dm644 "$DATA/files/fonts/Sacramento-OFL.txt" /usr/local/share/fonts/Twilight/Sacramento-OFL.txt
    sudo fc-cache -f /usr/local/share/fonts >/dev/null
  fi
}

step_sounds() {
  say "Installing the Twilight sound theme…"
  mkdir -p "$HOME/.local/share/sounds"
  rm -rf "$HOME/.local/share/sounds/Twilight"
  cp -a "$DATA/files/sounds/Twilight" "$HOME/.local/share/sounds/"
}

ego_install() {
  local uuid=$1 ver url zip
  ver=$(shell_major)
  url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$ver" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("download_url",""))' 2>/dev/null) || true
  if [[ -z $url ]]; then
    warn "$uuid has no release for GNOME $ver yet; skipping."
    return
  fi
  zip=$(mktemp --suffix=.zip)
  curl -fsSL -o "$zip" "https://extensions.gnome.org$url"
  gnome-extensions install --force "$zip"
  rm -f "$zip"
}

step_extensions() {
  say "Installing GNOME extensions…"
  local uuid
  for uuid in "${EGO_EXTENSIONS[@]}"; do
    if [[ -d $HOME/.local/share/gnome-shell/extensions/$uuid ]]; then
      say "  $uuid already installed (updates come through Extension Manager)"
    else
      say "  $uuid"; ego_install "$uuid"
    fi
  done

  say "  $ROUNDED_UUID (from git)"
  checkout rounded-windows "$ROUNDED_URL" "$ROUNDED_REF"
  local dest="$HOME/.local/share/gnome-shell/extensions/$ROUNDED_UUID"
  mkdir -p "$dest"
  rsync -a --delete --exclude .git "$SRC/rounded-windows/" "$dest/"
  glib-compile-schemas "$dest/schemas"

  # A copy in ~/.local wins over the Fedora package; that's fine as long as
  # Extension Manager keeps it updated, but worth knowing after a GNOME upgrade.
  for uuid in "${DNF_EXTENSIONS[@]}"; do
    if [[ -d $HOME/.local/share/gnome-shell/extensions/$uuid && -d /usr/share/gnome-shell/extensions/$uuid ]]; then
      say "  note: $uuid in ~/.local overrides the Fedora package (update it via Extension Manager)"
    fi
  done

  mkdir -p "$HOME/.config/burn-my-windows/profiles"
  cp "$DATA/files/burn-my-windows/twilight-glide.conf" "$HOME/.config/burn-my-windows/profiles/"
}

step_qt() {
  say "Building colourful Qt title bars (QAdwaitaColorfulDecorations + Twilight patch)…"
  checkout QAdwaitaColorfulDecorations "$QADW_URL" "$QADW_REF"
  render "$DATA/templates/qt/qadwaita-twilight.patch" "$BUILD/qadwaita-twilight.patch"
  git -C "$SRC/QAdwaitaColorfulDecorations" apply "$BUILD/qadwaita-twilight.patch"
  local b="$SRC/QAdwaitaColorfulDecorations/build"
  cmake -S "$SRC/QAdwaitaColorfulDecorations" -B "$b" -G Ninja \
        -DUSE_QT6=ON -DHAS_QT6_SUPPORT=ON -DCMAKE_BUILD_TYPE=Release -DQT_NO_PRIVATE_MODULE_WARNING=ON >/dev/null
  cmake --build "$b" >/dev/null
  local so; so=$(find "$b" -name 'libqadwaitadecorations.so' | head -1)
  [[ -n $so ]] || die "Qt plugin build produced no libqadwaitadecorations.so"
  install -Dm755 "$so" "$HOME/.local/lib/qt6/plugins/wayland-decoration-client/libqadwaitadecorations.so"
  mkdir -p "$STATE"; rpm -q qt6-qtbase qt6-qtwayland > "$STATE/qt-built-against"

  mkdir -p "$HOME/.config/environment.d"
  cp "$DATA/files/environment.d/90-twilight-qt.conf" "$HOME/.config/environment.d/"
}

step_lockscreen() {
  say "Installing the WACK lock screen with Twilight styling (also used by GDM)…"
  checkout wack-sonoma-lockscreen "$WACK_URL" "$WACK_REF"
  local w="$SRC/wack-sonoma-lockscreen"

  # Twilight layout tweaks. Each edit is checked so upstream changes are noticed.
  set_const() { # FILE NAME VALUE
    sed -i -E "s/^(export const $2 = )[^;]+;/\1$3;/" "$w/$1"
    grep -qE "^export const $2 = $3;" "$w/$1" || warn "Could not set $2 in $1 (upstream changed?)"
  }
  set_const src/main/constants.js DATETIME_TOP_FRACTION 0.075
  set_const src/main/constants.js DATE_LABEL_HEIGHT 42
  set_const src/main/constants.js PROMPT_BLUR_RADIUS 38
  set_const src/main/constants.js PROMPT_BLUR_BRIGHTNESS 0.92
  set_const src/main/constants.js NOTIF_BLUR_RADIUS 30
  set_const src/main/constants.js NOTIF_BLUR_BRIGHTNESS 0.94
  set_const src/main/constants.js NOTIF_CARD_RADIUS 18
  set_const src/pro/gdmUtils.js GDM_DATETIME_TOP_FRACTION 0.075
  sed -i "/^export function centerClockLabel/,/^}/ s/factor: [0-9.]*,/factor: $LOCK_CLOCK_X,/" "$w/src/main/constants.js"

  render "$DATA/templates/lockscreen/stylesheet.css" "$BUILD/lock.css"
  render "$DATA/templates/lockscreen/gdm.css" "$BUILD/gdm.css"
  upsert_block "$w/stylesheet.css" "$BUILD/lock.css"
  upsert_block "$w/src/pro/gdm.css" "$BUILD/gdm.css"
  glib-compile-schemas "$w/schemas"

  local target="/usr/share/gnome-shell/extensions/$WACK_UUID"
  sudo mkdir -p "$target"
  sudo rsync -a --delete --no-owner --no-group \
       --exclude .git --exclude gnome-shell --exclude screenshots "$w/" "$target/"
  sudo chown -R root:root "$target"
  sudo find "$target" -type d -exec chmod 755 {} +
  sudo find "$target" -type f -exec chmod 644 {} +
  sudo find "$target/scripts" -name '*.sh' -exec chmod 755 {} + 2>/dev/null || true

  # Enable it for the login screen (gdm user).
  sudo mkdir -p /etc/dconf/db/gdm.d
  printf '[org/gnome/shell]\nenabled-extensions=[%s]\ndisable-user-extensions=false\n' "'$WACK_UUID'" \
    | sudo tee /etc/dconf/db/gdm.d/99-wack-lockscreen >/dev/null
  sudo dconf update
  rpm -q gnome-shell > "$STATE/lockscreen-built-against" 2>/dev/null || true
}

step_settings() {
  say "Applying GNOME settings…"
  render "$DATA/dconf/twilight.ini" "$BUILD/dconf.ini"
  dconf load / < "$BUILD/dconf.ini"
  gsettings set org.gnome.shell.extensions.burn-my-windows active-profile \
    "$HOME/.config/burn-my-windows/profiles/twilight-glide.conf" 2>/dev/null || true
  step_settings_ptyxis

  local want=(background-logo@fedorahosted.org "${DNF_EXTENSIONS[@]}" "${EGO_EXTENSIONS[@]}" "$ROUNDED_UUID" "$WACK_UUID")
  python3 - "${want[@]}" <<'PY'
import ast, subprocess, sys
cur = ast.literal_eval(subprocess.run(["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
                                      capture_output=True, text=True).stdout.replace("@as ", "") or "[]")
for u in sys.argv[1:]:
    if u not in cur:
        cur.append(u)
subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(cur)], check=True)
PY

  if [[ -n $WALLPAPER ]]; then
    local dest="$HOME/.local/share/backgrounds/twilight-$(basename "$WALLPAPER")" uri
    [[ $WALLPAPER == "$dest" ]] || install -Dm644 "$WALLPAPER" "$dest"
    uri=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).as_uri())' "$dest")
    gsettings set org.gnome.desktop.background picture-uri "$uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
    gsettings set org.gnome.desktop.screensaver picture-uri "$uri"
  fi
}

# Ptyxis: Twilight palette, slight transparency and line spacing on the
# default profile. Profiles live under their UUID, so find (or create) it.
step_settings_ptyxis() {
  gsettings list-schemas | grep -x org.gnome.Ptyxis >/dev/null || return 0
  render "$DATA/templates/ptyxis/twilight.palette" "$HOME/.local/share/org.gnome.Ptyxis/palettes/twilight.palette"
  local uuid profile
  uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")
  if [[ -z $uuid ]]; then
    uuid=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
    gsettings set org.gnome.Ptyxis profile-uuids "['$uuid']"
    gsettings set org.gnome.Ptyxis default-profile-uuid "$uuid"
  fi
  profile="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$uuid/"
  gsettings set "$profile" palette twilight
  gsettings set "$profile" opacity 0.94
  gsettings set "$profile" cell-height-scale 1.1
}

# App launchers: NAME|BINDING|COMMAND. Stored under their own dconf paths so a
# user's existing custom shortcuts are never overwritten.
LAUNCHERS=(
  "Open Terminal|<Super>t|ptyxis"
  "Open Files|<Super>e|nautilus --new-window"
)

step_shortcuts() {
  say "Applying keyboard shortcuts…"
  dconf load / < "$DATA/dconf/shortcuts.ini"
  python3 - "${LAUNCHERS[@]}" <<'PY2'
import ast, re, subprocess, sys

BASE = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
SCHEMA = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

def get(schema, key, path=None):
    s = f"{schema}:{path}" if path else schema
    out = subprocess.run(["gsettings", "get", s, key], capture_output=True, text=True).stdout.strip()
    return ast.literal_eval(out.replace("@as ", "")) if out else ""

def put(schema, key, value, path=None):
    s = f"{schema}:{path}" if path else schema
    subprocess.run(["gsettings", "set", s, key, value if isinstance(value, str) else str(value)], check=True)

paths = get("org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings") or []
ours = []
for spec in sys.argv[1:]:
    name, binding, command = spec.split("|", 2)
    path = BASE + "twilight-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") + "/"
    ours.append(path)
    # Preserve existing bindings; let the user resolve conflicts in Settings.
    for p in list(paths):
        if p not in ours and get(SCHEMA, "binding", p) == binding:
            print(f"Keeping existing shortcut {binding}; skipped {name}.", file=sys.stderr)
            break
    else:
        p = None
    if p is not None and p not in ours:
        continue
    for key, val in (("name", name), ("command", command), ("binding", binding)):
        subprocess.run(["gsettings", "set", f"{SCHEMA}:{path}", key, val], check=True)
    if path not in paths:
        paths.append(path)
put("org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings", paths)
PY2
}

step_heal() {
  say "Installing the login-time self-repair service…"
  mkdir -p "$HOME/.config/systemd/user"
  python3 - "$REPO" "$DATA/files/systemd/twilight-heal.service" "$HOME/.config/systemd/user/twilight-heal.service" <<'PYUNIT'
from pathlib import Path
import sys
repo, template, destination = sys.argv[1:]
# Escape systemd quoted arguments and literal percent specifiers.
executable = (repo + "/install.sh").replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%")
Path(destination).write_text(Path(template).read_text().replace("@INSTALLER@", executable))
PYUNIT
  systemctl --user daemon-reload
  systemctl --user enable twilight-heal.service >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------ healing ---

# Runs at every login. Never asks for a password; only rebuilds user-level
# pieces and sends a desktop notification for anything that needs root.
heal() {
  local changed=()

  if [[ ! -f $HOME/.local/lib/qt6/plugins/wayland-decoration-client/libqadwaitadecorations.so ]] ||
     [[ "$(rpm -q qt6-qtbase qt6-qtwayland)" != "$(cat "$STATE/qt-built-against" 2>/dev/null || true)" ]]; then
    if "$DATA/install.sh" --keep-palette --only qt >"$STATE/qt-build.log" 2>&1; then changed+=("Qt title bars rebuilt for $(rpm -q qt6-qtbase)")
    else notify "Qt title-bar rebuild failed; see $STATE/qt-build.log"; fi
  fi

  if [[ ! -d $HOME/.themes/$THEME_NAME ]] || ! has_block "$HOME/.themes/$THEME_NAME/gnome-shell/gnome-shell.css"; then
    if "$DATA/install.sh" --keep-palette --only theme >"$STATE/theme-build.log" 2>&1; then changed+=("GNOME Shell theme restored")
    else notify "Theme rebuild failed; see $STATE/theme-build.log"; fi
  elif ! has_block "$HOME/.config/gtk-4.0/gtk.css" || ! has_block "$HOME/.config/gtk-3.0/gtk.css"; then
    "$DATA/install.sh" --keep-palette --only gtk >/dev/null 2>&1 && changed+=("GTK window buttons restored")
  fi

  local w="/usr/share/gnome-shell/extensions/$WACK_UUID"
  if [[ ! -d $w ]] || ! has_block "$w/stylesheet.css"; then
    notify "The Twilight lock/login screen styling is missing (not installed yet, or an update replaced it). Run: $DATA/install.sh --keep-palette --only lockscreen"
  fi

  local ver uuid state
  ver=$(shell_major)
  for uuid in $(gsettings get org.gnome.shell enabled-extensions | tr -d "[]',"); do
    state=$(gnome-extensions info "$uuid" 2>/dev/null | awk -F': ' '/State/{print $2}' || true)
    case $state in
      ERROR|OUT\ OF\ DATE|OUT_OF_DATE)
        notify "Extension $uuid is $state on GNOME $ver. Update it in Extension Manager." ;;
    esac
  done

  if ((${#changed[@]})); then
    notify "$(IFS=';'; echo "${changed[*]}"). Log out and back in to see every change."
  fi
}

# ------------------------------------------------------------------ checking ---

# Read-only report of every piece. Exit code = number of failures.
check() {
  local fails=0 g e
  ok()   { printf '  %s✓%s %s\n' "$P" "$N" "$1"; }
  bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$1"; [[ -n ${2:-} ]] && printf '      → %s\n' "$2"; fails=$((fails+1)); }
  t()    { local desc=$1 fix=$2; shift 2; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc" "$fix"; fi; }
  gs()   { [[ "$(gsettings get "$1" "$2" 2>/dev/null)" == "'$3'" ]]; }
  run()  { echo "$DATA/install.sh --keep-palette --only $1"; }
  matches_palette() {
    python3 - "$REPO" "$ACTIVE_PALETTE" "$1" "$2" <<'PYMATCH'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / "scripts"))
from render import load_palette, render
try:
    expected = render(Path(sys.argv[3]).read_text(), load_palette(sys.argv[2]))
    sys.exit(0 if expected in Path(sys.argv[4]).read_text() else 1)
except OSError:
    sys.exit(1)
PYMATCH
  }

  echo "${B}Theme${N}"
  t "Theme $THEME_NAME built"                    "$(run theme)" test -f "$HOME/.themes/$THEME_NAME/index.theme"
  t "Top-bar pills in Shell theme"               "$(run theme)" has_block "$HOME/.themes/$THEME_NAME/gnome-shell/gnome-shell.css"
  t "GTK 3 window buttons"                       "$(run gtk)"   has_block "$HOME/.config/gtk-3.0/gtk.css"
  t "GTK 4 / libadwaita window buttons"          "$(run gtk)"   has_block "$HOME/.config/gtk-4.0/gtk.css"
  t "GTK theme selected"                         "$(run settings)" gs org.gnome.desktop.interface gtk-theme "$THEME_NAME"
  t "Shell theme selected"                       "$(run settings)" gs org.gnome.shell.extensions.user-theme name "$THEME_NAME"

  t "Shell colours match active palette" "$(run theme)" matches_palette "$REPO/templates/gnome-shell/twilight.css" "$HOME/.themes/$THEME_NAME/gnome-shell/gnome-shell.css"
  t "GTK 3 colours match active palette" "$(run gtk)" matches_palette "$REPO/templates/gtk-3.0/twilight.css" "$HOME/.config/gtk-3.0/gtk.css"
  t "GTK 4 colours match active palette" "$(run gtk)" matches_palette "$REPO/templates/gtk-4.0/twilight.css" "$HOME/.config/gtk-4.0/gtk.css"
  if command -v flatpak >/dev/null; then
    t "Flatpak apps can read the GTK button styles" "$(run gtk)" bash -c "flatpak override --user --show | grep -q xdg-config/gtk-4.0:ro"
  fi
  t "GNOME accent matches active palette" "$(run settings)" gs org.gnome.desktop.interface accent-color "$GNOME_ACCENT"

  echo "${B}Icons, cursor, fonts, sounds${N}"
  t "Papirus-Twilight folders"                   "$(run icons)"  test -f "$HOME/.local/share/icons/Papirus-Twilight/scalable/places/folder.svg"
  t "Twilight-Controls icon theme selected"      "$(run settings)" gs org.gnome.desktop.interface icon-theme Twilight-Controls
  t "Cursor $CURSOR installed"                   "$(run cursor)" bash -c "[[ -d '$HOME/.local/share/icons/$CURSOR' || -d '$HOME/.icons/$CURSOR' ]]"
  t "Cursor selected"                            "$(run settings)" gs org.gnome.desktop.interface cursor-theme "$CURSOR"
  t "Inter font"                                 "$(run packages)" bash -c "fc-list | grep -q 'Inter'"
  t "Sacramento font (user)"                     "$(run fonts)" bash -c "fc-list | grep -q Sacramento"
  t "Sacramento font (system, for login screen)" "$(run fonts)" test -f /usr/local/share/fonts/Twilight/Sacramento-Regular.ttf
  t "Twilight sound theme"                       "$(run sounds)" test -f "$HOME/.local/share/sounds/Twilight/index.theme"
  if gsettings list-schemas | grep -x org.gnome.Ptyxis >/dev/null; then
    t "Ptyxis palette matches active palette"     "$(run settings)" matches_palette "$REPO/templates/ptyxis/twilight.palette" "$HOME/.local/share/org.gnome.Ptyxis/palettes/twilight.palette"
    t "Ptyxis uses the Twilight palette"          "$(run settings)" bash -c "gsettings get org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/\$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d \"'\")/ palette | grep -q twilight"
  fi

  echo "${B}Qt & LibreOffice title bars${N}"
  t "Qt decoration plugin built"                 "$(run qt)" test -f "$HOME/.local/lib/qt6/plugins/wayland-decoration-client/libqadwaitadecorations.so"
  t "Plugin matches installed Qt"                "$(run qt)" bash -c "[[ \"\$(rpm -q qt6-qtbase qt6-qtwayland)\" == \"\$(cat '$STATE/qt-built-against')\" ]]"
  t "Qt environment file"                        "$(run qt)" test -f "$HOME/.config/environment.d/90-twilight-qt.conf"
  t "Qt environment active in this session"      "log out and back in" bash -c "systemctl --user show-environment | grep -q '^QT_WAYLAND_DECORATION=adwaita-colorful'"

  echo "${B}Lock & login screen${N}"
  local w="/usr/share/gnome-shell/extensions/$WACK_UUID"
  t "WACK lock screen installed"                 "$(run lockscreen)" test -f "$w/metadata.json"
  t "Twilight lock-screen styling"               "$(run lockscreen)" has_block "$w/stylesheet.css"
  t "Twilight login-screen styling"              "$(run lockscreen)" has_block "$w/src/pro/gdm.css"
  t "Enabled on the login screen (GDM)"          "$(run lockscreen)" grep -q "$WACK_UUID" /etc/dconf/db/gdm.d/99-wack-lockscreen

  t "Lock-screen colours match active palette" "$(run lockscreen)" matches_palette "$REPO/templates/lockscreen/stylesheet.css" "$w/stylesheet.css"
  t "Login-screen colours match active palette" "$(run lockscreen)" matches_palette "$REPO/templates/lockscreen/gdm.css" "$w/src/pro/gdm.css"

  echo "${B}Extensions (GNOME $(shell_major))${N}"
  for e in "${DNF_EXTENSIONS[@]}" "${EGO_EXTENSIONS[@]}" "$ROUNDED_UUID" "$WACK_UUID"; do
    g=$(gnome-extensions info "$e" 2>/dev/null | awk -F': ' '/State/{print $2}' || true)
    case $g in
      ACTIVE) ok "$e" ;;
      INITIALIZED|INACTIVE) if [[ $e == "$WACK_UUID" ]]; then ok "$e (only runs on the lock/login screen)"; else bad "$e: $g" "log out and back in"; fi ;;
      "") bad "$e: not installed" "$(run extensions)" ;;
      *) bad "$e: $g" "update it in Extension Manager" ;;
    esac
  done

  echo "${B}Keyboard shortcuts${N}"
  # The shortcuts step leaves a key alone when one of the user's own shortcuts
  # already uses it, so that counts as a pass rather than a fixable failure.
  launcher() { # DESC BINDING COMMAND
    local keys; keys=$(dconf dump /org/gnome/settings-daemon/plugins/media-keys/ 2>/dev/null || true)
    if grep -A2 -B1 -F "binding='$2'" <<<"$keys" | grep -q "$3"; then ok "$1"
    elif grep -qF "binding='$2'" <<<"$keys"; then ok "$1: key kept for your own shortcut"
    else bad "$1" "$(run shortcuts)"; fi
  }
  launcher "Super+T opens a terminal" '<Super>t' ptyxis
  launcher "Super+E opens Files"      '<Super>e' nautilus
  t "Super+Q closes windows"                     "$(run shortcuts)" bash -c "gsettings get org.gnome.desktop.wm.keybindings close | grep -q '<Super>q'"
  t "Super+Ctrl+arrows switch workspace"         "$(run shortcuts)" bash -c "gsettings get org.gnome.desktop.wm.keybindings switch-to-workspace-left | grep -q '<Super><Control>Left'"
  t "Super+M opens notifications"                "$(run shortcuts)" bash -c "gsettings get org.gnome.shell.keybindings toggle-message-tray | grep -q '<Super>m'"

  echo "${B}Self-repair${N}"
  t "twilight-heal.service enabled"              "$(run heal)" systemctl --user is-enabled twilight-heal.service
  if [[ -z "$(systemctl --user show -p ExecMainStartTimestamp --value twilight-heal.service)" ]]; then
    ok "Not run yet (first run at your next login)"
  else
    t "Last login run succeeded"                 "journalctl --user -u twilight-heal" bash -c "[[ \"\$(systemctl --user show -p Result --value twilight-heal.service)\" == success ]]"
  fi

  echo
  if ((fails)); then echo "${Y}$fails problem(s) found.${N}"; else echo "${P}${B}Everything is in place.${N}"; fi
  return "$fails"
}

# --------------------------------------------------------------------- main ---

ONLY="" NO_SUDO=false WALLPAPER="" CHECK=false AUTO_PALETTE=false DRY_RUN=false KEEP_PALETTE=false
while (($#)); do
  case $1 in
    --only|--wallpaper)
      [[ $# -ge 2 && -n $2 && $2 != --* ]] || die "$1 needs a value (see --help)."
      if [[ $1 == --only ]]; then ONLY=$2; else WALLPAPER=$(readlink -m -- "$2"); fi
      shift ;;
    --keep-palette) KEEP_PALETTE=true ;;
    --auto-palette) AUTO_PALETTE=true ;;
    --dry-run) DRY_RUN=true ;;
    --no-sudo) NO_SUDO=true ;;
    --heal) HEAL=true ;;
    --check) CHECK=true ;;
    --list) printf '%s\n' "${ALL_STEPS[@]}"; exit 0 ;;
    -h|--help) sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

steps=("${ALL_STEPS[@]}")
[[ -n $ONLY ]] && IFS=',' read -ra steps <<<"$ONLY"
[[ $ONLY != ,* && $ONLY != *, && $ONLY != *,,* ]] || die "Empty step in --only."
for s in "${steps[@]}"; do
  valid=false
  for allowed in "${ALL_STEPS[@]}"; do [[ $s != "$allowed" ]] || valid=true; done
  $valid || die "Unknown step: $s (see --list)"
done
[[ -z $WALLPAPER || -f $WALLPAPER && -r $WALLPAPER ]] || die "Wallpaper is not a readable file: $WALLPAPER"
if $KEEP_PALETTE; then
  [[ -f $ACTIVE_PALETTE ]] || die "No saved palette yet. Install once without --keep-palette."
fi
if $AUTO_PALETTE; then
  $KEEP_PALETTE && die "Use --auto-palette or --keep-palette, not both."
  [[ -n $WALLPAPER ]] || die "--auto-palette needs --wallpaper FILE."
  [[ " ${steps[*]} " == *" settings "* ]] || die "Include settings in --only to apply the wallpaper and accent."
fi
if $CHECK || $HEAL; then
  [[ -z $ONLY && -z $WALLPAPER && $AUTO_PALETTE == false && $DRY_RUN == false ]] || die "Use --check or --heal on its own (optionally --no-sudo)."
  [[ $CHECK != true || $HEAL != true ]] || die "Use --check or --heal, not both."
fi

if ! $HEAL && ! $CHECK; then
  say "Twilight installation plan"
  for s in "${steps[@]}"; do
    if $NO_SUDO && [[ $ROOT_STEPS == *" $s "* ]]; then
      say "  $s — skipped (--no-sudo)"
    else
      say "  $s"
    fi
  done
  [[ -z $WALLPAPER ]] || say "Wallpaper: $WALLPAPER"
  $AUTO_PALETTE && say "Colours: generated from wallpaper; saved in $ACTIVE_PALETTE"
  say "Settings and shortcuts steps change your GNOME preferences. Existing user configuration is backed up."
  if ! $NO_SUDO; then say "Packages, login-screen styling and system fonts may request sudo."; fi
  $DRY_RUN && exit 0
fi
[[ $EUID -ne 0 ]] || die "Run as your normal user; the script calls sudo when it needs to."

# Checks must not replace an installed palette or create an installation.
if $CHECK; then
  if [[ -f $ACTIVE_PALETTE ]]; then source "$ACTIVE_PALETTE"; else source "$REPO/palette.conf"; fi
  check; exit $?
fi

if ! $HEAL; then
  for cmd in python3 rsync; do
    command -v "$cmd" >/dev/null || die "Missing $cmd. Install prerequisites: sudo dnf install git python3 python3-pillow rsync"
  done
  if $AUTO_PALETTE; then
    # Validate and decode before touching the installed configuration.
    python3 "$REPO/scripts/palette-from-wallpaper.py" "$WALLPAPER" >/dev/null
  fi
  if [[ " ${steps[*]} " == *" settings "* || " ${steps[*]} " == *" shortcuts "* ]]; then
    command -v dconf >/dev/null && command -v gsettings >/dev/null || die "Run this from a GNOME desktop with dconf and gsettings installed."
    gsettings get org.gnome.desktop.interface gtk-theme >/dev/null || die "Cannot read GNOME settings. Run from your desktop terminal."
  fi
  backup="$WORK/backups/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  chmod 700 "$backup"
  for item in .config/gtk-3.0 .config/gtk-4.0 .config/environment.d/90-twilight-qt.conf .config/burn-my-windows .config/systemd/user/twilight-heal.service .local/share/twilight/palette.conf; do
    if [[ -e $HOME/$item || -L $HOME/$item ]]; then
      mkdir -p "$backup/$(dirname "$item")"
      cp -a "$HOME/$item" "$backup/$item"
    fi
  done
  if command -v dconf >/dev/null; then dconf dump / > "$backup/dconf.ini"; fi
  say "User configuration backup: $backup (see README for recovery; not a full uninstall)."
fi

mkdir -p "$SRC" "$BUILD" "$STATE" "$WORK/tmp"
export TMPDIR="$WORK/tmp"
if ! $HEAL; then
  if [[ -f $ACTIVE_PALETTE ]]; then cp "$ACTIVE_PALETTE" "$backup/palette.conf"; fi
  # A palette generated from the wallpaper survives partial runs, so --only
  # never leaves some pieces in the old colours. Full runs restore palette.conf.
  source_file="$STATE/palette-source"
  palette_source=$(cat "$source_file" 2>/dev/null || true)
  if [[ -z $palette_source && -f $ACTIVE_PALETTE ]]; then
    # Installs from before this file existed: a palette that differs from the
    # checkout's can only have come from a wallpaper.
    cmp -s "$ACTIVE_PALETTE" "$REPO/palette.conf" && palette_source=repo || palette_source=wallpaper
  fi
  if $AUTO_PALETTE; then
    python3 "$DATA/scripts/palette-from-wallpaper.py" "$WALLPAPER" --output "$ACTIVE_PALETTE"
    echo wallpaper > "$source_file"
  elif $KEEP_PALETTE || [[ -n $ONLY && $palette_source == wallpaper && -f $ACTIVE_PALETTE ]]; then
    $KEEP_PALETTE || say "Keeping the wallpaper palette for this partial run (a full run restores palette.conf)."
    if [[ -n $palette_source ]]; then echo "$palette_source" > "$source_file"; fi
  else
    cp "$REPO/palette.conf" "$ACTIVE_PALETTE"
    echo repo > "$source_file"
  fi

  # Keep the ten newest backups.
  find "$WORK/backups" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | tail -n +11 |
    while read -r old; do rm -rf "${WORK:?}/backups/$old"; done
fi
[[ -f $ACTIVE_PALETTE ]] || die "No active palette. Run ./install.sh first."
source "$ACTIVE_PALETTE"
trap trace ERR
if $HEAL; then heal; exit 0; fi

# Each step runs in its own subshell, so a failure is traced and reported
# but does not stop the independent steps after it.
failed=() index=0
for s in "${steps[@]}"; do
  if $NO_SUDO && [[ $ROOT_STEPS == *" $s "* ]]; then
    warn "Skipping '$s' (needs sudo)"; continue
  fi
  index=$((index + 1))
  say "[$index/${#steps[@]}] $s"
  # The parent must not treat the subshell's exit as a new error, and the
  # subshell must not run in a condition, which would disable set -e inside it.
  trap - ERR; set +e
  (set -e; trap trace ERR; "step_$s")
  rc=$?
  set -e; trap trace ERR
  if ((rc)); then
    failed+=("$s")
    warn "Step '$s' failed (exit $rc); continuing with the remaining steps."
    [[ $s != packages ]] || { warn "Every later step needs these packages; stopping."; break; }
  fi
done

if ((${#failed[@]})); then
  warn "Failed steps: ${failed[*]}. Backup: ${backup:-none}"
  warn "Fix the first error above, then rerun: $REPO/install.sh --keep-palette --only $(IFS=,; echo "${failed[*]}")"
  exit 1
fi
say "Done. Log out and back in to load the shell theme, extensions and Qt settings."
say "After logging in, run: $REPO/install.sh --check"
