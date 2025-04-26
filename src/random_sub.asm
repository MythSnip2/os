
; -------------------------------------------------------------------------------
; subroutine to print a string until null terminator
; address of string: ds:si
_printstr:
    cld ;clear DF flag in FLAGS
__printstr_loop:
    lodsb ;load character at ds:si to al, then inc si

    or al, al ;if al = 0
    jz __printstr_exit ;exit loop

    mov ah, 0x0E ;write character in TTY mode (bios call)
    xor bx, bx ;bh = 0
    int 0x10 ;bios call video services
    jmp __printstr_loop
__printstr_exit:
    ret
; -------------------------------------------------------------------------------
; subroutine to delay a certain amount of cpu cycles
; amount of clock cycles to wait(*17*65535): cx
_wait:
    push cx

    mov cx, 0xFFFF
__wait_innerloop:
    loop __wait_innerloop

    pop cx
    loop _wait
    ret
; -------------------------------------------------------------------------------
; subroutine to process keyboard interrupts, enter key makes newline
_keyInterrupt:
    xor ax, ax ;ah = 0, Read Character
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    
    ;check if character is newline
    cmp al, 0xD ;if carriage return
    je __keyInterrupt_newline

    mov ah, 0x0E ;print character in tty
    int 0x10 ;video services
    ret
__keyInterrupt_newline:
    mov ah, 0x0E ;print character in tty
    int 0x10 ;video services
    
    mov al, 0xA ;line feed
    int 0x10 ;video services
    ret
; -------------------------------------------------------------------------------


times 510-($-$$) db 0
db 0x55, 0xAA





; Call this with ax set to a value for CH4 HW1
; ax = dividend
_tobase10:
    mov bl, 0
    push bx  ;push 0 for terminate

__tobase10_loop:
    ;divide dx:ax by r/16b
    mov dx, 0
    mov bx, 10
    div bx  ;ax // bx(10) -> quotient AX remainder DX
    ;store remainder in ascii
    mov bl, '0'
    add bl, dl ;bl = '0' + remainder
    push bx
    
    ;jump if ax is non-zero
    mov dx, 0
    cmp ax, dx
    jne __tobase10_loop ;loop


__tobase10_print: ;print characters in stack until null
    pop ax
    ;toodaloo if al is null
    cmp al, dl
    je __tobase10_exit

    mov ah, 0x0E ;print character in tty
    int 0x10 ;video services

    jmp __tobase10_print
__tobase10_exit:
    ret









;Call this subroutine for CH4 HW2
hang:
    mov ax, 0
    push ax ;0 for terminate

hang_loop:

; subroutine to process keyboard interrupts, enter key makes newline
_keyInterrupt:
    xor ax, ax ;ah = 0, Read Character
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code

    ;check if character is 0xD
    mov bl, 0xD
    cmp al, bl ;if 0xD
    je _keyInterrupt_newline

    ;check if character is backspace
    mov bl, 0x8
    cmp al, bl ;if backspace
    je _keyInterrupt_del

    ;if character is not 0xD, save on stack
    xor ah, ah
    push ax

    mov ah, 0x0E ;print character in tty
    int 0x10 ;video services
    jmp hang_loop

_keyInterrupt_del:
    mov ah, 0x0E
    int 0x10
    mov al, 0x0
    int 0x10
    mov al, 0x8
    int 0x10
    pop ax
    ;if it is not zero return immediately
    mov bl, 0
    cmp al, bl
    jne _keyInterrupt_del_z
    ;push back
    push ax
_keyInterrupt_del_z:
    jmp hang_loop

_keyInterrupt_newline:
    mov ah, 0x0E ;print character in tty
    int 0x10 ;video services
    
    mov al, 0xA ;line feed
    int 0x10 ;video services

    ;print all characters saved on stack
_keyInterrupt_print:
    pop ax
    ;toodaloo if equal to 0
    mov bx, 0
    cmp ax, bx
    je _keyInterrupt_exit ;if ax == 0, exit

    ;print char
    mov ah, 0x0E
    int 0x10

    ;loop back
    jmp _keyInterrupt_print

_keyInterrupt_exit:
    ;restore the null value on stack for exit, then return
    mov ax, 0
    push ax

    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10

    jmp hang_loop










