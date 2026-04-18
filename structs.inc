; =========================================================
; RCT CHALLENGE - Data Structures
; =========================================================
; These match the conceptual structure of RCT's engine

; =========================================================
; Tile Structure (8 bytes)
; =========================================================
; Offset 0: Base height (byte)
; Offset 1: Top height / slope info (byte)
; Offset 2: Surface type (byte)
; Offset 3: Flags (byte)
; Offset 4: Object index (word)
; Offset 6: Reserved (word)
struc Tile
    .base_height    resb 1
    .top_height     resb 1
    .surface_type   resb 1
    .flags          resb 1
    .object_idx     resw 1
    .reserved       resw 1
endstruc

; =========================================================
; Track Piece Structure (16 bytes)
; =========================================================
; RCT used a "track piece" system where each piece is a 
; pre-defined segment with known entry/exit points
struc TrackPiece
    .type           resb 1      ; TRACK_* constants
    .direction      resb 1      ; DIR_* 
    .x              resb 1      ; Tile X
    .y              resb 1      ; Tile Y
    .z              resb 1      ; Height
    .flags          resb 1      ; Chain lift, brakes, etc
    .next_piece     resw 1      ; Index of next piece
    .prev_piece     resw 1      ; Index of previous piece
    .reserved       resd 1      ; Padding/chain speed
endstruc

; =========================================================
; Coaster Cart Structure (32 bytes)
; =========================================================
; Simulates the actual physics RCT used
struc Cart
    .track_piece    resw 1      ; Current track piece index
    .progress       resw 1      ; 0-65535 along piece (fixed point)
    .x              resd 1      ; World X (fixed point 16.16)
    .y              resd 1      ; World Y (fixed point 16.16)
    .z              resd 1      ; World Z (fixed point 16.16)
    .velocity       resd 1      ; Speed (fixed point, signed)
    .acceleration   resw 1      ; Current accel
    .state          resb 1      ; CART_* state
    .num_riders     resb 1      ; Guest count
    .reserved       resb 6      ; Padding
endstruc

; =========================================================
; Guest Structure (24 bytes)
; =========================================================
; Simplified peep simulation
struc Guest
    .x              resw 1      ; Tile X
    .y              resw 1      ; Tile Y
    .z              resb 1      ; Height
    .direction      resb 1      ; Facing
    .state          resb 1      ; Walking, queuing, riding, etc
    .happiness      resb 1      ; 0-255
    .energy         resb 1      ; 0-255
    .cash           resw 1      ; Money in pocket
    .destination_x  resw 1      ; Where they're going
    .destination_y  resw 1
    .ride_target    resw 1      ; Which ride they want
    .flags          resb 1      
    .shirt_color    resb 1
    .pants_color    resb 1
    .reserved       resb 5
endstruc

; =========================================================
; Isometric Draw Context (for renderer)
; =========================================================
struc DrawCtx
    .screen_x       resd 1
    .screen_y       resd 1
    .tile_x         resd 1
    .tile_y         resd 1
    .height         resd 1
    .color          resd 1
    .depth          resd 1      ; For Z-sorting
endstruc
