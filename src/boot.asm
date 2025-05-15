BITS 16
ORG 0x7C00

    ;set positive direction DF=0
    cld

    ;disable interrupts
    cli

;make sure running on 0:7C00, not 7C0:0
    jmp 0:start_nuckboot
start_nuckboot:
    ;zero out the segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax

    ;initialize stack
    mov sp, 0x7C00 ;stack grows below bootloader

    ;save the disk number
    mov [diskNum], dl

    ;set video mode to text mode(80x25)
    mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    int 0x10 ;bios call video services

    ;enable interrupts
    sti

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
    ;Read 59 sectors starting from 0:0:2 in drive dl, store in 0x7E00
    mov ax, 0x023B ;ah=scancode, Read sectors | al=number of sectors to read
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
    int 0x19

restart_pc:
    xor ax, ax
    mov ds, ax
    mov si, restart_msg
    call _printstr
    ;jump to reset vector
    jmp 0xFFFF:0x0000

; subroutine to delay cpu ticks
_wait:
    push cx
    mov cx, 0xFFFF
__wait_innerloop:
    loop __wait_innerloop
    pop cx
    loop _wait
    ret

    disk_read_msg db 'Reading from disk: '
    diskNum db 0 ;reserved for BIOS drive number
    db 0xD, 0xA, 0

    attempts_msg db 'Attempt '
    attempt_num db 0
    db ' of 8', 0xD, 0xA, 0

    startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
    disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
    disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
    disk_read_success db 'Disk read success', 0xD, 0xA, 0

    biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
    restart_msg db 'Restarting...', 0xD, 0xA, 0
    times 446-($-$$) db 0 ;446B bootloader code
    ;MBR partition table(64B)
    ;
    ;bootable, start 2048 end 124927 size 60MiB
    ;
    ;first entry
    db 0b10000000 ;bit 7: bootable flag
    ;chs addressing of first sector
    db 0b00100000 ;head (bits 0-7)
    db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
    db 0b00000000 ;cylinder(bits 0-7)
    db 0x0C ;partition type (W95 FAT32 (LBA))
    ;chs addressing of last sector
    db 0b11000101 ;head (bits 0-7)
    db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
    db 0b00000111 ;cylinder(bits 0-7)
    dd 0x00000800 ;LBA for first sector
    dd 0x0001E000 ;Number of sectors in partition
    ;other entries
    times 3*16 db 0

times 510-($-$$) db 0 ;510B excluding boot signature
db 0x55, 0xAA
; end of first sector, 512B -------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
    ;Data    
    ;kernel data
kernel_setting_block_start:
    kernel_gfx_mode db 1 ;0 for VGA, 1 for VBE
    kernel_VBE_mode dw 0xFFFF ;VBE mode number if gfx mode is set to 1
    kernel_test_mode db 0

; TOTAL of 512 bytes
VBE_info_block_start:
    VBE_info_block_signature db 'NEIN'
    VBE_info_block_version dw 0
    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
    VBE_info_block_capabilities dd 0
    VBE_info_block_video_mode_offset dw 0
    VBE_info_block_video_mode_segment dw 0
    VBE_info_block_total_memory dw 0 ;count of 64k blocks
    times 492 db 0 ;reserved

; TOTAL of 256 bytes
VBE_mode_info_block_start:
    VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
    VBE_mode_info_block_window_a db 0 ;deprecated
    VBE_mode_info_block_window_b db 0 ;deprecated
    VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
    VBE_mode_info_block_window_size dw 0 ;in KB
    VBE_mode_info_block_segment_a dw 0 ;0 if not supported
    VBE_mode_info_block_segment_b dw 0 ;0 if not supported
    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
    VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line

    VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
    VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
    VBE_mode_info_block_char_width db 0 ;in pixels, unused
    VBE_mode_info_block_char_height db 0 ;in pixels, unused
    VBE_mode_info_block_planes_count db 0
    VBE_mode_info_block_bpp db 0 ;bits per pixel
    VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
    VBE_mode_info_block_memory_model db 0
    VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
    VBE_mode_info_block_image_pages_count db 0 ;count - 1
    VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0

    ;size and pos of masks
    VBE_mode_info_block_red_mask db 0
    VBE_mode_info_block_red_pos db 0
    VBE_mode_info_block_green_mask db 0
    VBE_mode_info_block_green_pos db 0
    VBE_mode_info_block_blue_mask db 0
    VBE_mode_info_block_blue_pos db 0
    VBE_mode_info_block_reserved_mask db 0
    VBE_mode_info_block_reserved_pos db 0
    VBE_mode_info_block_direct_color_attributes db 0

    ;added in revision 2.0
    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
    VBE_mode_info_block_off_screen_mem_offset dd 0 
    VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
    VBE_mode_info_block_reserved times 206 db 0 ;available in revision 3.0, useless

