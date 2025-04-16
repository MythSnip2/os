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

    xor ax, ax       ;print bootloader start msg
    mov ds, ax
    mov si, startup_msg
    call _printstr

    mov cx, 0x4000
    call _wait

    call _disk_read ;read bootloader code to ram

    jmp main

_disk_read:
    mov di, 0 ;counter for retry
_disk_read_loop:

    xor ax, ax
    mov ds, ax
    mov si, disk_read_msg ;Reading from disk: diskNum
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

    ;if number of attempts is over or equal 8, restart computer
    cmp di, 8
    jge biosboot_pc

    xor ax, ax
    mov ds, ax
    mov si, disk_read_fail
    call _printstr

    ;attempt to reset disk
    xor ax, ax ;scancode ah = 0
    mov dl, [diskNum]
    int 13 ;reset disk system

    inc di
    ;update number of attempts
    mov ax, di
    add ax, '0'
    mov [attempt_num], al

    xor ax, ax
    mov ds, ax
    mov si, attempts_msg
    call _printstr

    mov cx, 0x2000
    call _wait

    jmp _disk_read_loop


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

biosboot_pc:
    xor ax, ax
    mov ds, ax
    mov si, biosboot_msg
    call _printstr

    mov cx, 0xB000
    call _wait

    int 0x19

    cli
    hlt
restart_pc:
    xor ax, ax
    mov ds, ax
    mov si, restart_msg
    call _printstr

    mov cx, 0xB000
    call _wait

    ;jump to reset vector
    jmp 0xFFFF:0x0000

    cli
    hlt
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

    cli
    hlt

    disk_read_msg db 'Reading from disk: '
    diskNum db 1 ;reserved for BIOS drive number
    db 0xD, 0xA, 0

    attempts_msg db 'Attempt '
    attempt_num db 3
    db ' of 8', 0xD, 0xA, 0

    startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
    disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
    disk_read_success db 'Disk read success', 0xD, 0xA, 0

    biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
    restart_msg db 'Restarting...', 0xD, 0xA, 0

    times 445-($-$$) db 0 ;446B bootloader code
    db 0xAA
    ;MBR partition table(64B)

    times 510-($-$$) db 0 ;510B excluding boot signature
    db 0x55, 0xAA
; end of first sector, 512B -----------------------------------------------------------------------------------------------

main:
    xor ax, ax
    mov ds, ax
    mov si, oslogo
    call _printstr
    mov si, osdesc
    call _printstr

    ;print a helpful message
    mov si, msg
    call _printstr

hang:
    mov ax, 0x0001 ;ah = 1, get keyboard status(get character but non blocking)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jnz hang ;if key not pressed jump back

    ;check if character is a
    cmp al, 'a'
    je _beep
    ;check if character is 1
    cmp al, '1'
    je biosboot_pc
    ;check if character is 2
    cmp al, '2'
    je restart_pc
    ;check if character is 3
    cmp al, '3'
    je halt


    jmp hang

;bios beep tone
_beep:
    mov ah, 0x0E
    mov al, 7
    int 0x10
    jmp hang

halt:
    xor ax, ax
    mov ds, ax
    mov si, halt_msg
    call _printstr
    cli
    hlt

    msg db 'Press a for beep', 0xD, 0xA, 'Press 1 to go into BIOS setup(I think)', 0xD, 0xA, 'Press 2 to restart(far jump to reset vector)', 0xD, 0xA, 'Press 3 to halt', 0xD, 0xA, 0
    halt_msg db 'Halted!', 0xD, 0xA, 0
    oslogo db ' _   _                   ___    ____  ', 0xD, 0xA, '| | | |   ___   _ __    / _ \  / ___| ', 0xD, 0xA, "| |_| |  / _ \ | '_ \  | | | | \___ \ ", 0xD, 0xA, '|  _  | |  __/ | | | | | |_| |  ___', 0x29, ' |', 0xD, 0xA, '|_| |_|  \___| |_| |_|  \___/  |____/ ', 0xD, 0xA, 0
    osdesc db 34, 'operating system of the future ', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0xA, 0

times 10240-($-$$) db 0 ;total length of binary 20 sector
                        ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:code
