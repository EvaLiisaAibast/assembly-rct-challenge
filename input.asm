; =========================================================
; RCT CHALLENGE - Input Handling
; =========================================================
; Mouse and keyboard input for camera and building

%include "constants.inc"

section .data
    ; Input device paths
    mouse_path db "/dev/input/mice", 0
    keyboard_path db "/dev/input/event0", 0
    
    ; Key codes (Linux input events)
    KEY_ESC     equ 1
    KEY_1       equ 2
    KEY_2       equ 3
    KEY_3       equ 4
    KEY_Q       equ 16
    KEY_W       equ 17
    KEY_E       equ 18
    KEY_R       equ 19
    KEY_A       equ 30
    KEY_S       equ 31
    KEY_D       equ 32
    KEY_SPACE   equ 57
    
    ; Mouse button masks
    MOUSE_LEFT   equ 0x01
    MOUSE_RIGHT  equ 0x02
    MOUSE_MIDDLE equ 0x04

section .bss
    ; Mouse state
    mouse_fd resq 1
    mouse_x resd 1
    mouse_y resd 1
    mouse_buttons resb 1
    mouse_dx resb 1
    mouse_dy resb 1
    
    ; Keyboard state
    kb_fd resq 1
    keys_pressed resb 256
    
    ; Game state
    selected_tool resb 1        ; 0=hand, 1=track, 2=terrain
    selected_track_type resb 1
    hover_tile_x resd 1
    hover_tile_y resd 1
    
    ; Camera control
    camera_panning resb 1
    last_mouse_x resd 1
    last_mouse_y resd 1

section .text
    global handle_input
    global init_input
    global cleanup_input
    global screen_to_tile
    
    extern camera_tile_x
    extern camera_tile_y
    extern world_to_screen
    extern add_track_piece
    extern screen_to_world

