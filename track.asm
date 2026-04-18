; =========================================================
; RCT CHALLENGE - Track System
; =========================================================
; Implements RCT-style track pieces with proper connectivity

%include "constants.inc"
%include "structs.inc"

section .data
    ; Track piece geometry lookup tables
    ; Each piece defines its entry/exit points relative to tile
    
    ; Entry deltas: dx, dy, dz (for each direction)
    ; Piece type 0: STRAIGHT
    piece_straight_entry:
        db 0, 0, 0          ; North
        db 0, 0, 0          ; East  
        db 0, 0, 0          ; South
        db 0, 0, 0          ; West
    piece_straight_exit:
        db 0, 1, 0          ; North -> South
        db 1, 0, 0          ; East -> West
        db 0, -1, 0         ; South -> North
        db -1, 0, 0         ; West -> East
    
    ; Piece type 1: FLAT_TURN (90 degree)
    piece_turn_entry:
        db 0, 0, 0
        db 0, 0, 0
        db 0, 0, 0
        db 0, 0, 0
    piece_turn_exit:
        db 1, 0, 0          ; North -> East
        db 0, 1, 0          ; East -> South
        db -1, 0, 0         ; South -> West
        db 0, -1, 0         ; West -> North
    
    ; Piece type 2: SLOPE_UP
    piece_slope_up_entry:
        db 0, 0, 0
        db 0, 0, 0
        db 0, 0, 2          ; Start 2 units higher from south
        db 0, 0, 2
    piece_slope_up_exit:
        db 0, 1, 2          ; North -> South, +2 height
        db 1, 0, 2
        db 0, -1, -2        ; Going back down
        db -1, 0, -2
    
    ; Piece type 3: SLOPE_DOWN (inverse of up)
    piece_slope_down_entry:
        db 0, 0, 2
        db 0, 0, 2
        db 0, 0, 0
        db 0, 0, 0
    piece_slope_down_exit:
        db 0, 1, -2
        db 1, 0, -2
        db 0, -1, 2
        db -1, 0, 2
    
    ; Track color
    track_color dd 0xFFB0C4DE     ; Light steel blue
    track_rail_color dd 0xFF708090 ; Darker steel
    
    ; Status
    track_count dd 0
    selected_piece_type db 0

section .bss
    track_pieces resb MAX_TRACK_PIECES * TRACK_PIECE_SIZE
    coaster_start_piece resw 1      ; Index of first piece

section .text
    global init_track_system
    global add_track_piece
    global remove_track_piece
    global get_track_piece
    global find_track_at
    global get_next_piece_index
    global get_prev_piece_index
    global get_piece_exit_point
    global is_valid_placement
    global connect_track_pieces
    
    extern get_tile
    extern set_tile
    extern world_to_screen
    extern draw_line
    extern draw_pixel_z
    extern get_color

; =========================================================
; Initialize Track System
; =========================================================
init_track_system:
    ; Clear track array
    mov rdi, track_pieces
    xor rax, rax
    mov rcx, (MAX_TRACK_PIECES * TRACK_PIECE_SIZE) / 8
    rep stosq
    
    mov dword [track_count], 0
    mov word [coaster_start_piece], -1
    
    ; Add a test track (small loop)
    call build_test_track
    
    ret

