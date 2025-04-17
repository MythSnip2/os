BITS 16
ORG 0x7C00


start:
    ;disable interrupts
    cli

    cld
    ;zero out the segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax

    ;save the disk number
    mov [diskNum], dl

    ;initialize stack
    mov ss, ax
    mov sp, 0x7BFF ;stack grows below bootloader

    ;set video mode to text mode(8x25)
    mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    int 0x10 ;bios call video services
    ;enable cursor
    mov ah, 0x01 ;ah = 1
    xor cx, cx ;ch = start scanline, cl = end scanline



    ;enable interrupts
    sti

    xor ax, ax       ;print bootloader start msg
    mov ds, ax
    mov si, startup_msg
    call _printstr

    call _disk_read ;read bootloader code to ram

    jmp main

_disk_read:
    xor di, di ;counter for retry
_disk_read_loop:

    xor ax, ax
    mov ds, ax
    mov si, disk_read_msg ;Reading from disk: diskNum
    call _printstr

    ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
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
    ;if number of attempts is over or equal 8
    cmp di, 8
    jge __disk_read_fail_final

    xor ax, ax
    mov ds, ax
    mov si, disk_read_fail
    call _printstr

    ;attempt to reset disk
    xor ax, ax ;scancode ah = 0
    mov dl, [diskNum]
    int 0x13 ;reset disk system

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

__disk_read_fail_final:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_fail_final
    call _printstr
    ;blocking keyboard input
    xor ax, ax
    int 0x16 ;keyboard services
    jmp biosboot_pc

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

    mov cx, 0x2000
    call _wait

    int 0x19

    hlt
restart_pc:
    xor ax, ax
    mov ds, ax
    mov si, restart_msg
    call _printstr

    mov cx, 0x2000
    call _wait

    ;jump to reset vector
    jmp 0xFFFF:0x0000

    hlt
; subroutine to delay a certain amount of BIOS clock ticks
; cx: amount of ticks to wait(1 tick =~55ms)
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
    disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
    disk_read_success db 'Disk read success', 0xD, 0xA, 0

    biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
    restart_msg db 'Restarting...', 0xD, 0xA, 0
    times 446-($-$$) db 0 ;446B bootloader code
    ;MBR partition table(64B)
    ;first entry
    db 0b10000000 ;bit 7: bootable flag
    ;chs addressing of first sector
    db 0b00000000 ;head (bits 0-7)
    db 0b00000010 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
    db 0b00000000 ;cylinder(bits 0-7)
    db 0x0B ;partition type
    ;chs addressing of last sector
    db 0b00000000 ;head (bits 0-7)
    db 0b00010100 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
    db 0b00000000 ;cylinder(bits 0-7)
    dd 0x00000001 ;LBA for first sector
    dd 0x00000013 ;Number of sectors in partition
    ;other entries
    times 3*16 db 0

    times 510-($-$$) db 0 ;510B excluding boot signature
    db 0x55, 0xAA
; end of first sector, 512B -----------------------------------------------------------------------------------------------
; buffer sector(s)
times 512 db 0






main:
    xor ax, ax
    mov ds, ax
    mov si, oslogo
    call _printstr

    ;print a helpful message
    mov si, msg
    call _printstr

hang:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz hang ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    mov ah, 0x00
    int 0x16 ;ah = scancode, al = char

    ;detect F1-5 HIGH
    cmp ah, 0x3B
    je biosboot_pc
    cmp ah, 0x3C
    je restart_pc
    cmp ah, 0x3D
    je cls
    cmp ah, 0x3E
    je halt
    cmp ah, 0x3F
    je biosbeep

    push ax
    call hang_virtual_piano
    pop ax

    jmp hang



;subroutine to play a note in virtual piano
;key: al
hang_virtual_piano:
    xor cx, cx             ;i = 0
    mov dx, [keylen]       ;k = 10
hang_virtual_piano_loop:
    cmp cx, dx
    jge hang               ;return if i >= k
    mov si, cx             ;si = i
    xor bx, bx
    mov bl, [keys + si]    ;bl = keys[i]
    cmp al, bl             ;if pressed_key == keys[i]
    je hang_virtual_piano_play

    inc cx                 ;i++
    jmp hang_virtual_piano_loop

hang_virtual_piano_play:
    push cx
    mov ah, 0x0E
    int 0x10
    pop ax
    mov cx, 2
    mul cx
    mov si, ax
    mov ax, [notes + si]
    
    call _tone
    mov cx, 0xFFFF
    mov dx, 0x5
    call _wait_PIT
    call speaker_off
    jmp hang

    cli
    hlt
keylen dw 61
keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'

notes dw 65, 73, 82, 87, 98, 110, 123
dw 131, 147, 164, 174, 196, 220, 246
dw 262, 294, 330, 349, 392, 440, 494
dw 523, 587, 659, 698, 784, 880, 988
dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
dw 2093
dw 69, 78, 92, 104, 117
dw 139, 156, 185, 208, 233
dw 277, 311, 370, 415, 466
dw 554, 622, 740, 831, 932
dw 1109, 1245, 1480, 1661, 1865

cls:
    mov cx, 50