;----------------------------------------------------------------------------------------------------------------------------

    msg db 0xD, 0xA, 'F1: PC functions submenu', 0xD, 0xA
    db 'F2: change kernel boot options', 0xD, 0xA
    db 'F3: enter 32 bit protected mode and execute Nuck OS', 0xD, 0xA, 0
    db 'F4: virtual piano', 0xD, 0xA, 0

    boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
    kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
    beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
    oslogo
    db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
    db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.01      ', 0xD, 0xA
    db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
    db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
    db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
    db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0

    hang_virtual_piano_mode db 0b00

    mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
    mode_1_msg db 'Low octave', 0xD, 0xA, 0
    mode_2_msg db 'High octave', 0xD, 0xA, 0

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

    notes_low dw 33, 37, 41, 44, 49, 55, 62
    dw 65, 73, 82, 87, 98, 110, 123
    dw 131, 147, 164, 174, 196, 220, 246
    dw 262, 294, 330, 349, 392, 440, 494
    dw 523, 587, 659, 698, 784, 880, 988
    dw 1047

    dw 35, 39, 46, 52, 58
    dw 69, 78, 92, 104, 117
    dw 139, 156, 185, 208, 233
    dw 277, 311, 370, 415, 466
    dw 554, 622, 740, 831, 932

    notes_high dw 131, 147, 164, 174, 196, 220, 246
    dw 262, 294, 330, 349, 392, 440, 494
    dw 523, 587, 659, 698, 784, 880, 988
    dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
    dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
    dw 4186

    dw 139, 156, 185, 208, 233
    dw 277, 311, 370, 415, 466
    dw 554, 622, 740, 831, 932
    dw 1109, 1245, 1480, 1661, 1865
    dw 2217, 2489, 2960, 3322, 3729

    kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
    kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
    kernel_load_success db 'Kernel load success', 0xD, 0xA, 0

    VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, "VBE controller info:", 0xD, 0xA, 0
    VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0

    VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0

    VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0

    print_VBE_mode_text_msg db " bpp:", 0
    print_VBE_mode_text_msg1 db " pitch:", 0
    print_VBE_mode_text_msg2 db " mm:", 0

    VBEStuff_iter_modes_best_mode_msg db "Best mode: ", 0xD, 0xA, 0
    VBEStuff_iter_modes_best_mode_msg1 db "Switching to VBE graphics mode... ", 0xD, 0xA, 0

    VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
    dw VBE_mode_info_block_fb_support_t

    VBE_mode_info_block_fb_support_t db "LFB: JA", 0
    VBE_mode_info_block_fb_support_f db "LFB: NEIN", 0

    current_mode_number dw 0

    check_VBE_mode_msg db ' valid', 0
    check_VBE_mode_msg1 db ' best', 0

    check_VBE_mode_best_mode_number dw 0

    check_VBE_mode_best_area_high dw 0
    check_VBE_mode_best_area_low dw 0

    check_VBE_mode_best_screen_width dw 0

    kernel_setting_selected db 0
    kernel_setting_selected_mode_number dw 0

;code segment descriptor
;Base            32b: starting location of segment
;Limit           20b: size of limit
;Present          1b: Is this segment used/is a valid segment
;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
;Type             1b: 1 if segment is code or data segment
;Flags(1b):
;  Type flags(4b):
;    1. Code? Will segment contain code
;    2. Conforming: can this code be executed from lower privileged segments
;            For data segment, this flag becomes direction flag, if direction=1, segment
;            becomes an expand down segment
;    3. Readable, can this segment be read?
;            For data segment, this flag becomes writable flag, if writable=0,
;            segment becomes read only
;    4. Accessed: set to 1 when CPU is using the segment
;  Other flags(4b):
;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
;    2. 32 bits: Is this segment going to use 32 bit memory?
;    3 & 4: 64 bit tetio, just set to 0

