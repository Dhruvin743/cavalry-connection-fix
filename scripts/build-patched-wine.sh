#!/bin/bash
# Download Wine 11.13, apply the Cavalry connection-drag patch, and build it.
#
# This does NOT install build dependencies — run ./install.sh for that, or see
# HOWTO-SHARE.md for the per-distro dependency list.
#
# Result: a ready-to-use patched wine at  $PREFIX/bin/wine
# (default PREFIX is ~/cavalry-wine)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/wine-src"
BUILD="$ROOT/build"
PREFIX="${PREFIX:-$HOME/cavalry-wine}"
JOBS="${JOBS:-$(nproc)}"

WINE_TAG="wine-11.13"
WINE_REPO="https://gitlab.winehq.org/wine/wine.git"
PATCH="$ROOT/patches/cavalry-connection-noodle-park-and-overlay.patch"

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31mx %s\033[0m\n' "$*" >&2; }

if [[ ! -f "$PATCH" ]]; then
  err "Can't find the patch at: $PATCH"
  exit 1
fi

# --- 1. Get the Wine source (clone once, reuse afterwards) ------------------
say "1/4  Getting the Wine source ($WINE_TAG)"
if [[ -d "$SRC/.git" ]]; then
  ok "Wine source already present at $SRC — reusing it."
else
  if ! command -v git >/dev/null 2>&1; then
    err "git is not installed. Install it (or run ./install.sh) and try again."
    exit 1
  fi
  echo "Cloning $WINE_TAG (this downloads a few hundred MB)..."
  git clone --depth 1 --branch "$WINE_TAG" "$WINE_REPO" "$SRC"
  ok "Cloned Wine source into $SRC"
fi

# --- 2. Apply the patch (idempotent) ---------------------------------------
say "2/4  Applying the Cavalry patch"
cd "$SRC"
if git apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  ok "Patch is already applied — skipping."
elif git apply --check "$PATCH" >/dev/null 2>&1; then
  git apply "$PATCH"
  ok "Patch applied cleanly."
else
  # Fall back to plain patch with fuzz for small upstream drift.
  echo "Clean apply failed; retrying with 'patch --fuzz'..."
  if patch -p1 --forward --fuzz=3 <"$PATCH"; then
    ok "Patch applied with fuzz."
  else
    err "The patch did not apply to this Wine source."
    err "Your Wine tree may differ from $WINE_TAG. See docs/TECHNICAL.md for the"
    err "exact base commit to check out as a guaranteed-good fallback."
    exit 1
  fi
fi

# --- 3. Configure + build ---------------------------------------------------
say "3/4  Configuring and building (x86_64 only — Cavalry is 64-bit)"
echo "This is the slow part: usually 20–60 minutes. Fans may spin. Normal."
mkdir -p "$BUILD"
cd "$BUILD"
"$SRC/configure" --prefix="$PREFIX" --enable-archs=x86_64
make -j"$JOBS"

# --- 4. Install -------------------------------------------------------------
say "4/4  Installing to $PREFIX"
make install

if [[ ! -x "$PREFIX/bin/wine" ]]; then
  err "Build finished but $PREFIX/bin/wine is missing — something went wrong above."
  exit 1
fi

# --- Optional cleanup -------------------------------------------------------
# The installed wine at $PREFIX is self-contained; the source and build dirs are
# only needed while compiling. Set CLEAN_BUILD=1 to delete them and reclaim disk.
if [[ "${CLEAN_BUILD:-0}" == "1" ]]; then
  say "Cleaning up build files to save disk (CLEAN_BUILD=1)"
  rm -rf "$SRC" "$BUILD"
  ok "Removed $SRC and $BUILD."
fi

say "Done!"
ok "Patched wine ready at: $PREFIX/bin/wine"
echo
echo "Next: point your existing Cavalry opener at this wine binary."
echo "In your Cavalry .desktop / launcher, replace the word 'wine' with:"
echo
echo "    $PREFIX/bin/wine"
echo
echo "Leave WINEPREFIX (your ~/.cavalry data folder) exactly as it is."
echo "Then run 'wineserver -k' and relaunch Cavalry."