cls_loop:
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10
    loop cls_loop
    jmp hang

;bios beep tone
biosbeep:
    xor ax, ax
    mov ds, ax
    mov si, beep_msg
    call _printstr
    mov cx, 0x1000
    call _wait
    jmp hang

halt:
    mov cx, 50
halt_cls_loop:
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10
    loop halt_cls_loop
    ;disable cursor
    mov ah, 0x01
    mov cx, 0x2000 ;disable cursor
    int 0x10    ;int 0x10, 1: set cursor type

    cli
    hlt










_printstr_color:
    cld ;clear DF flag in FLAGS
__printstr_color_loop:
    mov al, [si]
    inc si

    or al, al ;if al = 0
    jz __printstr_color_exit ;exit loop
    push si
    mov ah, 0x09 ;write character with attribute
    mov bx, 0x00A0 ;bh page num, bl attribute
    mov cx, 1 ;number of times to write
    int 0x10 ;bios call video services
    
    mov ah, 0x03 ;read cursor position
    mov bh, 0x00 ;page num
    int 0x10

    inc dl ;increment column
    mov ah, 0x02 ;set cursor position
    mov bh, 0x00 ;page num
    int 0x10
    pop si
    jmp __printstr_color_loop
__printstr_color_exit:
    ret

;dx*cx is amount of ticks to wait
_wait_PIT:
    push cx
    call _wait_PIT_once
    pop cx
    dec dx
    jnz _wait_PIT
    ret

;cx, starting
;cx is amount of ticks to wait
_wait_PIT_once:
    push cx
    call _read_PIT_ticks
    push bx ;bx = starting count, pushed
_wait_PIT_once_loop:
    call _read_PIT_ticks ;read the count again, store in bx
    ;compute time difference = current count - start count
    pop ax      ;current count is bx, starting count is ax
    sub bx, ax  ;bx = time diff
    pop cx
    push cx
    push ax
    cmp bx, cx  ;if time diff < wait ticks, loop again
    jl _wait_PIT_once_loop
    pop ax
    pop ax
    ret


;returns PIT ticks stored in bx
_read_PIT_ticks:
    cli
    mov al, 0b00000000
    out 0x43, al
    in al, 0x40 ;LSB
    mov bl, al
    in al, 0x40 ;MSB
    mov bh, al
    sti
    ret

;PIT notes
;I/O port     Usage
;0x40         Channel 0 data port (read/write)
;0x41         Channel 1 data port (read/write)
;0x42         Channel 2 data port (read/write)
;0x43         Mode/Command register (write only, a read is ignored)
;
;Bits:  7 6 5 4 3 2 1 0
;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
;       | | | | +--+-- Mode (0–5)
;       | | +-----+-- Access Mode: 
;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
;subroutine to play a tone
;ax: frequency
_tone:
    push ax
    ;calculate divisor from frequency
    ;divisor = 1193182 / freq
    ;load numerator into dx:ax (1193182)(0x1234DE)
    mov dx, 0x12
    mov ax, 0x34DE
    ;load denominator into bx(frequency)
    pop bx
    ;divide
    div bx ;dx:ax / bx, quotient ax, remainder dx
    push ax ;save on stack

    call speaker_off
    ;write to PIT control register
    mov al, 0b10110110
    out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
    ;write divisor to channel 2 data port
    pop ax         ; Divisor
    mov bx, ax
    mov al, bl
    out 0x42, al         ; LSB first
    mov al, bh
    out 0x42, al         ; Then MSB
    
    call speaker_on
    xor ax, ax
    mov ds, ax
    ret

;tell speaker to not shut up
speaker_on:
    in al, 0x61
    or al, 0b11
    out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
    ret
;tell speaker to shut up
speaker_off:
    in al, 0x61
    and al, 0b11111100
    out 0x61, al
    ret

    cli
    hlt

    msg db 0xD, 0xA
    db 'Press F1 to go into BIOS setup(I think)', 0xD, 0xA
    db 'Press F2 to restart(far jump to reset vector)', 0xD, 0xA
    db 'Press F3 to clear screen', 0xD, 0xA
    db 'Press F4 to halt', 0xD, 0xA
    db 'Press F5 for BIOS beep', 0xD, 0xA
    db 'also virtual piano probably works', 0xD, 0xA
    
    
    db 0

    beep_msg db 'oAh', 0xD, 0xA, 0x7, 0
    oslogo db 0xD, 0xA
    db ' _   _                  _       ___    ____    _        ___  ', 0xD, 0xA
    db '| \ | |  _   _    ___  | | __  / _ \  / ___|  / |      / _ \ ', 0xD, 0xA
    db '|  \| | | | | |  / __| | |/ / | | | | \___ \  | |     | | | |', 0xD, 0xA
    db '| |\  | | |_| | | (__  |   <  | |_| |  ___) | | |  _  | |_| |', 0xD, 0xA
    db '|_| \_|  \__,_|  \___| |_|\_\  \___/  |____/  |_| (_)  \___/ ', 0xD, 0xA
    db 34, 'operating system of the future ', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0

    




times 10240-($-$$) db 0 ;total length of binary 20 sector
                        ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:code