;offset of the segment descriptors relative to the beginning of the GDT
CODE_SEG equ GDT_code - GDT_start
DATA_SEG equ GDT_data - GDT_start

;kernel location is 0x10000
KERNEL_LOCATION equ 0x1000

GDT_start:
    GDT_null:
        dd 0 ;(32 bits)
        dd 0 ;(32 bits)
    GDT_code:
        ;base: 0
        ;limit: 0xFFFFF
        ;PPT: 1001
        ;Type: 1010
        ;Other: 1100

        ;first 16 bits of limit
        dw 0xFFFF
        ;first 24 bits of base
        dw 0x0000 ;16 bits
        db 0x00   ; 8 bits
        ;PPT + Type
        db 0b10011010
        ;other + last 4 bits of limit
        db 0b11001111
        ;last 8 bits of base
        db 0x00
    GDT_data:
        ;base: 0
        ;limit: 0xFFFFF
        ;PPT: 1001
        ;Type: 0010
        ;Other: 1100

        ;first 16 bits of limit
        dw 0xFFFF
        ;first 24 bits of base
        dw 0x0000 ;16 bits
        db 0x00   ; 8 bits
        ;PPT + Type
        db 0b10010010
        ;other + last 4 bits of limit
        db 0b11001111
        ;last 8 bits of base
        db 0b00000000
GDT_end:
GDT_descriptor:
    ;size of GDT(16 bits)
    dw GDT_end - GDT_start - 1
    ;start of GDT(32 bits)
    dd GDT_start

;----------------------------------------------------------------------------------------------------------------------------

main:


    xor ax, ax
    mov ds, ax
    mov si, oslogo
    call _printstr
hang_early:
    ;print a helpful message
    xor ax, ax
    mov ds, ax
    mov si, msg
    call _printstr

hang:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz hang ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    xor ax, ax
    int 0x16 ;ah = scancode, al = char

    ;print char
    push ax
    mov ah, 0x0E
    int 0x10
    pop ax

    cmp ah, 0x3B
    je submenu_1
    cmp ah, 0x3C
    je submenu_2
    cmp ah, 0x3D
    je boot_pmode
    cmp ah, 0x3E
    je virtual_piano_loop

    jmp hang


;----------------------------------------------------------------------------------------------------------------------------


submenu_1_msg db 0xD, 0xA, 'PC functions:', 0xD, 0xA
db 'F1: restart/boot next/enter BIOS', 0xD, 0xA
db 'F2: restart(jmp to reset vector)', 0xD, 0xA
db 'F3: clear screen', 0xD, 0xA
db 'F4: halt', 0xD, 0xA
db 'F5: BIOS beep', 0xD, 0xA
db 'F6: Reload NuckBoot from boot device', 0xD, 0xA
db 'Esc: go back', 0xD, 0xA, 0x7, 0


submenu_1:
    ;print message
    xor ax, ax
    mov ds, ax
    mov si, submenu_1_msg
    call _printstr

submenu_1_hang:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz submenu_1_hang ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    xor ax, ax
    int 0x16 ;ah = scancode, al = char

    ;print char
    push ax
    mov ah, 0x0E
    int 0x10
    pop ax

    ;check Esc
    cmp ah, 0x01
    je hang_early
    ;F1-5
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
    cmp ah, 0x40
    je retest

    jmp submenu_1_hang


;----------------------------------------------------------------------------------------------------------------------------

submenu_2_msg db 0xD, 0xA, 'Nuck OS boot settings:', 0xD, 0xA
db 'F1: change kernel graphics mode', 0xD, 0xA
db 'F2: change kernel test mode', 0xD, 0xA
db 'Esc: go back', 0xD, 0xA, 0x7, 0
submenu_2_msg2 db 'Select gfx mode:', 0xD, 0xA
db 'F1: select VGA', 0xD, 0xA
db 'F2: list all VBE modes', 0xD, 0xA
db 'F3: list and select valid VBE mode', 0xD, 0xA, 0
submenu_2_msg3 db 'VGA selected', 0xD, 0xA, 0

submenu_2:
    ;print message
    xor ax, ax
    mov ds, ax
    mov si, submenu_2_msg
    call _printstr

submenu_2_hang:
    call print_kernel_current_settings
