; =========================================================
; RCT CHALLENGE - Renderer
; =========================================================
; Isometric tile rendering with proper depth sorting

%include "constants.inc"
%include "structs.inc"

section .data
    ; Tile surface colors (indexed)
    surface_colors:
        dd 0xFF1a1a1a        ; 0: None
        dd 0xFF2d5016        ; 1: Grass dark
        dd 0xFF3d6b1f        ; 2: Grass light
        dd 0xFF4d7b2f        ; 3: Grass highlight
        dd 0xFF8B4513        ; 4: Dirt
        dd 0xFFA0522D        ; 5: Mud
        dd 0xFF808080        ; 6: Rock
        dd 0xFFFFFFFF        ; 7: Snow/Ice
        dd 0xFF0066CC        ; 8: Water deep
        dd 0xFF0088FF        ; 9: Water shallow
    
    ; Track colors by type
    track_type_colors:
        dd 0xFFB0C4DE        ; Straight: Light steel
        dd 0xFF708090        ; Turn: Darker steel
        dd 0xFF4682B4        ; Slope up: Steel blue
        dd 0xFF4682B4        ; Slope down
        dd 0xFF4169E1        ; Steep: Royal blue
        dd 0xFF4169E1
        dd 0xFF0000CD        ; Vertical: Medium blue
        dd 0xFF0000CD
        dd 0xFF32CD32        ; Station: Lime green
        dd 0xFFFFD700        ; Lift hill: Gold
        dd 0xFFFF4500        ; Brakes: Orange red
    
    ; Cart colors
    cart_body_color dd 0xFFFF0000       ; Red
    cart_wheel_color dd 0xFF333333      ; Dark grey

section .bss
    ; Render state
    render_depth resd 1
    visible_tiles resw 1024             ; List of visible tile indices
    visible_count resd 1

section .text
    global render_frame
    global render_tile
    global render_track
    global render_cart
    global render_guests
    
    extern clear_screen
    extern world_to_screen
    extern get_tile
    extern get_tile_height
    extern get_track_piece
    extern find_track_at
    extern get_cart_position
    extern draw_line
    extern draw_pixel_z
    extern iso_project
    extern track_pieces
    extern track_count
    extern coaster_carts
    extern num_carts
    extern guests
    extern num_guests
    extern camera_tile_x
    extern camera_tile_y
    extern world_tiles

; =========================================================
; Render Frame - Main render pass
; =========================================================
render_frame:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Clear screen
    call clear_screen
    
    ; Render visible world (back to front for proper depth)
    call render_world
    
    ; Render track pieces
    call render_all_tracks
    
    ; Render coaster carts
    call render_all_carts
    
    ; Render guests
    call render_all_guests
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Render World - Draw all visible tiles
; =========================================================
render_world:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Calculate visible range based on camera
    mov eax, [camera_tile_x]
    sub eax, 20             ; View distance
    mov r12d, eax           ; start_x
    mov eax, [camera_tile_x]
    add eax, 20
    mov r13d, eax           ; end_x
    
    mov eax, [camera_tile_y]
    sub eax, 20
    mov r14d, eax           ; start_y
    mov eax, [camera_tile_y]
    add eax, 20
    mov r15d, eax           ; end_y
    
    ; Clamp to world bounds
    cmp r12d, 0
    jge .x_start_ok
    xor r12d, r12d
.x_start_ok:
    cmp r13d, WORLD_SIZE
    jle .x_end_ok
    mov r13d, WORLD_SIZE
.x_end_ok:
    cmp r14d, 0
    jge .y_start_ok
    xor r14d, r14d
.y_start_ok:
    cmp r15d, WORLD_SIZE
    jle .y_end_ok
    mov r15d, WORLD_SIZE
