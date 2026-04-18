; =========================================================
; RCT CHALLENGE - Guest System (Simplified Peep AI)
; =========================================================
; Basic guest simulation with wandering and ride interest

%include "constants.inc"
%include "structs.inc"

section .data
    ; Guest appearance variations
    shirt_colors db 0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFF00FF, 0x00FFFF
    pants_colors db 0x000080, 0x008000, 0x800000, 0x808000, 0x800080, 0x008080
    skin_tones   db 0xFFCC99, 0xE8BEAC, 0xD2A679, 0x8D5524, 0xC68642
    
    ; Random seed
    guest_seed dd 987654321
    
    ; Guest states
    GUEST_WALKING equ 0
    GUEST_QUEUING equ 1
    GUEST_RIDING  equ 2
    GUEST_SITTING equ 3
    GUEST_LEAVING equ 4

section .bss
    guests resb MAX_GUESTS * GUEST_SIZE
    num_guests resd 1
    active_guests resd 1

section .text
    global init_guests
    global update_guests
    global spawn_guest
    global remove_guest
    global render_guest
    
    extern get_tile
    extern get_tile_height
    extern world_to_screen
    extern draw_pixel_z
    extern rand

; =========================================================
; Initialize Guest System
; =========================================================
init_guests:
    push rbx
    
    ; Clear guest array
    mov rdi, guests
    xor rax, rax
    mov rcx, (MAX_GUESTS * GUEST_SIZE) / 8
    rep stosq
    
    mov dword [num_guests], 0
    mov dword [active_guests], 0
    
    ; Spawn some initial guests
    mov ebx, 10
.spawn_loop:
    call spawn_guest
    dec ebx
    jnz .spawn_loop
    
    pop rbx
    ret

; =========================================================
; Spawn New Guest at Park Entrance
; =========================================================
spawn_guest:
    push rbx
    push r12
    push r13
    push r14
    
    ; Find empty slot
    xor ebx, ebx
.find_slot:
    cmp ebx, MAX_GUESTS
    jge .failed
    
    mov eax, ebx
    imul eax, GUEST_SIZE
    lea r12, [guests + rax]
    
    cmp byte [r12 + Guest.state], 0
    je .found_slot          ; State 0 with x,y=0 is empty
    
    movzx eax, word [r12 + Guest.x]
    cmp eax, 0
    jne .next_slot
    movzx eax, word [r12 + Guest.y]
    cmp eax, 0
    je .found_slot
    
.next_slot:
    inc ebx
    jmp .find_slot
    
.found_slot:
    mov r13d, ebx           ; Guest index
    
    ; Initialize guest
    mov word [r12 + Guest.x], 64        ; Park entrance
    mov word [r12 + Guest.y], 64
    mov byte [r12 + Guest.z], 32        ; Ground level
    mov byte [r12 + Guest.direction], DIR_SOUTH
    mov byte [r12 + Guest.state], GUEST_WALKING
    mov byte [r12 + Guest.happiness], 128
    mov byte [r12 + Guest.energy], 200
    mov word [r12 + Guest.cash], 5000   ; $50.00
    mov word [r12 + Guest.destination_x], 0
    mov word [r12 + Guest.destination_y], 0
    mov word [r12 + Guest.ride_target], -1
    mov byte [r12 + Guest.flags], 0
    
    ; Random appearance
    call rand
    xor edx, edx
    mov ecx, 6
    div ecx
    mov al, [shirt_colors + edx]
    mov byte [r12 + Guest.shirt_color], al
    
    call rand
    xor edx, edx
    mov ecx, 6
    div ecx
    mov al, [pants_colors + edx]
    mov byte [r12 + Guest.pants_color], al
    
    inc dword [num_guests]
    inc dword [active_guests]
    
    mov eax, r13d
    jmp .done
    
.failed:
    mov eax, -1
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Update All Guests
; =========================================================
update_guests:
    push rbx
    push r12
    
    xor ebx, ebx