submenu_2_keyhang:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz submenu_2_keyhang ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    xor ax, ax
    int 0x16 ;ah = scancode, al = char

    cmp ah, 0x01
    je hang_early

    cmp ah, 0x3B
    je submenu_2_select_gfx_mode


    jmp submenu_2_hang

submenu_2_select_gfx_mode:
    xor ax, ax
    mov ds, ax
    mov si, submenu_2_msg2
    call _printstr

submenu_2_select_gfx_mode_loop:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz submenu_2_select_gfx_mode_loop ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    xor ax, ax
    int 0x16 ;ah = scancode, al = char

    cmp ah, 0x01
    je submenu_2_hang

    cmp ah, 0x3B 
    je submenu_2_select_gfx_mode_VGA
    cmp ah, 0x3C
    je submenu_2_select_gfx_mode_VBE1
    cmp ah, 0x3D
    je submenu_2_select_gfx_mode_VBE2

    jmp submenu_2_select_gfx_mode_loop
submenu_2_select_gfx_mode_VGA:
    xor ax, ax
    mov [kernel_gfx_mode], ax
    mov ds, ax
    mov si, submenu_2_msg3
    call _printstr
    je submenu_2_select_gfx_mode_loop
submenu_2_select_gfx_mode_VBE1:
    ;list all VBE modes
    call VBEStuff
    je submenu_2_select_gfx_mode_loop
submenu_2_select_gfx_mode_VBE2:
    ;list valid VBE modes
    call VBEStuff

    je submenu_2_select_gfx_mode_loop

print_kernel_current_settings_msg1 db 'Current settings:', 0xD, 0xA, 0
print_kernel_current_settings_msg2 db 'VGA Text 80x25', 0xD, 0xA, 0
print_kernel_current_settings_msg3 db 'VBE/VESA Mode ', 0
print_kernel_current_settings_msg4 db 'Not selected', 0xD, 0xA, 0
print_kernel_current_settings_msg5 db 'Kernel test mode: ', 0

print_kernel_current_settings:
    xor ax, ax
    mov ds, ax
    mov si, print_kernel_current_settings_msg1
    call _printstr
    mov bl, [kernel_gfx_mode]
    or bl, bl
    jne print_kernel_current_settings_notVGA
    ;VGA text mode
    xor ax, ax
    mov ds, ax
    mov si, print_kernel_current_settings_msg2
    call _printstr
print_kernel_current_settings_back:
    xor ax, ax
    mov ds, ax
    mov si, print_kernel_current_settings_msg5
    call _printstr

    mov al, [kernel_test_mode]
    call print_al

    mov ax, 0xE0D
    int 0x10
    mov ax, 0xE0A
    int 0x10

    ret

print_kernel_current_settings_notVGA:
    xor ax, ax
    mov ds, ax
    mov si, print_kernel_current_settings_msg3
    call _printstr
    mov al, [kernel_setting_selected]
    or al, al
    je print_kernel_current_settings_notVGA_not_selected
    ;query info about selected mode
    mov ax, [kernel_setting_selected_mode_number]
    call print_VBE_mode_text

    jmp print_kernel_current_settings_back

print_kernel_current_settings_notVGA_not_selected:
    xor ax, ax
    mov ds, ax
    mov si, print_kernel_current_settings_msg4
    call _printstr
    jmp print_kernel_current_settings_back




;----------------------------------------------------------------------------------------------------------------------------



virtual_piano_menu_msg db 0xD, 0xA, 'Virtual piano:', 0xD, 0xA
db 'Esc: go back', 0xD, 0xA, 0x7, 0

virtual_piano_loop:
    ;print message
    xor ax, ax
    mov ds, ax
    mov si, virtual_piano_menu_msg
    call _printstr
virtual_piano_looploop:
    mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
    int 0x16 ;keyboard services
    ;return: AL = character, AH = scan code
    jz virtual_piano_looploop ;if key not pressed jump back
    ;if there is a key use int 0x16,0 to get the results
    xor ax, ax
    int 0x16 ;ah = scancode, al = char

    ;print char
    push ax
    mov ah, 0x0E
    int 0x10
    pop ax

    ;check Esc
    cmp ah, 0x01
    je hang_early
    
    push ax
    call hang_virtual_piano
    pop ax

    jmp virtual_piano_looploop

;----------------------------------------------------------------------------------------------------------------------------





;subroutine to retest nuck os
retest:
    mov dl, [diskNum]
    push dx
    call retest_disk_read
    ;jump to the start
    pop dx
    jmp 0x07C0:0x0000


