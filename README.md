# OBSKUR Studio (1990 → 2026)

🌐 **Language:** **English** | [Deutsch](README.de.md)

![OBSKUR Studio 3D Plasma Sphere](https://github.com/wuestawatschn/obskur-pas/releases/download/v1.1.0/preview.png)

An interactive 3D function and sculpture generator written in **FreePascal / Lazarus** for **Linux, macOS, and Windows**.

## Background & History
The original **`obskur.exe`** (the source code obskur.pas got lost over time) was created in **1990** in **Turbo Pascal** (using the classic BGI graphics library in 16-color EGA mode) to draw isometric 3D wave landscapes polygon by polygon on DOS PCs.

In **2026**, the original 16-bit DOS executable was reconstructed via reverse engineering and evolved into a modern, cross-platform **64-bit desktop application** — featuring 24-bit TrueColor, interactive 3D mouse rotation, spherical projection, live bilingual UI (**English / German**), and 28 mathematical 3D formulas.

## Features
* **28 3D Formulas:** From classic sine-cosine waves and the Mexican hat to volcanic craters, spiral galaxies, Mandelbrot fractals, and organic plasma turbulence.
* **Plane & Sphere Mode:** Render every formula either as a classic 3D heightfield grid or wrapped around a closed 3D sphere (with depth sorting / Painter's algorithm).
* **Double Mirroring & 5 Palettes:** *Classic*, *Lava & Embers*, *Deep Sea & Ocean*, *Northern Lights (Aurora)*, and *Rainbow Spectrum*.
* **Interactive Controls:** Mouse drag 3D rotation, resolution from `64 × 64` to `1024 × 1024`, live wave animation, auto-fit scaling, bilingual UI (`English / Deutsch`), and PNG export.

## Download (Linux, macOS & Windows)
Pre-built 64-bit binaries for all three operating systems are available on the **[Releases page](../../releases/latest)**:
* **Linux (64-Bit):** `OBSKUR-Linux-x86_64.zip`
* **macOS (Apple Silicon / Cocoa):** `OBSKUR-macOS-AppleSilicon.zip` *(first launch: right-click `obskur.app` → "Open")*
* **Windows (64-Bit):** `OBSKUR-Windows-x64.zip`

## Building from Source
Requires **FreePascal (`fpc`)** and **Lazarus (`lazbuild`)** (plus `libgtk2.0-dev` on Debian/Ubuntu):
```bash
# Linux (GTK2)
lazbuild obskur.lpi
./lib/x86_64-linux/obskur

# macOS (Cocoa)
lazbuild --ws=cocoa --opt="-k-ld_classic" obskur.lpi

# Windows (Win32/Win64)
lazbuild --ws=win32 obskur.lpi
```

## License
Licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see [LICENSE](LICENSE).
