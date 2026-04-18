# GitHub Repository Information

## Repo Name
```
assembly-rct-challenge
```

Alternative options:
- `rct-engine-asm`
- `iso-coaster-asm64`
- `rct-clone-assembly`
- `roller-assembly-tycoon`

## Description (Short - 350 chars max for GitHub)
```
RollerCoaster Tycoon-style isometric engine written from scratch in x86-64 assembly. Features tile-based world, track piece system, real physics with gravity/friction, and basic guest AI. Built as a junior dev challenge to understand classic game engine architecture.
```

## Topics / Tags
```
assembly
x86-64
nasm
rollercoaster-tycoon
isometric
game-engine
retro-games
low-level
systems-programming
linux
framebuffer
physics-simulation
```

## README Title Options
```
# Assembly RCT Challenge 🎢
## Building RollerCoaster Tycoon's Engine in Pure x86-64 Assembly
### From-Scratch Isometric Coaster Engine in NASM
```

## About Section
```
Educational implementation of an RCT-style isometric game engine written entirely in x86-64 assembly. Demonstrates real game engine concepts: isometric projection, piece-based track systems, fixed-point physics, and Z-buffered rendering.
```

## Badges (for top of README)
```markdown
![Assembly](https://img.shields.io/badge/Assembly-x86--64-blue)
![NASM](https://img.shields.io/badge/NASM-2.15+-green)
![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)
![License](https://img.shields.io/badge/License-Public%20Domain-brightgreen)
```

## Full GitHub Description

### One-liner
> "RollerCoaster Tycoon's engine architecture, rebuilt in 2000 lines of x86-64 assembly"

### Paragraph
This project is a from-scratch implementation of an isometric tile-based game engine inspired by RollerCoaster Tycoon (1999). Written entirely in x86-64 assembly using NASM, it demonstrates core game engine concepts including isometric projection with height levels, a piece-based track construction system, real-time physics simulation with fixed-point arithmetic, Z-buffered depth sorting, and basic AI agent simulation. Built as a learning challenge to understand how classic tycoon games worked under the hood.

### Key Highlights for README
- 🎢 **11 track piece types** (straights, turns, slopes, stations, lifts, brakes)
- 🌍 **128×128 tile world** with 256 height levels
- ⚡ **Real physics** - gravity affects cart speed on slopes
- 🖥️ **Direct framebuffer** rendering on Linux
- 👥 **256 guest agents** with state-machine AI
- 🔧 **~2000 lines** of hand-written assembly

## Screenshot Placeholders
Since this renders to raw framebuffer, add these to your README once you capture them:

```markdown
## Screenshots

### Isometric Terrain
![Terrain](screenshots/terrain.png)

### Track Building
![Track](screenshots/track.png)

### Physics Simulation
![Physics](screenshots/physics.png)
```

## Installation Section

```markdown
## 🚀 Quick Start

### Requirements
- Linux with `/dev/fb0` framebuffer support
- NASM assembler (`sudo apt install nasm`)
- Root access (for framebuffer)

### Build
```bash
git clone https://github.com/yourusername/assembly-rct-challenge.git
cd assembly-rct-challenge
make
```

### Run
```bash
sudo ./rct_engine
```

> ⚠️ **Warning**: This writes directly to the Linux framebuffer. Run from a TTY (Ctrl+Alt+F3) or your display manager may crash.
```

## Attribution
```markdown
## Credits

Inspired by [Chris Sawyer's RollerCoaster Tycoon](https://en.wikipedia.org/wiki/RollerCoaster_Tycoon) (1999), famously written almost entirely in x86 assembly by a single developer.

This is an educational project for understanding classic game engine architecture.
```