retest_disk_read:
    xor di, di ;counter for retry
retest_disk_read_loop:

    ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
    mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
    xor dh, dh ;head number CHS
    mov dl, [diskNum] ;drive number
    ;Address to store values in: es:bx which is 0:7E00
    xor bx, bx
    mov es, bx
    mov bx, 0x7C00
    int 0x13 ;disk read
    jc retest__disk_read_fail

    ;disk read success
    ret

retest__disk_read_fail:
    ;if number of attempts is over or equal 8
    cmp di, 8
    jge retest__disk_read_fail_final

    ;attempt to reset disk
    xor ax, ax ;scancode ah = 0
    mov dl, [diskNum]
    int 0x13 ;reset disk system

    inc di

    mov cx, 0x2000
    call _wait

    jmp retest_disk_read_loop

retest__disk_read_fail_final:
    ;blocking keyboard input
    xor ax, ax
    int 0x16 ;keyboard services
    jmp biosboot_pc

;----------------------------------------------------------------------------------------------------------------------------


;subroutine to play a note in virtual piano
;key: al
hang_virtual_piano:
    ;change mode
    push ax

    cmp al, 0x3B
    je hang_virtual_piano_mode_rst
    cmp al, 0x27
    je hang_virtual_piano_mode_1
    cmp al, 0x22
    je hang_virtual_piano_mode_2
    jmp hang_virtual_piano_mode_done
hang_virtual_piano_mode_rst:
    xor ax, ax
    mov [hang_virtual_piano_mode], al
    mov ds, ax
    mov si, mode_rst_msg
    call _printstr
    jmp hang_virtual_piano_mode_done
hang_virtual_piano_mode_1:
    mov ax, 0x0001
    mov [hang_virtual_piano_mode], al
    xor ax, ax
    mov ds, ax
    mov si, mode_1_msg
    call _printstr    
    jmp hang_virtual_piano_mode_done
hang_virtual_piano_mode_2:
    mov ax, 0x0002
    mov [hang_virtual_piano_mode], al
    xor ax, ax
    mov ds, ax
    mov si, mode_2_msg
    call _printstr
hang_virtual_piano_mode_done:
    ;load difference in di
    xor ax, ax
    mov al, [hang_virtual_piano_mode]
    mov bx, 122 ;byte difference between the modes defined contiguously in memory
    xor dx, dx
    mul bx
    mov di, ax
    pop ax

    xor cx, cx             ;i = 0
    mov dx, [keylen]       ;k = 10
hang_virtual_piano_loop:
    cmp cx, dx
    jge hang               ;return if i >= k
    mov si, cx             ;si = i
    mov bl, [keys + si]    ;bl = keys[i]
    cmp al, bl             ;if pressed_key == keys[i]
    je hang_virtual_piano_play

    inc cx                 ;i++
    jmp hang_virtual_piano_loop

hang_virtual_piano_play:
    mov ax, cx
    mov cx, 2
    mul cx
    mov si, ax
    mov ax, notes
    add ax, di
    add ax, si
    mov bx, ax
    mov ax, [bx]
    
    call _tone
    mov cx, 0xFFFF
    mov dx, 0x5
    call _wait_PIT
    call speaker_off
    jmp hang

;----------------------------------------------------------------------------------------------------------------------------


cls:
    mov cx, 50
cls_loop:
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10
    loop cls_loop
    jmp submenu_1_hang


cls_call:
    mov cx, 50
cls_loop_call:
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10
    loop cls_loop_call
    ret

;----------------------------------------------------------------------------------------------------------------------------


;bios beep tone
biosbeep:
    xor ax, ax
    mov ds, ax
    mov si, beep_msg
    call _printstr
    mov cx, 0x100
    call _wait
    jmp submenu_1_hang

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

;----------------------------------------------------------------------------------------------------------------------------


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
    push bx ;bx = starting count
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
    xor ax, ax
    out 0x43, al
    in al, 0x40 ;LSB
    mov bl, al
    in al, 0x40 ;MSB
    mov bh, al
    sti
    ret

;----------------------------------------------------------------------------------------------------------------------------

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
    cli
    in al, 0x61
    or al, 0b11
    out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
    sti
    ret
