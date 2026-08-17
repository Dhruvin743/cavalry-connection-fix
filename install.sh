#!/bin/bash
# Friendly one-command installer for the Cavalry connection-drag fix.
# Safe to re-run. Talks to you in plain English the whole way.
#
# Assumes you ALREADY have Cavalry working on Linux via the CavalryOnLinux guide
# (login works, ~/.cavalry prefix set up). This only fixes the connection drag.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-$HOME/cavalry-wine}"
WINE_BIN="$PREFIX/bin/wine"
APPS_DIR="$HOME/.local/share/applications"

say()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31mx %s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------------------
say "Cavalry drag-fix installer"
cat <<'INTRO'
This fixes the "can't drag a connection" bug in Cavalry on Linux.

IMPORTANT: this assumes you already have Cavalry installed and logging in
through Wine (the usual CavalryOnLinux setup). This does NOT set up Cavalry,
your login, or your ~/.cavalry data folder — it only swaps the Wine "engine"
so connections work.

Here is exactly what I'm going to do:
  1. Install the pieces needed to build (you'll be asked for your password
     once, for your system's package manager).
  2. Download Wine 11.13, apply the fix, and build it into ~/cavalry-wine.
     THIS IS SLOW — usually 20 to 60 minutes. Your fans may get loud. Normal.
  3. Point your existing Cavalry launcher at the patched Wine (with your
     permission, and keeping a backup).

Your ~/.cavalry data folder (WINEPREFIX) is never touched.
INTRO

read -r -p $'\nReady to go? Type y and press Enter: ' answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) warn "No problem — nothing was changed. Run me again whenever you're ready."; exit 0 ;;
esac

# ---------------------------------------------------------------------------
say "Step 1 of 3 — installing the build pieces"

install_deps() {
  if command -v dnf >/dev/null 2>&1; then
    ok "Detected Fedora / RHEL (dnf)."
    # Install normally. If dnf stops on a package conflict, we DON'T force anything
    # (removing packages could break other apps). We just explain the problem and
    # hand you the command to run yourself if you decide the removals are safe.
    dnf_install() {
      if ! sudo dnf install -y "$@"; then
        err "dnf couldn't install some packages — most likely a package conflict."
        err "dnf usually suggests re-running with --allowerasing, which fixes it by"
        err "REMOVING the conflicting package(s). That can affect other software, so"
        err "it's your call. If the packages it wants to remove look safe, run:"
        err ""
        err "    sudo dnf install --allowerasing $*"
        err ""
        err "then re-run this installer."
        exit 1
      fi
    }
    dnf_install git
    if ! sudo dnf builddep -y wine; then
      err "dnf builddep for wine failed — likely a package conflict."
      err "If it suggested --allowerasing and the removals look safe to you, run:"
      err ""
      err "    sudo dnf builddep --allowerasing wine"
      err ""
      err "then re-run this installer."
      exit 1
    fi
    dnf_install mingw64-gcc mingw32-gcc opencl-headers \
      mesa-libGL-devel mesa-libEGL-devel vulkan-loader-devel \
      gnutls-devel libxslt-devel alsa-lib-devel pulseaudio-libs-devel \
      pipewire-devel SDL2-devel cups-devel
  elif command -v apt-get >/dev/null 2>&1; then
    ok "Detected Debian / Ubuntu (apt)."
    sudo apt-get update
    sudo apt-get install -y git
    sudo apt-get build-dep -y wine || warn "build-dep failed — you may need to enable 'Sources' in your software settings."
    sudo apt-get install -y gcc-mingw-w64 opencl-headers libgl1-mesa-dev libegl1-mesa-dev \
      libvulkan-dev libgnutls28-dev libxslt1-dev libasound2-dev \
      libpulse-dev libpipewire-0.3-dev libsdl2-dev libcups2-dev || true
  elif command -v pacman >/dev/null 2>&1; then
    ok "Detected Arch (pacman)."
    sudo pacman -S --needed --noconfirm git base-devel mingw-w64-gcc opencl-headers \
      mesa vulkan-icd-loader gnutls libxslt alsa-lib libpulse pipewire sdl2 cups
  elif command -v zypper >/dev/null 2>&1; then
    ok "Detected openSUSE (zypper)."
    sudo zypper install -y git
    sudo zypper install -y -t pattern devel_basis || true
    sudo zypper install -y gcc opencl-headers Mesa-libGL-devel gnutls-devel libxslt-devel \
      alsa-devel libpulse-devel pipewire-devel libSDL2-devel cups-devel || true
  else
    warn "I couldn't recognize your Linux package manager."
    warn "Please install git and Wine's build dependencies manually, then re-run me."
    warn "(Search: 'install wine build dependencies <your distro>')"
    read -r -p "Already installed them and want to continue anyway? (y/N): " cont
    [[ "$cont" =~ ^[yY] ]] || exit 1
  fi
}
install_deps
ok "Build pieces are ready."

# ---------------------------------------------------------------------------
say "Step 2 of 3 — downloading Wine, applying the fix, and building it"
warn "Go make a coffee. This can take 20–60 minutes."
PREFIX="$PREFIX" JOBS="${JOBS:-$(nproc)}" bash "$ROOT/scripts/build-patched-wine.sh"

