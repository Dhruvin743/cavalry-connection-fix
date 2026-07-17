# Sharing this fix (and the by-hand steps)

This page is for **you, the person passing this along** — plus a plain-language,
do-it-by-hand walkthrough for anyone who'd rather not use `install.sh`.

New here and just want to fix your own Cavalry? Start with [`README.md`](README.md) instead.

---

## Part 1 — How to share it

The nice part: what you share is **tiny**. You do NOT ship a copy of Wine. The build
script downloads Wine itself and applies your small patch. So you're really only sharing
a patch file, a few scripts, and the docs.

### What to send

Zip up these (or put them on GitHub/GitLab):

- `README.md` ← tell people to start here
- `install.sh` ← the one-command installer
- `HOWTO-SHARE.md` (this file)
- `docs/TECHNICAL.md`
- `patches/` ← the actual fix (one ~42 KB `.patch` file)
- `scripts/` ← the build script and example launcher

That's it — a few hundred KB total.

### What NOT to send

- `wine-src/`, `build/` — created locally when someone builds; huge and machine-specific.
- Any leftover `wine/`, `wine-install/`, or `dist/` folders from older setups — not needed;
  the build downloads Wine fresh.
- Your personal Wine prefix (usually `~/.cavalry`) — it can contain licenses and personal files.
- Any crash logs with paths you don't want public.

### A short blurb you can paste into Discord / Reddit / the CavalryOnLinux gist

> If you followed CavalryOnLinux but attribute/layer **connections won't drag**, here's a
> fix. It's a small Wine patch: Qt hit-tests using the top-level window's geometry, so the
> layered "noodle" window was eating every click. The patch parks that window off-screen
> and draws a click-through X11 overlay line instead. A script downloads Wine 11.13,
> applies the patch, builds it, and then you just point your existing Cavalry launcher at
> the patched `wine`. Your `~/.cavalry` prefix isn't touched. Link: <your link>. Tested on
> Fedora + GNOME Wayland/XWayland + NVIDIA. Cavalry-specific.

### Quick checklist before you post

- [ ] The patch applies cleanly on a fresh `wine-11.13` clone
      (`git apply --check patches/cavalry-connection-noodle-park-and-overlay.patch`).
- [ ] You told people their existing Cavalry data (`WINEPREFIX`, e.g. `~/.cavalry`) is
      *not* changed — only the `wine` program they run.
- [ ] You mentioned it's Cavalry-specific and uses Wine's X11/XWayland driver.
- [ ] You did **not** upload your private Wine prefix or a full Wine tree.

---

## Part 2 — The by-hand walkthrough (no installer)

Prefer to do it yourself, or the installer didn't fit your system? Here's every step.
You'll be typing into a terminal.

### What you need first

- A 64-bit Linux machine with `git` and Wine's build tools installed.
- Cavalry **already installed and logging in** through Wine (per the CavalryOnLinux guide).
  This only fixes the connection drag; it does not set Cavalry up.

### Step 1 — Install the build pieces

On **Fedora**:

```bash
sudo dnf install -y git
sudo dnf builddep -y wine
sudo dnf install -y mingw64-gcc mingw32-gcc mesa-libGL-devel mesa-libEGL-devel \
  vulkan-loader-devel gnutls-devel libxslt-devel alsa-lib-devel \
  pulseaudio-libs-devel pipewire-devel SDL2-devel cups-devel
```

On other distros, install `git` plus Wine's build dependencies (search "install wine build
dependencies <your distro>"). `install.sh` has ready-made commands for Debian/Ubuntu,
Arch, and openSUSE.

### Step 2 — Download Wine and apply the patch

```bash
git clone --depth 1 --branch wine-11.13 https://gitlab.winehq.org/wine/wine.git wine-src
cd wine-src
git apply ../patches/cavalry-connection-noodle-park-and-overlay.patch
# (or: patch -p1 < ../patches/cavalry-connection-noodle-park-and-overlay.patch)
cd ..
```

If it ever fails to apply on a future Wine version, check out the exact base commit the
patch was made against instead: `d30dcd75bc9f24277f13ae3605c8a4bb506885e4` (see
[`docs/TECHNICAL.md`](docs/TECHNICAL.md)).

The whole `scripts/build-patched-wine.sh` script does Steps 2 and 3 for you.

### Step 3 — Build the fixed Wine

```bash
mkdir build && cd build
../wine-src/configure --prefix="$HOME/cavalry-wine" --enable-archs=x86_64
make -j"$(nproc)"
make install
cd ..
```

This gives you the patched engine at `~/cavalry-wine/bin/wine`. It takes a while
(20–60 min) — that's normal. (Cavalry is 64-bit, so `x86_64` is enough.)

### Step 4 — Point your existing Cavalry launcher at it

You do NOT change your `WINEPREFIX`. You only change the `wine` **program** your launcher
runs. Find your Cavalry launcher — usually a `.desktop` file in
`~/.local/share/applications` (possibly under a `wine/` subfolder) — and edit its `Exec=`
line:

```
before:  Exec=env WINEPREFIX="/home/you/.cavalry" wine "C:\\Program Files\\Cavalry\\Cavalry.exe" %u
after:   Exec=env WINEPREFIX="/home/you/.cavalry" /home/you/cavalry-wine/bin/wine "C:\\Program Files\\Cavalry\\Cavalry.exe" %u
```

If instead you use a launcher **script** (e.g. `~/.local/bin/cavalry-launcher.sh`), change
the `wine` line there the same way — or copy the ready-made template:

```bash
cp scripts/cavalry-launcher.example.sh ~/.local/bin/cavalry
chmod +x ~/.local/bin/cavalry
# then edit PATCHED_WINE / WINEPREFIX near the top if your paths differ
```

Then refresh and restart cleanly:

```bash
update-desktop-database ~/.local/share/applications 2>/dev/null || true
wineserver -k   # close any running Cavalry/Wine
```

### Step 5 — (Optional) keep Wine on X11/XWayland

Your **desktop session can stay Wayland**. This just tells Wine to use `winex11`
(via XWayland) rather than the flaky native `winewayland` driver:

```bash
WINEPREFIX=~/.cavalry ~/cavalry-wine/bin/wine reg add \
  'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d 'x11,wayland' /f
```

### Step 6 — Test it

Launch Cavalry the way you normally do, then drag a connection (e.g. **Scale X → Scale Y**).
You should see a pale curved line, and the connection should take when you let go.

---

Want to know *why* any of this works? See [`docs/TECHNICAL.md`](docs/TECHNICAL.md).
