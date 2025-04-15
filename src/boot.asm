BITS 16
ORG 0x7C00


start:
    xor ax, ax
    mov ds, ax
    mov si, startup_msg
    call _printstr

    ;save the disk number
    mov [diskNum], dl

    ;initialize stack
    cli
    mov sp, 0x7BFF ;below bootloader
    sti

    ;set video mode to text mode(8x25)
    mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    int 0x10 ;bios call video services

    xor ax, ax
    mov ds, ax
    mov si, startup_msg
    call _printstr

    call _disk_read ;read bootloader code to ram

    jmp main

_disk_read:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_msg
    call _printstr

    ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    ;Read 19(0x13) sectors starting from 0:0:4 in drive dl, store in 0x7E00
    mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    mov cx, 0x0004 ;ch=cylinder number CHS | cl=sector number CHS
    xor dh, dh ;head number CHS
    mov dl, [diskNum] ;drive number
    ;Address to store values in: es:bx which is 0:7E00
    xor bx, bx
    mov es, bx
    mov bx, 0x7E00
    int 0x13 ;disk read
    jc __disk_read_fail

    ;disk read success
    xor ax, ax
    mov ds, ax
    mov si, disk_read_success
    call _printstr


    ret
__disk_read_fail:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_fail
    call _printstr

    ;reset disk system
    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset
    call _printstr

    xor ax, ax ;scancode ah = 0
    mov dl, [diskNum]
    int 13 ;reset disk system
    jc __disk_reset_fail

    ;reset success
    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset_success
    call _printstr
__disk_retry_resume:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_retry
    call _printstr

    jmp _disk_read

__disk_reset_fail:
    mov cx, 0x3000
    call _wait

    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset_failure
    call _printstr

    jmp __disk_retry_resume


; subroutine to print a string until null terminator
; address of string: ds:si
_printstr:
    cld ;clear DF flag in FLAGS
__printstr_loop:
    mov al, [si]
    inc si

    or al, al ;if al = 0
    jz __printstr_exit ;exit loop

    mov ah, 0x0E ;write character in TTY mode (bios call)
    xor bx, bx ;bh = 0
    int 0x10 ;bios call video services
    jmp __printstr_loop
__printstr_exit:
    ret



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

    hlt

    startup_msg db 'Nuck OS bootloader', 0xD, 0xA, 0
    disk_read_msg db 'Reading from disk: '
    diskNum db 1 ;reserved for BIOS drive number
    db 0xD, 0xA, 0

    disk_read_fail db 'Disk read failure', 0xD, 0xA, 0
    disk_read_success db 'Disk read success', 0xD, 0xA, 0

    disk_read_retry db 'Retrying', 0xD, 0xA, 0
    disk_read_reset db 'Resetting disk', 0xD, 0xA, 0
    disk_read_reset_failure db 'Disk reset failure', 0xD, 0xA, 0
    disk_read_reset_success db 'Disk reset success', 0xD, 0xA, 0

    times 510-($-$$) db 0
    db 0x55, 0xAA
; end of first sector, 512B ---------------------------------------------------------------------


main:

    xor ax, ax
    mov ds, ax
    mov si, oslogo
    call _printstr
    mov si, osdesc
    call _printstr
    mov si, archlogo
    call _printstr






hang:

    mov ax, 0
    push ax ;0 for terminate
    ;print shell character
    mov ax, 0x0E7E ;~
    int 0x10
hang_loop:

; subroutine to process keyboard interrupts, enter key makes newline
_keyInterrupt:
    mov ax, 0x0001 ;ah = 1, get keyboard status(get character but non blocking)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jnz hang_loop ;if key not pressed jump back


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
    int 0x10 ;prints backspace(move cursor back)
    mov al, 0x0
    int 0x10 ;prints null (to erase character)
    mov al, 0x8
    int 0x10 ;moves cursor back again
    pop ax
    ;if it is not zero return immediately
    mov bl, 0
    cmp al, bl
    jne hang_loop
    ;push back
    push ax
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

    ;print shell character
    mov ax, 0x0E7E ;~
    int 0x10
    jmp hang_loop


    hlt
    
    oslogo db ' _   _                   ___    ____  ', 0xD, 0xA, '| | | |   ___   _ __    / _ \  / ___| ', 0xD, 0xA, "| |_| |  / _ \ | '_ \  | | | | \___ \ ", 0xD, 0xA, '|  _  | |  __/ | | | | | |_| |  ___', 0x29, ' |', 0xD, 0xA, '|_| |_|  \___| |_| |_|  \___/  |____/ ', 0xD, 0xA, 0
    osdesc db 34, 'operating system of the future ', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
    archlogo db '                   -`', 0xD, 0xA, '                  .o+`', 0xD, 0xA, '                 `ooo/', 0xD, 0xA, '                `+oooo:', 0xD, 0xA, '               `+oooooo:', 0xD, 0xA, '               -+oooooo+:', 0xD, 0xA, '             `/:-:++oooo+:', 0xD, 0xA, '            `/++++/+++++++:', 0xD, 0xA, '           `/++++++++++++++:', 0xD, 0xA, '          `/+++ooooooooooooo/`', 0xD, 0xA, '         ./ooosssso++osssssso+`', 0xD, 0xA, '        .oossssso-````/ossssss+`', 0xD, 0xA, '       -osssssso.      :ssssssso.', 0xD, 0xA, '      :osssssss/        osssso+++.', 0xD, 0xA, '     /ossssssss/        +ssssooo/-', 0xD, 0xA, '   `/ossssso+/:-        -:/+osssso+-', 0xD, 0xA, '  `+sso+:-`                 `.-/+oso:', 0xD, 0xA, ' `++:.                           `-/+/', 0xD, 0xA, ' .`                                 `', 0xD, 0xA, 0




times 10240-($-$$) db 0 ;total length of binary 20 sectors
                           ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:code
