; =========================================================
; RCT CHALLENGE - Video/Framebuffer System
; =========================================================

%include "constants.inc"

section .data
    fb_path db "/dev/fb0", 0
    fb_size dq SCREEN_WIDTH * SCREEN_HEIGHT * FB_BPP
    
    ; Color palette (indexed colors like RCT!)
    palette:
        dd 0xFF1a1a1a    ; 0: Black/Dark
        dd 0xFF2d5016    ; 1: Deep green (grass)
        dd 0xFF3d6b1f    ; 2: Green (grass lit)
        dd 0xFF8B4513    ; 3: Brown (dirt)
        dd 0xFFA0522D    ; 4: Light brown
        dd 0xFF0066CC    ; 5: Water
        dd 0xFF0088FF    ; 6: Water light
        dd 0xFFB0C4DE    ; 7: Steel (track)
        dd 0xFF708090    ; 8: Dark steel
        dd 0xFF8B0000    ; 9: Dark red
        dd 0xFFFF0000    ; 10: Red
        dd 0xFFFFCC99    ; 11: Skin
        dd 0xFF4169E1    ; 12: Royal blue (pants)
        dd 0xFF228B22    ; 13: Forest green
        dd 0xFFDAA520    ; 14: Goldenrod (supports)
        dd 0xFFFFFFFF    ; 15: White

section .bss
    fb_fd resq 1
    fb_mem resq 1
    z_buffer resd SCREEN_WIDTH * SCREEN_HEIGHT  ; For proper isometric depth

section .text
    global init_framebuffer
    global cleanup
    global clear_screen
    global draw_pixel
    global draw_pixel_z
    global draw_line
    global get_color
    global swap_buffers
    global iso_project

; =========================================================
; Initialize Framebuffer
; =========================================================
init_framebuffer:
    push rbx
    
    ; Open /dev/fb0
    mov rax, 2              ; sys_open
    mov rdi, fb_path
    mov rsi, 2              ; O_RDWR
    syscall
    
    cmp rax, 0
    jl .error
    mov [fb_fd], rax
    
    ; mmap the framebuffer
    mov rax, 9              ; sys_mmap
    xor rdi, rdi            ; Let kernel choose address
    mov rsi, [fb_size]
    mov rdx, 3              ; PROT_READ | PROT_WRITE
    mov r10, 1              ; MAP_SHARED
    mov r8, [fb_fd]
    xor r9, r9              ; Offset 0
    syscall
    
    cmp rax, -4095
    jae .error
    mov [fb_mem], rax
    
    ; Clear z-buffer
    mov rdi, z_buffer
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov eax, 0x7FFFFFFF     ; Max depth
    rep stosd
    
    xor rax, rax            ; Success
    pop rbx
    ret
    
.error:
    mov rax, -1
    pop rbx
    ret

; =========================================================
; Cleanup
; =========================================================
cleanup:
    ; munmap
    mov rax, 11             ; sys_munmap
    mov rdi, [fb_mem]
    mov rsi, [fb_size]
    syscall
    
    ; close fb
    mov rax, 3              ; sys_close
    mov rdi, [fb_fd]
    syscall
    ret

; =========================================================
; Clear Screen
; =========================================================
clear_screen:
    push rdi
    push rcx
    
    mov rdi, [fb_mem]
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov eax, 0xFF1a1a1a     ; Dark background
    rep stosd
    
    ; Clear z-buffer
    mov rdi, z_buffer
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov eax, 0x7FFFFFFF
    rep stosd
    
    pop rcx
    pop rdi
    ret

; =========================================================
; Draw Pixel with Z-buffer
; Input: eax=x, ebx=y, ecx=color, edx=z (depth)
; =========================================================
draw_pixel_z:
    ; Bounds check
    cmp eax, 0
    jl .out
    cmp eax, SCREEN_WIDTH
    jge .out
    cmp ebx, 0
    jl .out
    cmp ebx, SCREEN_HEIGHT
    jge .out
    
    ; Calculate z-buffer index
    push rax
    push rbx
    imul ebx, SCREEN_WIDTH
    add ebx, eax
    shl ebx, 2              ; *4 for dword
    
    ; Depth test
    mov eax, [z_buffer + ebx]
    cmp edx, eax
    jge .skip               ; Behind existing pixel
    
    ; Update z-buffer
    mov [z_buffer + ebx], edx
    
    pop rbx
    pop rax
    
    ; Draw pixel (fall through to draw_pixel)
    jmp draw_pixel.no_bounds
    
.skip:
    pop rbx
    pop rax
.out:
    ret

