BITS 16
ORG 0x7C00


start:
    ;reset segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ;save the disk number
    mov [diskNum], dl

    ;initialize stack
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0x7BFF ;below bootloader
    sti

    ;set video mode to text mode(8x25)
    mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    int 0x10 ;bios call video services

    call _disk_read


    jmp hang

_disk_read:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_msg
    call _printstr

    ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    ;Read 7 sectors starting from 0:0:4 in drive dl, store in 0x7E00
    mov ax, 0x0207 ;ah=scancode, Read sectors | al=number of sectors to read
    mov cx, 0x0004 ;ch=cylinder number CHS | cl=sector number CHS
    xor dh, dh ;head number CHS
    mov dl, [diskNum] ;drive number
    ;Address to store values in: es:bx which is 0:7E00
    mov bx, 0
    mov es, bx
    mov bx, 0x7E00
    int 0x13
    jc __disk_read_fail

    ;disk read success
    xor ax, ax
    mov ds, ax
    mov si, disk_read_success_msg
    call _printstr

    ret
__disk_read_fail:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_fail_msg
    call _printstr

    mov cx, 0x3000
    call _wait

    ;reset disk system
    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset_msg
    call _printstr

    xor ax, ax ;ah = 0
    mov dl, [diskNum]
    int 13
    jc __disk_reset_fail

    mov cx, 0x3000
    call _wait

    ;reset success
    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset_success_msg
    call _printstr
__disk_retry_resume:
    xor ax, ax
    mov ds, ax
    mov si, disk_read_retry_msg
    call _printstr

    mov cx, 0x3000
    call _wait

    jmp _disk_read

__disk_reset_fail:
    mov cx, 0x3000
    call _wait

    xor ax, ax
    mov ds, ax
    mov si, disk_read_reset_failure_msg
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

    disk_read_msg db 'Reading from disk: '
    diskNum db 1 ;reserved for BIOS drive number
    db 0xD, 0xA, 0

    disk_read_fail_msg db 'Disk read failure', 0xD, 0xA, 0
    disk_read_success_msg db 'Disk read success', 0xD, 0xA, 0
    disk_read_retry_msg db 'Retrying...', 0xD, 0xA, 0
    disk_read_reset_msg db 'Resetting disk...', 0xD, 0xA, 0
    disk_read_reset_failure_msg db 'Disk reset failure...', 0xD, 0xA, 0
    disk_read_reset_success_msg db 'Disk reset success...', 0xD, 0xA, 0

    times 510-($-$$) db 0
    db 0x55, 0xAA
; end of first sector ---------------------------------------------------------------------














    msg1 db 'Question ', 
    qnum db 49, ':', 0xD, 0xA, 0
    msg2 db 'Classwork II Question '
    qnum2 db 49, ':', 0xD, 0xA, 0


hang:

    xor ax, ax
    mov ds, ax 
    mov si, msg1 ;address = 0000:msg1
    call _printstr

for1_start:
    ;sum pushed on stack
    xor ax, ax
    push ax

    mov cx, 1
for1_loop:
    cmp cx, 99
    jg for1_exit

    pop ax
    add ax, cx
    push ax

    add cx, 2
    jmp for1_loop

for1_exit:
    pop ax
    call _tobase10

    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10





    ;add question number
    mov ax, [qnum]
    inc ax
    mov [qnum], ax
    ;print question
    xor ax, ax
    mov ds, ax 
    mov si, msg1 ;address = 0000:msg1
    call _printstr





for2_start:
    mov cx, -23 ;cx = i
for2_loop:
    cmp cx, 57
    jg for2_exit
    
    ;check if cx is divisible by 3
    mov ax, cx
    mov bx, 3
    cwd ;sign extend ax to dx:ax
    idiv bx ;quotient: ax remainder: dx
    or dx, dx ;check remainder
    jz for2_divisible_3
    jmp for2_check_end
for2_divisible_3:
    ;check if cx is divisible by 5
    mov ax, cx
    mov bx, 5
    cwd ;sign extend ax to dx:ax
    idiv bx
    or dx, dx ;check remainder
    jz for2_divisible_passed
    jmp for2_check_end
for2_divisible_passed:
    ;console.log(c)
    mov ax, cx
    push cx
    call _tobase10

    ;print newline
    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0E0A
    int 0x10
    pop cx

for2_check_end:
    inc cx
    jmp for2_loop

for2_exit:




    ;add question number
    mov ax, [qnum]
    inc ax
    mov [qnum], ax
    ;print question
    xor ax, ax
    mov ds, ax 
    mov si, msg1 ;address = 0000:msg1
    call _printstr





    ;dx = sum
    xor dx, dx ;sum = 0
for3_start:
    mov cx, -20 ;cx = i
for3_loop:
    cmp cx, 60
    jg for3_exit

    push dx
    ;check if cx is divisible by 3
    mov ax, cx
    mov bx, 3
    cwd ;sign extend ax to dx:ax
    idiv bx ;quotient: ax remainder: dx
    or dx, dx ;check remainder
    jz for3_divisible
    pop dx
    jmp for3_check_end
for3_divisible:
    ;sum += c
    pop dx
    add dx, cx
for3_check_end:
    inc cx
    jmp for3_loop
for3_exit:
    ;console.log(sum)
    mov ax, dx
    call _tobase10

    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10

    ;add question number
    mov ax, [qnum]
    inc ax
    mov [qnum], ax
    ;print question
    xor ax, ax
    mov ds, ax 
    mov si, msg1 ;address = 0000:msg1
    call _printstr





    ;dx = sum
    xor dx, dx ;sum = 0
for4_start:
    mov cx, -10 ;cx = i
for4_loop:
    cmp cx, 15
    jg for4_exit

    push dx
    ;check if cx is divisible by 6
    mov ax, cx
    mov bx, 6
    cwd ;sign extend ax to dx:ax
    idiv bx ;quotient: ax remainder: dx
    or dx, dx ;check remainder
    jz for4_divisible
    pop dx
    jmp for4_check_end
for4_divisible:
    ;sum++
    pop dx
    inc dx
for4_check_end:
    inc cx
    jmp for4_loop
for4_exit:
    ;console.log(sum)
    mov ax, dx
    call _tobase10

    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10


    ;add question number
    mov ax, [qnum]
    inc ax
    mov [qnum], ax
    
    ;print question
    xor ax, ax
    mov ds, ax 
    mov si, msg1 ;address = 0000:msg1
    call _printstr




;dx = sum
    xor dx, dx ;sum = 0
for5_start:
    mov cx, -10 ;cx = i
for5_loop:
    cmp cx, 10
    jg for5_exit

    push dx
    ;check if cx is not divisible by 2
    mov ax, cx
    mov bx, 2
    cwd ;sign extend ax to dx:ax
    idiv bx ;quotient: ax remainder: dx
    or dx, dx ;check remainder
    jz for5_divisible
    pop dx
    ;sum++
    inc dx

    jmp for5_check_end
for5_divisible:
    pop dx
for5_check_end:
    inc cx
    jmp for5_loop
for5_exit:
    ;console.log(sum)
    mov ax, dx
    call _tobase10

    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10




    











    jmp halt



    


; Call this with ax set to a value for CH4 HW1
; ax = dividend
_tobase10:
    ;check if AX is negative
    cmp ax, 0
    jge _tobase10_main ;AX is positive, skip negation
    push ax
    mov ax, 0x0E2D ;print -
    int 0x10
    pop ax
    neg ax ;arithmetically negate ax

_tobase10_main:
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


halt:
    jmp halt

    hlt

times 10240-($-$$) db 0 ;total length of binary 20 sectors
                           ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:code