.guest_loop:
    cmp ebx, MAX_GUESTS
    jge .done
    
    mov eax, ebx
    imul eax, GUEST_SIZE
    lea r12, [guests + rax]
    
    ; Check if guest is active
    cmp byte [r12 + Guest.state], 0
    je .next
    
    ; Update this guest
    mov rdi, rbx
    call update_single_guest
    
.next:
    inc ebx
    jmp .guest_loop
    
.done:
    pop r12
    pop rbx
    ret

; =========================================================
; Update Single Guest AI
; Input: rdi = guest index, r12 = guest pointer
; =========================================================
update_single_guest:
    push rbx
    push r13
    
    mov r13d, edi           ; Save index
    
    ; Decrease energy slowly
    dec byte [r12 + Guest.energy]
    jz .tired_guest
    
    ; State machine
    movzx eax, byte [r12 + Guest.state]
    cmp eax, GUEST_WALKING
    je .walking
    cmp eax, GUEST_QUEUING
    je .queuing
    cmp eax, GUEST_RIDING
    je .riding
    cmp eax, GUEST_LEAVING
    je .leaving
    jmp .done

.tired_guest:
    ; Guest leaves park
    mov byte [r12 + Guest.state], GUEST_LEAVING
    jmp .leaving

.walking:
    ; Wander randomly
    call rand
    and eax, 0x1F           ; 0-31
    cmp eax, 2
    jg .no_turn
    
    ; Random turn
    call rand
    and eax, 3
    mov byte [r12 + Guest.direction], al
    
.no_turn:
    ; Try to move forward
    movzx eax, word [r12 + Guest.x]
    movzx ebx, word [r12 + Guest.y]
    movzx ecx, byte [r12 + Guest.direction]
    
    ; Calculate new position
    cmp ecx, DIR_NORTH
    je .move_north
    cmp ecx, DIR_EAST
    je .move_east
    cmp ecx, DIR_SOUTH
    je .move_south
    cmp ecx, DIR_WEST
    je .move_west
    jmp .check_move

.move_north:
    dec ebx
    jmp .check_move
.move_east:
    inc eax
    jmp .check_move
.move_south:
    inc ebx
    jmp .check_move
.move_west:
    dec eax
    jmp .check_move

.check_move:
    ; Check bounds
    cmp eax, 0
    jl .no_move
    cmp eax, WORLD_SIZE
    jge .no_move
    cmp ebx, 0
    jl .no_move
    cmp ebx, WORLD_SIZE
    jge .no_move
    
    ; Check if tile is walkable
    call get_tile
    test rax, rax
    jz .no_move
    
    ; Check for path or ground
    movzx ecx, byte [rax + Tile.flags]
    test ecx, TILE_HAS_PATH
    jnz .can_move
    test ecx, TILE_OCCUPIED
    jnz .no_move
    
    ; Can walk on grass too
    movzx ecx, byte [rax + Tile.surface_type]
    cmp ecx, 1              ; Grass
    je .can_move
    cmp ecx, 2
    je .can_move
    jmp .no_move
    
.can_move:
    ; Get height at new position
    push rax
    push rbx
    call get_tile_height
    mov edx, ecx
    pop rbx
    pop rax
    
    ; Only move if height difference is small
    movzx ecx, byte [r12 + Guest.z]
    sub ecx, edx
    cmp ecx, -4
    jl .no_move
    cmp ecx, 4
    jg .no_move
    
    ; Update position
    mov [r12 + Guest.x], ax
    mov [r12 + Guest.y], bx
    mov [r12 + Guest.z], dl
    
    ; Slight happiness from walking
    inc byte [r12 + Guest.happiness]
    
.no_move:
    ; Chance to change state
    call rand
    and eax, 0xFF
    cmp eax, 250            ; 1/256 chance to leave
    je .want_leave
    
    jmp .done

.want_leave:
    mov byte [r12 + Guest.state], GUEST_LEAVING
    jmp .done

