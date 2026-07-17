# Technical notes (for developers)

This is the "how it actually works" companion to the friendly `README.md`. If you just
want to *use* the fix, you don't need anything in here.

**Scope:** Cavalry-specific (Qt 6.6 `Qt663*` UI). This is not a general Wine fix for all
apps and is not in a form WineHQ would merge as-is.

Tested reference: Fedora, GNOME Wayland + XWayland, NVIDIA, Wine **11.13**, Cavalry Qt 6.6.

## Patch base (for reference)

The patch in `patches/cavalry-connection-noodle-park-and-overlay.patch` was generated
against this exact upstream Wine commit:

- Base commit: `d30dcd75bc9f24277f13ae3605c8a4bb506885e4`
  — *"pdh: Implement PdhGetFormattedCounterArrayA/W."* (2026-07-14), a `master` commit
  dated just after the `wine-11.13` tag.
- `wine-11.13` tag: `847fb54cb65b7402d2873a710303951f8f50f2b4`
  (tag object; its commit is `6eb2e4c32cc9e271856146df11ed3a5c2cf29234`).

Verified: the patch applies cleanly (`git apply --check`) to a fresh `wine-11.13` clone,
so the build script defaults to that tag. If a *future* Wine version ever makes the patch
fail to apply, check out the pinned base commit above as a guaranteed-good starting point:

```bash
git clone https://gitlab.winehq.org/wine/wine.git wine-src
cd wine-src && git checkout d30dcd75bc9f24277f13ae3605c8a4bb506885e4
```

## What it fixes

- Connection drag can complete (drop / blue target feedback works).
- A visible rubber-band "noodle" while dragging.

## Known limitations

- The stroke is a **custom** overlay, not Cavalry's exact native noodle.
- On some setups the line can still slip under OpenGL/viewport panels (z-order).
- Wine’s native Wayland driver (`winewayland`) may fail on some NVIDIA boxes — keep
  Wine on its X11 driver (XWayland under a Wayland desktop is fine; that’s the tested path).

## How the fix works

| Problem | Cause | Fix |
|--------|--------|-----|
| Drop never arms / no connect | Qt uses top-level **geometry** hit-testing; the ULW noodle rect always contains the cursor | Park that window's **Win32** rect at `(-32000,-32000)` |
| Native noodle breaks / vanishes when parked | Qt rubber-band math assumes on-screen geometry | Draw a **custom** click-through ARGB overlay in `winex11` |
| Long drags used to freeze custom stroke | Size heuristic stopped matching (~1200px) | Keep matching for the active drag hwnd |

Main code (after the patch is applied):

- `dlls/win32u/window.c` — detect Cavalry noodle, park, send overlay paint
- `dlls/win32u/input.c` — capture / picker helpers
- `dlls/winex11.drv/window.c` — global overlay draw/hide

Environment knobs (if present in your build):

- `CAVALRY_INVISIBLE_NOODLE=1` — park/connect only, no overlay stroke

## Build flow

The normal path is `./install.sh` (installs deps) which calls
`scripts/build-patched-wine.sh`. That script clones Wine `wine-11.13` into `wine-src/`,
applies the patch idempotently, and builds/installs into `~/cavalry-wine`.

To do it by hand:

```bash
git clone --depth 1 --branch wine-11.13 https://gitlab.winehq.org/wine/wine.git wine-src
cd wine-src
git apply ../patches/cavalry-connection-noodle-park-and-overlay.patch
cd ..
mkdir build && cd build
../wine-src/configure --prefix="$HOME/cavalry-wine" --enable-archs=x86_64
make -j"$(nproc)"
make install
```

Cavalry is 64-bit, so `x86_64` is enough. If `git apply` conflicts on a newer Wine, fall
back to the pinned base commit under **Patch base** above, or re-apply the logic by hand.

### Reclaiming disk after install

The installed tree at `$PREFIX` (default `~/cavalry-wine`) is self-contained — it does not
reference `wine-src/` or `build/` at runtime. Once `make install` finishes you can delete
both to reclaim space (roughly 1 GB source + several GB of build objects):

```bash
rm -rf wine-src build
```

`scripts/build-patched-wine.sh` will do this automatically if you run it with
`CLEAN_BUILD=1`, and `install.sh` offers it as a prompt. Keep the dirs only if you plan to
rebuild (a kept `build/` allows fast incremental rebuilds).

## Regenerating the patch after further changes

The patch is a diff of the seven touched files against the Wine base. If you keep your own
working Wine tree as a git checkout (this repo historically kept one under `wine/`), run:

```bash
cd wine-src   # or your working Wine checkout
git diff HEAD -- \
  dlls/win32u/window.c \
  dlls/win32u/input.c \
  dlls/win32u/win32u_private.h \
  dlls/win32u/dce.c \
  dlls/winex11.drv/window.c \
  dlls/winex11.drv/bitblt.c \
  dlls/winex11.drv/x11drv.h \
  > ../patches/cavalry-connection-noodle-park-and-overlay.patch
```

Caveat: `git diff HEAD` produces a diff against *your* checkout's `HEAD`. To guarantee the
patch applies for others, regenerate it against a clean `wine-11.13` checkout (or verify
with `git apply --check` on a fresh `wine-11.13` clone, as noted under **Patch base**).

Fast rebuild of just the changed DLLs (from your `build/` dir):

```bash
make -C build/dlls/win32u -j"$(nproc)"
make -C build/dlls/winex11.drv -j"$(nproc)"
# copy the .so into ~/cavalry-wine/lib/wine/x86_64-unix/  (or run make install)
wineserver -k
```

## Upstreaming?

Not mergeable into WineHQ as-is (app-specific heuristics + synthetic UI). Reasonable
share targets:

- Cavalry Linux / Wine community threads
- A personal GitHub gist/repo with the patch + the howto
- A cleaned, more general "park layered tip during capture" proposal later, separate
  from the Cavalry overlay
