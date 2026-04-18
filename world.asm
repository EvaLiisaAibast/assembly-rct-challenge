; =========================================================
; RCT CHALLENGE - World/Tile System
; =========================================================
; Manages the tile grid - the foundation of the game world

%include "constants.inc"
%include "structs.inc"

section .data
    ; Perlin-like noise for terrain generation (simplified)
    terrain_seed dd 12345
    
    ; Tile type colors
    grass_colors db 1, 2, 2, 1, 3, 3    ; Variation

section .bss
    ; World tile array
    world_tiles resb WORLD_SIZE * WORLD_SIZE * TILE_SIZE
    
    ; Camera state
    camera_tile_x resd 1
    camera_tile_y resd 1
    camera_zoom   resd 1

section .text
    global init_world
    global get_tile
    global set_tile
    global set_tile_height
    global get_tile_height
    global generate_terrain
    global world_to_screen
    global screen_to_world

; =========================================================
; Initialize World
; =========================================================
init_world:
    push rbx
    push r12
    
    ; Clear all tiles
    mov rdi, world_tiles
    xor rax, rax
    mov rcx, (WORLD_SIZE * WORLD_SIZE * TILE_SIZE) / 8
    rep stosq
    
    ; Generate terrain
    call generate_terrain
    
    ; Initialize camera
    mov dword [camera_tile_x], 64
    mov dword [camera_tile_y], 64
    mov dword [camera_zoom], 1
    
    pop r12
    pop rbx
    ret

; =========================================================
; Generate Terrain - Simple rolling hills
; =========================================================
generate_terrain:
    push rbx
    push r12
    push r13
    
    mov r12d, 0             ; y
.y_loop:
    cmp r12d, WORLD_SIZE
    jge .done
    
    mov r13d, 0             ; x
.x_loop:
    cmp r13d, WORLD_SIZE
    jge .next_y
    
    ; Calculate height using simple sine approximation
    ; height = base + sin(x/10) * 8 + cos(y/10) * 8
    
    mov eax, r13d
    xor edx, edx
    mov ecx, 10
    div ecx                 ; eax = x/10
    
    ; Simple pseudo-random height
    imul eax, r13d, 37
    imul ebx, r12d, 23
    add eax, ebx
    xor eax, [terrain_seed]
    and eax, 0x0F           ; 0-15
    add eax, HEIGHT_BASE - 4
    
    ; Clamp
    cmp eax, HEIGHT_MIN
    jge .not_min
    mov eax, HEIGHT_MIN
.not_min:
    cmp eax, HEIGHT_MAX
    jle .not_max
    mov eax, HEIGHT_MAX
.not_max:
    
    ; Set tile
    mov ebx, eax            ; height
    mov eax, r13d           ; x
    mov ecx, r12d           ; y
    call set_tile_height
    
    ; Set surface type (grass mostly)
    mov eax, r13d
    mov ebx, r12d
    call get_tile
    test rax, rax
    jz .skip
    
    mov byte [rax + Tile.surface_type], 1  ; Grass
    mov byte [rax + Tile.flags], 0
    
.skip:
    inc r13d
    jmp .x_loop
    
.next_y:
    inc r12d
    jmp .y_loop
    
.done:
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Get Tile Pointer
; Input: eax=x, ebx=y
; Output: rax=tile pointer (null if out of bounds)
; =========================================================
get_tile:
    ; Bounds check
    cmp eax, 0
    jl .out_of_bounds
    cmp eax, WORLD_SIZE
    jge .out_of_bounds
    cmp ebx, 0
    jl .out_of_bounds
    cmp ebx, WORLD_SIZE
    jge .out_of_bounds
    
    ; Calculate index: (y * WORLD_SIZE + x) * TILE_SIZE
    push rdx
    imul ebx, WORLD_SIZE
    add ebx, eax
    imul ebx, TILE_SIZE
    
    lea rax, [world_tiles + rbx]
    pop rdx
    ret
    
.out_of_bounds:
    xor rax, rax
    ret

; =========================================================
; Set Tile Data
; Input: eax=x, ebx=y, ecx=height, edx=type
; =========================================================
set_tile:
    push rax
    
    call get_tile
    test rax, rax
    jz .done
    
    mov byte [rax + Tile.base_height], cl
    mov byte [rax + Tile.surface_type], dl
    
.done:
    pop rax
    ret

; =========================================================
; Set Tile Height
; Input: eax=x, ebx=y, ecx=height
; =========================================================
set_tile_height:
    push rax
    push rcx
    
    call get_tile
    test rax, rax
    jz .done
    
    mov byte [rax + Tile.base_height], cl
    ; Update top height based on slope (simplified - no slopes yet)
    mov byte [rax + Tile.top_height], cl
    
.done:
    pop rcx
    pop rax
    ret

; =========================================================
; Get Tile Height
; Input: eax=x, ebx=y
; Output: ecx=height (0 if out of bounds)
; =========================================================
get_tile_height:
    push rax
    
    call get_tile
    test rax, rax
    jz .zero
    
    movzx ecx, byte [rax + Tile.base_height]
    jmp .done
    
.zero:
    xor ecx, ecx
    
.done:
    pop rax
    ret

; =========================================================
; World to Screen (isometric projection)
; Input: eax=world_x, ebx=world_y, ecx=height
; Output: r8d=screen_x, r9d=screen_y
; =========================================================
world_to_screen:
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Adjust for camera
    sub eax, [camera_tile_x]
    sub ebx, [camera_tile_y]
    
    ; Apply zoom
    mov edx, [camera_zoom]
    imul eax, edx
    imul ebx, edx
    
    ; Isometric projection
    ; x_screen = (world_x - world_y) * 16 + center_x
    ; y_screen = (world_x + world_y) * 8 - height * 8 + center_y
    
    mov r8d, eax
    sub r8d, ebx
    shl r8d, 4
    add r8d, SCREEN_WIDTH / 2
    
    add eax, ebx
    shl eax, 3
    shl ecx, 3              ; height * 8
    sub eax, ecx
    add eax, 100
    mov r9d, eax
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Screen to World (inverse isometric, approximate)
; Input: eax=screen_x, ebx=screen_y
; Output: eax=world_x, ebx=world_y
; =========================================================
screen_to_world:
    push rcx
    push rdx
    
    ; Remove camera offset
    sub eax, SCREEN_WIDTH / 2
    sub ebx, 100
    
    ; Approximate inverse:
    ; world_x ≈ (x_screen/16 + y_screen/8) / 2
    ; world_y ≈ (y_screen/8 - x_screen/16) / 2
    
    mov ecx, eax
    sar ecx, 4              ; x/16
    
    mov edx, ebx
    sar edx, 3              ; y/8
    
    ; world_x = (ecx + edx) / 2
    mov eax, ecx
    add eax, edx
    sar eax, 1
    
    ; world_y = (edx - ecx) / 2
    mov ebx, edx
    sub ebx, ecx
    sar ebx, 1
    
    ; Add camera back
    add eax, [camera_tile_x]
    add ebx, [camera_tile_y]
    
    pop rdx
    pop rcx
    ret