;tell speaker to shut up
speaker_off:
    cli
    in al, 0x61
    and al, 0b11111100
    out 0x61, al
    sti
    ret

;----------------------------------------------------------------------------------------------------------------------------


print_ax:
    pusha

    push ax
    mov ah, 0xE
    mov al, '0'
    int 0x10
    mov ah, 0xE
    mov al, 'b'
    int 0x10
    pop ax

    mov bx, ax
    mov cx, 16
print_ax_loop:
    mov ax, bx
    and ax, 1
    add ax, '0'
    mov ah, 0xE
    push ax
    shr bx, 1
    loop print_ax_loop
    mov cx, 16
print_ax_loop2:
    pop ax
    int 0x10
    loop print_ax_loop2
    popa
    ret

;----------------------------------------------------------------------------------------------------------------------------


print_al:
    pusha

    push ax
    mov ah, 0xE
    mov al, '0'
    int 0x10
    mov ah, 0xE
    mov al, 'b'
    int 0x10
    pop ax

    xor bh, bh
    mov bl, al
    mov cx, 8
print_al_loop:
    mov al, bl
    and al, 1
    add al, '0'
    mov ah, 0xE
    push ax
    shr bl, 1
    loop print_al_loop
    mov cx, 8
print_al_loop2:
    pop ax
    int 0x10
    loop print_al_loop2
    popa
    ret

;----------------------------------------------------------------------------------------------------------------------------


;print value of ax in decimal
print_ax_decimal:
    pusha
    ;push 0 for print function to end
    xor bx, bx
    push bx
    ;if ax is already zero, just print a 0
    or ax, ax
    jz print_ax_decimal_zero
print_ax_decimal_loop:
    or ax, ax
    jz print_ax_decimal_printloop
    xor dx, dx
    mov bx, 10
    ;16 bit division, dx:ax / bx = ax, remainder dx
    div bx
    ;push remainder in ascii
    add dx, '0'
    push dx
    ;loop
    jmp print_ax_decimal_loop
print_ax_decimal_printloop:
    ;print digits pushed on the stack
    pop ax
    ;if popped value is 0, exit
    or ax, ax
    jz print_ax_decimal_end
    ;print value
    mov ah, 0xE
    int 0x10
    jmp print_ax_decimal_printloop
print_ax_decimal_zero:
    pop bx
    mov ah, 0xE
    mov al, '0'
    int 0x10
print_ax_decimal_end:
    popa
    ret

;----------------------------------------------------------------------------------------------------------------------------


_kernel_load:
    xor di, di ;counter for retry
_kernel_load_loop:

    xor ax, ax
    mov ds, ax
    mov si, disk_read_msg ;Reading from disk: diskNum
    call _printstr

    ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
    mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
    xor dh, dh ;head number CHS
    mov dl, [diskNum] ;drive number
    ;Address to store values in: es:bx
    mov bx, 0x1000
    mov es, bx
    xor bx, bx

    int 0x13 ;disk read
    jc __kernel_load_fail

    ;disk read success
    xor ax, ax
    mov ds, ax
    mov si, kernel_load_success
    call _printstr
    
    ret

__kernel_load_fail:
    ;if number of attempts is over or equal 8
    cmp di, 8
    jge __kernel_load_fail_final

    xor ax, ax
    mov ds, ax
    mov si, kernel_load_fail
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

    jmp _kernel_load_loop

__kernel_load_fail_final:
    xor ax, ax
    mov ds, ax
    mov si, kernel_load_fail_final
    call _printstr
    pop ax
    jmp hang  ;go back to 16 bit hang loop if fail

;----------------------------------------------------------------------------------------------------------------------------



;FAILSTATES
VBEStuff_get_controller_info_fail:
    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_get_controller_info_fail_msg
    call _printstr
    ;blocking keyboard input
    xor ax, ax
    int 0x16 ;keyboard services
    jmp biosboot_pc
VBEStuff_get_mode_info_fail:
    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_get_mode_info_fail_msg
    call _printstr
    ;blocking keyboard input
    xor ax, ax
    int 0x16 ;keyboard services
    jmp biosboot_pc