if [[ ! -x "$WINE_BIN" ]]; then
  err "Build finished but I can't find the patched wine at: $WINE_BIN"
  err "Something went wrong during the build. Scroll up for the first red error."
  exit 1
fi
ok "Patched Wine built successfully: $WINE_BIN"

# --- Optional: free up the download + build files --------------------------
SRC_DIR="$ROOT/wine-src"
BUILD_DIR="$ROOT/build"
if [[ -d "$SRC_DIR" || -d "$BUILD_DIR" ]]; then
  space="$(du -shc "$SRC_DIR" "$BUILD_DIR" 2>/dev/null | tail -1 | cut -f1)"
  say "Free up space? (optional)"
  echo "The downloaded Wine source and build files (about ${space:-a few GB}) are NOT"
  echo "needed to run Cavalry — the patched Wine is fully installed at $PREFIX."
  echo "You'd only keep them to rebuild faster later."
  read -r -p "Delete them now to reclaim the space? (y/N): " clean
  if [[ "$clean" =~ ^[yY] ]]; then
    rm -rf "$SRC_DIR" "$BUILD_DIR"
    ok "Removed wine-src/ and build/."
  else
    warn "Keeping them. You can delete wine-src/ and build/ by hand anytime."
  fi
fi

# ---------------------------------------------------------------------------
say "Step 3 of 3 — pointing your Cavalry launcher at the patched Wine"

print_manual_help() {
  cat <<HELP

To finish, edit your existing Cavalry launcher so it runs the patched wine
instead of the system 'wine'. You only change the program — NOT your WINEPREFIX.

If you use a .desktop file (often in ~/.local/share/applications), change its
Exec line like this:

  before:  Exec=env WINEPREFIX="\$HOME/.cavalry" wine "C:\\\\Program Files\\\\Cavalry\\\\Cavalry.exe" %u
  after:   Exec=env WINEPREFIX="\$HOME/.cavalry" $WINE_BIN "C:\\\\Program Files\\\\Cavalry\\\\Cavalry.exe" %u

If you use a launcher script, change the 'wine' line the same way:

  before:  exec wine ".../Cavalry.exe" "\$@"
  after:   exec $WINE_BIN ".../Cavalry.exe" "\$@"

Then apply it:

  update-desktop-database "$APPS_DIR" 2>/dev/null || true
  wineserver -k        # stop any running Cavalry/Wine first
HELP
}

# Find real Cavalry launchers. Be precise: matching bare "cavalry" is wrong because
# every Wine file-association .desktop contains WINEPREFIX=.../.cavalry in its Exec.
# A real launcher runs the Cavalry app (Cavalry.exe/.lnk), OR handles the cavalry://
# scheme, OR is named like Cavalry.
mapfile -t candidates < <(
  {
    grep -rilE --include='*.desktop' '^Exec=.*[Cc]avalry\.(exe|lnk)' "$APPS_DIR" 2>/dev/null
    grep -rilE --include='*.desktop' '^MimeType=.*x-scheme-handler/cavalry' "$APPS_DIR" 2>/dev/null
    find "$APPS_DIR" -type f -iname '*cavalry*.desktop' 2>/dev/null
  } | sort -u
)

updated_any=0
if [[ ${#candidates[@]} -eq 0 ]]; then
  warn "I couldn't find a Cavalry .desktop launcher automatically."
  print_manual_help
else
  ok "Found ${#candidates[@]} Cavalry launcher file(s)."
  for f in "${candidates[@]}"; do
    exec_line="$(grep -m1 '^Exec=' "$f" || true)"
    # Only offer if it currently calls some 'wine' and not already our patched path.
    if [[ "$exec_line" == *"$WINE_BIN"* ]]; then
      ok "Already points at the patched Wine: $f"
      updated_any=1
      continue
    fi
    if ! grep -qiE '(^|[ =/])wine( |$)' <<<"$exec_line"; then
      continue
    fi
    echo
    echo "File: $f"
    echo "  now: $exec_line"
    read -r -p "Update this to use the patched Wine? (y/N): " yn
    if [[ "$yn" =~ ^[yY] ]]; then
      cp "$f" "$f.bak"
      # Replace the wine program (bare 'wine' or an absolute path ending /wine)
      # on the Exec line, leaving WINEPREFIX and everything else intact.
      sed -E "/^Exec=/ s#(^|[ =])(/[^ ]*/)?wine( )#\1${WINE_BIN}\3#g" "$f.bak" > "$f"
      new_line="$(grep -m1 '^Exec=' "$f" || true)"
      if [[ "$new_line" == *"$WINE_BIN"* ]]; then
        ok "Updated (backup saved as $(basename "$f").bak):"
        echo "  new: $new_line"
        updated_any=1
      else
        warn "Couldn't safely auto-edit this one; restoring backup."
        mv "$f.bak" "$f"
      fi
    fi
  done

  if [[ $updated_any -eq 1 ]]; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
    ok "Refreshed the desktop database."
  else
    warn "Nothing was changed automatically."
    print_manual_help
  fi
fi

# ---------------------------------------------------------------------------
say "All done! 🎉"
cat <<DONE
Last steps before testing:

  wineserver -k        # close any running Cavalry/Wine

Then launch Cavalry the way you normally do and test the fix:
drag a connection like Scale X → Scale Y — it should connect now.

Tip: if windows look broken on Wayland + NVIDIA, make sure Wine uses X11/XWayland.
DONE
