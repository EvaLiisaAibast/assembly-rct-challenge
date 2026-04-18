# RCT Challenge - Isometric Coaster Engine

A from-scratch x86-64 assembly implementation inspired by RollerCoaster Tycoon's legendary engine. Built as a junior developer challenge project.

## Features

### Core Engine
- **Isometric Tile Renderer** - True 3D projection with height support (0-255 levels)
- **Z-Buffered Rendering** - Proper depth sorting for correct overlapping
- **128x128 Tile World** - RCT-style tile grid with surface types
- **Procedural Terrain** - Rolling hills with grass surfaces

### Track System
- **Piece-Based Tracks** - Like the real RCT, tracks are built from pre-defined pieces:
  - Straight sections
  - Flat turns (90°)
  - Gentle slopes (up/down)
  - Steep slopes
  - Station platforms
  - Chain lifts
  - Brakes
- **Connected Segments** - Pieces link together to form complete circuits
- **Direction-Aware** - Each piece has entry/exit directions

### Physics Engine
- **Real Coaster Physics** - Gravity affects speed on slopes
- **Fixed-Point Math** - 16.16 precision for smooth simulation
- **Friction Model** - Rolling resistance slows carts
- **Chain Lifts** - Automatic speed override on lift hills
- **Brake Sections** - Controlled deceleration
- **Station Dispatch** - Automatic train launching

### Guest System (Simplified)
- **Basic AI** - Guests wander, queue, ride, and leave
- **State Machine** - Walking, queuing, riding, leaving states
- **Energy/Happiness** - Stats that affect behavior
- **Random Appearance** - Varied clothing colors

### Controls
| Key | Action |
|-----|--------|
| `WASD` / Arrow Keys | Camera pan (or middle mouse drag) |
| `1` | Select hand/camera tool |
| `2` | Select track builder tool |
| `Q` | Place straight track |
| `W` | Place flat turn |
| `A` | Place slope up |
| `S` | Place slope down |
| `D` | Place station |
| `ESC` | Quit |

## Architecture

```
rct_challenge/
├── main.asm          # Entry point, game loop
├── constants.inc     # All game constants
├── structs.inc       # Data structure definitions
├── video.asm         # Framebuffer, pixel drawing, Z-buffer
├── world.asm         # Tile grid, terrain, height system
├── track.asm         # Track pieces, connectivity
├── physics.asm       # Cart physics, gravity, movement
├── renderer.asm      # Isometric rendering of all elements
├── input.asm         # Mouse and keyboard handling
├── guests.asm        # Guest AI and rendering
└── Makefile          # Build system
```

## Building

**Requirements:**
- Linux with framebuffer support (`/dev/fb0`)
- NASM assembler
- LD linker
- Root access (for framebuffer)

**Build:**
```bash
cd rct_challenge
make
```

**Run:**
```bash
sudo make run
```

**Debug:**
```bash
sudo make debug
```

## Technical Details

### Isometric Projection
```
screen_x = (tile_x - tile_y) * 16 + center_x
screen_y = (tile_x + tile_y) * 8 - height * 8 + offset_y
depth = tile_x + tile_y + height  ; For Z-sorting
```

### Physics Model
- **Velocity** - Fixed-point (16.16) tiles/second
- **Gravity** - 0.003 tiles/frame² on slopes
- **Friction** - 1% velocity loss per frame
- **Slopes** - Affect velocity based on steepness

### Memory Layout
- **World Tiles** - 128×128×8 bytes = 128KB
- **Track Pieces** - 2048×16 bytes = 32KB
- **Carts** - 32×32 bytes = 1KB
- **Guests** - 256×24 bytes = 6KB
- **Z-Buffer** - 1024×768×4 bytes = 3MB (for depth sorting)

## Differences from Real RCT

This is a learning project - real RCT was far more complex:

| Feature | This Project | Real RCT |
|---------|---------------|----------|
| Graphics | Simple colored shapes | 10,000+ sprite assets |
| Guests | ~256 simple agents | 2,000+ with complex needs |
| Rides | 1 coaster type | 30+ ride types |
| Economy | None | Full park management |
| Pathfinding | Random walk | A* on 10,000+ tile maps |
| Sound | None | Full audio system |

## Code Quality Notes

This codebase prioritizes **learning and clarity** over production quality:
- Some edge cases aren't handled
- No error recovery in places
- Spinloop timing (should use proper timers)
- Direct framebuffer access (should use SDL/X11)

It's designed to show the **architectural concepts** of an RCT-style engine in a manageable codebase (~2000 lines vs RCT's ~100,000).

## Senior Dev Challenge Tips

If you're showing this to challenge seniors:

1. **The isometric math** - Point out the clever use of `x-y` and `x+y` for projection
2. **Piece-based tracks** - Explain how this mirrors real RCT's track system
3. **Fixed-point physics** - Show the gravity/friction calculations
4. **Z-buffering** - Explain why depth sorting matters for isometric
5. **The bugs you fixed** - Everyone loves a good bug story

## Future Enhancements

If you want to extend this:
- Add more track piece types (loops, corkscrews)
- Implement proper pathfinding for guests
- Add ride statistics (excitement, intensity, nausea)
- Support for multiple coasters
- Save/load park files
- Sound effects
- SDL backend for windowed mode

## Credits

Inspired by Chris Sawyer's RollerCoaster Tycoon (1999) - one of the greatest assembly-language games ever written.

Built as a junior dev challenge to understand how classic game engines work under the hood.

## License

Public domain - use as a learning resource however you want.
