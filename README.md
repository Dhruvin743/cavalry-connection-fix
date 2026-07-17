# Cavalry connection-drag fix for Linux

**In one sentence:** if you already run **Cavalry** on Linux through Wine but dragging a
line to connect two attributes/layers doesn't work, this gives you a patched Wine that
fixes it.

## The problem this solves

If you followed the popular [CavalryOnLinux guide](https://gist.github.com/micahlt/3c97f834adaf688fe18344c0f546466c)
you can install Cavalry, log in through Canva, and use most of the app. But there's one
well-known bug nobody in that thread could fix: when you try to **drag a connection**
between two attributes or layers (that curvy line people call a "noodle"), it either
doesn't show up or refuses to connect.

This project fixes exactly that, and nothing else.

## What this is (and isn't)

- It **is** a small patch to Wine plus a script that builds a fixed `wine` for you.
- It is **not** a Cavalry setup guide. It assumes you already have Cavalry installed and
  logging in. If you don't yet, do the
  [CavalryOnLinux guide](https://gist.github.com/micahlt/3c97f834adaf688fe18344c0f546466c)
  first, then come back here.

Built against **Wine 11.13** (upstream commit `d30dcd75`).

## How it works (the whole idea in 20 seconds)

Wine is the "engine" that runs the Windows Cavalry app on Linux. The connection bug lives
in that engine. So we build a **fixed copy of the `wine` program**, then tell your
existing Cavalry launcher to use *that* `wine` instead of the system one.

Two words that are easy to mix up:

- **`WINEPREFIX`** = your Cavalry **data folder** (usually `~/.cavalry`). This does **not**
  change. Everything you set up from the guide stays.
- **the `wine` program** = the engine that runs the app. This is the only thing we swap.

```mermaid
flowchart LR
  A["download Wine 11.13 source"] --> B["apply the fix (patch)"]
  B --> C["build it"]
  C --> D["~/cavalry-wine/bin/wine"]
  D --> E["point your Cavalry launcher at it"]
```

## Before you start (will this work for me?)

- You're on **64-bit Linux**.
- You already have **Cavalry installed and logging in** through Wine (per the guide).
- You're okay running **one command** and waiting while it builds (20–60 min, fans spin —
  that's normal). Building needs `git` and compiler tools; the script installs them.

Two honest heads-ups:

- The connecting line you'll see is a **simple stand-in**, not Cavalry's exact fancy noodle.
  It works, it just looks a little plainer.
- Keep Wine on **X11 / XWayland** (the default). Your desktop session can still be Wayland;
  just avoid Wine's **native Wayland** driver, which fails to show a window on some NVIDIA
  setups.

## Do it (one command)

Open a terminal in this project folder and run:

```bash
./install.sh
```

The script will:

1. Explain what it's about to do and ask you to confirm.
2. Install `git` and the build tools it needs.
3. **Download Wine 11.13, apply the fix, and build it** into `~/cavalry-wine` (the slow part).
4. Find your existing Cavalry launcher and offer to point it at the patched Wine
   (it keeps a `.bak` backup, and shows you the manual edit if you'd rather do it yourself).

When it's done, run `wineserver -k` (to close any running Cavalry), then start Cavalry the
way you normally do.

## How to test the fix

Try dragging a connection (for example, **Scale X → Scale Y**). You should see a pale
curved line follow your cursor, and the connection should actually take when you let go.

If it works — you're done. Enjoy. 🎉

## What "point your launcher at it" actually means

Your Cavalry launcher currently runs the plain `wine` command. You change only that word
to the full path of the patched wine. For example, in a `.desktop` file's `Exec=` line:

```
before:  Exec=env WINEPREFIX="$HOME/.cavalry" wine "C:\\Program Files\\Cavalry\\Cavalry.exe" %u
after:   Exec=env WINEPREFIX="$HOME/.cavalry" /home/you/cavalry-wine/bin/wine "C:\\Program Files\\Cavalry\\Cavalry.exe" %u
```

`WINEPREFIX` stays the same — only `wine` becomes `/home/you/cavalry-wine/bin/wine`.
`install.sh` can do this edit for you; `HOWTO-SHARE.md` has the by-hand version.

## If something goes wrong

| What you see | What to try |
|---|---|
| `Permission denied` running the script | Run `chmod +x install.sh` first, then try again. |
| Build stops with a missing-package error | Copy the error and ask wherever you got this file, or see [`docs/TECHNICAL.md`](docs/TECHNICAL.md). |
| The patch fails to apply | You're likely on a very different Wine version. See the pinned base commit in [`docs/TECHNICAL.md`](docs/TECHNICAL.md). |
| Cavalry starts but the drag still doesn't work | Make sure your launcher really points at `~/cavalry-wine/bin/wine`, and that you ran `wineserver -k` before relaunching. |
| Windows missing / broken after forcing Wine's native Wayland driver | Don't. Stay on the default (Wine X11 → XWayland). Your desktop session can still be Wayland. |

Still stuck? There's a by-hand walkthrough in [`HOWTO-SHARE.md`](HOWTO-SHARE.md), and the
deep technical details are in [`docs/TECHNICAL.md`](docs/TECHNICAL.md).

## What's in this folder

| File / folder | What it is |
|---|---|
| `README.md` | This friendly guide (you are here). |
| `install.sh` | The one-command installer (deps → build → point your launcher). |
| `patches/` | The actual fix, saved as a small `.patch` file. |
| `scripts/` | The build script and an example launcher. |
| `HOWTO-SHARE.md` | For the person **sharing** this: what to send, plus the by-hand steps. |
| `docs/TECHNICAL.md` | The nerdy "how it works under the hood" details. |
| `wine-src/`, `build/` | Downloaded Wine source and build output, created during install. Big; safe to delete later. |

## Credit & sharing

Feel free to pass this along. This is a hobby fix for the Cavalry-on-Linux community —
it's **not** an official Wine feature and it's tuned specifically for Cavalry.