VBEStuff:
    ;get controller info
    xor ax, ax ;es:di
    mov es, ax
    mov di, VBE_info_block_start    
    mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
    int 0x10
    cmp ax, 0x004F
    jne VBEStuff_get_controller_info_fail

    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_get_controller_info_success_msg
    call _printstr

    ;print controller info

    mov al, [VBE_info_block_signature]
    mov ah, 0xE
    int 0x10
    mov ax, [VBE_info_block_signature+1]
    mov ah, 0xE
    int 0x10
    mov ax, [VBE_info_block_signature+2]
    mov ah, 0xE
    int 0x10
    mov ax, [VBE_info_block_signature+3]
    mov ah, 0xE
    int 0x10
    mov ax, 0xE20
    int 0x10
    mov ax, [VBE_info_block_version]
    mov al, 0xE
    xchg ah, al
    add al, '0'
    int 0x10

    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_get_controller_info_print_msg1
    call _printstr

    mov ax, [VBE_info_block_video_mode_segment]
    call print_ax
    mov ah, 0xE
    mov al, ':'
    int 0x10
    mov ax, [VBE_info_block_video_mode_offset]
    call print_ax

    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10

    ;iter mode numbers and find the good one
    ;get start of modes array and put into fs:si
    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
    mov fs, ax
    mov si, [VBE_info_block_video_mode_offset]
VBEStuff_iter_modes_loop:
    mov ax, fs:[si] ;ax = current mode number

    push ax
    push fs
    push si
    ;now print mode in text form
    call print_VBE_mode_text
    pop si
    pop fs
    pop ax


    ;if mode number is 0xFFFF, exit program
    cmp ax, 0xFFFF
    je VBEStuff_iter_modes_exit

    ;increment si
    add si, 2

    mov cx, 0x100
    call _wait

    jmp VBEStuff_iter_modes_loop
VBEStuff_iter_modes_exit:
    ;print best mode number
    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_iter_modes_best_mode_msg
    call _printstr

    mov ax, [check_VBE_mode_best_mode_number]
    call print_VBE_mode_text

    ret


;----------------------------------------------------------------------------------------------------------------------------


;mode number in ax
VBEStuff_setMode:
    push ax
    ;switch to the mode
    xor ax, ax
    mov ds, ax
    mov si, VBEStuff_iter_modes_best_mode_msg1
    call _printstr

    mov cx, 0x3000
    call _wait

    ;set video mode
    xor ax, ax
    mov ds, ax
    mov ax, 0x4F02
    pop bx
    int 0x10
    ret

;----------------------------------------------------------------------------------------------------------------------------


print_VBE_mode_text:
    ;save mode number here
    mov [current_mode_number], ax

    ;if mode number is 0xFFFF, exit program
    cmp ax, 0xFFFF
    je print_VBE_mode_text_end

    ;if dl is not 1, print value in ax
    call print_ax

    ;print space
    mov bx, ax
    mov ax, 0x0E20
    int 0x10
    mov ax, bx

    ;now get mode info
    xor ax, ax
    mov ds, ax

    mov cx, bx ;cx = mode number
    mov ax, 0x4F01 ;scancode
    ;es:di = 256b buffer
    xor dx, dx
    mov es, dx
    mov di, VBE_mode_info_block_start
    int 0x10
    cmp ax, 0x004F
    jne VBEStuff_get_mode_info_fail

    ;now print out width and height
    mov ax, [VBE_mode_info_block_width]
    call print_ax_decimal
    mov ah, 0xE
    mov al, 'x'
    int 0x10
    mov ax, [VBE_mode_info_block_height]
    call print_ax_decimal
    mov ax, 0x0E20
    int 0x10

    ;print if it supports linear framebuffer or not
    xor ax, ax
    mov ds, ax
    mov bx, [VBE_mode_info_block_attributes]
    and bx, 0b10000000 ;if bit 7 is 1 it supports
    shr bx, 6
    add bx, VBE_mode_info_block_fb_support
    mov si, [bx] ;pointer array shenanigans
    call _printstr
    ;print space and msg
    mov si, print_VBE_mode_text_msg
    call _printstr
    ;print bits per pixel
    xor ax, ax
    mov al, [VBE_mode_info_block_bpp]
    call print_ax_decimal
    ;print space and msg
    mov si, print_VBE_mode_text_msg2
    call _printstr
    ;print memory model
    xor ax, ax
    mov al, [VBE_mode_info_block_memory_model]
    call print_ax_decimal
    ;print space and msg
    xor ax, ax
    mov ds, ax
    mov si, print_VBE_mode_text_msg1
    call _printstr
    ;print pitch
    mov ax, [VBE_mode_info_block_pitch]
    call print_ax_decimal

    ;now check if the mode is actually good & find best one
    call check_VBE_mode
    
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10

    xor ax, ax
    mov ds, ax
