; =========================================================
; RCT CHALLENGE - Constants
; =========================================================

; Display
SCREEN_WIDTH    equ 1024
SCREEN_HEIGHT   equ 768
FB_BPP          equ 4

; World dimensions (power of 2 for fast indexing)
WORLD_SIZE      equ 128
WORLD_SHIFT     equ 7           ; log2(128) for bit shifts
TILE_SIZE       equ 8           ; bytes per tile

; Tile flags
TILE_OCCUPIED   equ 0x01
TILE_HAS_TRACK  equ 0x02
TILE_HAS_PATH   equ 0x04
TILE_WATER      equ 0x08
TILE_HAS_GUEST  equ 0x10

; Heights
HEIGHT_MIN      equ 0
HEIGHT_MAX      equ 255
HEIGHT_BASE     equ 32          ; Ground level

; Track system
MAX_TRACK_PIECES equ 2048
TRACK_PIECE_SIZE equ 16

; Track piece types (like RCT's actual system!)
TRACK_STRAIGHT      equ 0
TRACK_FLAT_TURN     equ 1
TRACK_SLOPE_UP      equ 2
TRACK_SLOPE_DOWN    equ 3
TRACK_STEEP_UP      equ 4
TRACK_STEEP_DOWN    equ 5
TRACK_VERTICAL_UP   equ 6
TRACK_VERTICAL_DOWN equ 7
TRACK_STATION       equ 8
TRACK_LIFT_HILL     equ 9
TRACK_BRAKES        equ 10

; Directions
DIR_NORTH   equ 0
DIR_EAST    equ 1
DIR_SOUTH   equ 2
DIR_WEST    equ 3

; Coaster carts
MAX_CARTS   equ 32
CART_SIZE   equ 32

; Cart states
CART_STOPPED    equ 0
CART_MOVING     equ 1
CART_LIFTING    equ 2
CART_BRAKING    equ 3

; Guests
MAX_GUESTS  equ 256
GUEST_SIZE  equ 24

; Physics
GRAVITY     equ 50      ; Fixed-point gravity
FRICTION    equ 2       ; Rolling resistance
LIFT_SPEED  equ 800     ; Chain lift speed (fixed point)
MAX_SPEED   equ 3000    ; Terminal velocity

; Colors (ARGB)
COLOR_BLACK     equ 0xFF000000
COLOR_WHITE     equ 0xFFFFFFFF
COLOR_GREEN     equ 0xFF00AA00
COLOR_DARK_GREEN equ 0xFF006600
COLOR_BROWN     equ 0xFF8B4513
COLOR_STEEL     equ 0xFFB0C4DE
COLOR_DIRT      equ 0xFF8B7355
COLOR_WATER     equ 0xFF0066CC
COLOR_SKIN      equ 0xFFFFCC99
COLOR_SHIRT     equ 0xFFFF0000
COLOR_PANTS     equ 0xFF0000FF
