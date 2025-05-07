     1                                  BITS 16
     2                                  ORG 0x7C00
     3                                  
     4                                  
     5                                  start_boot:
     6                                  
     7                                      ;set positive direction DF=0
     8 00000000 FC                          cld
     9                                  
    10                                      ;disable interrupts
    11 00000001 FA                          cli
    12                                  
    13                                  ;make sure running on 0:7C00, not 7C0:0
    14 00000002 EA[0700]0000                jmp 0x0000:start_nuckboot
    15                                      
    16                                  start_nuckboot:
    17                                      ;zero out the segment registers
    18 00000007 31C0                        xor ax, ax
    19 00000009 8ED8                        mov ds, ax
    20 0000000B 8EC0                        mov es, ax
    21 0000000D 8EE0                        mov fs, ax
    22                                  
    23                                      ;save the disk number
    24 0000000F 8816[E700]                  mov [diskNum], dl
    25                                  
    26                                      ;initialize stack
    27 00000013 8ED0                        mov ss, ax
    28 00000015 BCFF7B                      mov sp, 0x7BFF ;stack grows below bootloader
    29                                  
    30                                      ;set video mode to text mode(80x25)
    31 00000018 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    32 0000001B CD10                        int 0x10 ;bios call video services
    33                                  
    34                                      ;enable interrupts
    35 0000001D FB                          sti
    36                                  
    37 0000001E 31C0                        xor ax, ax       ;print bootloader start msg
    38 00000020 8ED8                        mov ds, ax
    39 00000022 BE[FC00]                    mov si, startup_msg
    40 00000025 E87600                      call _printstr
    41                                  
    42 00000028 E80300                      call _disk_read ;read bootloader code to ram
    43                                  
    44 0000002B E9E80B                      jmp main
    45                                  
    46                                  _disk_read:
    47 0000002E 31FF                        xor di, di ;counter for retry
    48                                  _disk_read_loop:
    49                                  
    50 00000030 31C0                        xor ax, ax
    51 00000032 8ED8                        mov ds, ax
    52 00000034 BE[D400]                    mov si, disk_read_msg ;Reading from disk: diskNum
    53 00000037 E86400                      call _printstr
    54                                  
    55                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    56                                      ;Read 59 sectors starting from 0:0:2 in drive dl, store in 0x7E00
    57 0000003A B83B02                      mov ax, 0x023B ;ah=scancode, Read sectors | al=number of sectors to read
    58 0000003D B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    59 00000040 30F6                        xor dh, dh ;head number CHS
    60 00000042 8A16[E700]                  mov dl, [diskNum] ;drive number
    61                                      ;Address to store values in: es:bx which is 0:7E00
    62 00000046 31DB                        xor bx, bx
    63 00000048 8EC3                        mov es, bx
    64 0000004A BB007E                      mov bx, 0x7E00
    65 0000004D CD13                        int 0x13 ;disk read
    66 0000004F 720B                        jc __disk_read_fail
    67                                  
    68                                      ;disk read success
    69 00000051 31C0                        xor ax, ax
    70 00000053 8ED8                        mov ds, ax
    71 00000055 BE[6301]                    mov si, disk_read_success
    72 00000058 E84300                      call _printstr
    73 0000005B C3                          ret
    74                                  
    75                                  __disk_read_fail:
    76                                      ;if number of attempts is over or equal 8
    77 0000005C 83FF08                      cmp di, 8
    78 0000005F 7D2D                        jge __disk_read_fail_final
    79                                  
    80 00000061 31C0                        xor ax, ax
    81 00000063 8ED8                        mov ds, ax
    82 00000065 BE[1001]                    mov si, disk_read_fail
    83 00000068 E83300                      call _printstr
    84                                  
    85                                      ;attempt to reset disk
    86 0000006B 31C0                        xor ax, ax ;scancode ah = 0
    87 0000006D 8A16[E700]                  mov dl, [diskNum]
    88 00000071 CD13                        int 0x13 ;reset disk system
    89                                  
    90 00000073 47                          inc di
    91                                      ;update number of attempts
    92 00000074 89F8                        mov ax, di
    93 00000076 83C030                      add ax, '0'
    94 00000079 A2[F300]                    mov [attempt_num], al
    95                                  
    96 0000007C 31C0                        xor ax, ax
    97 0000007E 8ED8                        mov ds, ax
    98 00000080 BE[EB00]                    mov si, attempts_msg
    99 00000083 E81800                      call _printstr
   100                                  
   101 00000086 B90020                      mov cx, 0x2000
   102 00000089 E83E00                      call _wait
   103                                  
   104 0000008C EBA2                        jmp _disk_read_loop
   105                                  
   106                                  __disk_read_fail_final:
   107 0000008E 31C0                        xor ax, ax
   108 00000090 8ED8                        mov ds, ax
   109 00000092 BE[3201]                    mov si, disk_read_fail_final
   110 00000095 E80600                      call _printstr
   111                                      ;blocking keyboard input
   112 00000098 31C0                        xor ax, ax
   113 0000009A CD16                        int 0x16 ;keyboard services
   114 0000009C EB11                        jmp biosboot_pc
   115                                  
   116                                  ; subroutine to print a string until null terminator
   117                                  ; address of string: ds:si
   118                                  _printstr:
   119 0000009E FC                          cld ;clear DF flag in FLAGS
   120                                  __printstr_loop:
   121 0000009F 8A04                        mov al, [si]
   122 000000A1 46                          inc si
   123                                  
   124 000000A2 08C0                        or al, al ;if al = 0
   125 000000A4 7408                        jz __printstr_exit ;exit loop
   126                                  
   127 000000A6 B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   128 000000A8 31DB                        xor bx, bx ;bh = 0
   129 000000AA CD10                        int 0x10 ;bios call video services
   130 000000AC EBF1                        jmp __printstr_loop
   131                                  __printstr_exit:
   132 000000AE C3                          ret
   133                                  
   134                                  biosboot_pc:
   135 000000AF 31C0                        xor ax, ax
   136 000000B1 8ED8                        mov ds, ax
   137 000000B3 BE[7701]                    mov si, biosboot_msg
   138 000000B6 E8E5FF                      call _printstr
   139 000000B9 CD19                        int 0x19
   140                                  
   141                                  restart_pc:
   142 000000BB 31C0                        xor ax, ax
   143 000000BD 8ED8                        mov ds, ax
   144 000000BF BE[9401]                    mov si, restart_msg
   145 000000C2 E8D9FF                      call _printstr
   146                                      ;jump to reset vector
   147 000000C5 EA0000FFFF                  jmp 0xFFFF:0x0000
   148                                  
   149                                  ; subroutine to delay cpu ticks
   150                                  _wait:
   151 000000CA 51                          push cx
   152 000000CB B9FFFF                      mov cx, 0xFFFF
   153                                  __wait_innerloop:
   154 000000CE E2FE                        loop __wait_innerloop
   155 000000D0 59                          pop cx
   156 000000D1 E2F7                        loop _wait
   157 000000D3 C3                          ret
   158                                  
   159 000000D4 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   159 000000DD 726F6D206469736B3A-
   159 000000E6 20                 
   160 000000E7 00                          diskNum db 0 ;reserved for BIOS drive number
   161 000000E8 0D0A00                      db 0xD, 0xA, 0
   162                                  
   163 000000EB 417474656D707420            attempts_msg db 'Attempt '
   164 000000F3 00                          attempt_num db 0
   165 000000F4 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   166                                  
   167 000000FC 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   167 00000105 6F746C6F616465720D-
   167 0000010E 0A00               
   168 00000110 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   168 00000119 206661696C7572652C-
   168 00000122 20726573657474696E-
   168 0000012B 672E2E2E0D0A00     
   169 00000132 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   169 0000013B 206661696C65642C20-
   169 00000144 707265737320616E79-
   169 0000014D 206B657920746F2063-
   169 00000156 6F6E74696E75652E2E-
   169 0000015F 2E0D0A00           
   170 00000163 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   170 0000016C 20737563636573730D-
   170 00000175 0A00               
   171                                  
   172 00000177 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   172 00000180 6E746F2042494F5320-
   172 00000189 73657475702E2E2E0D-
   172 00000192 0A00               
   173 00000194 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   173 0000019D 672E2E2E0D0A00     
   174 000001A4 00<rep 1Ah>                 times 446-($-$$) db 0 ;446B bootloader code
   175                                      ;MBR partition table(64B)
   176                                      ;
   177                                      ;bootable, start 2048 end 124927 size 60MiB
   178                                      ;
   179                                      ;first entry
   180 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   181                                      ;chs addressing of first sector
   182 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   183 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   184 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   185 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   186                                      ;chs addressing of last sector
   187 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   188 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   189 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   190 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   191 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   192                                      ;other entries
   193 000001CE 00<rep 30h>                 times 3*16 db 0
   194                                  
   195                                  times 510-($-$$) db 0 ;510B excluding boot signature
   196 000001FE 55AA                    db 0x55, 0xAA
   197                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   198                                  
   199                                      ;Data    
   200 00000200 46313A2062696F7320-         msg db 'F1: bios setup/restart/boot next    '
   200 00000209 73657475702F726573-
   200 00000212 746172742F626F6F74-
   200 0000021B 206E65787420202020 
   201 00000224 46323A207265737461-         db 'F2: restart (far jump to reset vector)', 0xD, 0xA
   201 0000022D 72742028666172206A-
   201 00000236 756D7020746F207265-
   201 0000023F 73657420766563746F-
   201 00000248 72290D0A           
   202 0000024C 46333A20636C656172-         db 'F3: clear screen                    '
   202 00000255 2073637265656E2020-
   202 0000025E 202020202020202020-
   202 00000267 202020202020202020 
   203 00000270 46343A2068616C740D-         db 'F4: halt', 0xD, 0xA
   203 00000279 0A                 
   204 0000027A 46353A2042494F5320-         db 'F5: BIOS beep                       '
   204 00000283 626565702020202020-
   204 0000028C 202020202020202020-
   204 00000295 202020202020202020 
   205 0000029E 46363A206C6F616420-         db 'F6: load kernel and enter pmode', 0xD, 0xA
   205 000002A7 6B65726E656C20616E-
   205 000002B0 6420656E7465722070-
   205 000002B9 6D6F64650D0A       
   206 000002BF 46373A2072656C6F61-         db 'F7: reload NuckBoot from dev', 0xD, 0xA
   206 000002C8 64204E75636B426F6F-
   206 000002D1 742066726F6D206465-
   206 000002DA 760D0A             
   207 000002DD 4638202D204631313A-         db 'F8 - F11: set kernel gfx test mode', 0xD, 0xA
   207 000002E6 20736574206B65726E-
   207 000002EF 656C20676678207465-
   207 000002F8 7374206D6F64650D0A 
   208 00000301 202020205669727475-         db '    Virtual piano:', 0xD, 0xA
   208 0000030A 616C207069616E6F3A-
   208 00000313 0D0A               
   209 00000315 507265737320272066-         db 'Press ', 0x27, ' for lower octave, Press ', 0x22, ' for higher octave, Press ', 0x3B, ' to reset octave', 0xD, 0xA, 0
   209 0000031E 6F72206C6F77657220-
   209 00000327 6F63746176652C2050-
   209 00000330 72657373202220666F-
   209 00000339 722068696768657220-
   209 00000342 6F63746176652C2050-
   209 0000034B 72657373203B20746F-
   209 00000354 207265736574206F63-
   209 0000035D 746176650D0A00     
   210                                  
   211 00000364 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   211 0000036D 206B65726E656C2E2E-
   211 00000376 2E0D0A00           
   212 0000037A 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   212 00000383 616465642C20737769-
   212 0000038C 746368696E6720746F-
   212 00000395 2070726F7465637465-
   212 0000039E 64206D6F64652E2E2E-
   212 000003A7 0D0A00             
   213 000003AA 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   214 000003B1 0D0A                        oslogo db 0xD, 0xA
   215 000003B3 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   215 000003BC 2020202020205F2020-
   215 000003C5 205F20202020202020-
   215 000003CE 20202020205F202020-
   215 000003D7 2020205F5F5F5F2020-
   215 000003E0 202020202020202020-
   215 000003E9 2020205F2020202020-
   215 000003F2 4F532056657273696F-
   215 000003FB 6E2020200D0A       
   216 00000401 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.01      ', 0xD, 0xA
   216 0000040A 20202020207C205C20-
   216 00000413 7C207C5F2020205F20-
   216 0000041C 205F5F5F7C207C205F-
   216 00000425 5F207C205F5F202920-
   216 0000042E 205F5F5F2020205F5F-
   216 00000437 5F207C207C5F202020-
   216 00000440 202020312E30312020-
   216 00000449 202020200D0A       
   217 0000044F 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   217 00000458 20202020207C20205C-
   217 00000461 7C207C207C207C207C-
   217 0000046A 2F205F5F7C207C2F20-
   217 00000473 2F207C20205F205C20-
   217 0000047C 2F205F205C202F205F-
   217 00000485 205C7C205F5F7C2020-
   217 0000048E 202020202020202020-
   217 00000497 202020200D0A       
   218 0000049D 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   218 000004A6 20202020207C207C5C-
   218 000004AF 20207C207C5F7C207C-
   218 000004B8 20285F5F7C2020203C-
   218 000004C1 20207C207C5F29207C-
   218 000004CA 20285F29207C20285F-
   218 000004D3 29207C207C5F202020-
   218 000004DC 202020202020202020-
   218 000004E5 202020200D0A       
   219 000004EB 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   219 000004F4 20202020207C5F7C20-
   219 000004FD 5C5F7C5C5F5F2C5F7C-
   219 00000506 5C5F5F5F7C5F7C5C5F-
   219 0000050F 5C207C5F5F5F5F2F20-
   219 00000518 5C5F5F5F2F205C5F5F-
   219 00000521 5F2F205C5F5F7C2020-
   219 0000052A 202020202020202020-
   219 00000533 202020200D0A       
   220 00000539 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   220 00000542 202020202020202020-
   220 0000054B 20226F706572617469-
   220 00000554 6E672073797374656D-
   220 0000055D 206F66207468652066-
   220 00000566 757475726522202854-
   220 0000056F 4D290D0A00         
   221                                  
   222 00000574 00                          hang_virtual_piano_mode db 0b00
   223                                  
   224 00000575 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   224 0000057E 6176650D0A00       
   225 00000584 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   225 0000058D 650D0A00           
   226 00000591 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   226 0000059A 76650D0A00         
   227                                  
   228 0000059F 3D00                        keylen dw 61
   229 000005A1 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   229 000005AA 307177657274797569-
   229 000005B3 6F706173646667686A-
   229 000005BC 6B6C7A786376626E6D 
   230 000005C5 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   230 000005CE 455459494F50534447-
   230 000005D7 484A4C5A435642     
   231                                  
   232 000005DE 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   232 000005E7 006E007B00         
   233 000005EC 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   233 000005F5 00DC00F600         
   234 000005FA 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   234 00000603 01B801EE01         
   235 00000608 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   235 00000611 037003DC03         
   236 00000616 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   236 0000061F 06E006B807         
   237 00000624 2D08                        dw 2093
   238                                  
   239 00000626 45004E005C00680075-         dw 69, 78, 92, 104, 117
   239 0000062F 00                 
   240 00000630 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   240 00000639 00                 
   241 0000063A 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   241 00000643 01                 
   242 00000644 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   242 0000064D 03                 
   243 0000064E 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   243 00000657 07                 
   244                                  
   245 00000658 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   245 00000661 0037003E00         
   246 00000666 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   246 0000066F 006E007B00         
   247 00000674 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   247 0000067D 00DC00F600         
   248 00000682 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   248 0000068B 01B801EE01         
   249 00000690 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   249 00000699 037003DC03         
   250 0000069E 1704                        dw 1047
   251                                  
   252 000006A0 230027002E0034003A-         dw 35, 39, 46, 52, 58
   252 000006A9 00                 
   253 000006AA 45004E005C00680075-         dw 69, 78, 92, 104, 117
   253 000006B3 00                 
   254 000006B4 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   254 000006BD 00                 
   255 000006BE 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   255 000006C7 01                 
   256 000006C8 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   256 000006D1 03                 
   257                                  
   258 000006D2 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   258 000006DB 00DC00F600         
   259 000006E0 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   259 000006E9 01B801EE01         
   260 000006EE 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   260 000006F7 037003DC03         
   261 000006FC 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   261 00000705 06E006B807         
   262 0000070A 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   262 00000713 0CC00D6F0F         
   263 00000718 5A10                        dw 4186
   264                                  
   265 0000071A 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   265 00000723 00                 
   266 00000724 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   266 0000072D 01                 
   267 0000072E 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   267 00000737 03                 
   268 00000738 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   268 00000741 07                 
   269 00000742 A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   269 0000074B 0E                 
   270                                  
   271 0000074C 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   271 00000755 6164206661696C7572-
   271 0000075E 652C20726573657474-
   271 00000767 696E672E2E2E0D0A00 
   272 00000770 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   272 00000779 6164206661696C6564-
   272 00000782 2C20676F696E672062-
   272 0000078B 61636B20746F207265-
   272 00000794 616C206D6F64652E2E-
   272 0000079D 2E0D0A00           
   273 000007A1 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   273 000007AA 616420737563636573-
   273 000007B3 730D0A00           
   274                                  
   275 000007B7 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   275 000007C0 6F6E74726F6C6C6572-
   275 000007C9 20696E666F20737563-
   275 000007D2 63657373210D0A00   
   276 000007DA 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   276 000007E3 6F6E74726F6C6C6572-
   276 000007EC 20696E666F20666169-
   276 000007F5 6C210D0A5072657373-
   276 000007FE 20616E79206B657920-
   276 00000807 746F20636F6E74696E-
   276 00000810 75652E2E2E0D0A00   
   277                                  
   278 00000818 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   278 00000821 6F6C6C657220696E66-
   278 0000082A 6F3A0D0A00         
   279 0000082F 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   279 00000838 6F6465732070747228-
   279 00000841 7365673A6F6666293A-
   279 0000084A 2000               
   280                                  
   281 0000084C 56424520676574206D-         VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   281 00000855 6F646520696E666F20-
   281 0000085E 6661696C210D0A5072-
   281 00000867 65737320616E79206B-
   281 00000870 657920746F20636F6E-
   281 00000879 74696E75652E2E2E0D-
   281 00000882 0A00               
   282                                  
   283 00000884 206270703A00                print_VBE_mode_text_msg db " bpp:", 0
   284 0000088A 2070697463683A00            print_VBE_mode_text_msg1 db " pitch:", 0
   285 00000892 206D6D3A00                  print_VBE_mode_text_msg2 db " mm:", 0
   286                                  
   287 00000897 42657374206D6F6465-         VBEStuff_iter_modes_best_mode_msg db "Best mode: ", 0xD, 0xA, 0
   287 000008A0 3A200D0A00         
   288 000008A5 537769746368696E67-         VBEStuff_iter_modes_best_mode_msg1 db "Switching to VBE graphics mode... ", 0xD, 0xA, 0
   288 000008AE 20746F205642452067-
   288 000008B7 72617068696373206D-
   288 000008C0 6F64652E2E2E200D0A-
   288 000008C9 00                 
   289                                  
   290 000008CA [D608]                      VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
   291 000008CC [CE08]                      dw VBE_mode_info_block_fb_support_t
   292                                  
   293 000008CE 4C46423A204A4100            VBE_mode_info_block_fb_support_t db "LFB: JA", 0
   294 000008D6 4C46423A204E45494E-         VBE_mode_info_block_fb_support_f db "LFB: NEIN", 0
   294 000008DF 00                 
   295                                  
   296 000008E0 0000                        current_mode_number dw 0
   297                                  
   298 000008E2 2076616C696400              check_VBE_mode_msg db ' valid', 0
   299 000008E9 206265737400                check_VBE_mode_msg1 db ' best', 0
   300                                  
   301 000008EF 0000                        check_VBE_mode_best_mode_number dw 0
   302                                  
   303 000008F1 0000                        check_VBE_mode_best_area_high dw 0
   304 000008F3 0000                        check_VBE_mode_best_area_low dw 0
   305                                  
   306 000008F5 0000                        check_VBE_mode_best_screen_width dw 0
   307                                  
   308                                  ;code segment descriptor
   309                                  ;Base            32b: starting location of segment
   310                                  ;Limit           20b: size of limit
   311                                  ;Present          1b: Is this segment used/is a valid segment
   312                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   313                                  ;Type             1b: 1 if segment is code or data segment
   314                                  ;Flags(1b):
   315                                  ;  Type flags(4b):
   316                                  ;    1. Code? Will segment contain code
   317                                  ;    2. Conforming: can this code be executed from lower privileged segments
   318                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   319                                  ;            becomes an expand down segment
   320                                  ;    3. Readable, can this segment be read?
   321                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   322                                  ;            segment becomes read only
   323                                  ;    4. Accessed: set to 1 when CPU is using the segment
   324                                  ;  Other flags(4b):
   325                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   326                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   327                                  ;    3 & 4: 64 bit tetio, just set to 0
   328                                  
   329                                  ;offset of the segment descriptors relative to the beginning of the GDT
   330                                  CODE_SEG equ GDT_code - GDT_start
   331                                  DATA_SEG equ GDT_data - GDT_start
   332                                  
   333                                  ;kernel location is 0x10000
   334                                  KERNEL_LOCATION equ 0x1000
   335                                  
   336                                  GDT_start:
   337                                      GDT_null:
   338 000008F7 00000000                        dd 0 ;(32 bits)
   339 000008FB 00000000                        dd 0 ;(32 bits)
   340                                      GDT_code:
   341                                          ;base: 0
   342                                          ;limit: 0xFFFFF
   343                                          ;PPT: 1001
   344                                          ;Type: 1010
   345                                          ;Other: 1100
   346                                  
   347                                          ;first 16 bits of limit
   348 000008FF FFFF                            dw 0xFFFF
   349                                          ;first 24 bits of base
   350 00000901 0000                            dw 0x0000 ;16 bits
   351 00000903 00                              db 0x00   ; 8 bits
   352                                          ;PPT + Type
   353 00000904 9A                              db 0b10011010
   354                                          ;other + last 4 bits of limit
   355 00000905 CF                              db 0b11001111
   356                                          ;last 8 bits of base
   357 00000906 00                              db 0x00
   358                                      GDT_data:
   359                                          ;base: 0
   360                                          ;limit: 0xFFFFF
   361                                          ;PPT: 1001
   362                                          ;Type: 0010
   363                                          ;Other: 1100
   364                                  
   365                                          ;first 16 bits of limit
   366 00000907 FFFF                            dw 0xFFFF
   367                                          ;first 24 bits of base
   368 00000909 0000                            dw 0x0000 ;16 bits
   369 0000090B 00                              db 0x00   ; 8 bits
   370                                          ;PPT + Type
   371 0000090C 92                              db 0b10010010
   372                                          ;other + last 4 bits of limit
   373 0000090D CF                              db 0b11001111
   374                                          ;last 8 bits of base
   375 0000090E 00                              db 0b00000000
   376                                  GDT_end:
   377                                  GDT_descriptor:
   378                                      ;size of GDT(16 bits)
   379 0000090F 1700                        dw GDT_end - GDT_start - 1
   380                                      ;start of GDT(32 bits)
   381 00000911 [F7080000]                  dd GDT_start
   382                                  
   383 00000915 01                      kernel_test_mode db 1
   384                                  ; TOTAL of 512 bytes
   385                                  VBE_info_block_start:
   386 00000916 4E45494E                    VBE_info_block_signature db 'NEIN'
   387 0000091A 0000                        VBE_info_block_version dw 0
   388 0000091C 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
   389 00000920 00000000                    VBE_info_block_capabilities dd 0
   390 00000924 0000                        VBE_info_block_video_mode_offset dw 0
   391 00000926 0000                        VBE_info_block_video_mode_segment dw 0
   392 00000928 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
   393 0000092A 00<rep 1ECh>                times 492 db 0 ;reserved
   394                                  
   395                                  ; TOTAL of 256 bytes
   396                                  VBE_mode_info_block_start:
   397 00000B16 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
   398 00000B18 00                          VBE_mode_info_block_window_a db 0 ;deprecated
   399 00000B19 00                          VBE_mode_info_block_window_b db 0 ;deprecated
   400 00000B1A 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
   401 00000B1C 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
   402 00000B1E 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
   403 00000B20 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
   404 00000B22 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
   405 00000B26 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
   406                                  
   407 00000B28 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
   408 00000B2A 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
   409 00000B2C 00                          VBE_mode_info_block_char_width db 0 ;in pixels, unused
   410 00000B2D 00                          VBE_mode_info_block_char_height db 0 ;in pixels, unused
   411 00000B2E 00                          VBE_mode_info_block_planes_count db 0
   412 00000B2F 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
   413 00000B30 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
   414 00000B31 00                          VBE_mode_info_block_memory_model db 0
   415 00000B32 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
   416 00000B33 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
   417 00000B34 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
   418                                  
   419                                      ;size and pos of masks
   420 00000B35 00                          VBE_mode_info_block_red_mask db 0
   421 00000B36 00                          VBE_mode_info_block_red_pos db 0
   422 00000B37 00                          VBE_mode_info_block_green_mask db 0
   423 00000B38 00                          VBE_mode_info_block_green_pos db 0
   424 00000B39 00                          VBE_mode_info_block_blue_mask db 0
   425 00000B3A 00                          VBE_mode_info_block_blue_pos db 0
   426 00000B3B 00                          VBE_mode_info_block_reserved_mask db 0
   427 00000B3C 00                          VBE_mode_info_block_reserved_pos db 0
   428 00000B3D 00                          VBE_mode_info_block_direct_color_attributes db 0
   429                                  
   430                                      ;added in revision 2.0
   431 00000B3E 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
   432 00000B42 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
   433 00000B46 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
   434 00000B48 00<rep CEh>                 VBE_mode_info_block_reserved times 206 db 0 ;available in revision 3.0, useless
   435                                  
   436                                  
   437                                  main:
   438 00000C16 31C0                        xor ax, ax
   439 00000C18 8ED8                        mov ds, ax
   440 00000C1A BE[B103]                    mov si, oslogo
   441 00000C1D E87EF4                      call _printstr
   442                                  
   443                                      ;print a helpful message
   444 00000C20 BE[0002]                    mov si, msg
   445 00000C23 E878F4                      call _printstr
   446                                  
   447                                  hang:
   448 00000C26 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   449 00000C28 CD16                        int 0x16 ;keyboard services
   450                                      ;return: AL = character, AH = scan code
   451 00000C2A 74FA                        jz hang ;if key not pressed jump back
   452                                      ;if there is a key use int 0x16,0 to get the results
   453 00000C2C 31C0                        xor ax, ax
   454 00000C2E CD16                        int 0x16 ;ah = scancode, al = char
   455                                  
   456                                      ;print char
   457 00000C30 50                          push ax
   458 00000C31 B40E                        mov ah, 0x0E
   459 00000C33 CD10                        int 0x10
   460 00000C35 58                          pop ax
   461                                  
   462 00000C36 80FC3B                      cmp ah, 0x3B
   463 00000C39 0F8472F4                    je biosboot_pc
   464 00000C3D 80FC3C                      cmp ah, 0x3C
   465 00000C40 0F8477F4                    je restart_pc
   466 00000C44 80FC3D                      cmp ah, 0x3D
   467 00000C47 0F842001                    je cls
   468 00000C4B 80FC3E                      cmp ah, 0x3E
   469 00000C4E 0F843E01                    je halt
   470 00000C52 80FC3F                      cmp ah, 0x3F
   471 00000C55 0F842401                    je biosbeep
   472 00000C59 80FC40                      cmp ah, 0x40
   473 00000C5C 0F84AF04                    je boot_pmode
   474 00000C60 80FC41                      cmp ah, 0x41
   475 00000C63 7433                        je retest
   476                                  
   477                                      ;sets mode for the kernel to have different behaviors
   478 00000C65 80FC42                      cmp ah, 0x42
   479 00000C68 7416                        je kernel_test_1
   480 00000C6A 80FC43                      cmp ah, 0x43
   481 00000C6D 7416                        je kernel_test_2
   482 00000C6F 80FC44                      cmp ah, 0x44
   483 00000C72 7416                        je kernel_test_3
   484 00000C74 80FC85                      cmp ah, 0x85
   485 00000C77 7416                        je kernel_test_4
   486                                  
   487                                  
   488                                  
   489 00000C79 50                          push ax
   490 00000C7A E86000                      call hang_virtual_piano
   491 00000C7D 58                          pop ax
   492                                  
   493 00000C7E EBA6                        jmp hang
   494                                  
   495                                  kernel_test_1:
   496 00000C80 BB0100                      mov bx, 1
   497 00000C83 EB0D                        jmp kernel_test_oah
   498                                  kernel_test_2:
   499 00000C85 BB0200                      mov bx, 2
   500 00000C88 EB08                        jmp kernel_test_oah
   501                                  kernel_test_3:
   502 00000C8A BB0300                      mov bx, 3
   503 00000C8D EB03                        jmp kernel_test_oah
   504                                  kernel_test_4:
   505 00000C8F BB0400                      mov bx, 4
   506                                  kernel_test_oah:
   507 00000C92 881E[1509]                  mov [kernel_test_mode], bl
   508 00000C96 EB8E                        jmp hang
   509                                  
   510                                  ;subroutine to retest nuck os
   511                                  retest:
   512 00000C98 8A16[E700]                  mov dl, [diskNum]
   513 00000C9C 52                          push dx
   514 00000C9D E80600                      call retest_disk_read
   515                                      ;jump to the start
   516 00000CA0 5A                          pop dx
   517 00000CA1 EA0000C007                  jmp 0x07C0:0x0000
   518                                  
   519                                  
   520                                  retest_disk_read:
   521 00000CA6 31FF                        xor di, di ;counter for retry
   522                                  retest_disk_read_loop:
   523                                  
   524                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   525                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   526 00000CA8 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   527 00000CAB B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   528 00000CAE 30F6                        xor dh, dh ;head number CHS
   529 00000CB0 8A16[E700]                  mov dl, [diskNum] ;drive number
   530                                      ;Address to store values in: es:bx which is 0:7E00
   531 00000CB4 31DB                        xor bx, bx
   532 00000CB6 8EC3                        mov es, bx
   533 00000CB8 BB007C                      mov bx, 0x7C00
   534 00000CBB CD13                        int 0x13 ;disk read
   535 00000CBD 7201                        jc retest__disk_read_fail
   536                                  
   537                                      ;disk read success
   538 00000CBF C3                          ret
   539                                  
   540                                  retest__disk_read_fail:
   541                                      ;if number of attempts is over or equal 8
   542 00000CC0 83FF08                      cmp di, 8
   543 00000CC3 7D11                        jge retest__disk_read_fail_final
   544                                  
   545                                      ;attempt to reset disk
   546 00000CC5 31C0                        xor ax, ax ;scancode ah = 0
   547 00000CC7 8A16[E700]                  mov dl, [diskNum]
   548 00000CCB CD13                        int 0x13 ;reset disk system
   549                                  
   550 00000CCD 47                          inc di
   551                                  
   552 00000CCE B90020                      mov cx, 0x2000
   553 00000CD1 E8F6F3                      call _wait
   554                                  
   555 00000CD4 EBD2                        jmp retest_disk_read_loop
   556                                  
   557                                  retest__disk_read_fail_final:
   558                                      ;blocking keyboard input
   559 00000CD6 31C0                        xor ax, ax
   560 00000CD8 CD16                        int 0x16 ;keyboard services
   561 00000CDA E9D2F3                      jmp biosboot_pc
   562                                  
   563                                  
   564                                  
   565                                  ;subroutine to play a note in virtual piano
   566                                  ;key: al
   567                                  hang_virtual_piano:
   568                                      ;change mode
   569 00000CDD 50                          push ax
   570                                  
   571 00000CDE 3C3B                        cmp al, 0x3B
   572 00000CE0 740A                        je hang_virtual_piano_mode_rst
   573 00000CE2 3C27                        cmp al, 0x27
   574 00000CE4 7415                        je hang_virtual_piano_mode_1
   575 00000CE6 3C22                        cmp al, 0x22
   576 00000CE8 7423                        je hang_virtual_piano_mode_2
   577 00000CEA EB31                        jmp hang_virtual_piano_mode_done
   578                                  hang_virtual_piano_mode_rst:
   579 00000CEC 31C0                        xor ax, ax
   580 00000CEE A2[7405]                    mov [hang_virtual_piano_mode], al
   581 00000CF1 8ED8                        mov ds, ax
   582 00000CF3 BE[7505]                    mov si, mode_rst_msg
   583 00000CF6 E8A5F3                      call _printstr
   584 00000CF9 EB22                        jmp hang_virtual_piano_mode_done
   585                                  hang_virtual_piano_mode_1:
   586 00000CFB B80100                      mov ax, 0x0001
   587 00000CFE A2[7405]                    mov [hang_virtual_piano_mode], al
   588 00000D01 31C0                        xor ax, ax
   589 00000D03 8ED8                        mov ds, ax
   590 00000D05 BE[8405]                    mov si, mode_1_msg
   591 00000D08 E893F3                      call _printstr    
   592 00000D0B EB10                        jmp hang_virtual_piano_mode_done
   593                                  hang_virtual_piano_mode_2:
   594 00000D0D B80200                      mov ax, 0x0002
   595 00000D10 A2[7405]                    mov [hang_virtual_piano_mode], al
   596 00000D13 31C0                        xor ax, ax
   597 00000D15 8ED8                        mov ds, ax
   598 00000D17 BE[9105]                    mov si, mode_2_msg
   599 00000D1A E881F3                      call _printstr
   600                                  hang_virtual_piano_mode_done:
   601                                      ;load difference in di
   602 00000D1D 31C0                        xor ax, ax
   603 00000D1F A0[7405]                    mov al, [hang_virtual_piano_mode]
   604 00000D22 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   605 00000D25 31D2                        xor dx, dx
   606 00000D27 F7E3                        mul bx
   607 00000D29 89C7                        mov di, ax
   608 00000D2B 58                          pop ax
   609                                  
   610 00000D2C 31C9                        xor cx, cx             ;i = 0
   611 00000D2E 8B16[9F05]                  mov dx, [keylen]       ;k = 10
   612                                  hang_virtual_piano_loop:
   613 00000D32 39D1                        cmp cx, dx
   614 00000D34 0F8DEEFE                    jge hang               ;return if i >= k
   615 00000D38 89CE                        mov si, cx             ;si = i
   616 00000D3A 8A9C[A105]                  mov bl, [keys + si]    ;bl = keys[i]
   617 00000D3E 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   618 00000D40 7403                        je hang_virtual_piano_play
   619                                  
   620 00000D42 41                          inc cx                 ;i++
   621 00000D43 EBED                        jmp hang_virtual_piano_loop
   622                                  
   623                                  hang_virtual_piano_play:
   624 00000D45 89C8                        mov ax, cx
   625 00000D47 B90200                      mov cx, 2
   626 00000D4A F7E1                        mul cx
   627 00000D4C 89C6                        mov si, ax
   628 00000D4E B8[DE05]                    mov ax, notes
   629 00000D51 01F8                        add ax, di
   630 00000D53 01F0                        add ax, si
   631 00000D55 89C3                        mov bx, ax
   632 00000D57 8B07                        mov ax, [bx]
   633                                      
   634 00000D59 E87900                      call _tone
   635 00000D5C B9FFFF                      mov cx, 0xFFFF
   636 00000D5F BA0500                      mov dx, 0x5
   637 00000D62 E84300                      call _wait_PIT
   638 00000D65 E89B00                      call speaker_off
   639 00000D68 E9BBFE                      jmp hang
   640                                  
   641                                  cls:
   642 00000D6B B93200                      mov cx, 50
   643                                  cls_loop:
   644 00000D6E B80D0E                      mov ax, 0x0E0D
   645 00000D71 CD10                        int 0x10
   646 00000D73 B80A0E                      mov ax, 0x0E0A
   647 00000D76 CD10                        int 0x10
   648 00000D78 E2F4                        loop cls_loop
   649 00000D7A E9A9FE                      jmp hang
   650                                  
   651                                  ;bios beep tone
   652                                  biosbeep:
   653 00000D7D 31C0                        xor ax, ax
   654 00000D7F 8ED8                        mov ds, ax
   655 00000D81 BE[AA03]                    mov si, beep_msg
   656 00000D84 E817F3                      call _printstr
   657 00000D87 B90001                      mov cx, 0x100
   658 00000D8A E83DF3                      call _wait
   659 00000D8D E996FE                      jmp hang
   660                                  
   661                                  halt:
   662 00000D90 B93200                      mov cx, 50
   663                                  halt_cls_loop:
   664 00000D93 B80D0E                      mov ax, 0x0E0D
   665 00000D96 CD10                        int 0x10
   666 00000D98 B80A0E                      mov ax, 0x0E0A
   667 00000D9B CD10                        int 0x10
   668 00000D9D E2F4                        loop halt_cls_loop
   669                                      ;disable cursor
   670 00000D9F B401                        mov ah, 0x01
   671 00000DA1 B90020                      mov cx, 0x2000 ;disable cursor
   672 00000DA4 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   673                                  
   674 00000DA6 FA                          cli
   675 00000DA7 F4                          hlt
   676                                  
   677                                  ;dx*cx is amount of ticks to wait
   678                                  _wait_PIT:
   679 00000DA8 51                          push cx
   680 00000DA9 E80500                      call _wait_PIT_once
   681 00000DAC 59                          pop cx
   682 00000DAD 4A                          dec dx
   683 00000DAE 75F8                        jnz _wait_PIT
   684 00000DB0 C3                          ret
   685                                  
   686                                  ;cx, starting
   687                                  ;cx is amount of ticks to wait
   688                                  _wait_PIT_once:
   689 00000DB1 51                          push cx
   690 00000DB2 E81100                      call _read_PIT_ticks
   691 00000DB5 53                          push bx ;bx = starting count
   692                                  _wait_PIT_once_loop:
   693 00000DB6 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   694                                      ;compute time difference = current count - start count
   695 00000DB9 58                          pop ax      ;current count is bx, starting count is ax
   696 00000DBA 29C3                        sub bx, ax  ;bx = time diff
   697 00000DBC 59                          pop cx
   698 00000DBD 51                          push cx
   699 00000DBE 50                          push ax
   700 00000DBF 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   701 00000DC1 7CF3                        jl _wait_PIT_once_loop
   702 00000DC3 58                          pop ax
   703 00000DC4 58                          pop ax
   704 00000DC5 C3                          ret
   705                                  
   706                                  ;returns PIT ticks stored in bx
   707                                  _read_PIT_ticks:
   708 00000DC6 FA                          cli
   709 00000DC7 31C0                        xor ax, ax
   710 00000DC9 E643                        out 0x43, al
   711 00000DCB E440                        in al, 0x40 ;LSB
   712 00000DCD 88C3                        mov bl, al
   713 00000DCF E440                        in al, 0x40 ;MSB
   714 00000DD1 88C7                        mov bh, al
   715 00000DD3 FB                          sti
   716 00000DD4 C3                          ret
   717                                  
   718                                  ;PIT notes
   719                                  ;I/O port     Usage
   720                                  ;0x40         Channel 0 data port (read/write)
   721                                  ;0x41         Channel 1 data port (read/write)
   722                                  ;0x42         Channel 2 data port (read/write)
   723                                  ;0x43         Mode/Command register (write only, a read is ignored)
   724                                  ;
   725                                  ;Bits:  7 6 5 4 3 2 1 0
   726                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   727                                  ;       | | | | +--+-- Mode (0–5)
   728                                  ;       | | +-----+-- Access Mode: 
   729                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   730                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   731                                  ;subroutine to play a tone
   732                                  ;ax: frequency
   733                                  _tone:
   734 00000DD5 50                          push ax
   735                                      ;calculate divisor from frequency
   736                                      ;divisor = 1193182 / freq
   737                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   738 00000DD6 BA1200                      mov dx, 0x12
   739 00000DD9 B8DE34                      mov ax, 0x34DE
   740                                      ;load denominator into bx(frequency)
   741 00000DDC 5B                          pop bx
   742                                      ;divide
   743 00000DDD F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   744 00000DDF 50                          push ax ;save on stack
   745                                  
   746 00000DE0 E82000                      call speaker_off
   747                                      ;write to PIT control register
   748 00000DE3 B0B6                        mov al, 0b10110110
   749 00000DE5 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   750                                      ;write divisor to channel 2 data port
   751 00000DE7 58                          pop ax         ; Divisor
   752 00000DE8 89C3                        mov bx, ax
   753 00000DEA 88D8                        mov al, bl
   754 00000DEC E642                        out 0x42, al         ; LSB first
   755 00000DEE 88F8                        mov al, bh
   756 00000DF0 E642                        out 0x42, al         ; Then MSB
   757                                      
   758 00000DF2 E80500                      call speaker_on
   759 00000DF5 31C0                        xor ax, ax
   760 00000DF7 8ED8                        mov ds, ax
   761 00000DF9 C3                          ret
   762                                  
   763                                  ;tell speaker to not shut up
   764                                  speaker_on:
   765 00000DFA FA                          cli
   766 00000DFB E461                        in al, 0x61
   767 00000DFD 0C03                        or al, 0b11
   768 00000DFF E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   769 00000E01 FB                          sti
   770 00000E02 C3                          ret
   771                                  ;tell speaker to shut up
   772                                  speaker_off:
   773 00000E03 FA                          cli
   774 00000E04 E461                        in al, 0x61
   775 00000E06 24FC                        and al, 0b11111100
   776 00000E08 E661                        out 0x61, al
   777 00000E0A FB                          sti
   778 00000E0B C3                          ret
   779                                  
   780                                  
   781                                  print_ax:
   782 00000E0C 60                          pusha
   783                                  
   784 00000E0D 50                          push ax
   785 00000E0E B40E                        mov ah, 0xE
   786 00000E10 B030                        mov al, '0'
   787 00000E12 CD10                        int 0x10
   788 00000E14 B40E                        mov ah, 0xE
   789 00000E16 B062                        mov al, 'b'
   790 00000E18 CD10                        int 0x10
   791 00000E1A 58                          pop ax
   792                                  
   793 00000E1B 89C3                        mov bx, ax
   794 00000E1D B91000                      mov cx, 16
   795                                  print_ax_loop:
   796 00000E20 89D8                        mov ax, bx
   797 00000E22 83E001                      and ax, 1
   798 00000E25 83C030                      add ax, '0'
   799 00000E28 B40E                        mov ah, 0xE
   800 00000E2A 50                          push ax
   801 00000E2B D1EB                        shr bx, 1
   802 00000E2D E2F1                        loop print_ax_loop
   803 00000E2F B91000                      mov cx, 16
   804                                  print_ax_loop2:
   805 00000E32 58                          pop ax
   806 00000E33 CD10                        int 0x10
   807 00000E35 E2FB                        loop print_ax_loop2
   808 00000E37 61                          popa
   809 00000E38 C3                          ret
   810                                  
   811                                  print_al:
   812 00000E39 60                          pusha
   813                                  
   814 00000E3A 50                          push ax
   815 00000E3B B40E                        mov ah, 0xE
   816 00000E3D B030                        mov al, '0'
   817 00000E3F CD10                        int 0x10
   818 00000E41 B40E                        mov ah, 0xE
   819 00000E43 B062                        mov al, 'b'
   820 00000E45 CD10                        int 0x10
   821 00000E47 58                          pop ax
   822                                  
   823 00000E48 30FF                        xor bh, bh
   824 00000E4A 88C3                        mov bl, al
   825 00000E4C B90800                      mov cx, 8
   826                                  print_al_loop:
   827 00000E4F 88D8                        mov al, bl
   828 00000E51 2401                        and al, 1
   829 00000E53 0430                        add al, '0'
   830 00000E55 B40E                        mov ah, 0xE
   831 00000E57 50                          push ax
   832 00000E58 D0EB                        shr bl, 1
   833 00000E5A E2F3                        loop print_al_loop
   834 00000E5C B90800                      mov cx, 8
   835                                  print_al_loop2:
   836 00000E5F 58                          pop ax
   837 00000E60 CD10                        int 0x10
   838 00000E62 E2FB                        loop print_al_loop2
   839 00000E64 61                          popa
   840 00000E65 C3                          ret
   841                                  
   842                                  
   843                                  ;print value of ax in decimal
   844                                  print_ax_decimal:
   845 00000E66 60                          pusha
   846                                      ;push 0 for print function to end
   847 00000E67 31DB                        xor bx, bx
   848 00000E69 53                          push bx
   849                                      ;if ax is already zero, just print a 0
   850 00000E6A 09C0                        or ax, ax
   851 00000E6C 741C                        jz print_ax_decimal_zero
   852                                  print_ax_decimal_loop:
   853 00000E6E 09C0                        or ax, ax
   854 00000E70 740D                        jz print_ax_decimal_printloop
   855 00000E72 31D2                        xor dx, dx
   856 00000E74 BB0A00                      mov bx, 10
   857                                      ;16 bit division, dx:ax / bx = ax, remainder dx
   858 00000E77 F7F3                        div bx
   859                                      ;push remainder in ascii
   860 00000E79 83C230                      add dx, '0'
   861 00000E7C 52                          push dx
   862                                      ;loop
   863 00000E7D EBEF                        jmp print_ax_decimal_loop
   864                                  print_ax_decimal_printloop:
   865                                      ;print digits pushed on the stack
   866 00000E7F 58                          pop ax
   867                                      ;if popped value is 0, exit
   868 00000E80 09C0                        or ax, ax
   869 00000E82 740D                        jz print_ax_decimal_end
   870                                      ;print value
   871 00000E84 B40E                        mov ah, 0xE
   872 00000E86 CD10                        int 0x10
   873 00000E88 EBF5                        jmp print_ax_decimal_printloop
   874                                  print_ax_decimal_zero:
   875 00000E8A 5B                          pop bx
   876 00000E8B B40E                        mov ah, 0xE
   877 00000E8D B030                        mov al, '0'
   878 00000E8F CD10                        int 0x10
   879                                  print_ax_decimal_end:
   880 00000E91 61                          popa
   881 00000E92 C3                          ret
   882                                  
   883                                  
   884                                  _kernel_load:
   885 00000E93 31FF                        xor di, di ;counter for retry
   886                                  _kernel_load_loop:
   887                                  
   888 00000E95 31C0                        xor ax, ax
   889 00000E97 8ED8                        mov ds, ax
   890 00000E99 BE[D400]                    mov si, disk_read_msg ;Reading from disk: diskNum
   891 00000E9C E8FFF1                      call _printstr
   892                                  
   893                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   894 00000E9F B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
   895 00000EA2 B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
   896 00000EA5 30F6                        xor dh, dh ;head number CHS
   897 00000EA7 8A16[E700]                  mov dl, [diskNum] ;drive number
   898                                      ;Address to store values in: es:bx
   899 00000EAB BB0010                      mov bx, 0x1000
   900 00000EAE 8EC3                        mov es, bx
   901 00000EB0 31DB                        xor bx, bx
   902                                  
   903 00000EB2 CD13                        int 0x13 ;disk read
   904 00000EB4 720B                        jc __kernel_load_fail
   905                                  
   906                                      ;disk read success
   907 00000EB6 31C0                        xor ax, ax
   908 00000EB8 8ED8                        mov ds, ax
   909 00000EBA BE[A107]                    mov si, kernel_load_success
   910 00000EBD E8DEF1                      call _printstr
   911                                      
   912 00000EC0 C3                          ret
   913                                  
   914                                  __kernel_load_fail:
   915                                      ;if number of attempts is over or equal 8
   916 00000EC1 83FF08                      cmp di, 8
   917 00000EC4 7D2D                        jge __kernel_load_fail_final
   918                                  
   919 00000EC6 31C0                        xor ax, ax
   920 00000EC8 8ED8                        mov ds, ax
   921 00000ECA BE[4C07]                    mov si, kernel_load_fail
   922 00000ECD E8CEF1                      call _printstr
   923                                  
   924                                      ;attempt to reset disk
   925 00000ED0 31C0                        xor ax, ax ;scancode ah = 0
   926 00000ED2 8A16[E700]                  mov dl, [diskNum]
   927 00000ED6 CD13                        int 0x13 ;reset disk system
   928                                  
   929 00000ED8 47                          inc di
   930                                      ;update number of attempts
   931 00000ED9 89F8                        mov ax, di
   932 00000EDB 83C030                      add ax, '0'
   933 00000EDE A2[F300]                    mov [attempt_num], al
   934                                  
   935 00000EE1 31C0                        xor ax, ax
   936 00000EE3 8ED8                        mov ds, ax
   937 00000EE5 BE[EB00]                    mov si, attempts_msg
   938 00000EE8 E8B3F1                      call _printstr
   939                                  
   940 00000EEB B90020                      mov cx, 0x2000
   941 00000EEE E8D9F1                      call _wait
   942                                  
   943 00000EF1 EBA2                        jmp _kernel_load_loop
   944                                  
   945                                  __kernel_load_fail_final:
   946 00000EF3 31C0                        xor ax, ax
   947 00000EF5 8ED8                        mov ds, ax
   948 00000EF7 BE[7007]                    mov si, kernel_load_fail_final
   949 00000EFA E8A1F1                      call _printstr
   950 00000EFD 58                          pop ax
   951 00000EFE E925FD                      jmp hang  ;go back to 16 bit hang loop if fail
   952                                  
   953                                  
   954                                  ;FAILSTATES
   955                                  VBEStuff_get_controller_info_fail:
   956 00000F01 31C0                        xor ax, ax
   957 00000F03 8ED8                        mov ds, ax
   958 00000F05 BE[DA07]                    mov si, VBEStuff_get_controller_info_fail_msg
   959 00000F08 E893F1                      call _printstr
   960                                      ;blocking keyboard input
   961 00000F0B 31C0                        xor ax, ax
   962 00000F0D CD16                        int 0x16 ;keyboard services
   963 00000F0F E99DF1                      jmp biosboot_pc
   964                                  VBEStuff_get_mode_info_fail:
   965 00000F12 31C0                        xor ax, ax
   966 00000F14 8ED8                        mov ds, ax
   967 00000F16 BE[4C08]                    mov si, VBEStuff_get_mode_info_fail_msg
   968 00000F19 E882F1                      call _printstr
   969                                      ;blocking keyboard input
   970 00000F1C 31C0                        xor ax, ax
   971 00000F1E CD16                        int 0x16 ;keyboard services
   972 00000F20 E98CF1                      jmp biosboot_pc
   973                                  
   974                                  VBEStuff:
   975                                      ;get controller info
   976 00000F23 31C0                        xor ax, ax ;es:di
   977 00000F25 8EC0                        mov es, ax
   978 00000F27 BF[1609]                    mov di, VBE_info_block_start    
   979 00000F2A B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
   980 00000F2D CD10                        int 0x10
   981 00000F2F 83F84F                      cmp ax, 0x004F
   982 00000F32 75CD                        jne VBEStuff_get_controller_info_fail
   983                                  
   984 00000F34 31C0                        xor ax, ax
   985 00000F36 8ED8                        mov ds, ax
   986 00000F38 BE[B707]                    mov si, VBEStuff_get_controller_info_success_msg
   987 00000F3B E860F1                      call _printstr
   988                                  
   989                                      ;print controller info
   990 00000F3E 31C0                        xor ax, ax
   991 00000F40 8ED8                        mov ds, ax
   992 00000F42 BE[1808]                    mov si, VBEStuff_get_controller_info_print_msg
   993 00000F45 E856F1                      call _printstr
   994                                  
   995 00000F48 A0[1609]                    mov al, [VBE_info_block_signature]
   996 00000F4B B40E                        mov ah, 0xE
   997 00000F4D CD10                        int 0x10
   998 00000F4F A1[1709]                    mov ax, [VBE_info_block_signature+1]
   999 00000F52 B40E                        mov ah, 0xE
  1000 00000F54 CD10                        int 0x10
  1001 00000F56 A1[1809]                    mov ax, [VBE_info_block_signature+2]
  1002 00000F59 B40E                        mov ah, 0xE
  1003 00000F5B CD10                        int 0x10
  1004 00000F5D A1[1909]                    mov ax, [VBE_info_block_signature+3]
  1005 00000F60 B40E                        mov ah, 0xE
  1006 00000F62 CD10                        int 0x10
  1007 00000F64 B8200E                      mov ax, 0xE20
  1008 00000F67 CD10                        int 0x10
  1009 00000F69 A1[1A09]                    mov ax, [VBE_info_block_version]
  1010 00000F6C B00E                        mov al, 0xE
  1011 00000F6E 86C4                        xchg ah, al
  1012 00000F70 0430                        add al, '0'
  1013 00000F72 CD10                        int 0x10
  1014                                  
  1015 00000F74 31C0                        xor ax, ax
  1016 00000F76 8ED8                        mov ds, ax
  1017 00000F78 BE[2F08]                    mov si, VBEStuff_get_controller_info_print_msg1
  1018 00000F7B E820F1                      call _printstr
  1019                                  
  1020 00000F7E A1[2609]                    mov ax, [VBE_info_block_video_mode_segment]
  1021 00000F81 E888FE                      call print_ax
  1022 00000F84 B40E                        mov ah, 0xE
  1023 00000F86 B03A                        mov al, ':'
  1024 00000F88 CD10                        int 0x10
  1025 00000F8A A1[2409]                    mov ax, [VBE_info_block_video_mode_offset]
  1026 00000F8D E87CFE                      call print_ax
  1027                                  
  1028 00000F90 B80D0E                      mov ax, 0x0E0D
  1029 00000F93 CD10                        int 0x10
  1030 00000F95 B80A0E                      mov ax, 0x0E0A
  1031 00000F98 CD10                        int 0x10
  1032                                  
  1033                                      ;iter mode numbers and find the good one
  1034                                      ;get start of modes array and put into fs:si
  1035 00000F9A A1[2609]                    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
  1036 00000F9D 8EE0                        mov fs, ax
  1037 00000F9F 8B36[2409]                  mov si, [VBE_info_block_video_mode_offset]
  1038                                  VBEStuff_iter_modes_loop:
  1039 00000FA3 648B04                      mov ax, fs:[si] ;ax = current mode number
  1040                                  
  1041 00000FA6 50                          push ax
  1042 00000FA7 0FA0                        push fs
  1043 00000FA9 56                          push si
  1044                                      ;now print mode in text form
  1045 00000FAA E84B00                      call print_VBE_mode_text
  1046 00000FAD 5E                          pop si
  1047 00000FAE 0FA1                        pop fs
  1048 00000FB0 58                          pop ax
  1049                                  
  1050                                  
  1051                                      ;if mode number is 0xFFFF, exit program
  1052 00000FB1 83F8FF                      cmp ax, 0xFFFF
  1053 00000FB4 740B                        je VBEStuff_iter_modes_exit
  1054                                  
  1055                                      ;increment si
  1056 00000FB6 83C602                      add si, 2
  1057                                  
  1058 00000FB9 B90001                      mov cx, 0x100
  1059 00000FBC E80BF1                      call _wait
  1060                                  
  1061 00000FBF EBE2                        jmp VBEStuff_iter_modes_loop
  1062                                  VBEStuff_iter_modes_exit:
  1063                                      ;print best mode number
  1064 00000FC1 31C0                        xor ax, ax
  1065 00000FC3 8ED8                        mov ds, ax
  1066 00000FC5 BE[9708]                    mov si, VBEStuff_iter_modes_best_mode_msg
  1067 00000FC8 E8D3F0                      call _printstr
  1068                                  
  1069 00000FCB A1[EF08]                    mov ax, [check_VBE_mode_best_mode_number]
  1070 00000FCE E82700                      call print_VBE_mode_text
  1071                                  
  1072                                  
  1073                                      ;switch to the mode
  1074 00000FD1 31C0                        xor ax, ax
  1075 00000FD3 8ED8                        mov ds, ax
  1076 00000FD5 BE[A508]                    mov si, VBEStuff_iter_modes_best_mode_msg1
  1077 00000FD8 E8C3F0                      call _printstr
  1078                                  
  1079                                      ;print which mode is actually doing
  1080 00000FDB A0[1509]                    mov al, [kernel_test_mode]
  1081 00000FDE 0430                        add al, '0'
  1082 00000FE0 B40E                        mov ah, 0xE
  1083 00000FE2 CD10                        int 0x10
  1084                                  
  1085 00000FE4 B90030                      mov cx, 0x3000
  1086 00000FE7 E8E0F0                      call _wait
  1087                                  
  1088                                  
  1089                                      ;set video mode
  1090 00000FEA 31C0                        xor ax, ax
  1091 00000FEC 8ED8                        mov ds, ax
  1092 00000FEE B8024F                      mov ax, 0x4F02
  1093 00000FF1 8B1E[EF08]                  mov bx, [check_VBE_mode_best_mode_number]
  1094 00000FF5 CD10                        int 0x10
  1095                                  
  1096 00000FF7 C3                          ret
  1097                                  
  1098                                  
  1099                                  
  1100                                  
  1101                                  print_VBE_mode_text:
  1102                                      ;save mode number here
  1103 00000FF8 A3[E008]                    mov [current_mode_number], ax
  1104                                  
  1105                                      ;if mode number is 0xFFFF, exit program
  1106 00000FFB 83F8FF                      cmp ax, 0xFFFF
  1107 00000FFE 0F849100                    je print_VBE_mode_text_end
  1108                                  
  1109                                      ;print value in ax
  1110 00001002 E807FE                      call print_ax
  1111                                  
  1112                                      ;print space
  1113 00001005 89C3                        mov bx, ax
  1114 00001007 B8200E                      mov ax, 0x0E20
  1115 0000100A CD10                        int 0x10
  1116 0000100C 89D8                        mov ax, bx
  1117                                  
  1118                                      ;now get mode info
  1119 0000100E 31C0                        xor ax, ax
  1120 00001010 8ED8                        mov ds, ax
  1121                                  
  1122 00001012 89D9                        mov cx, bx ;cx = mode number
  1123 00001014 B8014F                      mov ax, 0x4F01 ;scancode
  1124                                      ;es:di = 256b buffer
  1125 00001017 31D2                        xor dx, dx
  1126 00001019 8EC2                        mov es, dx
  1127 0000101B BF[160B]                    mov di, VBE_mode_info_block_start
  1128 0000101E CD10                        int 0x10
  1129 00001020 83F84F                      cmp ax, 0x004F
  1130 00001023 0F85EBFE                    jne VBEStuff_get_mode_info_fail
  1131                                  
  1132                                      ;now print out width and height
  1133 00001027 A1[280B]                    mov ax, [VBE_mode_info_block_width]
  1134 0000102A E839FE                      call print_ax_decimal
  1135 0000102D B40E                        mov ah, 0xE
  1136 0000102F B078                        mov al, 'x'
  1137 00001031 CD10                        int 0x10
  1138 00001033 A1[2A0B]                    mov ax, [VBE_mode_info_block_height]
  1139 00001036 E82DFE                      call print_ax_decimal
  1140 00001039 B8200E                      mov ax, 0x0E20
  1141 0000103C CD10                        int 0x10
  1142                                  
  1143                                      ;print if it supports linear framebuffer or not
  1144 0000103E 31C0                        xor ax, ax
  1145 00001040 8ED8                        mov ds, ax
  1146 00001042 8B1E[160B]                  mov bx, [VBE_mode_info_block_attributes]
  1147 00001046 81E38000                    and bx, 0b10000000 ;if bit 7 is 1 it supports
  1148 0000104A C1EB06                      shr bx, 6
  1149 0000104D 81C3[CA08]                  add bx, VBE_mode_info_block_fb_support
  1150 00001051 8B37                        mov si, [bx] ;pointer array shenanigans
  1151 00001053 E848F0                      call _printstr
  1152                                      ;print space and msg
  1153 00001056 BE[8408]                    mov si, print_VBE_mode_text_msg
  1154 00001059 E842F0                      call _printstr
  1155                                      ;print bits per pixel
  1156 0000105C 31C0                        xor ax, ax
  1157 0000105E A0[2F0B]                    mov al, [VBE_mode_info_block_bpp]
  1158 00001061 E802FE                      call print_ax_decimal
  1159                                      ;print space and msg
  1160 00001064 BE[9208]                    mov si, print_VBE_mode_text_msg2
  1161 00001067 E834F0                      call _printstr
  1162                                      ;print memory model
  1163 0000106A 31C0                        xor ax, ax
  1164 0000106C A0[310B]                    mov al, [VBE_mode_info_block_memory_model]
  1165 0000106F E8F4FD                      call print_ax_decimal
  1166                                      ;print space and msg
  1167 00001072 31C0                        xor ax, ax
  1168 00001074 8ED8                        mov ds, ax
  1169 00001076 BE[8A08]                    mov si, print_VBE_mode_text_msg1
  1170 00001079 E822F0                      call _printstr
  1171                                      ;print pitch
  1172 0000107C A1[260B]                    mov ax, [VBE_mode_info_block_pitch]
  1173 0000107F E8E4FD                      call print_ax_decimal
  1174                                  
  1175                                      ;now check if the mode is actually good & find best one
  1176 00001082 E80F00                      call check_VBE_mode
  1177                                  
  1178 00001085 B80D0E                      mov ax, 0x0E0D
  1179 00001088 CD10                        int 0x10
  1180 0000108A B80A0E                      mov ax, 0x0E0A
  1181 0000108D CD10                        int 0x10
  1182                                  
  1183 0000108F 31C0                        xor ax, ax
  1184 00001091 8ED8                        mov ds, ax
  1185                                  print_VBE_mode_text_end:
  1186 00001093 C3                          ret
  1187                                  
  1188                                  
  1189                                  
  1190                                  
  1191                                  
  1192                                  check_VBE_mode:
  1193                                      
  1194                                      ;if LFB is false, exit
  1195 00001094 A1[160B]                    mov ax, [VBE_mode_info_block_attributes]
  1196 00001097 258000                      and ax, 0b10000000 ;if bit 7 is 1 it supports
  1197 0000109A 09C0                        or ax, ax
  1198 0000109C 7470                        jz check_VBE_mode_exit
  1199                                  
  1200                                      ;if mm is not 6, exit
  1201 0000109E 31C0                        xor ax, ax
  1202 000010A0 A0[310B]                    mov al, [VBE_mode_info_block_memory_model]
  1203 000010A3 3C06                        cmp al, 6
  1204 000010A5 7567                        jne check_VBE_mode_exit
  1205                                  
  1206                                      ;if bpp is not 32, exit
  1207 000010A7 31C0                        xor ax, ax
  1208 000010A9 A0[2F0B]                    mov al, [VBE_mode_info_block_bpp]
  1209 000010AC 3C20                        cmp al, 32
  1210 000010AE 755E                        jne check_VBE_mode_exit
  1211                                  
  1212                                      ;print valid
  1213 000010B0 31C0                        xor ax, ax
  1214 000010B2 8ED8                        mov ds, ax
  1215 000010B4 BE[E208]                    mov si, check_VBE_mode_msg
  1216 000010B7 E8E4EF                      call _printstr
  1217                                  
  1218                                      ;get current mode's area
  1219 000010BA A1[280B]                    mov ax, [VBE_mode_info_block_width]
  1220 000010BD 8B1E[2A0B]                  mov bx, [VBE_mode_info_block_height]
  1221 000010C1 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1222                                      ;compare high word of current with best high word
  1223 000010C3 8B1E[F108]                  mov bx, [check_VBE_mode_best_area_high]
  1224 000010C7 39DA                        cmp dx, bx
  1225 000010C9 7C43                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1226 000010CB 7F19                        jg check_VBE_mode_update ;if current > highest, update values
  1227                                      ;if equal, check low word
  1228 000010CD 8B1E[F308]                  mov bx, [check_VBE_mode_best_area_low]
  1229 000010D1 39DA                        cmp dx, bx
  1230 000010D3 7C39                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1231 000010D5 7F0F                        jg check_VBE_mode_update ;if current > highest, update values
  1232                                  
  1233                                      ;if still equal, that means it's the exact same resolution
  1234                                      ;check if current screen width is more than best screen width
  1235 000010D7 A1[280B]                    mov ax, [VBE_mode_info_block_width]
  1236 000010DA 8B1E[F508]                  mov bx, [check_VBE_mode_best_screen_width]
  1237 000010DE 39D8                        cmp ax, bx
  1238 000010E0 7C2C                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1239 000010E2 7F02                        jg check_VBE_mode_update ;if current > highest, update values
  1240                                  
  1241 000010E4 EB28                        jmp check_VBE_mode_exit
  1242                                  check_VBE_mode_update:
  1243                                      ;restore current mode number
  1244 000010E6 8B1E[E008]                  mov bx, [current_mode_number]
  1245                                      ;update best mode number
  1246 000010EA 891E[EF08]                  mov [check_VBE_mode_best_mode_number], bx
  1247                                      ;update best area
  1248 000010EE A1[280B]                    mov ax, [VBE_mode_info_block_width]
  1249 000010F1 8B1E[2A0B]                  mov bx, [VBE_mode_info_block_height]
  1250 000010F5 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1251 000010F7 8916[F108]                  mov [check_VBE_mode_best_area_high], dx
  1252 000010FB A3[F308]                    mov [check_VBE_mode_best_area_low], ax
  1253                                      ;update best screen width
  1254 000010FE A1[280B]                    mov ax, [VBE_mode_info_block_width]
  1255 00001101 A3[F508]                    mov [check_VBE_mode_best_screen_width], ax
  1256                                  
  1257                                      ;print best
  1258 00001104 31C0                        xor ax, ax
  1259 00001106 8ED8                        mov ds, ax
  1260 00001108 BE[E908]                    mov si, check_VBE_mode_msg1
  1261 0000110B E890EF                      call _printstr
  1262                                  check_VBE_mode_exit:
  1263 0000110E C3                          ret
  1264                                  
  1265                                  
  1266                                  
  1267                                  
  1268                                  
  1269                                  
  1270                                  
  1271                                  boot_pmode:
  1272 0000110F 31C0                        xor ax, ax
  1273 00001111 8ED8                        mov ds, ax
  1274 00001113 BE[6403]                    mov si, boot_pmode_msg
  1275 00001116 E885EF                      call _printstr
  1276                                  
  1277 00001119 E877FD                      call _kernel_load
  1278                                  
  1279 0000111C 31C0                        xor ax, ax
  1280 0000111E 8ED8                        mov ds, ax
  1281 00001120 BE[7A03]                    mov si, kernel_loaded_msg
  1282 00001123 E878EF                      call _printstr
  1283                                  
  1284 00001126 B90010                      mov cx, 0x1000
  1285 00001129 E89EEF                      call _wait
  1286                                  
  1287 0000112C B93200                      mov cx, 50
  1288                                  clear_loop:
  1289 0000112F B80D0E                      mov ax, 0x0E0D
  1290 00001132 CD10                        int 0x10
  1291 00001134 B80A0E                      mov ax, 0x0E0A
  1292 00001137 CD10                        int 0x10
  1293 00001139 E2F4                        loop clear_loop
  1294                                      
  1295                                      ;set new graphics mode
  1296                                  
  1297                                      ;Mode 3h
  1298                                      ;VGA 80x25 text mode
  1299 0000113B B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1300 0000113E CD10                        int 0x10 ;bios call video services
  1301                                  
  1302                                      ;Mode 12h
  1303                                      ;VGA 640x480 16 color
  1304                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1305                                      ;int 0x10 ;bios call video services
  1306                                  
  1307                                      ;VBE graphics
  1308 00001140 E8E0FD                      call VBEStuff
  1309                                  
  1310 00001143 FA                          cli
  1311 00001144 0F0116[0F09]                lgdt [GDT_descriptor] ;load GDT
  1312                                      
  1313                                      ;change last bit of cr0 to 1
  1314 00001149 0F20C0                      mov eax, cr0
  1315 0000114C 6683C801                    or eax, 1
  1316 00001150 0F22C0                      mov cr0, eax
  1317                                      
  1318                                      ;PROTECTED MODE!
  1319                                      ;far jump to code segment
  1320 00001153 EA[5811]0800                jmp CODE_SEG:pmode
  1321                                  
  1322                                  BITS 32
  1323                                  pmode:
  1324 00001158 66B81000                    mov ax, DATA_SEG ;setup segments
  1325 0000115C 8ED8                        mov ds, ax
  1326 0000115E 8ED0                        mov ss, ax
  1327 00001160 8EC0                        mov es, ax
  1328 00001162 8EE0                        mov fs, ax
  1329 00001164 8EE8                        mov gs, ax
  1330 00001166 BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1331 0000116B 89EC                        mov esp, ebp
  1332                                  
  1333                                      ;jump to loaded kernel
  1334 0000116D E9(00000100)                jmp 0x10000
  1335 00001172 EBFE                        jmp $
  1336                                  
  1337                                  
  1338                                  
  1339                                  
  1340 00001174 00<rep 668Ch>           times 30720-($-$$) db 0 ;total length of binary 60 sector
  1341                                  
  1342                                  