.queuing:
    ; Standing in line - patience decreases
    dec byte [r12 + Guest.happiness]
    jz .leave_queue
    jmp .done

.leave_queue:
    mov byte [r12 + Guest.state], GUEST_WALKING
    jmp .done

.riding:
    ; On ride - happiness increases
    inc byte [r12 + Guest.happiness]
    inc byte [r12 + Guest.happiness]
    jmp .done

.leaving:
    ; Head to park exit
    mov word [r12 + Guest.destination_x], 64
    mov word [r12 + Guest.destination_y], 64
    
    ; Simple pathfinding toward exit
    movzx eax, word [r12 + Guest.x]
    movzx ebx, word [r12 + Guest.y]
    
    cmp eax, 64
    je .at_exit_x
    jl .go_east
    
.go_west:
    mov byte [r12 + Guest.direction], DIR_WEST
    jmp .try_exit_move
    
.go_east:
    mov byte [r12 + Guest.direction], DIR_EAST
    jmp .try_exit_move
    
.at_exit_x:
    cmp ebx, 64
    je .left_park
    jl .go_south
    
.go_north:
    mov byte [r12 + Guest.direction], DIR_NORTH
    jmp .try_exit_move
    
.go_south:
    mov byte [r12 + Guest.direction], DIR_SOUTH
    jmp .try_exit_move
    
.try_exit_move:
    ; Use same movement as walking
    jmp .walking
    
.left_park:
    ; Remove guest from park
    mov byte [r12 + Guest.state], 0
    mov word [r12 + Guest.x], 0
    mov word [r12 + Guest.y], 0
    dec dword [active_guests]
    
.done:
    pop r13
    pop rbx
    ret

; =========================================================
; Remove Guest
; =========================================================
remove_guest:
    push rbx
    
    mov eax, edi
    imul eax, GUEST_SIZE
    lea rbx, [guests + rax]
    
    mov byte [rbx + Guest.state], 0
    mov word [rbx + Guest.x], 0
    mov word [rbx + Guest.y], 0
    dec dword [active_guests]
    
    pop rbx
    ret

; =========================================================
; Render Guest
; Input: rdi = guest index
; =========================================================
render_guest:
    push rbx
    push r12
    push r13
    push r14
    
    mov r14d, edi
    
    ; Get guest pointer
    mov eax, edi
    imul eax, GUEST_SIZE
    lea r12, [guests + rax]
    
    ; Get position
    movzx r13d, word [r12 + Guest.x]
    movzx eax, word [r12 + Guest.y]
    movzx ebx, byte [r12 + Guest.z]
    
    ; Project to screen
    mov ecx, ebx
    mov ebx, eax
    mov eax, r13d
    call world_to_screen
    
    ; Calculate depth
    mov r10d, r13d
    add r10d, 150           ; Above ground
    
    ; Draw guest as small figure
    ; Head
    movzx ecx, byte [r12 + Guest.shirt_color]
    mov eax, r8d
    mov ebx, r9d
    sub ebx, 2
    mov edx, r10d
    push r8
    push r9
    call draw_pixel_z
    pop r9
    pop r8
    
    ; Body
    movzx ecx, byte [r12 + Guest.pants_color]
    mov eax, r8d
    mov ebx, r9d
    mov edx, r10d
    push r8
    push r9
    call draw_pixel_z
    pop r9
    pop r8
    
    ; Legs (2 pixels)
    mov ecx, 0xFF333333     ; Dark shoes
    mov eax, r8d
    dec eax
    inc ebx
    push r8
    push r9
    call draw_pixel_z
    pop r9
    pop r8
    
    inc eax
    push r8
    push r9
    call draw_pixel_z
    pop r9
    pop r8
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Simple Random Number Generator
; Returns: eax = random value
; =========================================================
rand:
    push rdx
    
    ; Linear congruential generator
    ; seed = seed * 1103515245 + 12345
    mov eax, [guest_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [guest_seed], eax
    
    ; Return upper bits
    shr eax, 16
    
    pop rdx
    ret