; =========================================================
; Initialize Input Devices
; =========================================================
init_input:
    push rbx
    
    ; Try to open mouse (optional - don't fail if unavailable)
    mov rax, 2              ; sys_open
    mov rdi, mouse_path
    mov rsi, 0              ; O_RDONLY | O_NONBLOCK would be better
    syscall
    
    cmp rax, 0
    jl .no_mouse
    mov [mouse_fd], rax
    
.no_mouse:
    ; Try keyboard
    mov rax, 2
    mov rdi, keyboard_path
    mov rsi, 0
    syscall
    
    cmp rax, 0
    jl .no_kb
    mov [kb_fd], rax
    
.no_kb:
    ; Initialize state
    mov dword [mouse_x], SCREEN_WIDTH / 2
    mov dword [mouse_y], SCREEN_HEIGHT / 2
    mov byte [mouse_buttons], 0
    mov byte [selected_tool], 0
    mov byte [selected_track_type], TRACK_STRAIGHT
    
    pop rbx
    ret

; =========================================================
; Cleanup Input
; =========================================================
cleanup_input:
    push rax
    push rdi
    
    ; Close mouse
    mov rax, [mouse_fd]
    cmp rax, 0
    jle .no_mouse_close
    mov rdi, rax
    mov rax, 3              ; sys_close
    syscall
    
.no_mouse_close:
    ; Close keyboard
    mov rax, [kb_fd]
    cmp rax, 0
    jle .done
    mov rdi, rax
    mov rax, 3
    syscall
    
.done:
    pop rdi
    pop rax
    ret

; =========================================================
; Handle Input - Process pending input events
; =========================================================
handle_input:
    push rbx
    push r12
    push r13
    
    ; Process mouse input
    call process_mouse
    
    ; Process keyboard input
    call process_keyboard
    
    ; Update hover tile
    mov eax, [mouse_x]
    mov ebx, [mouse_y]
    call screen_to_tile
    mov [hover_tile_x], eax
    mov [hover_tile_y], ebx
    
    ; Handle tool actions
    call handle_tool_input
    
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Process Mouse Events
; =========================================================
process_mouse:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    
    ; Check if mouse is available
    mov rax, [mouse_fd]
    cmp rax, 0
    jle .done
    
    ; Read mouse packet (3 bytes: buttons, dx, dy)
    mov rdi, [mouse_fd]
    mov rax, 0              ; sys_read
    lea rsi, [rsp - 16]     ; Temporary buffer on stack
    mov rdx, 3
    syscall
    
    cmp rax, 3
    jl .done                ; No data or error
    
    ; Parse packet
    movzx eax, byte [rsi]   ; Buttons
    mov [mouse_buttons], al
    
    movsx ebx, byte [rsi + 1]  ; dx (signed)
    movsx ecx, byte [rsi + 2]  ; dy (signed)
    
    ; Update position
    add [mouse_x], ebx
    add [mouse_y], ecx
    
    ; Clamp to screen
    mov eax, [mouse_x]
    cmp eax, 0
    jge .x_not_neg
    mov dword [mouse_x], 0
.x_not_neg:
    cmp eax, SCREEN_WIDTH
    jl .x_not_big
    mov dword [mouse_x], SCREEN_WIDTH - 1
.x_not_big:
    
    mov eax, [mouse_y]
    cmp eax, 0
    jge .y_not_neg
    mov dword [mouse_y], 0
.y_not_neg:
    cmp eax, SCREEN_HEIGHT
    jl .y_not_big
    mov dword [mouse_y], SCREEN_HEIGHT - 1
.y_not_big:
    
    ; Handle camera panning with middle button
    test byte [mouse_buttons], MOUSE_MIDDLE
    jz .not_panning
    
    ; Calculate camera movement based on mouse movement
    mov eax, ebx
    neg eax                 ; Invert for natural feel
    sar eax, 3              ; Scale down
    add [camera_tile_x], eax
    
    mov eax, ecx
    sar eax, 3
    add [camera_tile_y], eax
    
.not_panning:
    
.done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Process Keyboard Events
; =========================================================
process_keyboard:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi
    
    ; Check if keyboard is available
    mov rax, [kb_fd]
    cmp rax, 0
    jle .done
    
    ; Read keyboard event (struct input_event is 24 bytes on 64-bit)
    mov rdi, [kb_fd]
    mov rax, 0              ; sys_read
    lea rsi, [rsp - 32]     ; Buffer for input_event
    mov rdx, 24
    syscall
    
    cmp rax, 24
    jl .done
    
    ; Parse event
    ; struct input_event:
    ;   struct timeval time (16 bytes)
    ;   __u16 type (2 bytes)
    ;   __u16 code (2 bytes)
    ;   __s32 value (4 bytes)
    
    movzx eax, word [rsi + 16]  ; type
    cmp eax, 1                  ; EV_KEY
    jne .done
    
    movzx ebx, word [rsi + 18]  ; code (key code)
    movzx ecx, dword [rsi + 20] ; value (0=up, 1=down, 2=repeat)
    
    ; Store key state
    cmp ebx, 256
    jge .done
    mov [keys_pressed + ebx], cl
    
    ; Handle key press (value == 1)
    cmp ecx, 1
    jne .done
    
    ; Check specific keys
    cmp ebx, KEY_ESC
    je .key_esc
    cmp ebx, KEY_Q
    je .key_q
    cmp ebx, KEY_W
    je .key_w
    cmp ebx, KEY_A
    je .key_a
    cmp ebx, KEY_S
    je .key_s
    cmp ebx, KEY_D
    je .key_d
    cmp ebx, KEY_1
    je .key_1
    cmp ebx, KEY_2
    je .key_2
    jmp .done
    
.key_esc:
    ; Set quit flag
    mov byte [mouse_buttons], -1
    jmp .done
    
.key_q:
    mov byte [selected_track_type], TRACK_STRAIGHT
    jmp .done
    
.key_w:
    mov byte [selected_track_type], TRACK_FLAT_TURN
    jmp .done
    
.key_a:
    mov byte [selected_track_type], TRACK_SLOPE_UP
    jmp .done
    
.key_s:
    mov byte [selected_track_type], TRACK_SLOPE_DOWN
    jmp .done
    
.key_d:
    mov byte [selected_track_type], TRACK_STATION
    jmp .done
    
.key_1:
    mov byte [selected_tool], 0     ; Hand/camera
    jmp .done
    
.key_2:
    mov byte [selected_tool], 1     ; Track builder
    jmp .done

.done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Handle Tool Input
; Process mouse clicks based on selected tool
; =========================================================
handle_tool_input:
    push rax
    push rbx
    
    ; Check for left click
    mov al, [mouse_buttons]
    test al, MOUSE_LEFT
    jz .done
    
    ; Get selected tool
    movzx eax, byte [selected_tool]
    cmp eax, 1              ; Track tool
    jne .done
    
    ; Get hover tile
    mov eax, [hover_tile_x]
    mov ebx, [hover_tile_y]
    
    ; Validate coordinates
    cmp eax, 0
    jl .done
    cmp eax, WORLD_SIZE
    jge .done
    cmp ebx, 0
    jl .done
    cmp ebx, WORLD_SIZE
    jge .done
    
    ; Add track piece
    mov cl, al              ; x
    mov ch, bl              ; y
    mov al, [selected_track_type]
    mov ah, 0               ; direction - TODO: calculate based on previous piece
    mov dl, cl              ; x
    mov dh, ch              ; y
    mov cl, 32              ; height (default ground level)
    call add_track_piece
    
    ; Reconnect track pieces
    call connect_track_pieces
    
.done:
    pop rbx
    pop rax
    ret

; =========================================================
; Screen to Tile Conversion
; Input: eax=screen_x, ebx=screen_y
; Output: eax=tile_x, ebx=tile_y
; =========================================================
screen_to_tile:
    push rcx
    push rdx
    
    ; Adjust for screen center and camera
    sub eax, SCREEN_WIDTH / 2
    sub ebx, 100            ; Top margin
    
    ; Rough isometric inverse
    ; x = (screen_x / 16 + screen_y / 8) / 2 + camera_x
    ; y = (screen_y / 8 - screen_x / 16) / 2 + camera_y
    
    mov ecx, eax
    sar ecx, 4              ; screen_x / 16
    
    mov edx, ebx
    sar edx, 3              ; screen_y / 8
    
    ; Calculate tile x
    mov eax, ecx
    add eax, edx
    sar eax, 1
    add eax, [camera_tile_x]
    
    ; Calculate tile y
    mov ebx, edx
    sub ebx, ecx
    sar ebx, 1
    add ebx, [camera_tile_y]
    
    pop rdx
    pop rcx
    ret