.y_end_ok:
    
    ; Render from back to front (painter's algorithm)
    ; For isometric: render in diagonal scanlines
    mov ebx, r14d
    add ebx, r15d
    dec ebx                 ; Sum of x+y for diagonal lines
    
.diagonal_loop:
    cmp ebx, r12d
    jl .diagonal_done
    cmp ebx, r13d
    jge .diagonal_done
    
    ; Render this diagonal line
    mov ecx, r14d
.y_scan:
    cmp ecx, r15d
    jge .next_diagonal
    
    ; Calculate x for this diagonal: x = diagonal - y
    mov eax, ebx
    sub eax, ecx
    
    ; Check x bounds
    cmp eax, r12d
    jl .next_y
    cmp eax, r13d
    jge .next_y
    
    ; Render this tile
    push rbx
    push rcx
    mov ebx, ecx
    call render_tile
    pop rcx
    pop rbx
    
.next_y:
    inc ecx
    jmp .y_scan
    
.next_diagonal:
    dec ebx
    jmp .diagonal_loop
    
.diagonal_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Render Single Tile
; Input: eax=x, ebx=y
; =========================================================
render_tile:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12d, eax           ; tile x
    mov r13d, ebx           ; tile y
    
    ; Get tile data
    call get_tile
    test rax, rax
    jz .done
    mov r14, rax            ; r14 = tile pointer
    
    ; Get height
    movzx r15d, byte [r14 + Tile.base_height]
    
    ; Project to screen
    mov eax, r12d
    mov ebx, r13d
    mov ecx, r15d
    call world_to_screen    ; Returns: r8d=screen_x, r9d=screen_y
    
    ; Calculate depth for Z-buffer
    mov eax, r12d
    add eax, r13d
    add eax, r15d
    mov r10d, eax           ; Depth
    
    ; Draw tile diamond
    mov r11d, r8d           ; center x
    mov r12d, r9d           ; top y
    
    ; Get surface color
    movzx eax, byte [r14 + Tile.surface_type]
    cmp eax, 9
    ja .default_color
    mov ebx, eax
    shl ebx, 2
    mov r15d, [surface_colors + rbx]
    jmp .draw
.default_color:
    mov r15d, 0xFF2d5016
    
.draw:
    ; Draw diamond shape for tile
    call draw_tile_diamond
    
    ; Draw height edge if elevated
    cmp r15d, HEIGHT_BASE
    jle .done
    call draw_height_edge
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Draw Tile Diamond
; Input: r11d=center_x, r12d=top_y, r15d=color, r10d=depth
; =========================================================
draw_tile_diamond:
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r12
    
    ; Diamond dimensions
    ; Top point: (r11, r12)
    ; Right point: (r11+16, r12+8)
    ; Bottom: (r11, r12+16)
    ; Left: (r11-16, r12+8)
    
    mov eax, r11d
    sub eax, 16
    mov r8d, eax            ; Left x
    mov r9d, r12d
    add r9d, 8              ; Left y (middle)
    
    mov eax, r11d
    add eax, 16
    mov r12d, eax           ; Right x
    
    ; Draw left to top
    mov eax, r8d
    mov ebx, r9d
    mov ecx, r11d
    mov edx, r12d
    sub edx, 8              ; Top y
    mov ecx, r15d           ; color
    mov edx, r10d           ; depth
    call draw_line
    
    ; Draw top to right
    mov r8d, r11d
    mov r9d, r12d
    sub r9d, 8
    mov r10d, r12d
    add r10d, 16            ; Wait, need to recalc
    
    ; Actually, let's do a simpler fill with horizontal lines
    mov ecx, r15d
    mov edx, r10d
    
    mov r8d, 15             ; Height of diamond
.row_loop:
    ; Calculate row width based on position in diamond
    cmp r8d, 8
    jle .widening
    
    ; Narrowing part
    mov eax, 15
    sub eax, r8d
    jmp .calc_width
    
.widening:
    mov eax, r8d
    
.calc_width:
    ; width = eax * 2
    shl eax, 1
    inc eax                 ; Center pixel
    
    ; Draw row
    mov ebx, r12d
    add ebx, r8d            ; y = top + row
    sub ebx, 8              ; Adjust
    
    mov r9d, r11d
    sub r9d, eax
    shr eax, 1
    
    mov eax, r9d            ; Start x
    mov ecx, r15d           ; Color
    
    ; Draw horizontal line
    push r8
    mov r8d, eax
    add r8d, eax            ; End x = start + width
    mov r9d, ebx
    mov r10d, ebx
    mov r11d, r15d
    mov r12d, r10d          ; Depth
    call draw_line
    pop r8
    
    dec r8d
    jns .row_loop
    
    pop r12
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Draw Height Edge (for elevated terrain)
; =========================================================
draw_height_edge:
    ; Draw vertical edge to show elevation
    ret

; =========================================================
; Render All Tracks
; =========================================================
render_all_tracks:
    push rbx
    push r12
    push r13
    
    xor ebx, ebx
.track_loop:
    cmp ebx, [track_count]
    jge .done
    
    mov r12d, ebx
    call render_track
    
    inc ebx
    jmp .track_loop
    
.done:
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Render Single Track Piece
; Input: r12d = piece index
; =========================================================
render_track:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get piece data
    mov rdi, r12
    call get_track_piece
    test rax, rax
    jz .done
    mov r13, rax            ; r13 = piece pointer
    
    ; Get position
    movzx r14d, byte [r13 + TrackPiece.x]
    movzx r15d, byte [r13 + TrackPiece.y]
    movzx eax, byte [r13 + TrackPiece.z]
    
    ; Project to screen
    mov ebx, r15d
    mov ecx, eax
    mov eax, r14d
    call world_to_screen
    
    ; Get color based on type
    movzx eax, byte [r13 + TrackPiece.type]
    cmp eax, 10
    ja .default_track
    mov ebx, eax
    shl ebx, 2
    mov r12d, [track_type_colors + rbx]
    jmp .draw
.default_track:
    mov r12d, 0xFFB0C4DE
    
.draw:
    ; Calculate depth
    mov r10d, r14d
    add r10d, r15d
    add r10d, 100           ; Bias tracks above ground
    
    ; Draw track based on type
    movzx eax, byte [r13 + TrackPiece.type]
    cmp eax, TRACK_STRAIGHT
    je .draw_straight
    cmp eax, TRACK_FLAT_TURN
    je .draw_turn
    cmp eax, TRACK_SLOPE_UP
    je .draw_slope
    cmp eax, TRACK_SLOPE_DOWN
    je .draw_slope
    cmp eax, TRACK_STATION
    je .draw_station
    jmp .draw_generic

.draw_straight:
    ; Draw a line showing track direction
    ; Get exit point to determine line
    mov rdi, [rsp + 24]     ; Recover piece index
    push r8
    push r9
    push r10
    push r12
    call get_piece_exit_point
    pop r12
    pop r10
    
    ; Convert exit to screen
    shl r8d, 16
    shl r9d, 16
    mov eax, r8d
    mov ebx, r9d
    mov ecx, r10d
    shr eax, 16
    shr ebx, 16
    shr ecx, 16
    push r8
    push r9
    call world_to_screen
    pop r9
    pop r8
    
    mov r10d, r8d
    mov r11d, r9d
    mov r8d, [rsp]
    mov r9d, [rsp + 8]
    add rsp, 16
    
    ; Draw track line
    mov r12d, [rsp + 16]    ; color
    mov r13d, [rsp + 8]     ; depth
    call draw_line
    jmp .done

.draw_turn:
    ; Draw a curved segment (simplified as angled line)
    jmp .draw_generic

.draw_slope:
    ; Draw with height indication
    jmp .draw_generic

.draw_station:
    ; Draw station (wider, different color)
    mov r12d, 0xFF32CD32    ; Green station
    jmp .draw_generic

.draw_generic:
    ; Draw a simple 8x8 box at track location
    mov ecx, 8
.box_loop:
    push rcx
    mov ecx, 8
    
    .inner:
        mov eax, r8d
        add eax, ecx
        dec eax
        mov ebx, r9d
        add ebx, [rsp]
        dec ebx
        push rcx
        mov ecx, r12d
        mov edx, r10d
        call draw_pixel_z
        pop rcx
        loop .inner
    
    pop rcx
    loop .box_loop
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Render All Carts
; =========================================================
render_all_carts:
    push rbx
    push r12
    
    xor ebx, ebx
.cart_loop:
    cmp ebx, [num_carts]
    jge .done
    
    mov r12d, ebx
    call render_cart
    
    inc ebx
    jmp .cart_loop
    
.done:
    pop r12
    pop rbx
    ret

; =========================================================
; Render Single Cart
; Input: r12d = cart index
; =========================================================
render_cart:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get cart position
    mov rdi, r12
    call get_cart_position
    ; Returns: r8d=x, r9d=y, r10d=z
    
    mov r14d, r8d
    mov r15d, r9d
    mov r12d, r10d          ; Save z
    
    ; Project to screen
    mov eax, r14d
    mov ebx, r15d
    mov ecx, r12d
    call world_to_screen
    
    ; Calculate depth (higher than track)
    add r10d, 200
    
    ; Draw cart body (red box with wheels)
    mov r15d, [cart_body_color]
    
    ; Draw 10x6 cart body
    mov r11d, -5
.x_loop:
    cmp r11d, 5
    jge .body_done
    
    mov r12d, -3
.y_loop:
    cmp r12d, 3
    jge .next_x
    
    mov eax, r8d
    add eax, r11d
    mov ebx, r9d
    add ebx, r12d
    mov ecx, r15d
    mov edx, r10d
    push r8
    push r9
    push r10
    push r11
    push r12
    call draw_pixel_z
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    
    inc r12d
    jmp .y_loop
    
.next_x:
    inc r11d
    jmp .x_loop
    
.body_done:
    ; Draw wheels (dark grey dots at corners)
    mov r15d, [cart_wheel_color]
    
    ; Front wheel
    mov eax, r8d
    sub eax, 4
    mov ebx, r9d
    add ebx, 2
    mov ecx, r15d
    mov edx, r10d
    call draw_pixel_z
    
    ; Back wheel
    add eax, 8
    call draw_pixel_z
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Render All Guests
; =========================================================
render_all_guests:
    ret                      ; TODO: Implement guest rendering