; =========================================================
; Build Test Track - Simple oval for testing
; =========================================================
build_test_track:
    push rbx
    
    mov ebx, 0              ; piece index counter
    
    ; Start at tile (60, 60), height 32, facing North
    mov al, TRACK_STATION
    mov ah, DIR_NORTH
    mov dl, 60              ; x
    mov dh, 60              ; y
    mov cl, 32              ; z
    call add_track_piece
    
    ; Straight section
    mov al, TRACK_STRAIGHT
    mov ah, DIR_NORTH
    mov dl, 60
    mov dh, 61
    mov cl, 32
    call add_track_piece
    
    ; Turn to East
    mov al, TRACK_FLAT_TURN
    mov ah, DIR_NORTH
    mov dl, 60
    mov dh, 62
    mov cl, 32
    call add_track_piece
    
    ; Straight East
    mov al, TRACK_STRAIGHT
    mov ah, DIR_EAST
    mov dl, 61
    mov dh, 62
    mov cl, 32
    call add_track_piece
    
    ; Another straight
    mov al, TRACK_STRAIGHT
    mov ah, DIR_EAST
    mov dl, 62
    mov dh, 62
    mov cl, 32
    call add_track_piece
    
    ; Turn South
    mov al, TRACK_FLAT_TURN
    mov ah, DIR_EAST
    mov dl, 63
    mov dh, 62
    mov cl, 32
    call add_track_piece
    
    ; Straight South
    mov al, TRACK_STRAIGHT
    mov ah, DIR_SOUTH
    mov dl, 63
    mov dh, 61
    mov cl, 32
    call add_track_piece
    
    ; Straight South
    mov al, TRACK_STRAIGHT
    mov ah, DIR_SOUTH
    mov dl, 63
    mov dh, 60
    mov cl, 32
    call add_track_piece
    
    ; Turn West
    mov al, TRACK_FLAT_TURN
    mov ah, DIR_SOUTH
    mov dl, 63
    mov dh, 59
    mov cl, 32
    call add_track_piece
    
    ; Straight West (back toward start)
    mov al, TRACK_STRAIGHT
    mov ah, DIR_WEST
    mov dl, 62
    mov dh, 59
    mov cl, 32
    call add_track_piece
    
    ; Close the loop
    mov al, TRACK_STRAIGHT
    mov ah, DIR_WEST
    mov dl, 61
    mov dh, 59
    mov cl, 32
    call add_track_piece
    
    ; Connect pieces into a loop
    call connect_track_pieces
    
    pop rbx
    ret

; =========================================================
; Add Track Piece
; Input: al=type, ah=direction, dl=x, dh=y, cl=z
; Output: ax=piece index, or -1 if failed
; =========================================================
add_track_piece:
    push rbx
    push r12
    
    mov r12w, ax            ; Save type/direction
    
    ; Check if we have room
    mov ebx, [track_count]
    cmp ebx, MAX_TRACK_PIECES
    jge .failed
    
    ; Calculate offset
    mov eax, ebx
    imul eax, TRACK_PIECE_SIZE
    lea rbx, [track_pieces + rax]
    
    ; Fill in piece data
    mov byte [rbx + TrackPiece.type], r12b
    mov byte [rbx + TrackPiece.direction], r12h
    mov byte [rbx + TrackPiece.x], dl
    mov byte [rbx + TrackPiece.y], dh
    mov byte [rbx + TrackPiece.z], cl
    mov byte [rbx + TrackPiece.flags], 0
    mov word [rbx + TrackPiece.next_piece], -1
    mov word [rbx + TrackPiece.prev_piece], -1
    
    ; Mark tile as having track
    movzx eax, dl
    movzx ebx, dh
    call get_tile
    test rax, rax
    jz .skip_tile
    or byte [rax + Tile.flags], TILE_HAS_TRACK
.skip_tile:
    
    ; Increment count and return index
    mov eax, [track_count]
    mov ax, ax
    inc dword [track_count]
    
    pop r12
    pop rbx
    ret
    
.failed:
    mov ax, -1
    pop r12
    pop rbx
    ret

; =========================================================
; Connect Track Pieces - Links pieces based on proximity
; =========================================================
connect_track_pieces:
    push rbx
    push r12
    push r13
    
    ; For each piece, find the piece that starts where this one ends
    xor r12d, r12d          ; Current piece index
    
.connect_loop:
    cmp r12d, [track_count]
    jge .done
    
    ; Get current piece exit point
    mov rdi, r12
    call get_piece_exit_point
    ; Returns: r8d=exit_x, r9d=exit_y, r10d=exit_z, r11d=exit_dir
    
    ; Search for a piece at this location
    xor r13d, r13d
.search_loop:
    cmp r13d, [track_count]
    jge .next_piece
    cmp r13d, r12d
    je .skip
    
    ; Check if piece r13 starts at (r8, r9, r10) with entry dir matching
    mov eax, r13d
    imul eax, TRACK_PIECE_SIZE
    lea rbx, [track_pieces + rax]
    
    movzx eax, byte [rbx + TrackPiece.x]
    cmp eax, r8d
    jne .skip
    movzx eax, byte [rbx + TrackPiece.y]
    cmp eax, r9d
    jne .skip
    movzx eax, byte [rbx + TrackPiece.z]
    cmp eax, r10d
    jne .skip
    
    ; Found match - connect!
    mov eax, r12d
    imul eax, TRACK_PIECE_SIZE
    lea rbx, [track_pieces + rax]
    mov word [rbx + TrackPiece.next_piece], r13w
    
    mov eax, r13d
    imul eax, TRACK_PIECE_SIZE
    lea rbx, [track_pieces + rax]
    mov word [rbx + TrackPiece.prev_piece], r12w
    
    jmp .next_piece
    
