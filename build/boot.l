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
    21 00000011 BC007C                      mov sp, 0x7C00 ;stack grows below bootloader
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
    38 00000027 E9110B                      jmp main
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
   191                                  ; end of first sector, 512B -------------------------------------------------------------------------------------------------
   192                                  ;----------------------------------------------------------------------------------------------------------------------------
   193                                      ;Data    
   194                                      ;kernel data
   195                                  kernel_setting_block_start:
   196 00000200 01                          kernel_gfx_mode db 1 ;0 for VGA, 1 for VBE
   197 00000201 FFFF                        kernel_VBE_mode dw 0xFFFF ;VBE mode number if gfx mode is set to 1
   198 00000203 00                          kernel_test_mode db 0
   199                                  
   200                                  ; TOTAL of 512 bytes
   201                                  VBE_info_block_start:
   202 00000204 4E45494E                    VBE_info_block_signature db 'NEIN'
   203 00000208 0000                        VBE_info_block_version dw 0
   204 0000020A 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
   205 0000020E 00000000                    VBE_info_block_capabilities dd 0
   206 00000212 0000                        VBE_info_block_video_mode_offset dw 0
   207 00000214 0000                        VBE_info_block_video_mode_segment dw 0
   208 00000216 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
   209 00000218 00<rep 1ECh>                times 492 db 0 ;reserved
   210                                  
   211                                  ; TOTAL of 256 bytes
   212                                  VBE_mode_info_block_start:
   213 00000404 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
   214 00000406 00                          VBE_mode_info_block_window_a db 0 ;deprecated
   215 00000407 00                          VBE_mode_info_block_window_b db 0 ;deprecated
   216 00000408 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
   217 0000040A 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
   218 0000040C 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
   219 0000040E 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
   220 00000410 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
   221 00000414 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
   222                                  
   223 00000416 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
   224 00000418 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
   225 0000041A 00                          VBE_mode_info_block_char_width db 0 ;in pixels, unused
   226 0000041B 00                          VBE_mode_info_block_char_height db 0 ;in pixels, unused
   227 0000041C 00                          VBE_mode_info_block_planes_count db 0
   228 0000041D 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
   229 0000041E 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
   230 0000041F 00                          VBE_mode_info_block_memory_model db 0
   231 00000420 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
   232 00000421 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
   233 00000422 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
   234                                  
   235                                      ;size and pos of masks
   236 00000423 00                          VBE_mode_info_block_red_mask db 0
   237 00000424 00                          VBE_mode_info_block_red_pos db 0
   238 00000425 00                          VBE_mode_info_block_green_mask db 0
   239 00000426 00                          VBE_mode_info_block_green_pos db 0
   240 00000427 00                          VBE_mode_info_block_blue_mask db 0
   241 00000428 00                          VBE_mode_info_block_blue_pos db 0
   242 00000429 00                          VBE_mode_info_block_reserved_mask db 0
   243 0000042A 00                          VBE_mode_info_block_reserved_pos db 0
   244 0000042B 00                          VBE_mode_info_block_direct_color_attributes db 0
   245                                  
   246                                      ;added in revision 2.0
   247 0000042C 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
   248 00000430 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
   249 00000434 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
   250 00000436 00<rep CEh>                 VBE_mode_info_block_reserved times 206 db 0 ;available in revision 3.0, useless
   251                                  
   252                                  ;----------------------------------------------------------------------------------------------------------------------------
   253                                  
   254 00000504 0D0A46313A20504320-         msg db 0xD, 0xA, 'F1: PC functions submenu', 0xD, 0xA
   254 0000050D 66756E6374696F6E73-
   254 00000516 207375626D656E750D-
   254 0000051F 0A                 
   255 00000520 46323A206368616E67-         db 'F2: change kernel boot options', 0xD, 0xA
   255 00000529 65206B65726E656C20-
   255 00000532 626F6F74206F707469-
   255 0000053B 6F6E730D0A         
   256 00000540 46333A20656E746572-         db 'F3: enter 32 bit protected mode and execute Nuck OS', 0xD, 0xA, 0
   256 00000549 203332206269742070-
   256 00000552 726F74656374656420-
   256 0000055B 6D6F646520616E6420-
   256 00000564 65786563757465204E-
   256 0000056D 75636B204F530D0A00 
   257 00000576 46343A207669727475-         db 'F4: virtual piano', 0xD, 0xA, 0
   257 0000057F 616C207069616E6F0D-
   257 00000588 0A00               
   258                                  
   259 0000058A 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   259 00000593 206B65726E656C2E2E-
   259 0000059C 2E0D0A00           
   260 000005A0 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   260 000005A9 616465642C20737769-
   260 000005B2 746368696E6720746F-
   260 000005BB 2070726F7465637465-
   260 000005C4 64206D6F64652E2E2E-
   260 000005CD 0D0A00             
   261 000005D0 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   262                                      oslogo
   262          ******************       warning: label alone on a line without a colon might be in error [-w+label-orphan]
   263 000005D7 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   263 000005E0 2020202020205F2020-
   263 000005E9 205F20202020202020-
   263 000005F2 20202020205F202020-
   263 000005FB 2020205F5F5F5F2020-
   263 00000604 202020202020202020-
   263 0000060D 2020205F2020202020-
   263 00000616 4F532056657273696F-
   263 0000061F 6E2020200D0A       
   264 00000625 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.01      ', 0xD, 0xA
   264 0000062E 20202020207C205C20-
   264 00000637 7C207C5F2020205F20-
   264 00000640 205F5F5F7C207C205F-
   264 00000649 5F207C205F5F202920-
   264 00000652 205F5F5F2020205F5F-
   264 0000065B 5F207C207C5F202020-
   264 00000664 202020312E30312020-
   264 0000066D 202020200D0A       
   265 00000673 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   265 0000067C 20202020207C20205C-
   265 00000685 7C207C207C207C207C-
   265 0000068E 2F205F5F7C207C2F20-
   265 00000697 2F207C20205F205C20-
   265 000006A0 2F205F205C202F205F-
   265 000006A9 205C7C205F5F7C2020-
   265 000006B2 202020202020202020-
   265 000006BB 202020200D0A       
   266 000006C1 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   266 000006CA 20202020207C207C5C-
   266 000006D3 20207C207C5F7C207C-
   266 000006DC 20285F5F7C2020203C-
   266 000006E5 20207C207C5F29207C-
   266 000006EE 20285F29207C20285F-
   266 000006F7 29207C207C5F202020-
   266 00000700 202020202020202020-
   266 00000709 202020200D0A       
   267 0000070F 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   267 00000718 20202020207C5F7C20-
   267 00000721 5C5F7C5C5F5F2C5F7C-
   267 0000072A 5C5F5F5F7C5F7C5C5F-
   267 00000733 5C207C5F5F5F5F2F20-
   267 0000073C 5C5F5F5F2F205C5F5F-
   267 00000745 5F2F205C5F5F7C2020-
   267 0000074E 202020202020202020-
   267 00000757 202020200D0A       
   268 0000075D 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   268 00000766 202020202020202020-
   268 0000076F 20226F706572617469-
   268 00000778 6E672073797374656D-
   268 00000781 206F66207468652066-
   268 0000078A 757475726522202854-
   268 00000793 4D290D0A00         
   269                                  
   270 00000798 00                          hang_virtual_piano_mode db 0b00
   271                                  
   272 00000799 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   272 000007A2 6176650D0A00       
   273 000007A8 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   273 000007B1 650D0A00           
   274 000007B5 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   274 000007BE 76650D0A00         
   275                                  
   276 000007C3 3D00                        keylen dw 61
   277 000007C5 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   277 000007CE 307177657274797569-
   277 000007D7 6F706173646667686A-
   277 000007E0 6B6C7A786376626E6D 
   278 000007E9 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   278 000007F2 455459494F50534447-
   278 000007FB 484A4C5A435642     
   279                                  
   280 00000802 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   280 0000080B 006E007B00         
   281 00000810 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   281 00000819 00DC00F600         
   282 0000081E 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   282 00000827 01B801EE01         
   283 0000082C 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   283 00000835 037003DC03         
   284 0000083A 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   284 00000843 06E006B807         
   285 00000848 2D08                        dw 2093
   286                                  
   287 0000084A 45004E005C00680075-         dw 69, 78, 92, 104, 117
   287 00000853 00                 
   288 00000854 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   288 0000085D 00                 
   289 0000085E 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   289 00000867 01                 
   290 00000868 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   290 00000871 03                 
   291 00000872 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   291 0000087B 07                 
   292                                  
   293 0000087C 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   293 00000885 0037003E00         
   294 0000088A 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   294 00000893 006E007B00         
   295 00000898 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   295 000008A1 00DC00F600         
   296 000008A6 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   296 000008AF 01B801EE01         
   297 000008B4 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   297 000008BD 037003DC03         
   298 000008C2 1704                        dw 1047
   299                                  
   300 000008C4 230027002E0034003A-         dw 35, 39, 46, 52, 58
   300 000008CD 00                 
   301 000008CE 45004E005C00680075-         dw 69, 78, 92, 104, 117
   301 000008D7 00                 
   302 000008D8 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   302 000008E1 00                 
   303 000008E2 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   303 000008EB 01                 
   304 000008EC 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   304 000008F5 03                 
   305                                  
   306 000008F6 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   306 000008FF 00DC00F600         
   307 00000904 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   307 0000090D 01B801EE01         
   308 00000912 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   308 0000091B 037003DC03         
   309 00000920 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   309 00000929 06E006B807         
   310 0000092E 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   310 00000937 0CC00D6F0F         
   311 0000093C 5A10                        dw 4186
   312                                  
   313 0000093E 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   313 00000947 00                 
   314 00000948 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   314 00000951 01                 
   315 00000952 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   315 0000095B 03                 
   316 0000095C 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   316 00000965 07                 
   317 00000966 A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   317 0000096F 0E                 
   318                                  
   319 00000970 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   319 00000979 6164206661696C7572-
   319 00000982 652C20726573657474-
   319 0000098B 696E672E2E2E0D0A00 
   320 00000994 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   320 0000099D 6164206661696C6564-
   320 000009A6 2C20676F696E672062-
   320 000009AF 61636B20746F207265-
   320 000009B8 616C206D6F64652E2E-
   320 000009C1 2E0D0A00           
   321 000009C5 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   321 000009CE 616420737563636573-
   321 000009D7 730D0A00           
   322                                  
   323 000009DB 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, "VBE controller info:", 0xD, 0xA, 0
   323 000009E4 6F6E74726F6C6C6572-
   323 000009ED 20696E666F20737563-
   323 000009F6 63657373210D0A5642-
   323 000009FF 4520636F6E74726F6C-
   323 00000A08 6C657220696E666F3A-
   323 00000A11 0D0A00             
   324 00000A14 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   324 00000A1D 6F6E74726F6C6C6572-
   324 00000A26 20696E666F20666169-
   324 00000A2F 6C210D0A5072657373-
   324 00000A38 20616E79206B657920-
   324 00000A41 746F20636F6E74696E-
   324 00000A4A 75652E2E2E0D0A00   
   325                                  
   326 00000A52 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   326 00000A5B 6F6465732070747228-
   326 00000A64 7365673A6F6666293A-
   326 00000A6D 2000               
   327                                  
   328 00000A6F 56424520676574206D-         VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   328 00000A78 6F646520696E666F20-
   328 00000A81 6661696C210D0A5072-
   328 00000A8A 65737320616E79206B-
   328 00000A93 657920746F20636F6E-
   328 00000A9C 74696E75652E2E2E0D-
   328 00000AA5 0A00               
   329                                  
   330 00000AA7 206270703A00                print_VBE_mode_text_msg db " bpp:", 0
   331 00000AAD 2070697463683A00            print_VBE_mode_text_msg1 db " pitch:", 0
   332 00000AB5 206D6D3A00                  print_VBE_mode_text_msg2 db " mm:", 0
   333                                  
   334 00000ABA 42657374206D6F6465-         VBEStuff_iter_modes_best_mode_msg db "Best mode: ", 0xD, 0xA, 0
   334 00000AC3 3A200D0A00         
   335 00000AC8 537769746368696E67-         VBEStuff_iter_modes_best_mode_msg1 db "Switching to VBE graphics mode... ", 0xD, 0xA, 0
   335 00000AD1 20746F205642452067-
   335 00000ADA 72617068696373206D-
   335 00000AE3 6F64652E2E2E200D0A-
   335 00000AEC 00                 
   336                                  
   337 00000AED [F90A]                      VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
   338 00000AEF [F10A]                      dw VBE_mode_info_block_fb_support_t
   339                                  
   340 00000AF1 4C46423A204A4100            VBE_mode_info_block_fb_support_t db "LFB: JA", 0
   341 00000AF9 4C46423A204E45494E-         VBE_mode_info_block_fb_support_f db "LFB: NEIN", 0
   341 00000B02 00                 
   342                                  
   343 00000B03 0000                        current_mode_number dw 0
   344                                  
   345 00000B05 2076616C696400              check_VBE_mode_msg db ' valid', 0
   346 00000B0C 206265737400                check_VBE_mode_msg1 db ' best', 0
   347                                  
   348 00000B12 0000                        check_VBE_mode_best_mode_number dw 0
   349                                  
   350 00000B14 0000                        check_VBE_mode_best_area_high dw 0
   351 00000B16 0000                        check_VBE_mode_best_area_low dw 0
   352                                  
   353 00000B18 0000                        check_VBE_mode_best_screen_width dw 0
   354                                  
   355 00000B1A 00                          kernel_setting_selected db 0
   356 00000B1B 0000                        kernel_setting_selected_mode_number dw 0
   357                                  
   358                                  ;code segment descriptor
   359                                  ;Base            32b: starting location of segment
   360                                  ;Limit           20b: size of limit
   361                                  ;Present          1b: Is this segment used/is a valid segment
   362                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   363                                  ;Type             1b: 1 if segment is code or data segment
   364                                  ;Flags(1b):
   365                                  ;  Type flags(4b):
   366                                  ;    1. Code? Will segment contain code
   367                                  ;    2. Conforming: can this code be executed from lower privileged segments
   368                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   369                                  ;            becomes an expand down segment
   370                                  ;    3. Readable, can this segment be read?
   371                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   372                                  ;            segment becomes read only
   373                                  ;    4. Accessed: set to 1 when CPU is using the segment
   374                                  ;  Other flags(4b):
   375                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   376                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   377                                  ;    3 & 4: 64 bit tetio, just set to 0
   378                                  
   379                                  ;offset of the segment descriptors relative to the beginning of the GDT
   380                                  CODE_SEG equ GDT_code - GDT_start
   381                                  DATA_SEG equ GDT_data - GDT_start
   382                                  
   383                                  ;kernel location is 0x10000
   384                                  KERNEL_LOCATION equ 0x1000
   385                                  
   386                                  GDT_start:
   387                                      GDT_null:
   388 00000B1D 00000000                        dd 0 ;(32 bits)
   389 00000B21 00000000                        dd 0 ;(32 bits)
   390                                      GDT_code:
   391                                          ;base: 0
   392                                          ;limit: 0xFFFFF
   393                                          ;PPT: 1001
   394                                          ;Type: 1010
   395                                          ;Other: 1100
   396                                  
   397                                          ;first 16 bits of limit
   398 00000B25 FFFF                            dw 0xFFFF
   399                                          ;first 24 bits of base
   400 00000B27 0000                            dw 0x0000 ;16 bits
   401 00000B29 00                              db 0x00   ; 8 bits
   402                                          ;PPT + Type
   403 00000B2A 9A                              db 0b10011010
   404                                          ;other + last 4 bits of limit
   405 00000B2B CF                              db 0b11001111
   406                                          ;last 8 bits of base
   407 00000B2C 00                              db 0x00
   408                                      GDT_data:
   409                                          ;base: 0
   410                                          ;limit: 0xFFFFF
   411                                          ;PPT: 1001
   412                                          ;Type: 0010
   413                                          ;Other: 1100
   414                                  
   415                                          ;first 16 bits of limit
   416 00000B2D FFFF                            dw 0xFFFF
   417                                          ;first 24 bits of base
   418 00000B2F 0000                            dw 0x0000 ;16 bits
   419 00000B31 00                              db 0x00   ; 8 bits
   420                                          ;PPT + Type
   421 00000B32 92                              db 0b10010010
   422                                          ;other + last 4 bits of limit
   423 00000B33 CF                              db 0b11001111
   424                                          ;last 8 bits of base
   425 00000B34 00                              db 0b00000000
   426                                  GDT_end:
   427                                  GDT_descriptor:
   428                                      ;size of GDT(16 bits)
   429 00000B35 1700                        dw GDT_end - GDT_start - 1
   430                                      ;start of GDT(32 bits)
   431 00000B37 [1D0B0000]                  dd GDT_start
   432                                  
   433                                  ;----------------------------------------------------------------------------------------------------------------------------
   434                                  
   435                                  main:
   436                                  
   437                                  
   438 00000B3B 31C0                        xor ax, ax
   439 00000B3D 8ED8                        mov ds, ax
   440 00000B3F BE[D705]                    mov si, oslogo
   441 00000B42 E855F5                      call _printstr
   442                                  hang_early:
   443                                      ;print a helpful message
   444 00000B45 31C0                        xor ax, ax
   445 00000B47 8ED8                        mov ds, ax
   446 00000B49 BE[0405]                    mov si, msg
   447 00000B4C E84BF5                      call _printstr
   448                                  
   449                                  hang:
   450 00000B4F B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   451 00000B51 CD16                        int 0x16 ;keyboard services
   452                                      ;return: AL = character, AH = scan code
   453 00000B53 74FA                        jz hang ;if key not pressed jump back
   454                                      ;if there is a key use int 0x16,0 to get the results
   455 00000B55 31C0                        xor ax, ax
   456 00000B57 CD16                        int 0x16 ;ah = scancode, al = char
   457                                  
   458                                      ;print char
   459 00000B59 50                          push ax
   460 00000B5A B40E                        mov ah, 0x0E
   461 00000B5C CD10                        int 0x10
   462 00000B5E 58                          pop ax
   463                                  
   464 00000B5F 80FC3B                      cmp ah, 0x3B
   465 00000B62 0F84CD00                    je submenu_1
   466 00000B66 80FC3C                      cmp ah, 0x3C
   467 00000B69 0F84E901                    je submenu_2
   468 00000B6D 80FC3D                      cmp ah, 0x3D
   469 00000B70 0F84BC07                    je boot_pmode
   470 00000B74 80FC3E                      cmp ah, 0x3E
   471 00000B77 0F841703                    je virtual_piano_loop
   472                                  
   473 00000B7B EBD2                        jmp hang
   474                                  
   475                                  
   476                                  ;----------------------------------------------------------------------------------------------------------------------------
   477                                  
   478                                  
   479 00000B7D 0D0A50432066756E63-     submenu_1_msg db 0xD, 0xA, 'PC functions:', 0xD, 0xA
   479 00000B86 74696F6E733A0D0A   
   480 00000B8E 46313A207265737461-     db 'F1: restart/boot next/enter BIOS', 0xD, 0xA
   480 00000B97 72742F626F6F74206E-
   480 00000BA0 6578742F656E746572-
   480 00000BA9 2042494F530D0A     
   481 00000BB0 46323A207265737461-     db 'F2: restart(jmp to reset vector)', 0xD, 0xA
   481 00000BB9 7274286A6D7020746F-
   481 00000BC2 207265736574207665-
   481 00000BCB 63746F72290D0A     
   482 00000BD2 46333A20636C656172-     db 'F3: clear screen', 0xD, 0xA
   482 00000BDB 2073637265656E0D0A 
   483 00000BE4 46343A2068616C740D-     db 'F4: halt', 0xD, 0xA
   483 00000BED 0A                 
   484 00000BEE 46353A2042494F5320-     db 'F5: BIOS beep', 0xD, 0xA
   484 00000BF7 626565700D0A       
   485 00000BFD 46363A2052656C6F61-     db 'F6: Reload NuckBoot from boot device', 0xD, 0xA
   485 00000C06 64204E75636B426F6F-
   485 00000C0F 742066726F6D20626F-
   485 00000C18 6F7420646576696365-
   485 00000C21 0D0A               
   486 00000C23 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   486 00000C2C 61636B0D0A0700     
   487                                  
   488                                  
   489                                  submenu_1:
   490                                      ;print message
   491 00000C33 31C0                        xor ax, ax
   492 00000C35 8ED8                        mov ds, ax
   493 00000C37 BE[7D0B]                    mov si, submenu_1_msg
   494 00000C3A E85DF4                      call _printstr
   495                                  
   496                                  submenu_1_hang:
   497 00000C3D B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   498 00000C3F CD16                        int 0x16 ;keyboard services
   499                                      ;return: AL = character, AH = scan code
   500 00000C41 74FA                        jz submenu_1_hang ;if key not pressed jump back
   501                                      ;if there is a key use int 0x16,0 to get the results
   502 00000C43 31C0                        xor ax, ax
   503 00000C45 CD16                        int 0x16 ;ah = scancode, al = char
   504                                  
   505                                      ;print char
   506 00000C47 50                          push ax
   507 00000C48 B40E                        mov ah, 0x0E
   508 00000C4A CD10                        int 0x10
   509 00000C4C 58                          pop ax
   510                                  
   511                                      ;check Esc
   512 00000C4D 80FC01                      cmp ah, 0x01
   513 00000C50 0F84F1FE                    je hang_early
   514                                      ;F1-5
   515 00000C54 80FC3B                      cmp ah, 0x3B
   516 00000C57 0F8450F4                    je biosboot_pc
   517 00000C5B 80FC3C                      cmp ah, 0x3C
   518 00000C5E 0F8455F4                    je restart_pc
   519 00000C62 80FC3D                      cmp ah, 0x3D
   520 00000C65 0F842403                    je cls
   521 00000C69 80FC3E                      cmp ah, 0x3E
   522 00000C6C 0F845203                    je halt
   523 00000C70 80FC3F                      cmp ah, 0x3F
   524 00000C73 0F843803                    je biosbeep
   525 00000C77 80FC40                      cmp ah, 0x40
   526 00000C7A 0F843C02                    je retest
   527                                  
   528 00000C7E EBBD                        jmp submenu_1_hang
   529                                  
   530                                  
   531                                  ;----------------------------------------------------------------------------------------------------------------------------
   532                                  
   533 00000C80 0D0A4E75636B204F53-     submenu_2_msg db 0xD, 0xA, 'Nuck OS boot settings:', 0xD, 0xA
   533 00000C89 20626F6F7420736574-
   533 00000C92 74696E67733A0D0A   
   534 00000C9A 46313A206368616E67-     db 'F1: change kernel graphics mode', 0xD, 0xA
   534 00000CA3 65206B65726E656C20-
   534 00000CAC 677261706869637320-
   534 00000CB5 6D6F64650D0A       
   535 00000CBB 46323A206368616E67-     db 'F2: change kernel test mode', 0xD, 0xA
   535 00000CC4 65206B65726E656C20-
   535 00000CCD 74657374206D6F6465-
   535 00000CD6 0D0A               
   536 00000CD8 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   536 00000CE1 61636B0D0A0700     
   537 00000CE8 53656C656374206766-     submenu_2_msg2 db 'Select gfx mode:', 0xD, 0xA
   537 00000CF1 78206D6F64653A0D0A 
   538 00000CFA 46313A2073656C6563-     db 'F1: select VGA', 0xD, 0xA
   538 00000D03 74205647410D0A     
   539 00000D0A 46323A206C69737420-     db 'F2: list all VBE modes', 0xD, 0xA
   539 00000D13 616C6C20564245206D-
   539 00000D1C 6F6465730D0A       
   540 00000D22 46333A206C69737420-     db 'F3: list and select valid VBE mode', 0xD, 0xA, 0
   540 00000D2B 616E642073656C6563-
   540 00000D34 742076616C69642056-
   540 00000D3D 4245206D6F64650D0A-
   540 00000D46 00                 
   541 00000D47 5647412073656C6563-     submenu_2_msg3 db 'VGA selected', 0xD, 0xA, 0
   541 00000D50 7465640D0A00       
   542                                  
   543                                  submenu_2:
   544                                      ;print message
   545 00000D56 31C0                        xor ax, ax
   546 00000D58 8ED8                        mov ds, ax
   547 00000D5A BE[800C]                    mov si, submenu_2_msg
   548 00000D5D E83AF3                      call _printstr
   549                                  
   550                                  submenu_2_hang:
   551 00000D60 E8B100                      call print_kernel_current_settings
   552                                  submenu_2_keyhang:
   553 00000D63 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   554 00000D65 CD16                        int 0x16 ;keyboard services
   555                                      ;return: AL = character, AH = scan code
   556 00000D67 74FA                        jz submenu_2_keyhang ;if key not pressed jump back
   557                                      ;if there is a key use int 0x16,0 to get the results
   558 00000D69 31C0                        xor ax, ax
   559 00000D6B CD16                        int 0x16 ;ah = scancode, al = char
   560                                  
   561 00000D6D 80FC01                      cmp ah, 0x01
   562 00000D70 0F84D1FD                    je hang_early
   563                                  
   564 00000D74 80FC3B                      cmp ah, 0x3B
   565 00000D77 7402                        je submenu_2_select_gfx_mode
   566                                  
   567                                  
   568 00000D79 EBE5                        jmp submenu_2_hang
   569                                  
   570                                  submenu_2_select_gfx_mode:
   571 00000D7B 31C0                        xor ax, ax
   572 00000D7D 8ED8                        mov ds, ax
   573 00000D7F BE[E80C]                    mov si, submenu_2_msg2
   574 00000D82 E815F3                      call _printstr
   575                                  
   576                                  submenu_2_select_gfx_mode_loop:
   577 00000D85 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   578 00000D87 CD16                        int 0x16 ;keyboard services
   579                                      ;return: AL = character, AH = scan code
   580 00000D89 74FA                        jz submenu_2_select_gfx_mode_loop ;if key not pressed jump back
   581                                      ;if there is a key use int 0x16,0 to get the results
   582 00000D8B 31C0                        xor ax, ax
   583 00000D8D CD16                        int 0x16 ;ah = scancode, al = char
   584                                  
   585 00000D8F 80FC01                      cmp ah, 0x01
   586 00000D92 74CC                        je submenu_2_hang
   587                                  
   588 00000D94 80FC3B                      cmp ah, 0x3B 
   589 00000D97 740C                        je submenu_2_select_gfx_mode_VGA
   590 00000D99 80FC3C                      cmp ah, 0x3C
   591 00000D9C 7416                        je submenu_2_select_gfx_mode_VBE1
   592 00000D9E 80FC3D                      cmp ah, 0x3D
   593 00000DA1 7416                        je submenu_2_select_gfx_mode_VBE2
   594                                  
   595 00000DA3 EBE0                        jmp submenu_2_select_gfx_mode_loop
   596                                  submenu_2_select_gfx_mode_VGA:
   597 00000DA5 31C0                        xor ax, ax
   598 00000DA7 A3[0002]                    mov [kernel_gfx_mode], ax
   599 00000DAA 8ED8                        mov ds, ax
   600 00000DAC BE[470D]                    mov si, submenu_2_msg3
   601 00000DAF E8E8F2                      call _printstr
   602 00000DB2 74D1                        je submenu_2_select_gfx_mode_loop
   603                                  submenu_2_select_gfx_mode_VBE1:
   604                                      ;list all VBE modes
   605 00000DB4 E89E03                      call VBEStuff
   606 00000DB7 74CC                        je submenu_2_select_gfx_mode_loop
   607                                  submenu_2_select_gfx_mode_VBE2:
   608                                      ;list valid VBE modes
   609 00000DB9 E89903                      call VBEStuff
   610                                  
   611 00000DBC 74C7                        je submenu_2_select_gfx_mode_loop
   612                                  
   613 00000DBE 43757272656E742073-     print_kernel_current_settings_msg1 db 'Current settings:', 0xD, 0xA, 0
   613 00000DC7 657474696E67733A0D-
   613 00000DD0 0A00               
   614 00000DD2 564741205465787420-     print_kernel_current_settings_msg2 db 'VGA Text 80x25', 0xD, 0xA, 0
   614 00000DDB 38307832350D0A00   
   615 00000DE3 5642452F5645534120-     print_kernel_current_settings_msg3 db 'VBE/VESA Mode ', 0
   615 00000DEC 4D6F64652000       
   616 00000DF2 4E6F742073656C6563-     print_kernel_current_settings_msg4 db 'Not selected', 0xD, 0xA, 0
   616 00000DFB 7465640D0A00       
   617 00000E01 4B65726E656C207465-     print_kernel_current_settings_msg5 db 'Kernel test mode: ', 0
   617 00000E0A 7374206D6F64653A20-
   617 00000E13 00                 
   618                                  
   619                                  print_kernel_current_settings:
   620 00000E14 31C0                        xor ax, ax
   621 00000E16 8ED8                        mov ds, ax
   622 00000E18 BE[BE0D]                    mov si, print_kernel_current_settings_msg1
   623 00000E1B E87CF2                      call _printstr
   624 00000E1E 8A1E[0002]                  mov bl, [kernel_gfx_mode]
   625 00000E22 08DB                        or bl, bl
   626 00000E24 7525                        jne print_kernel_current_settings_notVGA
   627                                      ;VGA text mode
   628 00000E26 31C0                        xor ax, ax
   629 00000E28 8ED8                        mov ds, ax
   630 00000E2A BE[D20D]                    mov si, print_kernel_current_settings_msg2
   631 00000E2D E86AF2                      call _printstr
   632                                  print_kernel_current_settings_back:
   633 00000E30 31C0                        xor ax, ax
   634 00000E32 8ED8                        mov ds, ax
   635 00000E34 BE[010E]                    mov si, print_kernel_current_settings_msg5
   636 00000E37 E860F2                      call _printstr
   637                                  
   638 00000E3A A0[0302]                    mov al, [kernel_test_mode]
   639 00000E3D E82B02                      call print_al
   640                                  
   641 00000E40 B80D0E                      mov ax, 0xE0D
   642 00000E43 CD10                        int 0x10
   643 00000E45 B80A0E                      mov ax, 0xE0A
   644 00000E48 CD10                        int 0x10
   645                                  
   646 00000E4A C3                          ret
   647                                  
   648                                  print_kernel_current_settings_notVGA:
   649 00000E4B 31C0                        xor ax, ax
   650 00000E4D 8ED8                        mov ds, ax
   651 00000E4F BE[E30D]                    mov si, print_kernel_current_settings_msg3
   652 00000E52 E845F2                      call _printstr
   653 00000E55 A0[1A0B]                    mov al, [kernel_setting_selected]
   654 00000E58 08C0                        or al, al
   655 00000E5A 7408                        je print_kernel_current_settings_notVGA_not_selected
   656                                      ;query info about selected mode
   657 00000E5C A1[1B0B]                    mov ax, [kernel_setting_selected_mode_number]
   658 00000E5F E8B403                      call print_VBE_mode_text
   659                                  
   660 00000E62 EBCC                        jmp print_kernel_current_settings_back
   661                                  
   662                                  print_kernel_current_settings_notVGA_not_selected:
   663 00000E64 31C0                        xor ax, ax
   664 00000E66 8ED8                        mov ds, ax
   665 00000E68 BE[F20D]                    mov si, print_kernel_current_settings_msg4
   666 00000E6B E82CF2                      call _printstr
   667 00000E6E EBC0                        jmp print_kernel_current_settings_back
   668                                  
   669                                  
   670                                  
   671                                  
   672                                  ;----------------------------------------------------------------------------------------------------------------------------
   673                                  
   674                                  
   675                                  
   676 00000E70 0D0A5669727475616C-     virtual_piano_menu_msg db 0xD, 0xA, 'Virtual piano:', 0xD, 0xA
   676 00000E79 207069616E6F3A0D0A 
   677 00000E82 4573633A20676F2062-     db 'Esc: go back', 0xD, 0xA, 0x7, 0
   677 00000E8B 61636B0D0A0700     
   678                                  
   679                                  virtual_piano_loop:
   680                                      ;print message
   681 00000E92 31C0                        xor ax, ax
   682 00000E94 8ED8                        mov ds, ax
   683 00000E96 BE[700E]                    mov si, virtual_piano_menu_msg
   684 00000E99 E8FEF1                      call _printstr
   685                                  virtual_piano_looploop:
   686 00000E9C B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   687 00000E9E CD16                        int 0x16 ;keyboard services
   688                                      ;return: AL = character, AH = scan code
   689 00000EA0 74FA                        jz virtual_piano_looploop ;if key not pressed jump back
   690                                      ;if there is a key use int 0x16,0 to get the results
   691 00000EA2 31C0                        xor ax, ax
   692 00000EA4 CD16                        int 0x16 ;ah = scancode, al = char
   693                                  
   694                                      ;print char
   695 00000EA6 50                          push ax
   696 00000EA7 B40E                        mov ah, 0x0E
   697 00000EA9 CD10                        int 0x10
   698 00000EAB 58                          pop ax
   699                                  
   700                                      ;check Esc
   701 00000EAC 80FC01                      cmp ah, 0x01
   702 00000EAF 0F8492FC                    je hang_early
   703                                      
   704 00000EB3 50                          push ax
   705 00000EB4 E84800                      call hang_virtual_piano
   706 00000EB7 58                          pop ax
   707                                  
   708 00000EB8 EBE2                        jmp virtual_piano_looploop
   709                                  
   710                                  ;----------------------------------------------------------------------------------------------------------------------------
   711                                  
   712                                  
   713                                  
   714                                  
   715                                  
   716                                  ;subroutine to retest nuck os
   717                                  retest:
   718 00000EBA 8A16[E300]                  mov dl, [diskNum]
   719 00000EBE 52                          push dx
   720 00000EBF E80600                      call retest_disk_read
   721                                      ;jump to the start
   722 00000EC2 5A                          pop dx
   723 00000EC3 EA0000C007                  jmp 0x07C0:0x0000
   724                                  
   725                                  
   726                                  retest_disk_read:
   727 00000EC8 31FF                        xor di, di ;counter for retry
   728                                  retest_disk_read_loop:
   729                                  
   730                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   731                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   732 00000ECA B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   733 00000ECD B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   734 00000ED0 30F6                        xor dh, dh ;head number CHS
   735 00000ED2 8A16[E300]                  mov dl, [diskNum] ;drive number
   736                                      ;Address to store values in: es:bx which is 0:7E00
   737 00000ED6 31DB                        xor bx, bx
   738 00000ED8 8EC3                        mov es, bx
   739 00000EDA BB007C                      mov bx, 0x7C00
   740 00000EDD CD13                        int 0x13 ;disk read
   741 00000EDF 7201                        jc retest__disk_read_fail
   742                                  
   743                                      ;disk read success
   744 00000EE1 C3                          ret
   745                                  
   746                                  retest__disk_read_fail:
   747                                      ;if number of attempts is over or equal 8
   748 00000EE2 83FF08                      cmp di, 8
   749 00000EE5 7D11                        jge retest__disk_read_fail_final
   750                                  
   751                                      ;attempt to reset disk
   752 00000EE7 31C0                        xor ax, ax ;scancode ah = 0
   753 00000EE9 8A16[E300]                  mov dl, [diskNum]
   754 00000EED CD13                        int 0x13 ;reset disk system
   755                                  
   756 00000EEF 47                          inc di
   757                                  
   758 00000EF0 B90020                      mov cx, 0x2000
   759 00000EF3 E8D0F1                      call _wait
   760                                  
   761 00000EF6 EBD2                        jmp retest_disk_read_loop
   762                                  
   763                                  retest__disk_read_fail_final:
   764                                      ;blocking keyboard input
   765 00000EF8 31C0                        xor ax, ax
   766 00000EFA CD16                        int 0x16 ;keyboard services
   767 00000EFC E9ACF1                      jmp biosboot_pc
   768                                  
   769                                  ;----------------------------------------------------------------------------------------------------------------------------
   770                                  
   771                                  
   772                                  ;subroutine to play a note in virtual piano
   773                                  ;key: al
   774                                  hang_virtual_piano:
   775                                      ;change mode
   776 00000EFF 50                          push ax
   777                                  
   778 00000F00 3C3B                        cmp al, 0x3B
   779 00000F02 740A                        je hang_virtual_piano_mode_rst
   780 00000F04 3C27                        cmp al, 0x27
   781 00000F06 7415                        je hang_virtual_piano_mode_1
   782 00000F08 3C22                        cmp al, 0x22
   783 00000F0A 7423                        je hang_virtual_piano_mode_2
   784 00000F0C EB31                        jmp hang_virtual_piano_mode_done
   785                                  hang_virtual_piano_mode_rst:
   786 00000F0E 31C0                        xor ax, ax
   787 00000F10 A2[9807]                    mov [hang_virtual_piano_mode], al
   788 00000F13 8ED8                        mov ds, ax
   789 00000F15 BE[9907]                    mov si, mode_rst_msg
   790 00000F18 E87FF1                      call _printstr
   791 00000F1B EB22                        jmp hang_virtual_piano_mode_done
   792                                  hang_virtual_piano_mode_1:
   793 00000F1D B80100                      mov ax, 0x0001
   794 00000F20 A2[9807]                    mov [hang_virtual_piano_mode], al
   795 00000F23 31C0                        xor ax, ax
   796 00000F25 8ED8                        mov ds, ax
   797 00000F27 BE[A807]                    mov si, mode_1_msg
   798 00000F2A E86DF1                      call _printstr    
   799 00000F2D EB10                        jmp hang_virtual_piano_mode_done
   800                                  hang_virtual_piano_mode_2:
   801 00000F2F B80200                      mov ax, 0x0002
   802 00000F32 A2[9807]                    mov [hang_virtual_piano_mode], al
   803 00000F35 31C0                        xor ax, ax
   804 00000F37 8ED8                        mov ds, ax
   805 00000F39 BE[B507]                    mov si, mode_2_msg
   806 00000F3C E85BF1                      call _printstr
   807                                  hang_virtual_piano_mode_done:
   808                                      ;load difference in di
   809 00000F3F 31C0                        xor ax, ax
   810 00000F41 A0[9807]                    mov al, [hang_virtual_piano_mode]
   811 00000F44 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   812 00000F47 31D2                        xor dx, dx
   813 00000F49 F7E3                        mul bx
   814 00000F4B 89C7                        mov di, ax
   815 00000F4D 58                          pop ax
   816                                  
   817 00000F4E 31C9                        xor cx, cx             ;i = 0
   818 00000F50 8B16[C307]                  mov dx, [keylen]       ;k = 10
   819                                  hang_virtual_piano_loop:
   820 00000F54 39D1                        cmp cx, dx
   821 00000F56 0F8DF5FB                    jge hang               ;return if i >= k
   822 00000F5A 89CE                        mov si, cx             ;si = i
   823 00000F5C 8A9C[C507]                  mov bl, [keys + si]    ;bl = keys[i]
   824 00000F60 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   825 00000F62 7403                        je hang_virtual_piano_play
   826                                  
   827 00000F64 41                          inc cx                 ;i++
   828 00000F65 EBED                        jmp hang_virtual_piano_loop
   829                                  
   830                                  hang_virtual_piano_play:
   831 00000F67 89C8                        mov ax, cx
   832 00000F69 B90200                      mov cx, 2
   833 00000F6C F7E1                        mul cx
   834 00000F6E 89C6                        mov si, ax
   835 00000F70 B8[0208]                    mov ax, notes
   836 00000F73 01F8                        add ax, di
   837 00000F75 01F0                        add ax, si
   838 00000F77 89C3                        mov bx, ax
   839 00000F79 8B07                        mov ax, [bx]
   840                                      
   841 00000F7B E88900                      call _tone
   842 00000F7E B9FFFF                      mov cx, 0xFFFF
   843 00000F81 BA0500                      mov dx, 0x5
   844 00000F84 E85300                      call _wait_PIT
   845 00000F87 E8AB00                      call speaker_off
   846 00000F8A E9C2FB                      jmp hang
   847                                  
   848                                  ;----------------------------------------------------------------------------------------------------------------------------
   849                                  
   850                                  
   851                                  cls:
   852 00000F8D B93200                      mov cx, 50
   853                                  cls_loop:
   854 00000F90 B80D0E                      mov ax, 0x0E0D
   855 00000F93 CD10                        int 0x10
   856 00000F95 B80A0E                      mov ax, 0x0E0A
   857 00000F98 CD10                        int 0x10
   858 00000F9A E2F4                        loop cls_loop
   859 00000F9C E99EFC                      jmp submenu_1_hang
   860                                  
   861                                  
   862                                  cls_call:
   863 00000F9F B93200                      mov cx, 50
   864                                  cls_loop_call:
   865 00000FA2 B80D0E                      mov ax, 0x0E0D
   866 00000FA5 CD10                        int 0x10
   867 00000FA7 B80A0E                      mov ax, 0x0E0A
   868 00000FAA CD10                        int 0x10
   869 00000FAC E2F4                        loop cls_loop_call
   870 00000FAE C3                          ret
   871                                  
   872                                  ;----------------------------------------------------------------------------------------------------------------------------
   873                                  
   874                                  
   875                                  ;bios beep tone
   876                                  biosbeep:
   877 00000FAF 31C0                        xor ax, ax
   878 00000FB1 8ED8                        mov ds, ax
   879 00000FB3 BE[D005]                    mov si, beep_msg
   880 00000FB6 E8E1F0                      call _printstr
   881 00000FB9 B90001                      mov cx, 0x100
   882 00000FBC E807F1                      call _wait
   883 00000FBF E97BFC                      jmp submenu_1_hang
   884                                  
   885                                  halt:
   886 00000FC2 B93200                      mov cx, 50
   887                                  halt_cls_loop:
   888 00000FC5 B80D0E                      mov ax, 0x0E0D
   889 00000FC8 CD10                        int 0x10
   890 00000FCA B80A0E                      mov ax, 0x0E0A
   891 00000FCD CD10                        int 0x10
   892 00000FCF E2F4                        loop halt_cls_loop
   893                                      ;disable cursor
   894 00000FD1 B401                        mov ah, 0x01
   895 00000FD3 B90020                      mov cx, 0x2000 ;disable cursor
   896 00000FD6 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   897                                  
   898 00000FD8 FA                          cli
   899 00000FD9 F4                          hlt
   900                                  
   901                                  ;----------------------------------------------------------------------------------------------------------------------------
   902                                  
   903                                  
   904                                  ;dx*cx is amount of ticks to wait
   905                                  _wait_PIT:
   906 00000FDA 51                          push cx
   907 00000FDB E80500                      call _wait_PIT_once
   908 00000FDE 59                          pop cx
   909 00000FDF 4A                          dec dx
   910 00000FE0 75F8                        jnz _wait_PIT
   911 00000FE2 C3                          ret
   912                                  
   913                                  ;cx, starting
   914                                  ;cx is amount of ticks to wait
   915                                  _wait_PIT_once:
   916 00000FE3 51                          push cx
   917 00000FE4 E81100                      call _read_PIT_ticks
   918 00000FE7 53                          push bx ;bx = starting count
   919                                  _wait_PIT_once_loop:
   920 00000FE8 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   921                                      ;compute time difference = current count - start count
   922 00000FEB 58                          pop ax      ;current count is bx, starting count is ax
   923 00000FEC 29C3                        sub bx, ax  ;bx = time diff
   924 00000FEE 59                          pop cx
   925 00000FEF 51                          push cx
   926 00000FF0 50                          push ax
   927 00000FF1 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   928 00000FF3 7CF3                        jl _wait_PIT_once_loop
   929 00000FF5 58                          pop ax
   930 00000FF6 58                          pop ax
   931 00000FF7 C3                          ret
   932                                  
   933                                  ;returns PIT ticks stored in bx
   934                                  _read_PIT_ticks:
   935 00000FF8 FA                          cli
   936 00000FF9 31C0                        xor ax, ax
   937 00000FFB E643                        out 0x43, al
   938 00000FFD E440                        in al, 0x40 ;LSB
   939 00000FFF 88C3                        mov bl, al
   940 00001001 E440                        in al, 0x40 ;MSB
   941 00001003 88C7                        mov bh, al
   942 00001005 FB                          sti
   943 00001006 C3                          ret
   944                                  
   945                                  ;----------------------------------------------------------------------------------------------------------------------------
   946                                  
   947                                  ;PIT notes
   948                                  ;I/O port     Usage
   949                                  ;0x40         Channel 0 data port (read/write)
   950                                  ;0x41         Channel 1 data port (read/write)
   951                                  ;0x42         Channel 2 data port (read/write)
   952                                  ;0x43         Mode/Command register (write only, a read is ignored)
   953                                  ;
   954                                  ;Bits:  7 6 5 4 3 2 1 0
   955                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   956                                  ;       | | | | +--+-- Mode (0–5)
   957                                  ;       | | +-----+-- Access Mode: 
   958                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   959                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   960                                  ;subroutine to play a tone
   961                                  ;ax: frequency
   962                                  _tone:
   963 00001007 50                          push ax
   964                                      ;calculate divisor from frequency
   965                                      ;divisor = 1193182 / freq
   966                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   967 00001008 BA1200                      mov dx, 0x12
   968 0000100B B8DE34                      mov ax, 0x34DE
   969                                      ;load denominator into bx(frequency)
   970 0000100E 5B                          pop bx
   971                                      ;divide
   972 0000100F F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   973 00001011 50                          push ax ;save on stack
   974                                  
   975 00001012 E82000                      call speaker_off
   976                                      ;write to PIT control register
   977 00001015 B0B6                        mov al, 0b10110110
   978 00001017 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   979                                      ;write divisor to channel 2 data port
   980 00001019 58                          pop ax         ; Divisor
   981 0000101A 89C3                        mov bx, ax
   982 0000101C 88D8                        mov al, bl
   983 0000101E E642                        out 0x42, al         ; LSB first
   984 00001020 88F8                        mov al, bh
   985 00001022 E642                        out 0x42, al         ; Then MSB
   986                                      
   987 00001024 E80500                      call speaker_on
   988 00001027 31C0                        xor ax, ax
   989 00001029 8ED8                        mov ds, ax
   990 0000102B C3                          ret
   991                                  
   992                                  ;tell speaker to not shut up
   993                                  speaker_on:
   994 0000102C FA                          cli
   995 0000102D E461                        in al, 0x61
   996 0000102F 0C03                        or al, 0b11
   997 00001031 E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   998 00001033 FB                          sti
   999 00001034 C3                          ret
  1000                                  ;tell speaker to shut up
  1001                                  speaker_off:
  1002 00001035 FA                          cli
  1003 00001036 E461                        in al, 0x61
  1004 00001038 24FC                        and al, 0b11111100
  1005 0000103A E661                        out 0x61, al
  1006 0000103C FB                          sti
  1007 0000103D C3                          ret
  1008                                  
  1009                                  ;----------------------------------------------------------------------------------------------------------------------------
  1010                                  
  1011                                  
  1012                                  print_ax:
  1013 0000103E 60                          pusha
  1014                                  
  1015 0000103F 50                          push ax
  1016 00001040 B40E                        mov ah, 0xE
  1017 00001042 B030                        mov al, '0'
  1018 00001044 CD10                        int 0x10
  1019 00001046 B40E                        mov ah, 0xE
  1020 00001048 B062                        mov al, 'b'
  1021 0000104A CD10                        int 0x10
  1022 0000104C 58                          pop ax
  1023                                  
  1024 0000104D 89C3                        mov bx, ax
  1025 0000104F B91000                      mov cx, 16
  1026                                  print_ax_loop:
  1027 00001052 89D8                        mov ax, bx
  1028 00001054 83E001                      and ax, 1
  1029 00001057 83C030                      add ax, '0'
  1030 0000105A B40E                        mov ah, 0xE
  1031 0000105C 50                          push ax
  1032 0000105D D1EB                        shr bx, 1
  1033 0000105F E2F1                        loop print_ax_loop
  1034 00001061 B91000                      mov cx, 16
  1035                                  print_ax_loop2:
  1036 00001064 58                          pop ax
  1037 00001065 CD10                        int 0x10
  1038 00001067 E2FB                        loop print_ax_loop2
  1039 00001069 61                          popa
  1040 0000106A C3                          ret
  1041                                  
  1042                                  ;----------------------------------------------------------------------------------------------------------------------------
  1043                                  
  1044                                  
  1045                                  print_al:
  1046 0000106B 60                          pusha
  1047                                  
  1048 0000106C 50                          push ax
  1049 0000106D B40E                        mov ah, 0xE
  1050 0000106F B030                        mov al, '0'
  1051 00001071 CD10                        int 0x10
  1052 00001073 B40E                        mov ah, 0xE
  1053 00001075 B062                        mov al, 'b'
  1054 00001077 CD10                        int 0x10
  1055 00001079 58                          pop ax
  1056                                  
  1057 0000107A 30FF                        xor bh, bh
  1058 0000107C 88C3                        mov bl, al
  1059 0000107E B90800                      mov cx, 8
  1060                                  print_al_loop:
  1061 00001081 88D8                        mov al, bl
  1062 00001083 2401                        and al, 1
  1063 00001085 0430                        add al, '0'
  1064 00001087 B40E                        mov ah, 0xE
  1065 00001089 50                          push ax
  1066 0000108A D0EB                        shr bl, 1
  1067 0000108C E2F3                        loop print_al_loop
  1068 0000108E B90800                      mov cx, 8
  1069                                  print_al_loop2:
  1070 00001091 58                          pop ax
  1071 00001092 CD10                        int 0x10
  1072 00001094 E2FB                        loop print_al_loop2
  1073 00001096 61                          popa
  1074 00001097 C3                          ret
  1075                                  
  1076                                  ;----------------------------------------------------------------------------------------------------------------------------
  1077                                  
  1078                                  
  1079                                  ;print value of ax in decimal
  1080                                  print_ax_decimal:
  1081 00001098 60                          pusha
  1082                                      ;push 0 for print function to end
  1083 00001099 31DB                        xor bx, bx
  1084 0000109B 53                          push bx
  1085                                      ;if ax is already zero, just print a 0
  1086 0000109C 09C0                        or ax, ax
  1087 0000109E 741C                        jz print_ax_decimal_zero
  1088                                  print_ax_decimal_loop:
  1089 000010A0 09C0                        or ax, ax
  1090 000010A2 740D                        jz print_ax_decimal_printloop
  1091 000010A4 31D2                        xor dx, dx
  1092 000010A6 BB0A00                      mov bx, 10
  1093                                      ;16 bit division, dx:ax / bx = ax, remainder dx
  1094 000010A9 F7F3                        div bx
  1095                                      ;push remainder in ascii
  1096 000010AB 83C230                      add dx, '0'
  1097 000010AE 52                          push dx
  1098                                      ;loop
  1099 000010AF EBEF                        jmp print_ax_decimal_loop
  1100                                  print_ax_decimal_printloop:
  1101                                      ;print digits pushed on the stack
  1102 000010B1 58                          pop ax
  1103                                      ;if popped value is 0, exit
  1104 000010B2 09C0                        or ax, ax
  1105 000010B4 740D                        jz print_ax_decimal_end
  1106                                      ;print value
  1107 000010B6 B40E                        mov ah, 0xE
  1108 000010B8 CD10                        int 0x10
  1109 000010BA EBF5                        jmp print_ax_decimal_printloop
  1110                                  print_ax_decimal_zero:
  1111 000010BC 5B                          pop bx
  1112 000010BD B40E                        mov ah, 0xE
  1113 000010BF B030                        mov al, '0'
  1114 000010C1 CD10                        int 0x10
  1115                                  print_ax_decimal_end:
  1116 000010C3 61                          popa
  1117 000010C4 C3                          ret
  1118                                  
  1119                                  ;----------------------------------------------------------------------------------------------------------------------------
  1120                                  
  1121                                  
  1122                                  _kernel_load:
  1123 000010C5 31FF                        xor di, di ;counter for retry
  1124                                  _kernel_load_loop:
  1125                                  
  1126 000010C7 31C0                        xor ax, ax
  1127 000010C9 8ED8                        mov ds, ax
  1128 000010CB BE[D000]                    mov si, disk_read_msg ;Reading from disk: diskNum
  1129 000010CE E8C9EF                      call _printstr
  1130                                  
  1131                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
  1132 000010D1 B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
  1133 000010D4 B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
  1134 000010D7 30F6                        xor dh, dh ;head number CHS
  1135 000010D9 8A16[E300]                  mov dl, [diskNum] ;drive number
  1136                                      ;Address to store values in: es:bx
  1137 000010DD BB0010                      mov bx, 0x1000
  1138 000010E0 8EC3                        mov es, bx
  1139 000010E2 31DB                        xor bx, bx
  1140                                  
  1141 000010E4 CD13                        int 0x13 ;disk read
  1142 000010E6 720B                        jc __kernel_load_fail
  1143                                  
  1144                                      ;disk read success
  1145 000010E8 31C0                        xor ax, ax
  1146 000010EA 8ED8                        mov ds, ax
  1147 000010EC BE[C509]                    mov si, kernel_load_success
  1148 000010EF E8A8EF                      call _printstr
  1149                                      
  1150 000010F2 C3                          ret
  1151                                  
  1152                                  __kernel_load_fail:
  1153                                      ;if number of attempts is over or equal 8
  1154 000010F3 83FF08                      cmp di, 8
  1155 000010F6 7D2D                        jge __kernel_load_fail_final
  1156                                  
  1157 000010F8 31C0                        xor ax, ax
  1158 000010FA 8ED8                        mov ds, ax
  1159 000010FC BE[7009]                    mov si, kernel_load_fail
  1160 000010FF E898EF                      call _printstr
  1161                                  
  1162                                      ;attempt to reset disk
  1163 00001102 31C0                        xor ax, ax ;scancode ah = 0
  1164 00001104 8A16[E300]                  mov dl, [diskNum]
  1165 00001108 CD13                        int 0x13 ;reset disk system
  1166                                  
  1167 0000110A 47                          inc di
  1168                                      ;update number of attempts
  1169 0000110B 89F8                        mov ax, di
  1170 0000110D 83C030                      add ax, '0'
  1171 00001110 A2[EF00]                    mov [attempt_num], al
  1172                                  
  1173 00001113 31C0                        xor ax, ax
  1174 00001115 8ED8                        mov ds, ax
  1175 00001117 BE[E700]                    mov si, attempts_msg
  1176 0000111A E87DEF                      call _printstr
  1177                                  
  1178 0000111D B90020                      mov cx, 0x2000
  1179 00001120 E8A3EF                      call _wait
  1180                                  
  1181 00001123 EBA2                        jmp _kernel_load_loop
  1182                                  
  1183                                  __kernel_load_fail_final:
  1184 00001125 31C0                        xor ax, ax
  1185 00001127 8ED8                        mov ds, ax
  1186 00001129 BE[9409]                    mov si, kernel_load_fail_final
  1187 0000112C E86BEF                      call _printstr
  1188 0000112F 58                          pop ax
  1189 00001130 E91CFA                      jmp hang  ;go back to 16 bit hang loop if fail
  1190                                  
  1191                                  ;----------------------------------------------------------------------------------------------------------------------------
  1192                                  
  1193                                  
  1194                                  
  1195                                  ;FAILSTATES
  1196                                  VBEStuff_get_controller_info_fail:
  1197 00001133 31C0                        xor ax, ax
  1198 00001135 8ED8                        mov ds, ax
  1199 00001137 BE[140A]                    mov si, VBEStuff_get_controller_info_fail_msg
  1200 0000113A E85DEF                      call _printstr
  1201                                      ;blocking keyboard input
  1202 0000113D 31C0                        xor ax, ax
  1203 0000113F CD16                        int 0x16 ;keyboard services
  1204 00001141 E967EF                      jmp biosboot_pc
  1205                                  VBEStuff_get_mode_info_fail:
  1206 00001144 31C0                        xor ax, ax
  1207 00001146 8ED8                        mov ds, ax
  1208 00001148 BE[6F0A]                    mov si, VBEStuff_get_mode_info_fail_msg
  1209 0000114B E84CEF                      call _printstr
  1210                                      ;blocking keyboard input
  1211 0000114E 31C0                        xor ax, ax
  1212 00001150 CD16                        int 0x16 ;keyboard services
  1213 00001152 E956EF                      jmp biosboot_pc
  1214                                  
  1215                                  
  1216                                  
  1217                                  VBEStuff:
  1218                                      ;get controller info
  1219 00001155 31C0                        xor ax, ax ;es:di
  1220 00001157 8EC0                        mov es, ax
  1221 00001159 BF[0402]                    mov di, VBE_info_block_start    
  1222 0000115C B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
  1223 0000115F CD10                        int 0x10
  1224 00001161 83F84F                      cmp ax, 0x004F
  1225 00001164 75CD                        jne VBEStuff_get_controller_info_fail
  1226                                  
  1227 00001166 31C0                        xor ax, ax
  1228 00001168 8ED8                        mov ds, ax
  1229 0000116A BE[DB09]                    mov si, VBEStuff_get_controller_info_success_msg
  1230 0000116D E82AEF                      call _printstr
  1231                                  
  1232                                      ;print controller info
  1233                                  
  1234 00001170 A0[0402]                    mov al, [VBE_info_block_signature]
  1235 00001173 B40E                        mov ah, 0xE
  1236 00001175 CD10                        int 0x10
  1237 00001177 A1[0502]                    mov ax, [VBE_info_block_signature+1]
  1238 0000117A B40E                        mov ah, 0xE
  1239 0000117C CD10                        int 0x10
  1240 0000117E A1[0602]                    mov ax, [VBE_info_block_signature+2]
  1241 00001181 B40E                        mov ah, 0xE
  1242 00001183 CD10                        int 0x10
  1243 00001185 A1[0702]                    mov ax, [VBE_info_block_signature+3]
  1244 00001188 B40E                        mov ah, 0xE
  1245 0000118A CD10                        int 0x10
  1246 0000118C B8200E                      mov ax, 0xE20
  1247 0000118F CD10                        int 0x10
  1248 00001191 A1[0802]                    mov ax, [VBE_info_block_version]
  1249 00001194 B00E                        mov al, 0xE
  1250 00001196 86C4                        xchg ah, al
  1251 00001198 0430                        add al, '0'
  1252 0000119A CD10                        int 0x10
  1253                                  
  1254 0000119C 31C0                        xor ax, ax
  1255 0000119E 8ED8                        mov ds, ax
  1256 000011A0 BE[520A]                    mov si, VBEStuff_get_controller_info_print_msg1
  1257 000011A3 E8F4EE                      call _printstr
  1258                                  
  1259 000011A6 A1[1402]                    mov ax, [VBE_info_block_video_mode_segment]
  1260 000011A9 E892FE                      call print_ax
  1261 000011AC B40E                        mov ah, 0xE
  1262 000011AE B03A                        mov al, ':'
  1263 000011B0 CD10                        int 0x10
  1264 000011B2 A1[1202]                    mov ax, [VBE_info_block_video_mode_offset]
  1265 000011B5 E886FE                      call print_ax
  1266                                  
  1267 000011B8 B80D0E                      mov ax, 0x0E0D
  1268 000011BB CD10                        int 0x10
  1269 000011BD B80A0E                      mov ax, 0x0E0A
  1270 000011C0 CD10                        int 0x10
  1271                                  
  1272                                      ;iter mode numbers and find the good one
  1273                                      ;get start of modes array and put into fs:si
  1274 000011C2 A1[1402]                    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
  1275 000011C5 8EE0                        mov fs, ax
  1276 000011C7 8B36[1202]                  mov si, [VBE_info_block_video_mode_offset]
  1277                                  VBEStuff_iter_modes_loop:
  1278 000011CB 648B04                      mov ax, fs:[si] ;ax = current mode number
  1279                                  
  1280 000011CE 50                          push ax
  1281 000011CF 0FA0                        push fs
  1282 000011D1 56                          push si
  1283                                      ;now print mode in text form
  1284 000011D2 E84100                      call print_VBE_mode_text
  1285 000011D5 5E                          pop si
  1286 000011D6 0FA1                        pop fs
  1287 000011D8 58                          pop ax
  1288                                  
  1289                                  
  1290                                      ;if mode number is 0xFFFF, exit program
  1291 000011D9 83F8FF                      cmp ax, 0xFFFF
  1292 000011DC 740B                        je VBEStuff_iter_modes_exit
  1293                                  
  1294                                      ;increment si
  1295 000011DE 83C602                      add si, 2
  1296                                  
  1297 000011E1 B90001                      mov cx, 0x100
  1298 000011E4 E8DFEE                      call _wait
  1299                                  
  1300 000011E7 EBE2                        jmp VBEStuff_iter_modes_loop
  1301                                  VBEStuff_iter_modes_exit:
  1302                                      ;print best mode number
  1303 000011E9 31C0                        xor ax, ax
  1304 000011EB 8ED8                        mov ds, ax
  1305 000011ED BE[BA0A]                    mov si, VBEStuff_iter_modes_best_mode_msg
  1306 000011F0 E8A7EE                      call _printstr
  1307                                  
  1308 000011F3 A1[120B]                    mov ax, [check_VBE_mode_best_mode_number]
  1309 000011F6 E81D00                      call print_VBE_mode_text
  1310                                  
  1311 000011F9 C3                          ret
  1312                                  
  1313                                  
  1314                                  ;----------------------------------------------------------------------------------------------------------------------------
  1315                                  
  1316                                  
  1317                                  ;mode number in ax
  1318                                  VBEStuff_setMode:
  1319 000011FA 50                          push ax
  1320                                      ;switch to the mode
  1321 000011FB 31C0                        xor ax, ax
  1322 000011FD 8ED8                        mov ds, ax
  1323 000011FF BE[C80A]                    mov si, VBEStuff_iter_modes_best_mode_msg1
  1324 00001202 E895EE                      call _printstr
  1325                                  
  1326 00001205 B90030                      mov cx, 0x3000
  1327 00001208 E8BBEE                      call _wait
  1328                                  
  1329                                      ;set video mode
  1330 0000120B 31C0                        xor ax, ax
  1331 0000120D 8ED8                        mov ds, ax
  1332 0000120F B8024F                      mov ax, 0x4F02
  1333 00001212 5B                          pop bx
  1334 00001213 CD10                        int 0x10
  1335 00001215 C3                          ret
  1336                                  
  1337                                  ;----------------------------------------------------------------------------------------------------------------------------
  1338                                  
  1339                                  
  1340                                  print_VBE_mode_text:
  1341                                      ;save mode number here
  1342 00001216 A3[030B]                    mov [current_mode_number], ax
  1343                                  
  1344                                      ;if mode number is 0xFFFF, exit program
  1345 00001219 83F8FF                      cmp ax, 0xFFFF
  1346 0000121C 0F849100                    je print_VBE_mode_text_end
  1347                                  
  1348                                      ;if dl is not 1, print value in ax
  1349 00001220 E81BFE                      call print_ax
  1350                                  
  1351                                      ;print space
  1352 00001223 89C3                        mov bx, ax
  1353 00001225 B8200E                      mov ax, 0x0E20
  1354 00001228 CD10                        int 0x10
  1355 0000122A 89D8                        mov ax, bx
  1356                                  
  1357                                      ;now get mode info
  1358 0000122C 31C0                        xor ax, ax
  1359 0000122E 8ED8                        mov ds, ax
  1360                                  
  1361 00001230 89D9                        mov cx, bx ;cx = mode number
  1362 00001232 B8014F                      mov ax, 0x4F01 ;scancode
  1363                                      ;es:di = 256b buffer
  1364 00001235 31D2                        xor dx, dx
  1365 00001237 8EC2                        mov es, dx
  1366 00001239 BF[0404]                    mov di, VBE_mode_info_block_start
  1367 0000123C CD10                        int 0x10
  1368 0000123E 83F84F                      cmp ax, 0x004F
  1369 00001241 0F85FFFE                    jne VBEStuff_get_mode_info_fail
  1370                                  
  1371                                      ;now print out width and height
  1372 00001245 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1373 00001248 E84DFE                      call print_ax_decimal
  1374 0000124B B40E                        mov ah, 0xE
  1375 0000124D B078                        mov al, 'x'
  1376 0000124F CD10                        int 0x10
  1377 00001251 A1[1804]                    mov ax, [VBE_mode_info_block_height]
  1378 00001254 E841FE                      call print_ax_decimal
  1379 00001257 B8200E                      mov ax, 0x0E20
  1380 0000125A CD10                        int 0x10
  1381                                  
  1382                                      ;print if it supports linear framebuffer or not
  1383 0000125C 31C0                        xor ax, ax
  1384 0000125E 8ED8                        mov ds, ax
  1385 00001260 8B1E[0404]                  mov bx, [VBE_mode_info_block_attributes]
  1386 00001264 81E38000                    and bx, 0b10000000 ;if bit 7 is 1 it supports
  1387 00001268 C1EB06                      shr bx, 6
  1388 0000126B 81C3[ED0A]                  add bx, VBE_mode_info_block_fb_support
  1389 0000126F 8B37                        mov si, [bx] ;pointer array shenanigans
  1390 00001271 E826EE                      call _printstr
  1391                                      ;print space and msg
  1392 00001274 BE[A70A]                    mov si, print_VBE_mode_text_msg
  1393 00001277 E820EE                      call _printstr
  1394                                      ;print bits per pixel
  1395 0000127A 31C0                        xor ax, ax
  1396 0000127C A0[1D04]                    mov al, [VBE_mode_info_block_bpp]
  1397 0000127F E816FE                      call print_ax_decimal
  1398                                      ;print space and msg
  1399 00001282 BE[B50A]                    mov si, print_VBE_mode_text_msg2
  1400 00001285 E812EE                      call _printstr
  1401                                      ;print memory model
  1402 00001288 31C0                        xor ax, ax
  1403 0000128A A0[1F04]                    mov al, [VBE_mode_info_block_memory_model]
  1404 0000128D E808FE                      call print_ax_decimal
  1405                                      ;print space and msg
  1406 00001290 31C0                        xor ax, ax
  1407 00001292 8ED8                        mov ds, ax
  1408 00001294 BE[AD0A]                    mov si, print_VBE_mode_text_msg1
  1409 00001297 E800EE                      call _printstr
  1410                                      ;print pitch
  1411 0000129A A1[1404]                    mov ax, [VBE_mode_info_block_pitch]
  1412 0000129D E8F8FD                      call print_ax_decimal
  1413                                  
  1414                                      ;now check if the mode is actually good & find best one
  1415 000012A0 E80F00                      call check_VBE_mode
  1416                                      
  1417 000012A3 B80D0E                      mov ax, 0x0E0D
  1418 000012A6 CD10                        int 0x10
  1419 000012A8 B80A0E                      mov ax, 0x0E0A
  1420 000012AB CD10                        int 0x10
  1421                                  
  1422 000012AD 31C0                        xor ax, ax
  1423 000012AF 8ED8                        mov ds, ax
  1424                                  print_VBE_mode_text_end:
  1425 000012B1 C3                          ret
  1426                                  
  1427                                  ;----------------------------------------------------------------------------------------------------------------------------
  1428                                  
  1429                                  ;CF=1: mode is not valid
  1430                                  check_VBE_mode:
  1431                                      
  1432                                      ;if LFB is false, exit
  1433 000012B2 A1[0404]                    mov ax, [VBE_mode_info_block_attributes]
  1434 000012B5 258000                      and ax, 0b10000000 ;if bit 7 is 1 it supports
  1435 000012B8 09C0                        or ax, ax
  1436 000012BA 7472                        jz check_VBE_mode_exit_notValid
  1437                                  
  1438                                      ;if mm is not 6, exit
  1439 000012BC 31C0                        xor ax, ax
  1440 000012BE A0[1F04]                    mov al, [VBE_mode_info_block_memory_model]
  1441 000012C1 3C06                        cmp al, 6
  1442 000012C3 7569                        jne check_VBE_mode_exit_notValid
  1443                                  
  1444                                      ;if bpp is not 32, exit
  1445 000012C5 31C0                        xor ax, ax
  1446 000012C7 A0[1D04]                    mov al, [VBE_mode_info_block_bpp]
  1447 000012CA 3C20                        cmp al, 32
  1448 000012CC 7560                        jne check_VBE_mode_exit_notValid
  1449                                  
  1450                                      ;print valid
  1451 000012CE 31C0                        xor ax, ax
  1452 000012D0 8ED8                        mov ds, ax
  1453 000012D2 BE[050B]                    mov si, check_VBE_mode_msg
  1454 000012D5 E8C2ED                      call _printstr
  1455                                  
  1456                                      ;get current mode's area
  1457 000012D8 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1458 000012DB 8B1E[1804]                  mov bx, [VBE_mode_info_block_height]
  1459 000012DF F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1460                                      ;compare high word of current with best high word
  1461 000012E1 8B1E[140B]                  mov bx, [check_VBE_mode_best_area_high]
  1462 000012E5 39DA                        cmp dx, bx
  1463 000012E7 7C43                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1464 000012E9 7F19                        jg check_VBE_mode_update ;if current > highest, update values
  1465                                      ;if equal, check low word
  1466 000012EB 8B1E[160B]                  mov bx, [check_VBE_mode_best_area_low]
  1467 000012EF 39DA                        cmp dx, bx
  1468 000012F1 7C39                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1469 000012F3 7F0F                        jg check_VBE_mode_update ;if current > highest, update values
  1470                                  
  1471                                      ;if still equal, that means it's the exact same resolution
  1472                                      ;check if current screen width is more than best screen width
  1473 000012F5 A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1474 000012F8 8B1E[180B]                  mov bx, [check_VBE_mode_best_screen_width]
  1475 000012FC 39D8                        cmp ax, bx
  1476 000012FE 7C2C                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1477 00001300 7F02                        jg check_VBE_mode_update ;if current > highest, update values
  1478                                  
  1479 00001302 EB28                        jmp check_VBE_mode_exit
  1480                                  check_VBE_mode_update:
  1481                                      ;restore current mode number
  1482 00001304 8B1E[030B]                  mov bx, [current_mode_number]
  1483                                      ;update best mode number
  1484 00001308 891E[120B]                  mov [check_VBE_mode_best_mode_number], bx
  1485                                      ;update best area
  1486 0000130C A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1487 0000130F 8B1E[1804]                  mov bx, [VBE_mode_info_block_height]
  1488 00001313 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1489 00001315 8916[140B]                  mov [check_VBE_mode_best_area_high], dx
  1490 00001319 A3[160B]                    mov [check_VBE_mode_best_area_low], ax
  1491                                      ;update best screen width
  1492 0000131C A1[1604]                    mov ax, [VBE_mode_info_block_width]
  1493 0000131F A3[180B]                    mov [check_VBE_mode_best_screen_width], ax
  1494                                  
  1495                                      ;print best
  1496 00001322 31C0                        xor ax, ax
  1497 00001324 8ED8                        mov ds, ax
  1498 00001326 BE[0C0B]                    mov si, check_VBE_mode_msg1
  1499 00001329 E86EED                      call _printstr
  1500                                  check_VBE_mode_exit:
  1501 0000132C F8                          clc
  1502 0000132D C3                          ret
  1503                                  
  1504                                  check_VBE_mode_exit_notValid:
  1505 0000132E F9                          stc
  1506 0000132F C3                          ret
  1507                                  
  1508                                  
  1509                                  ;----------------------------------------------------------------------------------------------------------------------------
  1510                                  ;----------------------------------------------------------------------------------------------------------------------------
  1511                                  ;----------------------------------------------------------------------------------------------------------------------------
  1512                                  ;----------------------------------------------------------------------------------------------------------------------------
  1513                                  ;----------------------------------------------------------------------------------------------------------------------------
  1514                                  ;----------------------------------------------------------------------------------------------------------------------------
  1515                                  ;----------------------------------------------------------------------------------------------------------------------------
  1516                                  ;----------------------------------------------------------------------------------------------------------------------------
  1517                                  ;----------------------------------------------------------------------------------------------------------------------------
  1518                                  ;----------------------------------------------------------------------------------------------------------------------------
  1519                                  ;----------------------------------------------------------------------------------------------------------------------------
  1520                                  ;----------------------------------------------------------------------------------------------------------------------------
  1521                                  ;----------------------------------------------------------------------------------------------------------------------------
  1522                                  ;----------------------------------------------------------------------------------------------------------------------------
  1523                                  ;----------------------------------------------------------------------------------------------------------------------------
  1524                                  ;----------------------------------------------------------------------------------------------------------------------------
  1525                                  ;----------------------------------------------------------------------------------------------------------------------------
  1526                                  
  1527                                  
  1528                                  boot_pmode:
  1529 00001330 31C0                        xor ax, ax
  1530 00001332 8ED8                        mov ds, ax
  1531 00001334 BE[8A05]                    mov si, boot_pmode_msg
  1532 00001337 E860ED                      call _printstr
  1533                                  
  1534 0000133A E888FD                      call _kernel_load
  1535                                  
  1536 0000133D 31C0                        xor ax, ax
  1537 0000133F 8ED8                        mov ds, ax
  1538 00001341 BE[A005]                    mov si, kernel_loaded_msg
  1539 00001344 E853ED                      call _printstr
  1540                                  
  1541 00001347 B90010                      mov cx, 0x1000
  1542 0000134A E879ED                      call _wait
  1543                                  
  1544 0000134D B93200                      mov cx, 50
  1545                                  clear_loop:
  1546 00001350 B80D0E                      mov ax, 0x0E0D
  1547 00001353 CD10                        int 0x10
  1548 00001355 B80A0E                      mov ax, 0x0E0A
  1549 00001358 CD10                        int 0x10
  1550 0000135A E2F4                        loop clear_loop
  1551                                      
  1552                                      ;set new graphics mode
  1553                                  
  1554                                      ;Mode 3h
  1555                                      ;VGA 80x25 text mode
  1556 0000135C B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1557 0000135F CD10                        int 0x10 ;bios call video services
  1558                                  
  1559                                      ;Mode 12h
  1560                                      ;VGA 640x480 16 color
  1561                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1562                                      ;int 0x10 ;bios call video services
  1563                                  
  1564                                      ;VBE graphics
  1565 00001361 E8F1FD                      call VBEStuff
  1566 00001364 E893FE                      call VBEStuff_setMode
  1567                                  
  1568 00001367 FA                          cli
  1569 00001368 0F0116[350B]                lgdt [GDT_descriptor] ;load GDT
  1570                                      
  1571                                      ;change last bit of cr0 to 1
  1572 0000136D 0F20C0                      mov eax, cr0
  1573 00001370 6683C801                    or eax, 1
  1574 00001374 0F22C0                      mov cr0, eax
  1575                                      
  1576                                      ;PROTECTED MODE!
  1577                                      ;far jump to code segment
  1578 00001377 EA[7C13]0800                jmp CODE_SEG:pmode
  1579                                  
  1580                                  BITS 32
  1581                                  pmode:
  1582 0000137C 66B81000                    mov ax, DATA_SEG ;setup segments
  1583 00001380 8ED8                        mov ds, ax
  1584 00001382 8ED0                        mov ss, ax
  1585 00001384 8EC0                        mov es, ax
  1586 00001386 8EE0                        mov fs, ax
  1587 00001388 8EE8                        mov gs, ax
  1588 0000138A BD00000800                  mov ebp, 0x80000 ;stack
  1589 0000138F 89EC                        mov esp, ebp
  1590                                  
  1591                                      ;jump to loaded kernel
  1592 00001391 E9(00000100)                jmp 0x10000
  1593 00001396 EBFE                        jmp $
  1594                                  
  1595                                  
  1596                                  
  1597                                  
  1598 00001398 00<rep 6468h>           times 30720-($-$$) db 0 ;total length of binary 60 sector
