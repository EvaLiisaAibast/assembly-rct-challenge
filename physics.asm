; =========================================================
; RCT CHALLENGE - Physics Engine
; =========================================================
; Real coaster physics with gravity, friction, and chain lifts
; Uses fixed-point math (16.16 format for precision)

%include "constants.inc"
%include "structs.inc"

section .data
    ; Physics constants (fixed point)
    GRAVITY_FP      dd 196    ; 0.003 * 65536 (gravity per frame)
    FRICTION_FP     dd 655    ; 0.01 * 65536 (rolling friction)
    LIFT_SPEED_FP   dd 524288 ; 8.0 * 65536 (chain lift speed)
    BRAKE_SPEED_FP  dd 65536  ; 1.0 * 65536
    MAX_SPEED_FP    dd 1966080 ; 30.0 * 65536
    MIN_SPEED_FP    dd 1638   ; 0.025 * 65536 (don't stop completely)
    
    ; Track piece lengths (in sub-tile units, 65536 = 1 tile)
    STRAIGHT_LENGTH dd 65536
    TURN_LENGTH     dd 92681  ; sqrt(2) * 65536 for diagonal
    
    ; Stats
    total_riders    dd 0
    max_g_force     dd 0

section .bss
    ; Coaster cart array
    coaster_carts resb MAX_CARTS * CART_SIZE
    num_carts resd 1
    
    ; Station state
    station_dispatch_time resd 1
    station_timer resd 1

section .text
    global init_coaster
    global update_physics
    global spawn_cart
    global remove_cart
    global get_cart_position
    global apply_gravity
    global apply_friction
    global get_slope_factor
    
    extern get_track_piece
    extern get_piece_exit_point
    extern world_to_screen

; =========================================================
; Initialize Coaster
; =========================================================
init_coaster:
    ; Clear carts
    mov rdi, coaster_carts
    xor rax, rax
    mov rcx, (MAX_CARTS * CART_SIZE) / 8
    rep stosq
    
    mov dword [num_carts], 0
    mov dword [station_dispatch_time], 180  ; 3 seconds at 60fps
    mov dword [station_timer], 0
    
    ; Spawn initial train
    call spawn_cart
    ret

; =========================================================
; Spawn Cart
; Create a new cart at the station
; =========================================================
spawn_cart:
    push rbx
    
    ; Find empty cart slot
    mov ebx, [num_carts]
    cmp ebx, MAX_CARTS
    jge .failed
    
    ; Calculate cart pointer
    mov eax, ebx
    imul eax, CART_SIZE
    lea rbx, [coaster_carts + rax]
    
    ; Initialize cart at piece 0 (station)
    mov word [rbx + Cart.track_piece], 0
    mov word [rbx + Cart.progress], 0
    
    ; Get piece position
    xor rdi, rdi
    call get_track_piece
    test rax, rax
    jz .failed
    
    ; Set position (fixed point)
    movzx eax, byte [rax + TrackPiece.x]
    shl eax, 16             ; Convert to 16.16
    mov [rbx + Cart.x], eax
    
    xor rdi, rdi
    call get_track_piece
    movzx eax, byte [rax + TrackPiece.y]
    shl eax, 16
    mov [rbx + Cart.y], eax
    
    xor rdi, rdi
    call get_track_piece
    movzx eax, byte [rax + TrackPiece.z]
    shl eax, 16
    mov [rbx + Cart.z], eax
    
    ; Initial velocity (slight push from station)
    mov dword [rbx + Cart.velocity], 65536  ; 1.0 tiles/sec
    mov word [rbx + Cart.acceleration], 0
    mov byte [rbx + Cart.state], CART_MOVING
    mov byte [rbx + Cart.num_riders], 4    ; Test riders
    
    inc dword [num_carts]
    
    pop rbx
    ret
    
.failed:
    pop rbx
    ret

; =========================================================
; Update Physics - Main simulation step
; =========================================================
update_physics:
    push rbx
    push r12
    push r13
    push r14
    
    xor r12d, r12d          ; Cart index
    
.cart_loop:
    cmp r12d, [num_carts]
    jge .done
    
    ; Get cart pointer
    mov eax, r12d
    imul eax, CART_SIZE
    lea r13, [coaster_carts + rax]
    
    ; Get current track piece
    movzx rdi, word [r13 + Cart.track_piece]
    call get_track_piece
    test rax, rax
    jz .next_cart
    mov r14, rax            ; r14 = track piece pointer
    
    ; Get piece type and calculate physics
    movzx eax, byte [r14 + TrackPiece.type]
    movzx ebx, byte [r14 + TrackPiece.flags]
    
    ; Apply physics based on piece type
    test ebx, 0x01          ; Chain lift flag
    jnz .chain_lift
    test ebx, 0x02          ; Brake flag
    jnz .brake_section
    
    ; Normal track - apply gravity and friction
    call .apply_physics
    jmp .move_cart

.chain_lift:
    ; Chain lift - override velocity
    mov eax, [LIFT_SPEED_FP]
    cmp dword [r13 + Cart.velocity], eax
    jge .move_cart
    mov [r13 + Cart.velocity], eax
    mov byte [r13 + Cart.state], CART_LIFTING
    jmp .move_cart

.brake_section:
    ; Brake - slow down
    mov eax, [r13 + Cart.velocity]
    sub eax, [BRAKE_SPEED_FP]
    cmp eax, [BRAKE_SPEED_FP]
    jge .brake_ok
    mov eax, [BRAKE_SPEED_FP]
.brake_ok:
    mov [r13 + Cart.velocity], eax
    mov byte [r13 + Cart.state], CART_BRAKING

.move_cart:
    ; Move cart along track
    call move_cart_along_track

.next_cart:
    inc r12d
    jmp .cart_loop

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Apply Physics (gravity + friction)
; =========================================================
.apply_physics:
    push rax
    push rbx
    push rcx
    
    ; Calculate slope factor from piece type
    ; This determines how much gravity affects us
    movzx eax, byte [r14 + TrackPiece.type]
    call get_slope_factor   ; Returns: eax = slope factor (-positive for down, + for up)
    
    ; Apply gravity: velocity += gravity * slope
    imul eax, [GRAVITY_FP]
    sar eax, 16             ; Scale down
    add [r13 + Cart.velocity], eax
    
    ; Apply friction: velocity *= (1 - friction)
    ; v = v - (v * friction)
    mov eax, [r13 + Cart.velocity]
    imul eax, [FRICTION_FP]
    sar eax, 16
    sub [r13 + Cart.velocity], eax
    
    ; Clamp velocity
    mov eax, [r13 + Cart.velocity]
    cmp eax, [MAX_SPEED_FP]
    jle .not_max
    mov eax, [MAX_SPEED_FP]
    jmp .clamp_min
.not_max:
    cmp eax, -[MAX_SPEED_FP]
    jge .clamp_min
    mov eax, -[MAX_SPEED_FP]
.clamp_min:
    ; Allow small negative velocity for rollback
    cmp eax, -65536         ; -1.0 tiles/sec (rollback threshold)
    jg .store
    mov eax, -65536
.store:
    mov [r13 + Cart.velocity], eax
    
    ; Calculate acceleration for display
    mov ebx, [r13 + Cart.velocity]
    sub ebx, eax            ; Change in velocity
    sar ebx, 10             ; Scale for display
    mov [r13 + Cart.acceleration], bx
    
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Get Slope Factor
; Input: eax = track piece type
; Output: eax = slope factor (- for down, + for up, 0 for flat)
; =========================================================
get_slope_factor:
    cmp eax, TRACK_SLOPE_UP
    je .slope_up
    cmp eax, TRACK_STEEP_UP
    je .steep_up
    cmp eax, TRACK_VERTICAL_UP
    je .vertical_up
    cmp eax, TRACK_SLOPE_DOWN
    je .slope_down
    cmp eax, TRACK_STEEP_DOWN
    je .steep_down
    cmp eax, TRACK_VERTICAL_DOWN
    je .vertical_down
    
    ; Flat or turn
    xor eax, eax
    ret

.slope_up:
    mov eax, -2             ; Going up slows us down (negative factor)
    ret
.steep_up:
    mov eax, -4
    ret
.vertical_up:
    mov eax, -8
    ret
.slope_down:
    mov eax, 2              ; Going down speeds us up
    ret
.steep_down:
    mov eax, 4
    ret
.vertical_down:
    mov eax, 8
    ret

; =========================================================
; Move Cart Along Track
; Update cart position based on velocity
; =========================================================
move_cart_along_track:
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Get current progress and velocity
    movzx eax, word [r13 + Cart.progress]    ; 0-65535
    mov ebx, [r13 + Cart.velocity]           ; Fixed point velocity
    
    ; Progress += velocity (scaled)
    ; velocity is tiles/second, progress is fraction of piece
    sar ebx, 8              ; Scale velocity to piece units
    add eax, ebx
    
    ; Check if we've moved to next piece
    cmp eax, 65536
    jl .same_piece
    
    ; Move to next piece
    sub eax, 65536
    mov word [r13 + Cart.progress], ax
    
    ; Get next piece index
    movzx rdi, word [r14 + TrackPiece.next_piece]
    cmp di, -1
    je .at_end
    
    mov word [r13 + Cart.track_piece], di
    
    ; Update position to new piece start
    call get_track_piece
    test rax, rax
    jz .at_end
    
    movzx ecx, byte [rax + TrackPiece.x]
    shl ecx, 16
    mov [r13 + Cart.x], ecx
    
    movzx ecx, byte [rax + TrackPiece.y]
    shl ecx, 16
    mov [r13 + Cart.y], ecx
    
    movzx ecx, byte [rax + TrackPiece.z]
    shl ecx, 16
    mov [r13 + Cart.z], ecx
    
    jmp .update_interp

.same_piece:
    mov word [r13 + Cart.progress], ax
    
.update_interp:
    ; Interpolate position within piece
    call interpolate_cart_position
    jmp .done

.at_end:
    ; End of track - stop or loop back
    mov dword [r13 + Cart.velocity], 65536  ; Reset speed
    mov word [r13 + Cart.track_piece], 0     ; Loop to start
    mov word [r13 + Cart.progress], 0

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Interpolate Cart Position
; Calculate actual world position from track piece + progress
; =========================================================
interpolate_cart_position:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    ; Get current piece
    movzx rdi, word [r13 + Cart.track_piece]
    call get_track_piece
    test rax, rax
    jz .done
    mov rsi, rax            ; rsi = current piece
    
    ; Get entry position
    movzx eax, byte [rsi + TrackPiece.x]
    shl eax, 16
    movzx ebx, byte [rsi + TrackPiece.y]
    shl ebx, 16
    movzx ecx, byte [rsi + TrackPiece.z]
    shl ecx, 16
    
    ; Get exit direction and calculate exit position
    movzx edi, word [r13 + Cart.track_piece]
    push rax
    push rbx
    push rcx
    call get_piece_exit_point
    ; Returns: r8d=exit_x, r9d=exit_y, r10d=exit_z
    pop rcx
    pop rbx
    pop rax
    
    shl r8d, 16
    shl r9d, 16
    shl r10d, 16
    
    ; Get interpolation factor (0-65535)
    movzx edx, word [r13 + Cart.progress]
    
    ; Interpolate: pos = start + (end - start) * progress / 65536
    ; X
    mov edi, r8d
    sub edi, eax            ; delta
    imul edi, edx           ; * progress
    shr edi, 16
    add eax, edi
    mov [r13 + Cart.x], eax
    
    ; Y
    mov edi, r9d
    sub edi, ebx
    imul edi, edx
    shr edi, 16
    add ebx, edi
    mov [r13 + Cart.y], ebx
    
    ; Z
    mov edi, r10d
    sub edi, ecx
    imul edi, edx
    shr edi, 16
    add ecx, edi
    mov [r13 + Cart.z], ecx
    
.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Remove Cart
; =========================================================
remove_cart:
    ; TODO: Remove cart and compact array
    ret

; =========================================================
; Get Cart Position (for rendering)
; Input: rdi = cart index
; Output: r8d=x, r9d=y, r10d=z (integer tile coordinates)
; =========================================================
get_cart_position:
    push rax
    
    mov eax, edi
    imul eax, CART_SIZE
    lea rax, [coaster_carts + rax]
    
    mov r8d, [rax + Cart.x]
    shr r8d, 16             ; Convert from fixed point
    mov r9d, [rax + Cart.y]
    shr r9d, 16
    mov r10d, [rax + Cart.z]
    shr r10d, 16
    
    pop rax
    ret