.skip:
    inc r13d
    jmp .search_loop
    
.next_piece:
    inc r12d
    jmp .connect_loop
    
.done:
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Get Piece Exit Point
; Input: rdi=piece index
; Output: r8d=exit_x, r9d=exit_y, r10d=exit_z, r11d=exit_direction
; =========================================================
get_piece_exit_point:
    push rax
    push rbx
    
    ; Get piece pointer
    mov eax, edi
    imul eax, TRACK_PIECE_SIZE
    lea rbx, [track_pieces + rax]
    
    ; Get current position
    movzx r8d, byte [rbx + TrackPiece.x]
    movzx r9d, byte [rbx + TrackPiece.y]
    movzx r10d, byte [rbx + TrackPiece.z]
    movzx r11d, byte [rbx + TrackPiece.direction]
    movzx eax, byte [rbx + TrackPiece.type]
    
    ; Get exit delta based on type and direction
    ; (Simplified - just handle straight and turn)
    cmp al, TRACK_STRAIGHT
    je .straight
    cmp al, TRACK_FLAT_TURN
    je .turn
    cmp al, TRACK_SLOPE_UP
    je .slope_up
    cmp al, TRACK_SLOPE_DOWN
    je .slope_down
    cmp al, TRACK_STATION
    je .straight            ; Station acts like straight
    jmp .default

.straight:
    ; Exit direction is same as entry
    ; Move 1 tile in that direction
    cmp r11d, DIR_NORTH
    je .north
    cmp r11d, DIR_EAST
    je .east
    cmp r11d, DIR_SOUTH
    je .south
    jmp .west
    
.north:
    dec r9d                 ; y -= 1
    jmp .done
.east:
    inc r8d                 ; x += 1
    jmp .done
.south:
    inc r9d                 ; y += 1
    jmp .done
.west:
    dec r8d                 ; x -= 1
    jmp .done

.turn:
    ; Turn changes direction 90 degrees clockwise
    ; and moves diagonally
    inc r11d                ; Turn right
    and r11d, 3             ; Wrap 0-3
    
    ; Move based on NEW direction
    cmp r11d, DIR_NORTH
    je .north
    cmp r11d, DIR_EAST
    je .east
    cmp r11d, DIR_SOUTH
    je .south
    jmp .west

.slope_up:
    add r10d, 2             ; +2 height
    ; Then same as straight
    jmp .straight

.slope_down:
    sub r10d, 2             ; -2 height
    jmp .straight

.default:
    inc r9d                 ; Default: south

.done:
    pop rbx
    pop rax
    ret

; =========================================================
; Get Track Piece
; Input: eax=index
; Output: rax=pointer, or null
; =========================================================
get_track_piece:
    cmp eax, [track_count]
    jge .null
    cmp eax, 0
    jl .null
    
    imul eax, TRACK_PIECE_SIZE
    lea rax, [track_pieces + rax]
    ret
    
.null:
    xor rax, rax
    ret

; =========================================================
; Find Track at Position
; Input: eax=x, ebx=y, ecx=z
; Output: eax=piece index, or -1
; =========================================================
find_track_at:
    push rbx
    push r12
    push r13
    
    mov r12d, eax           ; target x
    mov r13d, ebx           ; target y
    xor ebx, ebx
    
.loop:
    cmp ebx, [track_count]
    jge .not_found
    
    mov eax, ebx
    imul eax, TRACK_PIECE_SIZE
    lea rax, [track_pieces + rax]
    
    movzx edx, byte [rax + TrackPiece.x]
    cmp edx, r12d
    jne .next
    movzx edx, byte [rax + TrackPiece.y]
    cmp edx, r13d
    jne .next
    movzx edx, byte [rax + TrackPiece.z]
    cmp edx, ecx
    jne .next
    
    ; Found it
    mov eax, ebx
    jmp .done
    
.next:
    inc ebx
    jmp .loop
    
.not_found:
    mov eax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    ret

; =========================================================
; Remove Track Piece (simplified - just marks as unused)
; =========================================================
remove_track_piece:
    ; TODO: Remove piece and reconnect neighbors
    ret

; =========================================================
; Is Valid Placement
; Check if a track piece can be placed here
; =========================================================
is_valid_placement:
    ; TODO: Check terrain, existing tracks, clearance
    mov eax, 1
    ret
