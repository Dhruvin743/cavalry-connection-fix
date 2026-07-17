#!/bin/bash
# Example launcher for Cavalry + patched Wine.
# Copy to ~/.local/bin/cavalry-launcher and edit the paths below.

set -euo pipefail

# --- edit these ---
PATCHED_WINE="${CAVALRY_PATCHED_WINE:-$HOME/cavalry-wine/bin/wine}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.cavalry}"
EXE="$WINEPREFIX/drive_c/Program Files/Cavalry/Cavalry.exe"
# --- end edit ---

WINE_BIN="$PATCHED_WINE"
if [[ ! -x "$WINE_BIN" ]]; then
  echo "Patched wine not found at $WINE_BIN; falling back to system wine" >&2
  WINE_BIN="$(command -v wine)"
fi

if [[ ! -f "$EXE" ]]; then
  echo "Cavalry not found at: $EXE" >&2
  echo "Install Cavalry into WINEPREFIX=$WINEPREFIX first." >&2
  exit 1
fi

exec "$WINE_BIN" "$EXE" "$@"