; =========================================================
; Draw Pixel (no z-test)
; Input: eax=x, ebx=y, ecx=color
; =========================================================
draw_pixel:
    ; Bounds check
    cmp eax, 0
    jl .out
    cmp eax, SCREEN_WIDTH
    jge .out
    cmp ebx, 0
    jl .out
    cmp ebx, SCREEN_HEIGHT
    jge .out
    
.no_bounds:
    push rdi
    push rax
    push rbx
    
    ; Calculate offset: (y * width + x) * 4
    imul ebx, SCREEN_WIDTH
    add ebx, eax
    shl ebx, 2
    
    mov rdi, [fb_mem]
    mov [rdi + rbx], ecx
    
    pop rbx
    pop rax
    pop rdi
.out:
    ret

; =========================================================
; Draw Line (Bresenham)
; Input: r8d=x0, r9d=y0, r10d=x1, r11d=y1, r12d=color, r13d=z
; =========================================================
draw_line:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Calculate deltas
    mov r14d, r10d
    sub r14d, r8d           ; dx
    mov r15d, r11d
    sub r15d, r9d           ; dy
    
    ; Determine step directions
    mov eax, 1
    test r14d, r14d
    jns .dx_pos
    neg eax
    neg r14d
.dx_pos:
    mov ebx, 1
    test r15d, r15d
    jns .dy_pos
    neg ebx
    neg r15d
.dy_pos:
    
    ; Store steps
    push rax                ; x step
    push rbx                ; y step
    
    ; Compare |dx| and |dy|
    cmp r14d, r15d
    jl .y_major
    
    ; X-major line
    mov edx, r14d
    shr edx, 1              ; err = dx/2
    mov ecx, r14d         ; count
    
.x_loop:
    ; Draw pixel
    mov eax, r8d
    mov ebx, r9d
    push rcx
    push rdx
    mov ecx, r12d
    mov edx, r13d
    call draw_pixel_z
    pop rdx
    pop rcx
    
    ; Update error
    sub edx, r15d
    jge .x_no_y
    add r9d, [rsp]        ; y step
    add edx, r14d
.x_no_y:
    add r8d, [rsp + 8]    ; x step
    loop .x_loop
    jmp .done

.y_major:
    ; Y-major line
    mov edx, r15d
    shr edx, 1              ; err = dy/2
    mov ecx, r15d
    
.y_loop:
    mov eax, r8d
    mov ebx, r9d
    push rcx
    push rdx
    mov ecx, r12d
    mov edx, r13d
    call draw_pixel_z
    pop rdx
    pop rcx
    
    sub edx, r14d
    jge .y_no_x
    add r8d, [rsp + 8]    ; x step
    add edx, r15d
.y_no_x:
    add r9d, [rsp]        ; y step
    loop .y_loop

.done:
    add rsp, 16             ; Clean up step values
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Isometric Projection
; Input: eax=tile_x, ebx=tile_y, ecx=height
; Output: r8d=screen_x, r9d=screen_y, r10d=depth
; =========================================================
iso_project:
    ; Isometric formula:
    ; screen_x = (x - y) * TILE_W/2 + offset_x
    ; screen_y = (x + y) * TILE_H/2 - height * HEIGHT_SCALE + offset_y
    ; depth = x + y (for painter's algorithm)
    
    push rax
    push rbx
    push rcx
    
    ; Calculate depth for Z-sorting
    mov r10d, eax
    add r10d, ebx
    add r10d, ecx           ; Depth = x + y + height
    
    ; Save height for later
    push rcx
    
    ; screen_x = (x - y) * 16 + 512 (center)
    sub eax, ebx
    shl eax, 4              ; *16
    add eax, 512
    mov r8d, eax
    
    ; screen_y = (x + y) * 8 + 100 - height*4
    pop rcx                 ; Restore height
    pop rbx
    pop rax
    add eax, ebx
    shl eax, 3              ; *8
    sub eax, ecx            ; Subtract height for fake 3D
    shl ecx, 2              ; height * 4
    sub eax, ecx
    add eax, 100
    mov r9d, eax
    
    pop rcx
    pop rbx
    pop rax
    ret

; =========================================================
; Get Color from Palette
; Input: al = color index
; Output: eax = ARGB color
; =========================================================
get_color:
    and eax, 0x0F
    mov ebx, eax
    shl ebx, 2              ; *4
    mov eax, [palette + ebx]
    ret

; =========================================================
; Swap Buffers (if using double buffering)
; For now, we draw directly to framebuffer
; =========================================================
swap_buffers:
    ; In a real implementation, this would flip between
    ; front and back buffers. For fb0, we're direct.
    ret