print_VBE_mode_text_end:
    ret

;----------------------------------------------------------------------------------------------------------------------------

;CF=1: mode is not valid
check_VBE_mode:
    
    ;if LFB is false, exit
    mov ax, [VBE_mode_info_block_attributes]
    and ax, 0b10000000 ;if bit 7 is 1 it supports
    or ax, ax
    jz check_VBE_mode_exit_notValid

    ;if mm is not 6, exit
    xor ax, ax
    mov al, [VBE_mode_info_block_memory_model]
    cmp al, 6
    jne check_VBE_mode_exit_notValid

    ;if bpp is not 32, exit
    xor ax, ax
    mov al, [VBE_mode_info_block_bpp]
    cmp al, 32
    jne check_VBE_mode_exit_notValid

    ;print valid
    xor ax, ax
    mov ds, ax
    mov si, check_VBE_mode_msg
    call _printstr

    ;get current mode's area
    mov ax, [VBE_mode_info_block_width]
    mov bx, [VBE_mode_info_block_height]
    mul bx ;ax * bx = dx:ax, 32-bit multiplication
    ;compare high word of current with best high word
    mov bx, [check_VBE_mode_best_area_high]
    cmp dx, bx
    jl check_VBE_mode_exit ;if current < highest, nuh uh
    jg check_VBE_mode_update ;if current > highest, update values
    ;if equal, check low word
    mov bx, [check_VBE_mode_best_area_low]
    cmp dx, bx
    jl check_VBE_mode_exit ;if current < highest, nuh uh
    jg check_VBE_mode_update ;if current > highest, update values

    ;if still equal, that means it's the exact same resolution
    ;check if current screen width is more than best screen width
    mov ax, [VBE_mode_info_block_width]
    mov bx, [check_VBE_mode_best_screen_width]
    cmp ax, bx
    jl check_VBE_mode_exit ;if current < highest, nuh uh
    jg check_VBE_mode_update ;if current > highest, update values

    jmp check_VBE_mode_exit
check_VBE_mode_update:
    ;restore current mode number
    mov bx, [current_mode_number]
    ;update best mode number
    mov [check_VBE_mode_best_mode_number], bx
    ;update best area
    mov ax, [VBE_mode_info_block_width]
    mov bx, [VBE_mode_info_block_height]
    mul bx ;ax * bx = dx:ax, 32-bit multiplication
    mov [check_VBE_mode_best_area_high], dx
    mov [check_VBE_mode_best_area_low], ax
    ;update best screen width
    mov ax, [VBE_mode_info_block_width]
    mov [check_VBE_mode_best_screen_width], ax

    ;print best
    xor ax, ax
    mov ds, ax
    mov si, check_VBE_mode_msg1
    call _printstr
check_VBE_mode_exit:
    clc
    ret

check_VBE_mode_exit_notValid:
    stc
    ret


;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------------------------------


boot_pmode:
    xor ax, ax
    mov ds, ax
    mov si, boot_pmode_msg
    call _printstr

    call _kernel_load

    xor ax, ax
    mov ds, ax
    mov si, kernel_loaded_msg
    call _printstr

    mov cx, 0x1000
    call _wait

    mov cx, 50
clear_loop:
    mov ax, 0x0E0D
    int 0x10
    mov ax, 0x0E0A
    int 0x10
    loop clear_loop
    
    ;set new graphics mode

    ;Mode 3h
    ;VGA 80x25 text mode
    mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    int 0x10 ;bios call video services

    ;Mode 12h
    ;VGA 640x480 16 color
    ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
    ;int 0x10 ;bios call video services

    ;VBE graphics
    call VBEStuff
    call VBEStuff_setMode

    cli
    lgdt [GDT_descriptor] ;load GDT
    
    ;change last bit of cr0 to 1
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ;PROTECTED MODE!
    ;far jump to code segment
    jmp CODE_SEG:pmode

BITS 32
pmode:
    mov ax, DATA_SEG ;setup segments
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ebp, 0x80000 ;stack
    mov esp, ebp

    ;jump to loaded kernel
    jmp 0x10000
    jmp $




times 30720-($-$$) db 0 ;total length of binary 60 sector
