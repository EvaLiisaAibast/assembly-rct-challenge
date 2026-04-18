; =========================================================
; RCT CHALLENGE - Main Entry Point
; =========================================================
; A real isometric tile engine inspired by RollerCoaster Tycoon
; 
; Architecture:
;   - Tile-based world (128x128 tiles)
;   - Height levels (0-255) for true 3D terrain
;   - Track piece system (straights, curves, slopes)
;   - Basic physics (gravity, friction, chain lifts)
;   - Simple guest system (pathfinding-lite)
; =========================================================

%include "constants.inc"
%include "structs.inc"

section .data
    ; Window/Display
    window_title db "RCT Challenge - Junior Dev Edition", 0
    
    ; Track piece type names for debugging
    piece_straight db "STRAIGHT", 0
    piece_flat_turn db "FLAT_TURN", 0
    piece_slope_up db "SLOPE_UP", 0
    piece_slope_down db "SLOPE_DOWN", 0
    
    ; Stats display
    fps_counter dd 0
    last_time dq 0

section .bss
    ; Framebuffer
    fb_fd resq 1
    fb_mem resq 1
    
    ; World state
    world_tiles resb WORLD_SIZE * WORLD_SIZE * TILE_SIZE
    track_pieces resb MAX_TRACK_PIECES * TRACK_PIECE_SIZE
    track_count resd 1
    
    ; Camera
    camera_x resd 1
    camera_y resd 1
    camera_zoom resd 1
    
    ; Coaster state
    coaster_carts resb MAX_CARTS * CART_SIZE
    num_carts resd 1
    
    ; Guests (simple)
    guests resb MAX_GUESTS * GUEST_SIZE
    num_guests resd 1
    
    ; Input
    mouse_x resd 1
    mouse_y resd 1
    mouse_buttons resd 1
    
    ; Time
    frame_count resd 1

section .text
    global _start
    
    ; External functions
    extern init_framebuffer
    extern init_world
    extern init_track_system
    extern init_coaster
    extern init_guests
    
    extern render_frame
    extern update_physics
    extern handle_input
    extern update_guests
    
    extern cleanup

_start:
    ; Initialize all systems
    call init_framebuffer
    test rax, rax
    js .init_failed
    
    call init_world
    call init_track_system
    call init_coaster
    call init_guests
    
    ; Set initial camera
    mov dword [camera_x], 64
    mov dword [camera_y], 64
    mov dword [camera_zoom], 1
    
    ; Main game loop
.game_loop:
    ; 1. Handle input (non-blocking)
    call handle_input
    
    ; 2. Update physics (60hz)
    call update_physics
    
    ; 3. Update guests
    call update_guests
    
    ; 4. Render
    call render_frame
    
    ; 5. Frame timing
    call frame_delay
    
    ; Check for quit (ESC key or Q)
    cmp dword [mouse_buttons], -1
    jne .game_loop
    
    ; Cleanup and exit
    call cleanup
    
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall

.init_failed:
    mov rax, 60
    mov rdi, 1
    syscall

; =========================================================
; Frame delay - ~16ms for 60 FPS
; =========================================================
frame_delay:
    push rbx
    
    ; Simple spinloop delay (improve with timer in real version)
    mov rcx, 8000000    ; Calibrate for your CPU
.delay_loop:
    pause               ; Hint to CPU we're spinning
    loop .delay_loop
    
    inc dword [frame_count]
    pop rbx
    ret
