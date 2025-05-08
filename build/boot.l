     1                                  BITS 16
     2                                  ORG 0x7C00
     3                                  
     4                                      ;set positive direction DF=0
     5 00000000 FC                          cld
     6                                  
     7                                      ;disable interrupts
     8 00000001 FA                          cli
     9                                  
    10                                  ;make sure running on 0:7C00, not 7C0:0
    11 00000002 EA[0700]0000                jmp 0:start_nuckboot
    12                                  start_nuckboot:
    13                                      ;zero out the segment registers
    14 00000007 31C0                        xor ax, ax
    15 00000009 8ED8                        mov ds, ax
    16 0000000B 8EC0                        mov es, ax
    17 0000000D 8EE0                        mov fs, ax
    18 0000000F 8ED0                        mov ss, ax
    19                                  
    20                                      ;initialize stack
    21 00000011 BCFF7B                      mov sp, 0x7BFF ;stack grows below bootloader
    22                                  
    23                                      ;save the disk number
    24 00000014 8816[E300]                  mov [diskNum], dl
    25                                  
    26                                      ;set video mode to text mode(80x25)
    27 00000018 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    28 0000001B CD10                        int 0x10 ;bios call video services
    29                                  
    30                                      ;enable interrupts
    31 0000001D FB                          sti
    32                                  
    33 0000001E BE[F800]                    mov si, startup_msg
    34 00000021 E87600                      call _printstr
    35                                  
    36 00000024 E80300                      call _disk_read ;read bootloader code to ram
    37                                  
    38 00000027 E9FE0A                      jmp main
    39                                  
    40                                  _disk_read:
    41 0000002A 31FF                        xor di, di ;counter for retry
    42                                  _disk_read_loop:
    43                                  
    44 0000002C 31C0                        xor ax, ax
    45 0000002E 8ED8                        mov ds, ax
    46 00000030 BE[D000]                    mov si, disk_read_msg ;Reading from disk: diskNum
    47 00000033 E86400                      call _printstr
    48                                  
    49                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    50                                      ;Read 59 sectors starting from 0:0:2 in drive dl, store in 0x7E00
    51 00000036 B83B02                      mov ax, 0x023B ;ah=scancode, Read sectors | al=number of sectors to read
    52 00000039 B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    53 0000003C 30F6                        xor dh, dh ;head number CHS
    54 0000003E 8A16[E300]                  mov dl, [diskNum] ;drive number
    55                                      ;Address to store values in: es:bx which is 0:7E00
    56 00000042 31DB                        xor bx, bx
    57 00000044 8EC3                        mov es, bx
    58 00000046 BB007E                      mov bx, 0x7E00
    59 00000049 CD13                        int 0x13 ;disk read
    60 0000004B 720B                        jc __disk_read_fail
    61                                  
    62                                      ;disk read success
    63 0000004D 31C0                        xor ax, ax
    64 0000004F 8ED8                        mov ds, ax
    65 00000051 BE[5F01]                    mov si, disk_read_success
    66 00000054 E84300                      call _printstr
    67 00000057 C3                          ret
    68                                  
    69                                  __disk_read_fail:
    70                                      ;if number of attempts is over or equal 8
    71 00000058 83FF08                      cmp di, 8
    72 0000005B 7D2D                        jge __disk_read_fail_final
    73                                  
    74 0000005D 31C0                        xor ax, ax
    75 0000005F 8ED8                        mov ds, ax
    76 00000061 BE[0C01]                    mov si, disk_read_fail
    77 00000064 E83300                      call _printstr
    78                                  
    79                                      ;attempt to reset disk
    80 00000067 31C0                        xor ax, ax ;scancode ah = 0
    81 00000069 8A16[E300]                  mov dl, [diskNum]
    82 0000006D CD13                        int 0x13 ;reset disk system
    83                                  
    84 0000006F 47                          inc di
    85                                      ;update number of attempts
    86 00000070 89F8                        mov ax, di
    87 00000072 83C030                      add ax, '0'
    88 00000075 A2[EF00]                    mov [attempt_num], al
    89                                  
    90 00000078 31C0                        xor ax, ax
    91 0000007A 8ED8                        mov ds, ax
    92 0000007C BE[E700]                    mov si, attempts_msg
    93 0000007F E81800                      call _printstr
    94                                  
    95 00000082 B90020                      mov cx, 0x2000
    96 00000085 E83E00                      call _wait
    97                                  
    98 00000088 EBA2                        jmp _disk_read_loop
    99                                  
   100                                  __disk_read_fail_final:
   101 0000008A 31C0                        xor ax, ax
   102 0000008C 8ED8                        mov ds, ax
   103 0000008E BE[2E01]                    mov si, disk_read_fail_final
   104 00000091 E80600                      call _printstr
   105                                      ;blocking keyboard input
   106 00000094 31C0                        xor ax, ax
   107 00000096 CD16                        int 0x16 ;keyboard services
   108 00000098 EB11                        jmp biosboot_pc
   109                                  
   110                                  ; subroutine to print a string until null terminator
   111                                  ; address of string: ds:si
   112                                  _printstr:
   113 0000009A FC                          cld ;clear DF flag in FLAGS
   114                                  __printstr_loop:
   115 0000009B 8A04                        mov al, [si]
   116 0000009D 46                          inc si
   117                                  
   118 0000009E 08C0                        or al, al ;if al = 0
   119 000000A0 7408                        jz __printstr_exit ;exit loop
   120                                  
   121 000000A2 B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   122 000000A4 31DB                        xor bx, bx ;bh = 0
   123 000000A6 CD10                        int 0x10 ;bios call video services
   124 000000A8 EBF1                        jmp __printstr_loop
   125                                  __printstr_exit:
   126 000000AA C3                          ret
   127                                  
   128                                  biosboot_pc:
   129 000000AB 31C0                        xor ax, ax
   130 000000AD 8ED8                        mov ds, ax
   131 000000AF BE[7301]                    mov si, biosboot_msg
   132 000000B2 E8E5FF                      call _printstr
   133 000000B5 CD19                        int 0x19
   134                                  
   135                                  restart_pc:
   136 000000B7 31C0                        xor ax, ax
   137 000000B9 8ED8                        mov ds, ax
   138 000000BB BE[9001]                    mov si, restart_msg
   139 000000BE E8D9FF                      call _printstr
   140                                      ;jump to reset vector
   141 000000C1 EA0000FFFF                  jmp 0xFFFF:0x0000
   142                                  
   143                                  ; subroutine to delay cpu ticks
   144                                  _wait:
   145 000000C6 51                          push cx
   146 000000C7 B9FFFF                      mov cx, 0xFFFF
   147                                  __wait_innerloop:
   148 000000CA E2FE                        loop __wait_innerloop
   149 000000CC 59                          pop cx
   150 000000CD E2F7                        loop _wait
   151 000000CF C3                          ret
   152                                  
   153 000000D0 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   153 000000D9 726F6D206469736B3A-
   153 000000E2 20                 
   154 000000E3 00                          diskNum db 0 ;reserved for BIOS drive number
   155 000000E4 0D0A00                      db 0xD, 0xA, 0
   156                                  
   157 000000E7 417474656D707420            attempts_msg db 'Attempt '
   158 000000EF 00                          attempt_num db 0
   159 000000F0 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   160                                  
   161 000000F8 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   161 00000101 6F746C6F616465720D-
   161 0000010A 0A00               
   162 0000010C 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   162 00000115 206661696C7572652C-
   162 0000011E 20726573657474696E-
   162 00000127 672E2E2E0D0A00     
   163 0000012E 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   163 00000137 206661696C65642C20-
   163 00000140 707265737320616E79-
   163 00000149 206B657920746F2063-
   163 00000152 6F6E74696E75652E2E-
   163 0000015B 2E0D0A00           
   164 0000015F 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   164 00000168 20737563636573730D-
   164 00000171 0A00               
   165                                  
   166 00000173 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   166 0000017C 6E746F2042494F5320-
   166 00000185 73657475702E2E2E0D-
   166 0000018E 0A00               
   167 00000190 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   167 00000199 672E2E2E0D0A00     
   168 000001A0 00<rep 1Eh>                 times 446-($-$$) db 0 ;446B bootloader code
   169                                      ;MBR partition table(64B)
   170                                      ;
   171                                      ;bootable, start 2048 end 124927 size 60MiB
   172                                      ;
   173                                      ;first entry
   174 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   175                                      ;chs addressing of first sector
   176 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   177 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   178 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   179 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   180                                      ;chs addressing of last sector
   181 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   182 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   183 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   184 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   185 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   186                                      ;other entries
   187 000001CE 00<rep 30h>                 times 3*16 db 0
   188                                  
   189                                  times 510-($-$$) db 0 ;510B excluding boot signature
   190 000001FE 55AA                    db 0x55, 0xAA
   191                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   192                                  
   193                                  
   194                                      ;Data    
   195                                      ;kernel data
   196                                  kernel_setting_block_start:
   197 00000200 01                          kernel_gfx_mode db 1 ;0 for VGA, 1 for VBE
   198 00000201 FFFF                        kernel_VBE_mode dw 0xFFFF ;VBE mode number if gfx mode is set to 1
   199 00000203 00                          kernel_test_mode db 0
   200                                  
   201                                  ; TOTAL of 512 bytes
   202                                  VBE_info_block_start:
   203 00000204 4E45494E                    VBE_info_block_signature db 'NEIN'
   204 00000208 0000                        VBE_info_block_version dw 0
   205 0000020A 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
   206 0000020E 00000000                    VBE_info_block_capabilities dd 0
   207 00000212 0000                        VBE_info_block_video_mode_offset dw 0
   208 00000214 0000                        VBE_info_block_video_mode_segment dw 0
   209 00000216 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
   210 00000218 00<rep 1ECh>                times 492 db 0 ;reserved
   211                                  
   212                                  ; TOTAL of 256 bytes
   213                                  VBE_mode_info_block_start:
   214 00000404 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
   215 00000406 00                          VBE_mode_info_block_window_a db 0 ;deprecated
   216 00000407 00                          VBE_mode_info_block_window_b db 0 ;deprecated
   217 00000408 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
   218 0000040A 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
   219 0000040C 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
   220 0000040E 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
   221 00000410 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
   222 00000414 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
   223                                  
   224 00000416 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
   225 00000418 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
   226 0000041A 00                          VBE_mode_info_block_char_width db 0 ;in pixels, unused
   227 0000041B 00                          VBE_mode_info_block_char_height db 0 ;in pixels, unused
   228 0000041C 00                          VBE_mode_info_block_planes_count db 0
   229 0000041D 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
   230 0000041E 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
   231 0000041F 00                          VBE_mode_info_block_memory_model db 0
   232 00000420 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
   233 00000421 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
   234 00000422 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
   235                                  
   236                                      ;size and pos of masks
   237 00000423 00                          VBE_mode_info_block_red_mask db 0
   238 00000424 00                          VBE_mode_info_block_red_pos db 0
   239 00000425 00                          VBE_mode_info_block_green_mask db 0
   240 00000426 00                          VBE_mode_info_block_green_pos db 0
   241 00000427 00                          VBE_mode_info_block_blue_mask db 0
   242 00000428 00                          VBE_mode_info_block_blue_pos db 0
   243 00000429 00                          VBE_mode_info_block_reserved_mask db 0
   244 0000042A 00                          VBE_mode_info_block_reserved_pos db 0
   245 0000042B 00                          VBE_mode_info_block_direct_color_attributes db 0
   246                                  
   247                                      ;added in revision 2.0
   248 0000042C 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
   249 00000430 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
   250 00000434 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
   251 00000436 00<rep CEh>                 VBE_mode_info_block_reserved times 206 db 0 ;available in revision 3.0, useless
   252                                  
   253                                  
   254                                  
   255                                  
   256 00000504 0D0A46313A20504320-         msg db 0xD, 0xA, 'F1: PC functions submenu', 0xD, 0xA
   256 0000050D 66756E6374696F6E73-
   256 00000516 207375626D656E750D-
   256 0000051F 0A                 
   257 00000520 46323A206368616E67-         db 'F2: change kernel boot options', 0xD, 0xA
   257 00000529 65206B65726E656C20-
   257 00000532 626F6F74206F707469-
   257 0000053B 6F6E730D0A         
   258 00000540 46333A20656E746572-         db 'F3: enter 32 bit protected mode and execute Nuck OS', 0xD, 0xA, 0
   258 00000549 203332206269742070-
   258 00000552 726F74656374656420-
   258 0000055B 6D6F646520616E6420-
   258 00000564 65786563757465204E-
   258 0000056D 75636B204F530D0A00 
   259                                  
   260 00000576 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   260 0000057F 206B65726E656C2E2E-
   260 00000588 2E0D0A00           
   261 0000058C 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   261 00000595 616465642C20737769-
   261 0000059E 746368696E6720746F-
   261 000005A7 2070726F7465637465-
   261 000005B0 64206D6F64652E2E2E-
   261 000005B9 0D0A00             
   262 000005BC 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   263                                      oslogo
   263          ******************       warning: label alone on a line without a colon might be in error [-w+label-orphan]
   264 000005C3 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   264 000005CC 2020202020205F2020-
   264 000005D5 205F20202020202020-
   264 000005DE 20202020205F202020-
   264 000005E7 2020205F5F5F5F2020-
   264 000005F0 202020202020202020-
   264 000005F9 2020205F2020202020-
   264 00000602 4F532056657273696F-
   264 0000060B 6E2020200D0A       
   265 00000611 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.01      ', 0xD, 0xA
   265 0000061A 20202020207C205C20-
   265 00000623 7C207C5F2020205F20-
   265 0000062C 205F5F5F7C207C205F-
   265 00000635 5F207C205F5F202920-
   265 0000063E 205F5F5F2020205F5F-
   265 00000647 5F207C207C5F202020-
   265 00000650 202020312E30312020-
   265 00000659 202020200D0A       
   266 0000065F 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   266 00000668 20202020207C20205C-
   266 00000671 7C207C207C207C207C-
   266 0000067A 2F205F5F7C207C2F20-
   266 00000683 2F207C20205F205C20-
   266 0000068C 2F205F205C202F205F-
   266 00000695 205C7C205F5F7C2020-
   266 0000069E 202020202020202020-
   266 000006A7 202020200D0A       
   267 000006AD 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   267 000006B6 20202020207C207C5C-
   267 000006BF 20207C207C5F7C207C-
   267 000006C8 20285F5F7C2020203C-
   267 000006D1 20207C207C5F29207C-
   267 000006DA 20285F29207C20285F-
   267 000006E3 29207C207C5F202020-
   267 000006EC 202020202020202020-
   267 000006F5 202020200D0A       
   268 000006FB 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   268 00000704 20202020207C5F7C20-
   268 0000070D 5C5F7C5C5F5F2C5F7C-
   268 00000716 5C5F5F5F7C5F7C5C5F-
   268 0000071F 5C207C5F5F5F5F2F20-
   268 00000728 5C5F5F5F2F205C5F5F-
   268 00000731 5F2F205C5F5F7C2020-
   268 0000073A 202020202020202020-
   268 00000743 202020200D0A       
   269 00000749 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   269 00000752 202020202020202020-
   269 0000075B 20226F706572617469-
   269 00000764 6E672073797374656D-
   269 0000076D 206F66207468652066-
   269 00000776 757475726522202854-
   269 0000077F 4D290D0A00         
   270                                  
   271 00000784 00                          hang_virtual_piano_mode db 0b00
   272                                  
   273 00000785 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   273 0000078E 6176650D0A00       
   274 00000794 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   274 0000079D 650D0A00           
   275 000007A1 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   275 000007AA 76650D0A00         
   276                                  
   277 000007AF 3D00                        keylen dw 61
   278 000007B1 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   278 000007BA 307177657274797569-
   278 000007C3 6F706173646667686A-
   278 000007CC 6B6C7A786376626E6D 
   279 000007D5 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   279 000007DE 455459494F50534447-
   279 000007E7 484A4C5A435642     
   280                                  
   281 000007EE 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   281 000007F7 006E007B00         
   282 000007FC 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   282 00000805 00DC00F600         
   283 0000080A 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   283 00000813 01B801EE01         
   284 00000818 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   284 00000821 037003DC03         
   285 00000826 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   285 0000082F 06E006B807         
   286 00000834 2D08                        dw 2093
   287                                  
   288 00000836 45004E005C00680075-         dw 69, 78, 92, 104, 117
   288 0000083F 00                 
   289 00000840 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   289 00000849 00                 
   290 0000084A 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   290 00000853 01                 
   291 00000854 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   291 0000085D 03                 
   292 0000085E 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   292 00000867 07                 
   293                                  
   294 00000868 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   294 00000871 0037003E00         
   295 00000876 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   295 0000087F 006E007B00         
   296 00000884 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   296 0000088D 00DC00F600         
   297 00000892 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   297 0000089B 01B801EE01         
   298 000008A0 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   298 000008A9 037003DC03         
   299 000008AE 1704                        dw 1047
   300                                  
   301 000008B0 230027002E0034003A-         dw 35, 39, 46, 52, 58
   301 000008B9 00                 
   302 000008BA 45004E005C00680075-         dw 69, 78, 92, 104, 117
   302 000008C3 00                 
   303 000008C4 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   303 000008CD 00                 
   304 000008CE 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   304 000008D7 01                 
   305 000008D8 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   305 000008E1 03                 
   306                                  
   307 000008E2 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   307 000008EB 00DC00F600         
   308 000008F0 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   308 000008F9 01B801EE01         
   309 000008FE 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   309 00000907 037003DC03         
   310 0000090C 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   310 00000915 06E006B807         
   311 0000091A 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   311 00000923 0CC00D6F0F         
   312 00000928 5A10                        dw 4186
   313                                  
   314 0000092A 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   314 00000933 00                 
   315 00000934 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   315 0000093D 01                 
   316 0000093E 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   316 00000947 03                 
   317 00000948 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   317 00000951 07                 
   318 00000952 A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   318 0000095B 0E                 
   319                                  
   320 0000095C 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   320 00000965 6164206661696C7572-
   320 0000096E 652C20726573657474-
   320 00000977 696E672E2E2E0D0A00 
   321 00000980 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   321 00000989 6164206661696C6564-
   321 00000992 2C20676F696E672062-
   321 0000099B 61636B20746F207265-
   321 000009A4 616C206D6F64652E2E-
   321 000009AD 2E0D0A00           
   322 000009B1 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   322 000009BA 616420737563636573-
   322 000009C3 730D0A00           
   323                                  
   324 000009C7 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   324 000009D0 6F6E74726F6C6C6572-
   324 000009D9 20696E666F20737563-
   324 000009E2 63657373210D0A00   
   325 000009EA 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   325 000009F3 6F6E74726F6C6C6572-
   325 000009FC 20696E666F20666169-
   325 00000A05 6C210D0A5072657373-
   325 00000A0E 20616E79206B657920-
   325 00000A17 746F20636F6E74696E-
   325 00000A20 75652E2E2E0D0A00   
   326                                  
   327 00000A28 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   327 00000A31 6F6C6C657220696E66-
   327 00000A3A 6F3A0D0A00         
   328 00000A3F 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   328 00000A48 6F6465732070747228-
   328 00000A51 7365673A6F6666293A-
   328 00000A5A 2000               
   329                                  
   330 00000A5C 56424520676574206D-         VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   330 00000A65 6F646520696E666F20-
   330 00000A6E 6661696C210D0A5072-
   330 00000A77 65737320616E79206B-
   330 00000A80 657920746F20636F6E-
   330 00000A89 74696E75652E2E2E0D-
   330 00000A92 0A00               
   331                                  
   332 00000A94 206270703A00                print_VBE_mode_text_msg db " bpp:", 0
   333 00000A9A 2070697463683A00            print_VBE_mode_text_msg1 db " pitch:", 0
   334 00000AA2 206D6D3A00                  print_VBE_mode_text_msg2 db " mm:", 0
   335                                  
   336 00000AA7 42657374206D6F6465-         VBEStuff_iter_modes_best_mode_msg db "Best mode: ", 0xD, 0xA, 0
   336 00000AB0 3A200D0A00         
   337 00000AB5 537769746368696E67-         VBEStuff_iter_modes_best_mode_msg1 db "Switching to VBE graphics mode... ", 0xD, 0xA, 0
   337 00000ABE 20746F205642452067-
   337 00000AC7 72617068696373206D-
   337 00000AD0 6F64652E2E2E200D0A-
   337 00000AD9 00                 
   338                                  
   339 00000ADA [E60A]                      VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
   340 00000ADC [DE0A]                      dw VBE_mode_info_block_fb_support_t
   341                                  
   342 00000ADE 4C46423A204A4100            VBE_mode_info_block_fb_support_t db "LFB: JA", 0
   343 00000AE6 4C46423A204E45494E-         VBE_mode_info_block_fb_support_f db "LFB: NEIN", 0
   343 00000AEF 00                 
   344                                  
   345 00000AF0 0000                        current_mode_number dw 0
   346                                  
   347 00000AF2 2076616C696400              check_VBE_mode_msg db ' valid', 0
   348 00000AF9 206265737400                check_VBE_mode_msg1 db ' best', 0
   349                                  
   350 00000AFF 0000                        check_VBE_mode_best_mode_number dw 0
   351                                  
   352 00000B01 0000                        check_VBE_mode_best_area_high dw 0
   353 00000B03 0000                        check_VBE_mode_best_area_low dw 0
   354                                  
   355 00000B05 0000                        check_VBE_mode_best_screen_width dw 0
   356                                  
   357 00000B07 00                          kernel_setting_selected db 0
   358 00000B08 0000                        kernel_setting_selected_mode_number dw 0
   359                                  
   360                                  ;code segment descriptor
   361                                  ;Base            32b: starting location of segment
   362                                  ;Limit           20b: size of limit
   363                                  ;Present          1b: Is this segment used/is a valid segment
   364                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   365                                  ;Type             1b: 1 if segment is code or data segment
   366                                  ;Flags(1b):
   367                                  ;  Type flags(4b):
   368                                  ;    1. Code? Will segment contain code
   369                                  ;    2. Conforming: can this code be executed from lower privileged segments
   370                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   371                                  ;            becomes an expand down segment
   372                                  ;    3. Readable, can this segment be read?
   373                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   374                                  ;            segment becomes read only
   375                                  ;    4. Accessed: set to 1 when CPU is using the segment
   376                                  ;  Other flags(4b):
   377                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   378                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   379                                  ;    3 & 4: 64 bit tetio, just set to 0
   380                                  
   381                                  ;offset of the segment descriptors relative to the beginning of the GDT
   382                                  CODE_SEG equ GDT_code - GDT_start
   383                                  DATA_SEG equ GDT_data - GDT_start
   384                                  
   385                                  ;kernel location is 0x10000
   386                                  KERNEL_LOCATION equ 0x1000
   387                                  
   388                                  GDT_start:
   389                                      GDT_null:
   390 00000B0A 00000000                        dd 0 ;(32 bits)
   391 00000B0E 00000000                        dd 0 ;(32 bits)
   392                                      GDT_code:
   393                                          ;base: 0
   394                                          ;limit: 0xFFFFF
   395                                          ;PPT: 1001
   396                                          ;Type: 1010
   397                                          ;Other: 1100
   398                                  
   399                                          ;first 16 bits of limit
   400 00000B12 FFFF                            dw 0xFFFF
   401                                          ;first 24 bits of base
   402 00000B14 0000                            dw 0x0000 ;16 bits
   403 00000B16 00                              db 0x00   ; 8 bits
   404                                          ;PPT + Type
   405 00000B17 9A                              db 0b10011010
   406                                          ;other + last 4 bits of limit
   407 00000B18 CF                              db 0b11001111
   408                                          ;last 8 bits of base
   409 00000B19 00                              db 0x00
   410                                      GDT_data:
   411                                          ;base: 0
   412                                          ;limit: 0xFFFFF
   413                                          ;PPT: 1001
   414                                          ;Type: 0010
   415                                          ;Other: 1100
   416                                  
   417                                          ;first 16 bits of limit
   418 00000B1A FFFF                            dw 0xFFFF
   419                                          ;first 24 bits of base
   420 00000B1C 0000                            dw 0x0000 ;16 bits
   421 00000B1E 00                              db 0x00   ; 8 bits
   422                                          ;PPT + Type
   423 00000B1F 92                              db 0b10010010
   424                                          ;other + last 4 bits of limit
   425 00000B20 CF                              db 0b11001111
   426                                          ;last 8 bits of base
   427 00000B21 00                              db 0b00000000
   428                                  GDT_end:
   429                                  GDT_descriptor:
   430                                      ;size of GDT(16 bits)
   431 00000B22 1700                        dw GDT_end - GDT_start - 1
   432                                      ;start of GDT(32 bits)
   433 00000B24 [0A0B0000]                  dd GDT_start
   434                                  
   435                                  
   436                                  
   437                                  main:
   438 00000B28 31C0                        xor ax, ax
   439 00000B2A 8ED8                        mov ds, ax
   440 00000B2C BE[C305]                    mov si, oslogo
   441 00000B2F E868F5                      call _printstr
   442                                  
   443                                  hang_early:
   444                                      ;print a helpful message
   445 00000B32 31C0                        xor ax, ax
   446 00000B34 8ED8                        mov ds, ax
   447 00000B36 BE[0405]                    mov si, msg
   448 00000B39 E85EF5                      call _printstr
   449                                  
   450                                  hang:
   451 00000B3C B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   452 00000B3E CD16                        int 0x16 ;keyboard services
   453                                      ;return: AL = character, AH = scan code
   454 00000B40 74FA                        jz hang ;if key not pressed jump back
   455                                      ;if there is a key use int 0x16,0 to get the results
   456 00000B42 31C0                        xor ax, ax
   457 00000B44 CD16                        int 0x16 ;ah = scancode, al = char
   458                                  
   459                                      ;print char
   460 00000B46 50                          push ax
   461 00000B47 B40E                        mov ah, 0x0E
   462 00000B49 CD10                        int 0x10
   463 00000B4B 58                          pop ax
   464                                  
   465 00000B4C 80FC3B                      cmp ah, 0x3B
   466 00000B4F 0F84CD00                    je submenu_1
   467 00000B53 80FC3C                      cmp ah, 0x3C
   468 00000B56 0F849C01                    je submenu_2
   469 00000B5A 80FC3D                      cmp ah, 0x3D
   470 00000B5D 0F847207                    je boot_pmode
   471 00000B61 80FC3E                      cmp ah, 0x3E
   472 00000B64 0F84D402                    je virtual_piano_loop
   473                                  
   474 00000B68 EBD2                        jmp hang
   475                                  
   476                                  
   477                                  
   478 00000B6A 0D0A50432066756E63-     submenu_1_msg db 0xD, 0xA, 'PC functions:', 0xD, 0xA
   478 00000B73 74696F6E733A0D0A   
   479 00000B7B 46313A207265737461-     db 'F1: restart/boot next/enter BIOS', 0xD, 0xA
   479 00000B84 72742F626F6F74206E-
   479 00000B8D 6578742F656E746572-
   479 00000B96 2042494F530D0A     
   480 00000B9D 46323A207265737461-     db 'F2: restart(jmp to reset vector)', 0xD, 0xA
   480 00000BA6 7274286A6D7020746F-
   480 00000BAF 207265736574207665-
   480 00000BB8 63746F72290D0A     
   481 00000BBF 46333A20636C656172-     db 'F3: clear screen', 0xD, 0xA
   481 00000BC8 2073637265656E0D0A 
   482 00000BD1 46343A2068616C740D-     db 'F4: halt', 0xD, 0xA
   482 00000BDA 0A                 
   483 00000BDB 46353A2042494F5320-     db 'F5: BIOS beep', 0xD, 0xA
   483 00000BE4 626565700D0A       
   484 00000BEA 46363A2052656C6F61-     db 'F6: Reload NuckBoot from boot device', 0xD, 0xA
   484 00000BF3 64204E75636B426F6F-
   484 00000BFC 742066726F6D20626F-
   484 00000C05 6F7420646576696365-
   484 00000C0E 0D0A               
   485 00000C10 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   485 00000C19 61636B0D0A0700     
   486                                  
   487                                  
   488                                  submenu_1:
   489                                      ;print message
   490 00000C20 31C0                        xor ax, ax
   491 00000C22 8ED8                        mov ds, ax
   492 00000C24 BE[6A0B]                    mov si, submenu_1_msg
   493 00000C27 E870F4                      call _printstr
   494                                  
   495                                  submenu_1_hang:
   496 00000C2A B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   497 00000C2C CD16                        int 0x16 ;keyboard services
   498                                      ;return: AL = character, AH = scan code
   499 00000C2E 74FA                        jz submenu_1_hang ;if key not pressed jump back
   500                                      ;if there is a key use int 0x16,0 to get the results
   501 00000C30 31C0                        xor ax, ax
   502 00000C32 CD16                        int 0x16 ;ah = scancode, al = char
   503                                  
   504                                      ;print char
   505 00000C34 50                          push ax
   506 00000C35 B40E                        mov ah, 0x0E
   507 00000C37 CD10                        int 0x10
   508 00000C39 58                          pop ax
   509                                  
   510                                      ;check Esc
   511 00000C3A 80FC01                      cmp ah, 0x01
   512 00000C3D 0F84F1FE                    je hang_early
   513                                      ;F1-5
   514 00000C41 80FC3B                      cmp ah, 0x3B
   515 00000C44 0F8463F4                    je biosboot_pc
   516 00000C48 80FC3C                      cmp ah, 0x3C
   517 00000C4B 0F8468F4                    je restart_pc
   518 00000C4F 80FC3D                      cmp ah, 0x3D
   519 00000C52 0F84E102                    je cls
   520 00000C56 80FC3E                      cmp ah, 0x3E
   521 00000C59 0F84FF02                    je halt
   522 00000C5D 80FC3F                      cmp ah, 0x3F
   523 00000C60 0F84E502                    je biosbeep
   524 00000C64 80FC40                      cmp ah, 0x40
   525 00000C67 0F84F901                    je retest
   526                                  
   527 00000C6B EBBD                        jmp submenu_1_hang
   528                                  
   529 00000C6D 0D0A4E75636B204F53-     submenu_2_msg db 0xD, 0xA, 'Nuck OS boot settings:', 0xD, 0xA
   529 00000C76 20626F6F7420736574-
   529 00000C7F 74696E67733A0D0A   
   530 00000C87 46313A206368616E67-     db 'F1: change kernel graphics mode', 0xD, 0xA
   530 00000C90 65206B65726E656C20-
   530 00000C99 677261706869637320-
   530 00000CA2 6D6F64650D0A       
   531 00000CA8 46323A206368616E67-     db 'F2: change kernel test mode', 0xD, 0xA
   531 00000CB1 65206B65726E656C20-
   531 00000CBA 74657374206D6F6465-
   531 00000CC3 0D0A               
   532 00000CC5 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   532 00000CCE 61636B0D0A0700     
   533 00000CD5 53656C656374206766-     submenu_2_msg2 db 'Select gfx mode:', 0xD, 0xA
   533 00000CDE 78206D6F64653A0D0A 
   534 00000CE7 46313A2073656C6563-     db 'F1: select VGA', 0
   534 00000CF0 742056474100       
   535                                  
   536                                  submenu_2:
   537                                      ;print message
   538 00000CF6 31C0                        xor ax, ax
   539 00000CF8 8ED8                        mov ds, ax
   540 00000CFA BE[6D0C]                    mov si, submenu_2_msg
   541 00000CFD E89AF3                      call _printstr
   542                                  
   543                                  submenu_2_hang:
   544 00000D00 E8BB00                      call print_kernel_current_settings
   545                                  submenu_2_keyhang:
   546 00000D03 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   547 00000D05 CD16                        int 0x16 ;keyboard services
   548                                      ;return: AL = character, AH = scan code
   549 00000D07 74FA                        jz submenu_2_keyhang ;if key not pressed jump back
   550                                      ;if there is a key use int 0x16,0 to get the results
   551 00000D09 31C0                        xor ax, ax
   552 00000D0B CD16                        int 0x16 ;ah = scancode, al = char
   553                                  
   554 00000D0D 80FC01                      cmp ah, 0x01
   555 00000D10 0F841EFE                    je hang_early
   556                                  
   557 00000D14 80FC3B                      cmp ah, 0x3B
   558 00000D17 7402                        je submenu_2_select_gfx_mode
   559                                  
   560                                  
   561 00000D19 EBE5                        jmp submenu_2_hang
   562                                  
   563                                  submenu_2_select_gfx_mode:
   564 00000D1B 31C0                        xor ax, ax
   565 00000D1D 8ED8                        mov ds, ax
   566 00000D1F BE[D50C]                    mov si, submenu_2_msg2
   567 00000D22 E875F3                      call _printstr
   568                                  
   569                                  submenu_2_select_gfx_loop:
   570 00000D25 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   571 00000D27 CD16                        int 0x16 ;keyboard services
   572                                      ;return: AL = character, AH = scan code
   573 00000D29 74D8                        jz submenu_2_keyhang ;if key not pressed jump back
   574                                      ;if there is a key use int 0x16,0 to get the results
   575 00000D2B 31C0                        xor ax, ax
   576 00000D2D CD16                        int 0x16 ;ah = scancode, al = char
   577                                  
   578                                  
   579 00000D2F 80FC01                      cmp ah, 0x01
   580 00000D32 74CC                        je submenu_2_hang
   581                                      
   582 00000D34 80FC3B                      cmp ah, 0x3B
   583 00000D37 0F8470F3                    je biosboot_pc
   584 00000D3B 80FC3C                      cmp ah, 0x3C
   585 00000D3E 0F8475F3                    je restart_pc
   586 00000D42 80FC3D                      cmp ah, 0x3D
   587 00000D45 0F84EE01                    je cls
   588 00000D49 80FC3E                      cmp ah, 0x3E
   589 00000D4C 0F840C02                    je halt
   590 00000D50 80FC3F                      cmp ah, 0x3F
   591 00000D53 0F84F201                    je biosbeep
   592                                  
   593                                  
   594                                  
   595                                  
   596                                  
   597                                  
   598                                  
   599                                  
   600                                      jmp submenu_2_select_gfx_mode_loop
   600          ******************       error: symbol `submenu_2_select_gfx_mode_loop' not defined
   601                                  
   602                                  
   603                                  
   604                                  
   605                                  
   606                                  
   607                                  
   608                                  
   609                                  
   610                                  
   611                                  
   612                                  
   613                                  
   614                                  
   615                                  
   616                                  
   617                                  
   618 00000D57 43757272656E742073-     print_kernel_current_settings_msg1 db 'Current settings:', 0xD, 0xA, 0
   618 00000D60 657474696E67733A0D-
   618 00000D69 0A00               
   619 00000D6B 564741205465787420-     print_kernel_current_settings_msg2 db 'VGA Text 80x25', 0xD, 0xA, 0
   619 00000D74 38307832350D0A00   
   620 00000D7C 5642452F5645534120-     print_kernel_current_settings_msg3 db 'VBE/VESA Mode ', 0
   620 00000D85 4D6F64652000       
   621 00000D8B 4E6F742073656C6563-     print_kernel_current_settings_msg4 db 'Not selected', 0xD, 0xA, 0
   621 00000D94 7465640D0A00       
   622 00000D9A 4E6F742073656C6563-     print_kernel_current_settings_msg5 db 'Not selected', 0xD, 0xA, 0
   622 00000DA3 7465640D0A00       
   623 00000DA9 4B65726E656C207465-     print_kernel_current_settings_msg6 db 'Kernel test mode: ', 0
   623 00000DB2 7374206D6F64653A20-
   623 00000DBB 00                 
   624                                  
   625                                  
   626                                  print_kernel_current_settings:
   627 00000DBC 31C0                        xor ax, ax
   628 00000DBE 8ED8                        mov ds, ax
   629 00000DC0 BE[570D]                    mov si, print_kernel_current_settings_msg1
   630 00000DC3 E8D4F2                      call _printstr
   631 00000DC6 8A1E[0002]                  mov bl, [kernel_gfx_mode]
   632 00000DCA 08DB                        or bl, bl
   633 00000DCC 7527                        jne print_kernel_current_settings_notVGA
   634                                      ;VGA text mode
   635 00000DCE 31C0                        xor ax, ax
   636 00000DD0 8ED8                        mov ds, ax
   637 00000DD2 BE[6B0D]                    mov si, print_kernel_current_settings_msg2
   638 00000DD5 E8C2F2                      call _printstr
   639                                  print_kernel_current_settings_back:
   640 00000DD8 31C0                        xor ax, ax
   641 00000DDA 8ED8                        mov ds, ax
   642 00000DDC BE[A90D]                    mov si, print_kernel_current_settings_msg6
   643 00000DDF E8B8F2                      call _printstr
   644                                  
   645 00000DE2 A0[0302]                    mov al, [kernel_test_mode]
   646 00000DE5 E81D02                      call print_al
   647                                  
   648 00000DE8 B80D0E                      mov ax, 0xE0D
   649 00000DEB CD10                        int 0x10
   650 00000DED B80A0E                      mov ax, 0xE0A
   651 00000DF0 CD10                        int 0x10
   652                                  
   653 00000DF2 C3                          ret
   654                                  
   655                                  print_kernel_current_settings_notVGA:
   656 00000DF3 31C0                        xor ax, ax
   657 00000DF5 8ED8                        mov ds, ax
   658 00000DF7 BE[7C0D]                    mov si, print_kernel_current_settings_msg3
   659 00000DFA E89DF2                      call _printstr
   660 00000DFD A0[070B]                    mov al, [kernel_setting_selected]
   661 00000E00 08C0                        or al, al
   662 00000E02 740A                        je print_kernel_current_settings_notVGA_not_selected
   663                                      ;query info about selected mode
   664 00000E04 A1[080B]                    mov ax, [kernel_setting_selected_mode_number]
   665 00000E07 E8B203                      call print_VBE_mode_text
   666                                  
   667 00000E0A EBCC                        jmp print_kernel_current_settings_back
   668                                  
   669                                  print_kernel_current_settings_notVGA_not_selected:
   670 00000E0C 31C0                        xor ax, ax
   671 00000E0E 8ED8                        mov ds, ax
   672 00000E10 BE[8B0D]                    mov si, print_kernel_current_settings_msg4
   673 00000E13 E884F2                      call _printstr
   674 00000E16 EBC0                        jmp print_kernel_current_settings_back
   675                                  
   676                                  
   677                                  
   678                                  
   679                                  
   680                                  
   681                                  
   682                                  
   683                                  
   684 00000E18 0D0A5669727475616C-     virtual_piano_menu_msg db 0xD, 0xA, 'Virtual piano:', 0xD, 0xA
   684 00000E21 207069616E6F3A0D0A 
   685 00000E2A 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   685 00000E33 61636B0D0A0700     
   686                                  
   687                                  virtual_piano_loop:
   688                                      ;print message
   689 00000E3A 31C0                        xor ax, ax
   690 00000E3C 8ED8                        mov ds, ax
   691 00000E3E BE[180E]                    mov si, virtual_piano_menu_msg
   692 00000E41 E856F2                      call _printstr
   693                                  virtual_piano_looploop:
   694 00000E44 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   695 00000E46 CD16                        int 0x16 ;keyboard services
   696                                      ;return: AL = character, AH = scan code
   697 00000E48 74FA                        jz virtual_piano_looploop ;if key not pressed jump back
   698                                      ;if there is a key use int 0x16,0 to get the results
   699 00000E4A 31C0                        xor ax, ax
   700 00000E4C CD16                        int 0x16 ;ah = scancode, al = char
   701                                  
   702                                      ;print char
   703 00000E4E 50                          push ax
   704 00000E4F B40E                        mov ah, 0x0E
   705 00000E51 CD10                        int 0x10
   706 00000E53 58                          pop ax
   707                                  
   708                                      ;check Esc
   709 00000E54 80FC01                      cmp ah, 0x01
   710 00000E57 0F84D7FC                    je hang_early
   711                                      
   712 00000E5B 50                          push ax
   713 00000E5C E84A00                      call hang_virtual_piano
   714 00000E5F 58                          pop ax
   715                                  
   716 00000E60 EBE2                        jmp virtual_piano_looploop
   717                                  
   718                                  
   719                                  
   720                                  
   721                                  
   722                                  
   723                                  
   724                                  
   725                                  
   726                                  
   727                                  
   728                                  
   729                                  
   730                                  ;subroutine to retest nuck os
   731                                  retest:
   732 00000E62 8A16[E300]                  mov dl, [diskNum]
   733 00000E66 52                          push dx
   734 00000E67 E80800                      call retest_disk_read
   735                                      ;jump to the start
   736 00000E6A 5A                          pop dx
   737 00000E6B EA0000C007                  jmp 0x07C0:0x0000
   738                                  
   739                                  
   740                                  retest_disk_read:
   741 00000E70 31FF                        xor di, di ;counter for retry
   742                                  retest_disk_read_loop:
   743                                  
   744                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   745                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   746 00000E72 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   747 00000E75 B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   748 00000E78 30F6                        xor dh, dh ;head number CHS
   749 00000E7A 8A16[E300]                  mov dl, [diskNum] ;drive number
   750                                      ;Address to store values in: es:bx which is 0:7E00
   751 00000E7E 31DB                        xor bx, bx
   752 00000E80 8EC3                        mov es, bx
   753 00000E82 BB007C                      mov bx, 0x7C00
   754 00000E85 CD13                        int 0x13 ;disk read
   755 00000E87 7203                        jc retest__disk_read_fail
   756                                  
   757                                      ;disk read success
   758 00000E89 C3                          ret
   759                                  
   760                                  retest__disk_read_fail:
   761                                      ;if number of attempts is over or equal 8
   762 00000E8A 83FF08                      cmp di, 8
   763 00000E8D 7D13                        jge retest__disk_read_fail_final
   764                                  
   765                                      ;attempt to reset disk
   766 00000E8F 31C0                        xor ax, ax ;scancode ah = 0
   767 00000E91 8A16[E300]                  mov dl, [diskNum]
   768 00000E95 CD13                        int 0x13 ;reset disk system
   769                                  
   770 00000E97 47                          inc di
   771                                  
   772 00000E98 B90020                      mov cx, 0x2000
   773 00000E9B E828F2                      call _wait
   774                                  
   775 00000E9E EBD2                        jmp retest_disk_read_loop
   776                                  
   777                                  retest__disk_read_fail_final:
   778                                      ;blocking keyboard input
   779 00000EA0 31C0                        xor ax, ax
   780 00000EA2 CD16                        int 0x16 ;keyboard services
   781 00000EA4 E904F2                      jmp biosboot_pc
   782                                  
   783                                  
   784                                  
   785                                  ;subroutine to play a note in virtual piano
   786                                  ;key: al
   787                                  hang_virtual_piano:
   788                                      ;change mode
   789 00000EA7 50                          push ax
   790                                  
   791 00000EA8 3C3B                        cmp al, 0x3B
   792 00000EAA 740C                        je hang_virtual_piano_mode_rst
   793 00000EAC 3C27                        cmp al, 0x27
   794 00000EAE 7417                        je hang_virtual_piano_mode_1
   795 00000EB0 3C22                        cmp al, 0x22
   796 00000EB2 7425                        je hang_virtual_piano_mode_2
   797 00000EB4 EB33                        jmp hang_virtual_piano_mode_done
   798                                  hang_virtual_piano_mode_rst:
   799 00000EB6 31C0                        xor ax, ax
   800 00000EB8 A2[8407]                    mov [hang_virtual_piano_mode], al
   801 00000EBB 8ED8                        mov ds, ax
   802 00000EBD BE[8507]                    mov si, mode_rst_msg
   803 00000EC0 E8D7F1                      call _printstr
   804 00000EC3 EB24                        jmp hang_virtual_piano_mode_done
   805                                  hang_virtual_piano_mode_1:
   806 00000EC5 B80100                      mov ax, 0x0001
   807 00000EC8 A2[8407]                    mov [hang_virtual_piano_mode], al
   808 00000ECB 31C0                        xor ax, ax
   809 00000ECD 8ED8                        mov ds, ax
   810 00000ECF BE[9407]                    mov si, mode_1_msg
   811 00000ED2 E8C5F1                      call _printstr    
   812 00000ED5 EB12                        jmp hang_virtual_piano_mode_done
   813                                  hang_virtual_piano_mode_2:
   814 00000ED7 B80200                      mov ax, 0x0002
   815 00000EDA A2[8407]                    mov [hang_virtual_piano_mode], al
   816 00000EDD 31C0                        xor ax, ax
   817 00000EDF 8ED8                        mov ds, ax
   818 00000EE1 BE[A107]                    mov si, mode_2_msg
   819 00000EE4 E8B3F1                      call _printstr
   820                                  hang_virtual_piano_mode_done:
   821                                      ;load difference in di
   822 00000EE7 31C0                        xor ax, ax
   823 00000EE9 A0[8407]                    mov al, [hang_virtual_piano_mode]
   824 00000EEC BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   825 00000EEF 31D2                        xor dx, dx
   826 00000EF1 F7E3                        mul bx
   827 00000EF3 89C7                        mov di, ax
   828 00000EF5 58                          pop ax
   829                                  
   830 00000EF6 31C9                        xor cx, cx             ;i = 0
   831 00000EF8 8B16[AF07]                  mov dx, [keylen]       ;k = 10
   832                                  hang_virtual_piano_loop:
   833 00000EFC 39D1                        cmp cx, dx
   834 00000EFE 0F8D3AFC                    jge hang               ;return if i >= k
   835 00000F02 89CE                        mov si, cx             ;si = i
   836 00000F04 8A9C[B107]                  mov bl, [keys + si]    ;bl = keys[i]
   837 00000F08 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   838 00000F0A 7405                        je hang_virtual_piano_play
   839                                  
   840 00000F0C 41                          inc cx                 ;i++
   841 00000F0D EBED                        jmp hang_virtual_piano_loop
   842                                  
   843                                  hang_virtual_piano_play:
   844 00000F0F 89C8                        mov ax, cx
   845 00000F11 B90200                      mov cx, 2
   846 00000F14 F7E1                        mul cx
   847 00000F16 89C6                        mov si, ax
   848 00000F18 B8[EE07]                    mov ax, notes
   849 00000F1B 01F8                        add ax, di
   850 00000F1D 01F0                        add ax, si
   851 00000F1F 89C3                        mov bx, ax
   852 00000F21 8B07                        mov ax, [bx]
   853                                      
   854 00000F23 E87B00                      call _tone
   855 00000F26 B9FFFF                      mov cx, 0xFFFF
   856 00000F29 BA0500                      mov dx, 0x5
   857 00000F2C E84500                      call _wait_PIT
   858 00000F2F E89D00                      call speaker_off
   859 00000F32 E907FC                      jmp hang
   860                                  
   861                                  cls:
   862 00000F35 B93200                      mov cx, 50
   863                                  cls_loop:
   864 00000F38 B80D0E                      mov ax, 0x0E0D
   865 00000F3B CD10                        int 0x10
   866 00000F3D B80A0E                      mov ax, 0x0E0A
   867 00000F40 CD10                        int 0x10
   868 00000F42 E2F4                        loop cls_loop
   869 00000F44 E9E3FC                      jmp submenu_1_hang
   870                                  
   871                                  ;bios beep tone
   872                                  biosbeep:
   873 00000F47 31C0                        xor ax, ax
   874 00000F49 8ED8                        mov ds, ax
   875 00000F4B BE[BC05]                    mov si, beep_msg
   876 00000F4E E849F1                      call _printstr
   877 00000F51 B90001                      mov cx, 0x100
   878 00000F54 E86FF1                      call _wait
   879 00000F57 E9D0FC                      jmp submenu_1_hang
   880                                  
   881                                  halt:
   882 00000F5A B93200                      mov cx, 50
   883                                  halt_cls_loop:
   884 00000F5D B80D0E                      mov ax, 0x0E0D
   885 00000F60 CD10                        int 0x10
   886 00000F62 B80A0E                      mov ax, 0x0E0A
   887 00000F65 CD10                        int 0x10
   888 00000F67 E2F4                        loop halt_cls_loop
   889                                      ;disable cursor
   890 00000F69 B401                        mov ah, 0x01
   891 00000F6B B90020                      mov cx, 0x2000 ;disable cursor
   892 00000F6E CD10                        int 0x10    ;int 0x10, 1: set cursor type
   893                                  
   894 00000F70 FA                          cli
   895 00000F71 F4                          hlt
   896                                  
   897                                  ;dx*cx is amount of ticks to wait
   898                                  _wait_PIT:
   899 00000F72 51                          push cx
   900 00000F73 E80700                      call _wait_PIT_once
   901 00000F76 59                          pop cx
   902 00000F77 4A                          dec dx
   903 00000F78 75F8                        jnz _wait_PIT
   904 00000F7A C3                          ret
   905                                  
   906                                  ;cx, starting
   907                                  ;cx is amount of ticks to wait
   908                                  _wait_PIT_once:
   909 00000F7B 51                          push cx
   910 00000F7C E81300                      call _read_PIT_ticks
   911 00000F7F 53                          push bx ;bx = starting count
   912                                  _wait_PIT_once_loop:
   913 00000F80 E80F00                      call _read_PIT_ticks ;read the count again, store in bx
   914                                      ;compute time difference = current count - start count
   915 00000F83 58                          pop ax      ;current count is bx, starting count is ax
   916 00000F84 29C3                        sub bx, ax  ;bx = time diff
   917 00000F86 59                          pop cx
   918 00000F87 51                          push cx
   919 00000F88 50                          push ax
   920 00000F89 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   921 00000F8B 7CF3                        jl _wait_PIT_once_loop
   922 00000F8D 58                          pop ax
   923 00000F8E 58                          pop ax
   924 00000F8F C3                          ret
   925                                  
   926                                  ;returns PIT ticks stored in bx
   927                                  _read_PIT_ticks:
   928 00000F90 FA                          cli
   929 00000F91 31C0                        xor ax, ax
   930 00000F93 E643                        out 0x43, al
   931 00000F95 E440                        in al, 0x40 ;LSB
   932 00000F97 88C3                        mov bl, al
   933 00000F99 E440                        in al, 0x40 ;MSB
   934 00000F9B 88C7                        mov bh, al
   935 00000F9D FB                          sti
   936 00000F9E C3                          ret
   937                                  
   938                                  ;PIT notes
   939                                  ;I/O port     Usage
   940                                  ;0x40         Channel 0 data port (read/write)
   941                                  ;0x41         Channel 1 data port (read/write)
   942                                  ;0x42         Channel 2 data port (read/write)
   943                                  ;0x43         Mode/Command register (write only, a read is ignored)
   944                                  ;
   945                                  ;Bits:  7 6 5 4 3 2 1 0
   946                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   947                                  ;       | | | | +--+-- Mode (0–5)
   948                                  ;       | | +-----+-- Access Mode: 
   949                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   950                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   951                                  ;subroutine to play a tone
   952                                  ;ax: frequency
   953                                  _tone:
   954 00000F9F 50                          push ax
   955                                      ;calculate divisor from frequency
   956                                      ;divisor = 1193182 / freq
   957                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   958 00000FA0 BA1200                      mov dx, 0x12
   959 00000FA3 B8DE34                      mov ax, 0x34DE
   960                                      ;load denominator into bx(frequency)
   961 00000FA6 5B                          pop bx
   962                                      ;divide
   963 00000FA7 F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   964 00000FA9 50                          push ax ;save on stack
   965                                  
   966 00000FAA E82200                      call speaker_off
   967                                      ;write to PIT control register
   968 00000FAD B0B6                        mov al, 0b10110110
   969 00000FAF E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   970                                      ;write divisor to channel 2 data port
   971 00000FB1 58                          pop ax         ; Divisor
   972 00000FB2 89C3                        mov bx, ax
   973 00000FB4 88D8                        mov al, bl
   974 00000FB6 E642                        out 0x42, al         ; LSB first
   975 00000FB8 88F8                        mov al, bh
   976 00000FBA E642                        out 0x42, al         ; Then MSB
   977                                      
   978 00000FBC E80700                      call speaker_on
   979 00000FBF 31C0                        xor ax, ax
   980 00000FC1 8ED8                        mov ds, ax
   981 00000FC3 C3                          ret
   982                                  
   983                                  ;tell speaker to not shut up
   984                                  speaker_on:
   985 00000FC4 FA                          cli
   986 00000FC5 E461                        in al, 0x61
   987 00000FC7 0C03                        or al, 0b11
   988 00000FC9 E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   989 00000FCB FB                          sti
   990 00000FCC C3                          ret
   991                                  ;tell speaker to shut up
   992                                  speaker_off:
   993 00000FCD FA                          cli
   994 00000FCE E461                        in al, 0x61
   995 00000FD0 24FC                        and al, 0b11111100
   996 00000FD2 E661                        out 0x61, al
   997 00000FD4 FB                          sti
   998 00000FD5 C3                          ret
   999                                  
  1000                                  
  1001                                  print_ax:
  1002 00000FD6 60                          pusha
  1003                                  
  1004 00000FD7 50                          push ax
  1005 00000FD8 B40E                        mov ah, 0xE
  1006 00000FDA B030                        mov al, '0'
  1007 00000FDC CD10                        int 0x10
  1008 00000FDE B40E                        mov ah, 0xE
  1009 00000FE0 B062                        mov al, 'b'
  1010 00000FE2 CD10                        int 0x10
  1011 00000FE4 58                          pop ax
  1012                                  
  1013 00000FE5 89C3                        mov bx, ax
  1014 00000FE7 B91000                      mov cx, 16
  1015                                  print_ax_loop:
  1016 00000FEA 89D8                        mov ax, bx
  1017 00000FEC 83E001                      and ax, 1
  1018 00000FEF 83C030                      add ax, '0'
  1019 00000FF2 B40E                        mov ah, 0xE
  1020 00000FF4 50                          push ax
  1021 00000FF5 D1EB                        shr bx, 1
  1022 00000FF7 E2F1                        loop print_ax_loop
  1023 00000FF9 B91000                      mov cx, 16
  1024                                  print_ax_loop2:
  1025 00000FFC 58                          pop ax
  1026 00000FFD CD10                        int 0x10
  1027 00000FFF E2FB                        loop print_ax_loop2
  1028 00001001 61                          popa
  1029 00001002 C3                          ret
  1030                                  
  1031                                  print_al:
  1032 00001003 60                          pusha
  1033                                  
  1034 00001004 50                          push ax
  1035 00001005 B40E                        mov ah, 0xE
  1036 00001007 B030                        mov al, '0'
  1037 00001009 CD10                        int 0x10
  1038 0000100B B40E                        mov ah, 0xE
  1039 0000100D B062                        mov al, 'b'
  1040 0000100F CD10                        int 0x10
  1041 00001011 58                          pop ax
  1042                                  
  1043 00001012 30FF                        xor bh, bh
  1044 00001014 88C3                        mov bl, al
  1045 00001016 B90800                      mov cx, 8
  1046                                  print_al_loop:
  1047 00001019 88D8                        mov al, bl
  1048 0000101B 2401                        and al, 1
  1049 0000101D 0430                        add al, '0'
  1050 0000101F B40E                        mov ah, 0xE
  1051 00001021 50                          push ax
  1052 00001022 D0EB                        shr bl, 1
  1053 00001024 E2F3                        loop print_al_loop
  1054 00001026 B90800                      mov cx, 8
  1055                                  print_al_loop2:
  1056 00001029 58                          pop ax
  1057 0000102A CD10                        int 0x10
  1058 0000102C E2FB                        loop print_al_loop2
  1059 0000102E 61                          popa
  1060 0000102F C3                          ret
  1061                                  
  1062                                  
  1063                                  ;print value of ax in decimal
  1064                                  print_ax_decimal:
  1065 00001030 60                          pusha
  1066                                      ;push 0 for print function to end
  1067 00001031 31DB                        xor bx, bx
  1068 00001033 53                          push bx
  1069                                      ;if ax is already zero, just print a 0
  1070 00001034 09C0                        or ax, ax
  1071 00001036 741E                        jz print_ax_decimal_zero
  1072                                  print_ax_decimal_loop:
  1073 00001038 09C0                        or ax, ax
  1074 0000103A 740F                        jz print_ax_decimal_printloop
  1075 0000103C 31D2                        xor dx, dx
  1076 0000103E BB0A00                      mov bx, 10
  1077                                      ;16 bit division, dx:ax / bx = ax, remainder dx
  1078 00001041 F7F3                        div bx
  1079                                      ;push remainder in ascii
  1080 00001043 83C230                      add dx, '0'
  1081 00001046 52                          push dx
  1082                                      ;loop
  1083 00001047 EBEF                        jmp print_ax_decimal_loop
  1084                                  print_ax_decimal_printloop:
  1085                                      ;print digits pushed on the stack
  1086 00001049 58                          pop ax
  1087                                      ;if popped value is 0, exit
  1088 0000104A 09C0                        or ax, ax
  1089 0000104C 740F                        jz print_ax_decimal_end
  1090                                      ;print value
  1091 0000104E B40E                        mov ah, 0xE
  1092 00001050 CD10                        int 0x10
  1093 00001052 EBF5                        jmp print_ax_decimal_printloop
  1094                                  print_ax_decimal_zero:
  1095 00001054 5B                          pop bx
  1096 00001055 B40E                        mov ah, 0xE
  1097 00001057 B030                        mov al, '0'
  1098 00001059 CD10                        int 0x10
  1099                                  print_ax_decimal_end:
  1100 0000105B 61                          popa
  1101 0000105C C3                          ret
  1102                                  
  1103                                  
  1104                                  _kernel_load:
  1105 0000105D 31FF                        xor di, di ;counter for retry
  1106                                  _kernel_load_loop:
  1107                                  
  1108 0000105F 31C0                        xor ax, ax
  1109 00001061 8ED8                        mov ds, ax
  1110 00001063 BE[D000]                    mov si, disk_read_msg ;Reading from disk: diskNum
  1111 00001066 E831F0                      call _printstr
  1112                                  
  1113                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
  1114 00001069 B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
  1115 0000106C B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
  1116 0000106F 30F6                        xor dh, dh ;head number CHS
  1117 00001071 8A16[E300]                  mov dl, [diskNum] ;drive number
  1118                                      ;Address to store values in: es:bx
  1119 00001075 BB0010                      mov bx, 0x1000
  1120 00001078 8EC3                        mov es, bx
  1121 0000107A 31DB                        xor bx, bx
  1122                                  
  1123 0000107C CD13                        int 0x13 ;disk read
  1124 0000107E 720D                        jc __kernel_load_fail
  1125                                  
  1126                                      ;disk read success
  1127 00001080 31C0                        xor ax, ax
  1128 00001082 8ED8                        mov ds, ax
  1129 00001084 BE[B109]                    mov si, kernel_load_success
  1130 00001087 E810F0                      call _printstr
  1131                                      
  1132 0000108A C3                          ret
  1133                                  
  1134                                  __kernel_load_fail:
  1135                                      ;if number of attempts is over or equal 8
  1136 0000108B 83FF08                      cmp di, 8
  1137 0000108E 7D2F                        jge __kernel_load_fail_final
  1138                                  
  1139 00001090 31C0                        xor ax, ax
  1140 00001092 8ED8                        mov ds, ax
  1141 00001094 BE[5C09]                    mov si, kernel_load_fail
  1142 00001097 E800F0                      call _printstr
  1143                                  
  1144                                      ;attempt to reset disk
  1145 0000109A 31C0                        xor ax, ax ;scancode ah = 0
  1146 0000109C 8A16[E300]                  mov dl, [diskNum]
  1147 000010A0 CD13                        int 0x13 ;reset disk system
  1148                                  
  1149 000010A2 47                          inc di
  1150                                      ;update number of attempts
  1151 000010A3 89F8                        mov ax, di
  1152 000010A5 83C030                      add ax, '0'
  1153 000010A8 A2[EF00]                    mov [attempt_num], al
  1154                                  
  1155 000010AB 31C0                        xor ax, ax
  1156 000010AD 8ED8                        mov ds, ax
  1157 000010AF BE[E700]                    mov si, attempts_msg
  1158 000010B2 E8E5EF                      call _printstr
  1159                                  
  1160 000010B5 B90020                      mov cx, 0x2000
  1161 000010B8 E80BF0                      call _wait
  1162                                  
  1163 000010BB EBA2                        jmp _kernel_load_loop
  1164                                  
  1165                                  __kernel_load_fail_final:
  1166 000010BD 31C0                        xor ax, ax
  1167 000010BF 8ED8                        mov ds, ax
  1168 000010C1 BE[8009]                    mov si, kernel_load_fail_final
  1169 000010C4 E8D3EF                      call _printstr
  1170 000010C7 58                          pop ax
  1171 000010C8 E971FA                      jmp hang  ;go back to 16 bit hang loop if fail
  1172                                  
  1173                                  
  1174                                  ;FAILSTATES
  1175                                  VBEStuff_get_controller_info_fail:
  1176 000010CB 31C0                        xor ax, ax
  1177 000010CD 8ED8                        mov ds, ax
  1178 000010CF BE[EA09]                    mov si, VBEStuff_get_controller_info_fail_msg
  1179 000010D2 E8C5EF                      call _printstr
  1180                                      ;blocking keyboard input
  1181 000010D5 31C0                        xor ax, ax
  1182 000010D7 CD16                        int 0x16 ;keyboard services
  1183 000010D9 E9CFEF                      jmp biosboot_pc
  1184                                  VBEStuff_get_mode_info_fail:
  1185 000010DC 31C0                        xor ax, ax
  1186 000010DE 8ED8                        mov ds, ax
  1187 000010E0 BE[5C0A]                    mov si, VBEStuff_get_mode_info_fail_msg
  1188 000010E3 E8B4EF                      call _printstr
  1189                                      ;blocking keyboard input
  1190 000010E6 31C0                        xor ax, ax
  1191 000010E8 CD16                        int 0x16 ;keyboard services
  1192 000010EA E9BEEF                      jmp biosboot_pc
  1193                                  
  1194                                  VBEStuff:
  1195                                      ;get controller info
  1196 000010ED 31C0                        xor ax, ax ;es:di
  1197 000010EF 8EC0                        mov es, ax
  1198 000010F1 BF[0402]                    mov di, VBE_info_block_start    
  1199 000010F4 B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
  1200 000010F7 CD10                        int 0x10
  1201 000010F9 83F84F                      cmp ax, 0x004F
  1202 000010FC 75CD                        jne VBEStuff_get_controller_info_fail
  1203                                  
  1204 000010FE 31C0                        xor ax, ax
  1205 00001100 8ED8                        mov ds, ax
  1206 00001102 BE[C709]                    mov si, VBEStuff_get_controller_info_success_msg
  1207 00001105 E892EF                      call _printstr
  1208                                  
  1209                                      ;print controller info
  1210 00001108 31C0                        xor ax, ax
  1211 0000110A 8ED8                        mov ds, ax
  1212 0000110C BE[280A]                    mov si, VBEStuff_get_controller_info_print_msg
  1213 0000110F E888EF                      call _printstr
  1214                                  
  1215 00001112 A0[0402]                    mov al, [VBE_info_block_signature]
  1216 00001115 B40E                        mov ah, 0xE
  1217 00001117 CD10                        int 0x10
  1218 00001119 A1[0502]                    mov ax, [VBE_info_block_signature+1]
  1219 0000111C B40E                        mov ah, 0xE
  1220 0000111E CD10                        int 0x10
  1221 00001120 A1[0602]                    mov ax, [VBE_info_block_signature+2]
  1222 00001123 B40E                        mov ah, 0xE
  1223 00001125 CD10                        int 0x10
  1224 00001127 A1[0702]                    mov ax, [VBE_info_block_signature+3]
  1225 0000112A B40E                        mov ah, 0xE
  1226 0000112C CD10                        int 0x10
  1227 0000112E B8200E                      mov ax, 0xE20
  1228 00001131 CD10                        int 0x10
  1229 00001133 A1[0802]                    mov ax, [VBE_info_block_version]
  1230 00001136 B00E                        mov al, 0xE
  1231 00001138 86C4                        xchg ah, al
  1232 0000113A 0430                        add al, '0'
  1233 0000113C CD10                        int 0x10
  1234                                  
  1235 0000113E 31C0                        xor ax, ax
  1236 00001140 8ED8                        mov ds, ax
  1237 00001142 BE[3F0A]                    mov si, VBEStuff_get_controller_info_print_msg1
  1238 00001145 E852EF                      call _printstr
  1239                                  
  1240 00001148 A1[1402]                    mov ax, [VBE_info_block_video_mode_segment]
  1241 0000114B E888FE                      call print_ax
  1242 0000114E B40E                        mov ah, 0xE
  1243 00001150 B03A                        mov al, ':'
  1244 00001152 CD10                        int 0x10
  1245 00001154 A1[1202]                    mov ax, [VBE_info_block_video_mode_offset]
  1246 00001157 E87CFE                      call print_ax
  1247                                  
  1248 0000115A B80D0E                      mov ax, 0x0E0D
  1249 0000115D CD10                        int 0x10
  1250 0000115F B80A0E                      mov ax, 0x0E0A
  1251 00001162 CD10                        int 0x10
  1252                                  
  1253                                      ;iter mode numbers and find the good one
  1254                                      ;get start of modes array and put into fs:si
  1255 00001164 A1[1402]                    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
  1256 00001167 8EE0                        mov fs, ax
  1257 00001169 8B36[1202]                  mov si, [VBE_info_block_video_mode_offset]
  1258                                  VBEStuff_iter_modes_loop:
  1259 0000116D 648B04                      mov ax, fs:[si] ;ax = current mode number
  1260                                  
  1261 00001170 50                          push ax
  1262 00001171 0FA0                        push fs
  1263 00001173 56                          push si
  1264                                      ;now print mode in text form
  1265 00001174 E84500                      call print_VBE_mode_text
  1266 00001177 5E                          pop si
  1267 00001178 0FA1                        pop fs
  1268 0000117A 58                          pop ax
  1269                                  
  1270                                  
  1271                                      ;if mode number is 0xFFFF, exit program
  1272 0000117B 83F8FF                      cmp ax, 0xFFFF
  1273 0000117E 740D                        je VBEStuff_iter_modes_exit
  1274                                  
  1275                                      ;increment si
  1276 00001180 83C602                      add si, 2
  1277                                  
  1278 00001183 B90001                      mov cx, 0x100
  1279 00001186 E83DEF                      call _wait
  1280                                  
  1281 00001189 EBE2                        jmp VBEStuff_iter_modes_loop
  1282                                  VBEStuff_iter_modes_exit:
  1283                                      ;print best mode number
  1284 0000118B 31C0                        xor ax, ax
  1285 0000118D 8ED8                        mov ds, ax
  1286 0000118F BE[A70A]                    mov si, VBEStuff_iter_modes_best_mode_msg
  1287 00001192 E805EF                      call _printstr
  1288                                  
  1289 00001195 A1[FF0A]                    mov ax, [check_VBE_mode_best_mode_number]
  1290 00001198 E82100                      call print_VBE_mode_text
  1291                                  
  1292 0000119B C3                          ret
  1293                                  
  1294                                  
  1295                                  
  1296                                  VBEStuff_setMode:
  1297                                      ;switch to the mode
  1298 0000119C 31C0                        xor ax, ax
  1299 0000119E 8ED8                        mov ds, ax
  1300 000011A0 BE[B50A]                    mov si, VBEStuff_iter_modes_best_mode_msg1
  1301 000011A3 E8F4EE                      call _printstr
  1302                                  
  1303 000011A6 B90030                      mov cx, 0x3000
  1304 000011A9 E81AEF                      call _wait
  1305                                  
  1306                                      ;set video mode
  1307 000011AC 31C0                        xor ax, ax
  1308 000011AE 8ED8                        mov ds, ax
  1309 000011B0 B8024F                      mov ax, 0x4F02
  1310 000011B3 8B1E[FF0A]                  mov bx, [check_VBE_mode_best_mode_number]
  1311 000011B7 CD10                        int 0x10
  1312 000011B9 C3                          ret
  1313                                  
  1314                                  
  1315                                  
  1316                                  
  1317                                  
  1318                                  
  1319                                  
  1320                                  print_VBE_mode_text:
  1321                                      ;save mode number here
  1322 000011BA A3[F00A]                    mov [current_mode_number], ax
  1323                                  
  1324                                      ;if mode number is 0xFFFF, exit program
  1325 000011BD 83F8FF                      cmp ax, 0xFFFF
  1326 000011C0 0F849300                    je print_VBE_mode_text_end
  1327                                  
  1328                                      ;print value in ax
  1329 000011C4 E80FFE                      call print_ax
  1330                                  
  1331                                      ;print space
  1332 000011C7 89C3                        mov bx, ax
  1333 000011C9 B8200E                      mov ax, 0x0E20
  1334 000011CC CD10                        int 0x10
  1335 000011CE 89D8                        mov ax, bx
  1336                                  
  1337                                      ;now get mode info
  1338 000011D0 31C0                        xor ax, ax
  1339 000011D2 8ED8                        mov ds, ax
  1340                                  
  1341 000011D4 89D9                        mov cx, bx ;cx = mode number
  1342 000011D6 B8014F                      mov ax, 0x4F01 ;scancode
  1343                                      ;es:di = 256b buffer
  1344 000011D9 31D2                        xor dx, dx
  1345 000011DB 8EC2                        mov es, dx
  1346 000011DD BF[0404]                    mov di, VBE_mode_info_block_start
  1347 000011E0 CD10                        int 0x10
  1348 000011E2 83F84F                      cmp ax, 0x004F
  1349 000011E5 0F85F3FE                    jne VBEStuff_get_mode_info_fail
  1350                                  
  1351                                      ;now print out width and height
  1352 000011E9 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1353 000011EC E841FE                      call print_ax_decimal
  1354 000011EF B40E                        mov ah, 0xE
  1355 000011F1 B078                        mov al, 'x'
  1356 000011F3 CD10                        int 0x10
  1357 000011F5 A1[1804]                    mov ax, [VBE_mode_info_block_height]
  1358 000011F8 E835FE                      call print_ax_decimal
  1359 000011FB B8200E                      mov ax, 0x0E20
  1360 000011FE CD10                        int 0x10
  1361                                  
  1362                                      ;print if it supports linear framebuffer or not
  1363 00001200 31C0                        xor ax, ax
  1364 00001202 8ED8                        mov ds, ax
  1365 00001204 8B1E[0404]                  mov bx, [VBE_mode_info_block_attributes]
  1366 00001208 81E38000                    and bx, 0b10000000 ;if bit 7 is 1 it supports
  1367 0000120C C1EB06                      shr bx, 6
  1368 0000120F 81C3[DA0A]                  add bx, VBE_mode_info_block_fb_support
  1369 00001213 8B37                        mov si, [bx] ;pointer array shenanigans
  1370 00001215 E882EE                      call _printstr
  1371                                      ;print space and msg
  1372 00001218 BE[940A]                    mov si, print_VBE_mode_text_msg
  1373 0000121B E87CEE                      call _printstr
  1374                                      ;print bits per pixel
  1375 0000121E 31C0                        xor ax, ax
  1376 00001220 A0[1D04]                    mov al, [VBE_mode_info_block_bpp]
  1377 00001223 E80AFE                      call print_ax_decimal
  1378                                      ;print space and msg
  1379 00001226 BE[A20A]                    mov si, print_VBE_mode_text_msg2
  1380 00001229 E86EEE                      call _printstr
  1381                                      ;print memory model
  1382 0000122C 31C0                        xor ax, ax
  1383 0000122E A0[1F04]                    mov al, [VBE_mode_info_block_memory_model]
  1384 00001231 E8FCFD                      call print_ax_decimal
  1385                                      ;print space and msg
  1386 00001234 31C0                        xor ax, ax
  1387 00001236 8ED8                        mov ds, ax
  1388 00001238 BE[9A0A]                    mov si, print_VBE_mode_text_msg1
  1389 0000123B E85CEE                      call _printstr
  1390                                      ;print pitch
  1391 0000123E A1[1404]                    mov ax, [VBE_mode_info_block_pitch]
  1392 00001241 E8ECFD                      call print_ax_decimal
  1393                                  
  1394                                      ;now check if the mode is actually good & find best one
  1395 00001244 E81100                      call check_VBE_mode
  1396                                  
  1397 00001247 B80D0E                      mov ax, 0x0E0D
  1398 0000124A CD10                        int 0x10
  1399 0000124C B80A0E                      mov ax, 0x0E0A
  1400 0000124F CD10                        int 0x10
  1401                                  
  1402 00001251 31C0                        xor ax, ax
  1403 00001253 8ED8                        mov ds, ax
  1404                                  print_VBE_mode_text_end:
  1405 00001255 C3                          ret
  1406                                  
  1407                                  
  1408                                  
  1409                                  
  1410                                  
  1411                                  check_VBE_mode:
  1412                                      
  1413                                      ;if LFB is false, exit
  1414 00001256 A1[0404]                    mov ax, [VBE_mode_info_block_attributes]
  1415 00001259 258000                      and ax, 0b10000000 ;if bit 7 is 1 it supports
  1416 0000125C 09C0                        or ax, ax
  1417 0000125E 7472                        jz check_VBE_mode_exit
  1418                                  
  1419                                      ;if mm is not 6, exit
  1420 00001260 31C0                        xor ax, ax
  1421 00001262 A0[1F04]                    mov al, [VBE_mode_info_block_memory_model]
  1422 00001265 3C06                        cmp al, 6
  1423 00001267 7569                        jne check_VBE_mode_exit
  1424                                  
  1425                                      ;if bpp is not 32, exit
  1426 00001269 31C0                        xor ax, ax
  1427 0000126B A0[1D04]                    mov al, [VBE_mode_info_block_bpp]
  1428 0000126E 3C20                        cmp al, 32
  1429 00001270 7560                        jne check_VBE_mode_exit
  1430                                  
  1431                                      ;print valid
  1432 00001272 31C0                        xor ax, ax
  1433 00001274 8ED8                        mov ds, ax
  1434 00001276 BE[F20A]                    mov si, check_VBE_mode_msg
  1435 00001279 E81EEE                      call _printstr
  1436                                  
  1437                                      ;get current mode's area
  1438 0000127C A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1439 0000127F 8B1E[1804]                  mov bx, [VBE_mode_info_block_height]
  1440 00001283 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1441                                      ;compare high word of current with best high word
  1442 00001285 8B1E[010B]                  mov bx, [check_VBE_mode_best_area_high]
  1443 00001289 39DA                        cmp dx, bx
  1444 0000128B 7C45                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1445 0000128D 7F1B                        jg check_VBE_mode_update ;if current > highest, update values
  1446                                      ;if equal, check low word
  1447 0000128F 8B1E[030B]                  mov bx, [check_VBE_mode_best_area_low]
  1448 00001293 39DA                        cmp dx, bx
  1449 00001295 7C3B                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1450 00001297 7F11                        jg check_VBE_mode_update ;if current > highest, update values
  1451                                  
  1452                                      ;if still equal, that means it's the exact same resolution
  1453                                      ;check if current screen width is more than best screen width
  1454 00001299 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1455 0000129C 8B1E[050B]                  mov bx, [check_VBE_mode_best_screen_width]
  1456 000012A0 39D8                        cmp ax, bx
  1457 000012A2 7C2E                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1458 000012A4 7F04                        jg check_VBE_mode_update ;if current > highest, update values
  1459                                  
  1460 000012A6 EB2A                        jmp check_VBE_mode_exit
  1461                                  check_VBE_mode_update:
  1462                                      ;restore current mode number
  1463 000012A8 8B1E[F00A]                  mov bx, [current_mode_number]
  1464                                      ;update best mode number
  1465 000012AC 891E[FF0A]                  mov [check_VBE_mode_best_mode_number], bx
  1466                                      ;update best area
  1467 000012B0 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1468 000012B3 8B1E[1804]                  mov bx, [VBE_mode_info_block_height]
  1469 000012B7 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1470 000012B9 8916[010B]                  mov [check_VBE_mode_best_area_high], dx
  1471 000012BD A3[030B]                    mov [check_VBE_mode_best_area_low], ax
  1472                                      ;update best screen width
  1473 000012C0 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1474 000012C3 A3[050B]                    mov [check_VBE_mode_best_screen_width], ax
  1475                                  
  1476                                      ;print best
  1477 000012C6 31C0                        xor ax, ax
  1478 000012C8 8ED8                        mov ds, ax
  1479 000012CA BE[F90A]                    mov si, check_VBE_mode_msg1
  1480 000012CD E8CAED                      call _printstr
  1481                                  check_VBE_mode_exit:
  1482 000012D0 C3                          ret
  1483                                  
  1484                                  
  1485                                  
  1486                                  
  1487                                  
  1488                                  
  1489                                  
  1490                                  boot_pmode:
  1491 000012D1 31C0                        xor ax, ax
  1492 000012D3 8ED8                        mov ds, ax
  1493 000012D5 BE[7605]                    mov si, boot_pmode_msg
  1494 000012D8 E8BFED                      call _printstr
  1495                                  
  1496 000012DB E87FFD                      call _kernel_load
  1497                                  
  1498 000012DE 31C0                        xor ax, ax
  1499 000012E0 8ED8                        mov ds, ax
  1500 000012E2 BE[8C05]                    mov si, kernel_loaded_msg
  1501 000012E5 E8B2ED                      call _printstr
  1502                                  
  1503 000012E8 B90010                      mov cx, 0x1000
  1504 000012EB E8D8ED                      call _wait
  1505                                  
  1506 000012EE B93200                      mov cx, 50
  1507                                  clear_loop:
  1508 000012F1 B80D0E                      mov ax, 0x0E0D
  1509 000012F4 CD10                        int 0x10
  1510 000012F6 B80A0E                      mov ax, 0x0E0A
  1511 000012F9 CD10                        int 0x10
  1512 000012FB E2F4                        loop clear_loop
  1513                                      
  1514                                      ;set new graphics mode
  1515                                  
  1516                                      ;Mode 3h
  1517                                      ;VGA 80x25 text mode
  1518 000012FD B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1519 00001300 CD10                        int 0x10 ;bios call video services
  1520                                  
  1521                                      ;Mode 12h
  1522                                      ;VGA 640x480 16 color
  1523                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1524                                      ;int 0x10 ;bios call video services
  1525                                  
  1526                                      ;VBE graphics
  1527 00001302 E8E8FD                      call VBEStuff
  1528 00001305 E894FE                      call VBEStuff_setMode
  1529                                  
  1530 00001308 FA                          cli
  1531 00001309 0F0116[220B]                lgdt [GDT_descriptor] ;load GDT
  1532                                      
  1533                                      ;change last bit of cr0 to 1
  1534 0000130E 0F20C0                      mov eax, cr0
  1535 00001311 6683C801                    or eax, 1
  1536 00001315 0F22C0                      mov cr0, eax
  1537                                      
  1538                                      ;PROTECTED MODE!
  1539                                      ;far jump to code segment
  1540 00001318 EA[1F13]0800                jmp CODE_SEG:pmode
  1541                                  
  1542                                  BITS 32
  1543                                  pmode:
  1544 0000131D 66B81000                    mov ax, DATA_SEG ;setup segments
  1545 00001321 8ED8                        mov ds, ax
  1546 00001323 8ED0                        mov ss, ax
  1547 00001325 8EC0                        mov es, ax
  1548 00001327 8EE0                        mov fs, ax
  1549 00001329 8EE8                        mov gs, ax
  1550 0000132B BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1551 00001330 89EC                        mov esp, ebp
  1552                                  
  1553                                      ;jump to loaded kernel
  1554 00001332 E9(00000100)                jmp 0x10000
  1555 00001337 EBFE                        jmp $
  1556                                  
  1557                                  
  1558                                  
  1559                                  
  1560 00001339 00<rep 64C7h>           times 30720-($-$$) db 0 ;total length of binary 60 sector
  1561                                  
  1562                                  
