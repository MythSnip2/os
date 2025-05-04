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
    13                                      ;zero out the segment registers
    14 00000002 31C0                        xor ax, ax
    15 00000004 8ED8                        mov ds, ax
    16 00000006 8EC0                        mov es, ax
    17 00000008 8EE0                        mov fs, ax
    18                                  
    19                                      ;save the disk number
    20 0000000A 8816[E200]                  mov [diskNum], dl
    21                                  
    22                                      ;initialize stack
    23 0000000E 8ED0                        mov ss, ax
    24 00000010 BCFF7B                      mov sp, 0x7BFF ;stack grows below bootloader
    25                                  
    26                                      ;set video mode to text mode(80x25)
    27 00000013 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    28 00000016 CD10                        int 0x10 ;bios call video services
    29                                  
    30                                      ;enable interrupts
    31 00000018 FB                          sti
    32                                  
    33 00000019 31C0                        xor ax, ax       ;print bootloader start msg
    34 0000001B 8ED8                        mov ds, ax
    35 0000001D BE[F700]                    mov si, startup_msg
    36 00000020 E87600                      call _printstr
    37                                  
    38 00000023 E80300                      call _disk_read ;read bootloader code to ram
    39                                  
    40 00000026 E9D701                      jmp main
    41                                  
    42                                  _disk_read:
    43 00000029 31FF                        xor di, di ;counter for retry
    44                                  _disk_read_loop:
    45                                  
    46 0000002B 31C0                        xor ax, ax
    47 0000002D 8ED8                        mov ds, ax
    48 0000002F BE[CF00]                    mov si, disk_read_msg ;Reading from disk: diskNum
    49 00000032 E86400                      call _printstr
    50                                  
    51                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    52                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    53 00000035 B81302                      mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    54 00000038 B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    55 0000003B 30F6                        xor dh, dh ;head number CHS
    56 0000003D 8A16[E200]                  mov dl, [diskNum] ;drive number
    57                                      ;Address to store values in: es:bx which is 0:7E00
    58 00000041 31DB                        xor bx, bx
    59 00000043 8EC3                        mov es, bx
    60 00000045 BB007E                      mov bx, 0x7E00
    61 00000048 CD13                        int 0x13 ;disk read
    62 0000004A 720B                        jc __disk_read_fail
    63                                  
    64                                      ;disk read success
    65 0000004C 31C0                        xor ax, ax
    66 0000004E 8ED8                        mov ds, ax
    67 00000050 BE[5E01]                    mov si, disk_read_success
    68 00000053 E84300                      call _printstr
    69 00000056 C3                          ret
    70                                  
    71                                  __disk_read_fail:
    72                                      ;if number of attempts is over or equal 8
    73 00000057 83FF08                      cmp di, 8
    74 0000005A 7D2D                        jge __disk_read_fail_final
    75                                  
    76 0000005C 31C0                        xor ax, ax
    77 0000005E 8ED8                        mov ds, ax
    78 00000060 BE[0B01]                    mov si, disk_read_fail
    79 00000063 E83300                      call _printstr
    80                                  
    81                                      ;attempt to reset disk
    82 00000066 31C0                        xor ax, ax ;scancode ah = 0
    83 00000068 8A16[E200]                  mov dl, [diskNum]
    84 0000006C CD13                        int 0x13 ;reset disk system
    85                                  
    86 0000006E 47                          inc di
    87                                      ;update number of attempts
    88 0000006F 89F8                        mov ax, di
    89 00000071 83C030                      add ax, '0'
    90 00000074 A2[EE00]                    mov [attempt_num], al
    91                                  
    92 00000077 31C0                        xor ax, ax
    93 00000079 8ED8                        mov ds, ax
    94 0000007B BE[E600]                    mov si, attempts_msg
    95 0000007E E81800                      call _printstr
    96                                  
    97 00000081 B90020                      mov cx, 0x2000
    98 00000084 E83E00                      call _wait
    99                                  
   100 00000087 EBA2                        jmp _disk_read_loop
   101                                  
   102                                  __disk_read_fail_final:
   103 00000089 31C0                        xor ax, ax
   104 0000008B 8ED8                        mov ds, ax
   105 0000008D BE[2D01]                    mov si, disk_read_fail_final
   106 00000090 E80600                      call _printstr
   107                                      ;blocking keyboard input
   108 00000093 31C0                        xor ax, ax
   109 00000095 CD16                        int 0x16 ;keyboard services
   110 00000097 EB11                        jmp biosboot_pc
   111                                  
   112                                  ; subroutine to print a string until null terminator
   113                                  ; address of string: ds:si
   114                                  _printstr:
   115 00000099 FC                          cld ;clear DF flag in FLAGS
   116                                  __printstr_loop:
   117 0000009A 8A04                        mov al, [si]
   118 0000009C 46                          inc si
   119                                  
   120 0000009D 08C0                        or al, al ;if al = 0
   121 0000009F 7408                        jz __printstr_exit ;exit loop
   122                                  
   123 000000A1 B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   124 000000A3 31DB                        xor bx, bx ;bh = 0
   125 000000A5 CD10                        int 0x10 ;bios call video services
   126 000000A7 EBF1                        jmp __printstr_loop
   127                                  __printstr_exit:
   128 000000A9 C3                          ret
   129                                  
   130                                  biosboot_pc:
   131 000000AA 31C0                        xor ax, ax
   132 000000AC 8ED8                        mov ds, ax
   133 000000AE BE[7201]                    mov si, biosboot_msg
   134 000000B1 E8E5FF                      call _printstr
   135 000000B4 CD19                        int 0x19
   136                                  
   137                                  restart_pc:
   138 000000B6 31C0                        xor ax, ax
   139 000000B8 8ED8                        mov ds, ax
   140 000000BA BE[8F01]                    mov si, restart_msg
   141 000000BD E8D9FF                      call _printstr
   142                                      ;jump to reset vector
   143 000000C0 EA0000FFFF                  jmp 0xFFFF:0x0000
   144                                  
   145                                  ; subroutine to delay cpu ticks
   146                                  _wait:
   147 000000C5 51                          push cx
   148 000000C6 B9FFFF                      mov cx, 0xFFFF
   149                                  __wait_innerloop:
   150 000000C9 E2FE                        loop __wait_innerloop
   151 000000CB 59                          pop cx
   152 000000CC E2F7                        loop _wait
   153 000000CE C3                          ret
   154                                  
   155 000000CF 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   155 000000D8 726F6D206469736B3A-
   155 000000E1 20                 
   156 000000E2 00                          diskNum db 0 ;reserved for BIOS drive number
   157 000000E3 0D0A00                      db 0xD, 0xA, 0
   158                                  
   159 000000E6 417474656D707420            attempts_msg db 'Attempt '
   160 000000EE 00                          attempt_num db 0
   161 000000EF 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   162                                  
   163 000000F7 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   163 00000100 6F746C6F616465720D-
   163 00000109 0A00               
   164 0000010B 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   164 00000114 206661696C7572652C-
   164 0000011D 20726573657474696E-
   164 00000126 672E2E2E0D0A00     
   165 0000012D 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   165 00000136 206661696C65642C20-
   165 0000013F 707265737320616E79-
   165 00000148 206B657920746F2063-
   165 00000151 6F6E74696E75652E2E-
   165 0000015A 2E0D0A00           
   166 0000015E 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   166 00000167 20737563636573730D-
   166 00000170 0A00               
   167                                  
   168 00000172 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   168 0000017B 6E746F2042494F5320-
   168 00000184 73657475702E2E2E0D-
   168 0000018D 0A00               
   169 0000018F 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   169 00000198 672E2E2E0D0A00     
   170 0000019F 00<rep 1Fh>                 times 446-($-$$) db 0 ;446B bootloader code
   171                                      ;MBR partition table(64B)
   172                                      ;
   173                                      ;bootable, start 2048 end 124927 size 60MiB
   174                                      ;
   175                                      ;first entry
   176 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   177                                      ;chs addressing of first sector
   178 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   179 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   180 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   181 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   182                                      ;chs addressing of last sector
   183 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   184 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   185 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   186 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   187 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   188                                      ;other entries
   189 000001CE 00<rep 30h>                 times 3*16 db 0
   190                                  
   191                                  times 510-($-$$) db 0 ;510B excluding boot signature
   192 000001FE 55AA                    db 0x55, 0xAA
   193                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   194                                  
   195                                  
   196                                  main:
   197 00000200 31C0                        xor ax, ax
   198 00000202 8ED8                        mov ds, ax
   199 00000204 BE[C805]                    mov si, oslogo
   200 00000207 E88FFE                      call _printstr
   201                                  
   202                                      ;print a helpful message
   203 0000020A BE[5104]                    mov si, msg
   204 0000020D E889FE                      call _printstr
   205                                  
   206                                  hang:
   207 00000210 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   208 00000212 CD16                        int 0x16 ;keyboard services
   209                                      ;return: AL = character, AH = scan code
   210 00000214 74FA                        jz hang ;if key not pressed jump back
   211                                      ;if there is a key use int 0x16,0 to get the results
   212 00000216 31C0                        xor ax, ax
   213 00000218 CD16                        int 0x16 ;ah = scancode, al = char
   214                                  
   215                                      ;print char
   216 0000021A 50                          push ax
   217 0000021B B40E                        mov ah, 0x0E
   218 0000021D CD10                        int 0x10
   219 0000021F 58                          pop ax
   220                                  
   221 00000220 80FC3B                      cmp ah, 0x3B
   222 00000223 0F8483FE                    je biosboot_pc
   223 00000227 80FC3C                      cmp ah, 0x3C
   224 0000022A 0F8488FE                    je restart_pc
   225 0000022E 80FC3D                      cmp ah, 0x3D
   226 00000231 0F84F400                    je cls
   227 00000235 80FC3E                      cmp ah, 0x3E
   228 00000238 0F841201                    je halt
   229 0000023C 80FC3F                      cmp ah, 0x3F
   230 0000023F 0F84F800                    je biosbeep
   231 00000243 80FC40                      cmp ah, 0x40
   232 00000246 0F84750B                    je boot_pmode
   233 0000024A 80FC41                      cmp ah, 0x41
   234 0000024D 7407                        je retest
   235                                  
   236 0000024F 50                          push ax
   237 00000250 E84800                      call hang_virtual_piano
   238 00000253 58                          pop ax
   239                                  
   240 00000254 EBBA                        jmp hang
   241                                  
   242                                  ;subroutine to retest nuck os
   243                                  retest:
   244 00000256 8A16[E200]                  mov dl, [diskNum]
   245 0000025A 52                          push dx
   246 0000025B E80600                      call retest_disk_read
   247                                      ;jump to the start
   248 0000025E 5A                          pop dx
   249 0000025F EA0000C007                  jmp 0x07C0:0x0000
   250                                  
   251                                  
   252                                  retest_disk_read:
   253 00000264 31FF                        xor di, di ;counter for retry
   254                                  retest_disk_read_loop:
   255                                  
   256                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   257                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   258 00000266 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   259 00000269 B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   260 0000026C 30F6                        xor dh, dh ;head number CHS
   261 0000026E 8A16[E200]                  mov dl, [diskNum] ;drive number
   262                                      ;Address to store values in: es:bx which is 0:7E00
   263 00000272 31DB                        xor bx, bx
   264 00000274 8EC3                        mov es, bx
   265 00000276 BB007C                      mov bx, 0x7C00
   266 00000279 CD13                        int 0x13 ;disk read
   267 0000027B 7201                        jc retest__disk_read_fail
   268                                  
   269                                      ;disk read success
   270 0000027D C3                          ret
   271                                  
   272                                  retest__disk_read_fail:
   273                                      ;if number of attempts is over or equal 8
   274 0000027E 83FF08                      cmp di, 8
   275 00000281 7D11                        jge retest__disk_read_fail_final
   276                                  
   277                                      ;attempt to reset disk
   278 00000283 31C0                        xor ax, ax ;scancode ah = 0
   279 00000285 8A16[E200]                  mov dl, [diskNum]
   280 00000289 CD13                        int 0x13 ;reset disk system
   281                                  
   282 0000028B 47                          inc di
   283                                  
   284 0000028C B90020                      mov cx, 0x2000
   285 0000028F E833FE                      call _wait
   286                                  
   287 00000292 EBD2                        jmp retest_disk_read_loop
   288                                  
   289                                  retest__disk_read_fail_final:
   290                                      ;blocking keyboard input
   291 00000294 31C0                        xor ax, ax
   292 00000296 CD16                        int 0x16 ;keyboard services
   293 00000298 E90FFE                      jmp biosboot_pc
   294                                  
   295                                  
   296                                  
   297                                  ;subroutine to play a note in virtual piano
   298                                  ;key: al
   299                                  hang_virtual_piano:
   300                                      ;change mode
   301 0000029B 50                          push ax
   302                                  
   303 0000029C 3C3B                        cmp al, 0x3B
   304 0000029E 740A                        je hang_virtual_piano_mode_rst
   305 000002A0 3C27                        cmp al, 0x27
   306 000002A2 7415                        je hang_virtual_piano_mode_1
   307 000002A4 3C22                        cmp al, 0x22
   308 000002A6 7423                        je hang_virtual_piano_mode_2
   309 000002A8 EB31                        jmp hang_virtual_piano_mode_done
   310                                  hang_virtual_piano_mode_rst:
   311 000002AA 31C0                        xor ax, ax
   312 000002AC A2[8B07]                    mov [hang_virtual_piano_mode], al
   313 000002AF 8ED8                        mov ds, ax
   314 000002B1 BE[8C07]                    mov si, mode_rst_msg
   315 000002B4 E8E2FD                      call _printstr
   316 000002B7 EB22                        jmp hang_virtual_piano_mode_done
   317                                  hang_virtual_piano_mode_1:
   318 000002B9 B80100                      mov ax, 0x0001
   319 000002BC A2[8B07]                    mov [hang_virtual_piano_mode], al
   320 000002BF 31C0                        xor ax, ax
   321 000002C1 8ED8                        mov ds, ax
   322 000002C3 BE[9B07]                    mov si, mode_1_msg
   323 000002C6 E8D0FD                      call _printstr    
   324 000002C9 EB10                        jmp hang_virtual_piano_mode_done
   325                                  hang_virtual_piano_mode_2:
   326 000002CB B80200                      mov ax, 0x0002
   327 000002CE A2[8B07]                    mov [hang_virtual_piano_mode], al
   328 000002D1 31C0                        xor ax, ax
   329 000002D3 8ED8                        mov ds, ax
   330 000002D5 BE[A807]                    mov si, mode_2_msg
   331 000002D8 E8BEFD                      call _printstr
   332                                  hang_virtual_piano_mode_done:
   333                                      ;load difference in di
   334 000002DB 31C0                        xor ax, ax
   335 000002DD A0[8B07]                    mov al, [hang_virtual_piano_mode]
   336 000002E0 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   337 000002E3 31D2                        xor dx, dx
   338 000002E5 F7E3                        mul bx
   339 000002E7 89C7                        mov di, ax
   340 000002E9 58                          pop ax
   341                                  
   342 000002EA 31C9                        xor cx, cx             ;i = 0
   343 000002EC 8B16[B607]                  mov dx, [keylen]       ;k = 10
   344                                  hang_virtual_piano_loop:
   345 000002F0 39D1                        cmp cx, dx
   346 000002F2 0F8D1AFF                    jge hang               ;return if i >= k
   347 000002F6 89CE                        mov si, cx             ;si = i
   348 000002F8 8A9C[B807]                  mov bl, [keys + si]    ;bl = keys[i]
   349 000002FC 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   350 000002FE 7403                        je hang_virtual_piano_play
   351                                  
   352 00000300 41                          inc cx                 ;i++
   353 00000301 EBED                        jmp hang_virtual_piano_loop
   354                                  
   355                                  hang_virtual_piano_play:
   356 00000303 89C8                        mov ax, cx
   357 00000305 B90200                      mov cx, 2
   358 00000308 F7E1                        mul cx
   359 0000030A 89C6                        mov si, ax
   360 0000030C B8[F507]                    mov ax, notes
   361 0000030F 01F8                        add ax, di
   362 00000311 01F0                        add ax, si
   363 00000313 89C3                        mov bx, ax
   364 00000315 8B07                        mov ax, [bx]
   365                                      
   366 00000317 E87900                      call _tone
   367 0000031A B9FFFF                      mov cx, 0xFFFF
   368 0000031D BA0500                      mov dx, 0x5
   369 00000320 E84300                      call _wait_PIT
   370 00000323 E89B00                      call speaker_off
   371 00000326 E9E7FE                      jmp hang
   372                                  
   373                                  cls:
   374 00000329 B93200                      mov cx, 50
   375                                  cls_loop:
   376 0000032C B80D0E                      mov ax, 0x0E0D
   377 0000032F CD10                        int 0x10
   378 00000331 B80A0E                      mov ax, 0x0E0A
   379 00000334 CD10                        int 0x10
   380 00000336 E2F4                        loop cls_loop
   381 00000338 E9D5FE                      jmp hang
   382                                  
   383                                  ;bios beep tone
   384                                  biosbeep:
   385 0000033B 31C0                        xor ax, ax
   386 0000033D 8ED8                        mov ds, ax
   387 0000033F BE[C105]                    mov si, beep_msg
   388 00000342 E854FD                      call _printstr
   389 00000345 B90001                      mov cx, 0x100
   390 00000348 E87AFD                      call _wait
   391 0000034B E9C2FE                      jmp hang
   392                                  
   393                                  halt:
   394 0000034E B93200                      mov cx, 50
   395                                  halt_cls_loop:
   396 00000351 B80D0E                      mov ax, 0x0E0D
   397 00000354 CD10                        int 0x10
   398 00000356 B80A0E                      mov ax, 0x0E0A
   399 00000359 CD10                        int 0x10
   400 0000035B E2F4                        loop halt_cls_loop
   401                                      ;disable cursor
   402 0000035D B401                        mov ah, 0x01
   403 0000035F B90020                      mov cx, 0x2000 ;disable cursor
   404 00000362 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   405                                  
   406 00000364 FA                          cli
   407 00000365 F4                          hlt
   408                                  
   409                                  ;dx*cx is amount of ticks to wait
   410                                  _wait_PIT:
   411 00000366 51                          push cx
   412 00000367 E80500                      call _wait_PIT_once
   413 0000036A 59                          pop cx
   414 0000036B 4A                          dec dx
   415 0000036C 75F8                        jnz _wait_PIT
   416 0000036E C3                          ret
   417                                  
   418                                  ;cx, starting
   419                                  ;cx is amount of ticks to wait
   420                                  _wait_PIT_once:
   421 0000036F 51                          push cx
   422 00000370 E81100                      call _read_PIT_ticks
   423 00000373 53                          push bx ;bx = starting count
   424                                  _wait_PIT_once_loop:
   425 00000374 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   426                                      ;compute time difference = current count - start count
   427 00000377 58                          pop ax      ;current count is bx, starting count is ax
   428 00000378 29C3                        sub bx, ax  ;bx = time diff
   429 0000037A 59                          pop cx
   430 0000037B 51                          push cx
   431 0000037C 50                          push ax
   432 0000037D 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   433 0000037F 7CF3                        jl _wait_PIT_once_loop
   434 00000381 58                          pop ax
   435 00000382 58                          pop ax
   436 00000383 C3                          ret
   437                                  
   438                                  ;returns PIT ticks stored in bx
   439                                  _read_PIT_ticks:
   440 00000384 FA                          cli
   441 00000385 31C0                        xor ax, ax
   442 00000387 E643                        out 0x43, al
   443 00000389 E440                        in al, 0x40 ;LSB
   444 0000038B 88C3                        mov bl, al
   445 0000038D E440                        in al, 0x40 ;MSB
   446 0000038F 88C7                        mov bh, al
   447 00000391 FB                          sti
   448 00000392 C3                          ret
   449                                  
   450                                  ;PIT notes
   451                                  ;I/O port     Usage
   452                                  ;0x40         Channel 0 data port (read/write)
   453                                  ;0x41         Channel 1 data port (read/write)
   454                                  ;0x42         Channel 2 data port (read/write)
   455                                  ;0x43         Mode/Command register (write only, a read is ignored)
   456                                  ;
   457                                  ;Bits:  7 6 5 4 3 2 1 0
   458                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   459                                  ;       | | | | +--+-- Mode (0–5)
   460                                  ;       | | +-----+-- Access Mode: 
   461                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   462                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   463                                  ;subroutine to play a tone
   464                                  ;ax: frequency
   465                                  _tone:
   466 00000393 50                          push ax
   467                                      ;calculate divisor from frequency
   468                                      ;divisor = 1193182 / freq
   469                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   470 00000394 BA1200                      mov dx, 0x12
   471 00000397 B8DE34                      mov ax, 0x34DE
   472                                      ;load denominator into bx(frequency)
   473 0000039A 5B                          pop bx
   474                                      ;divide
   475 0000039B F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   476 0000039D 50                          push ax ;save on stack
   477                                  
   478 0000039E E82000                      call speaker_off
   479                                      ;write to PIT control register
   480 000003A1 B0B6                        mov al, 0b10110110
   481 000003A3 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   482                                      ;write divisor to channel 2 data port
   483 000003A5 58                          pop ax         ; Divisor
   484 000003A6 89C3                        mov bx, ax
   485 000003A8 88D8                        mov al, bl
   486 000003AA E642                        out 0x42, al         ; LSB first
   487 000003AC 88F8                        mov al, bh
   488 000003AE E642                        out 0x42, al         ; Then MSB
   489                                      
   490 000003B0 E80500                      call speaker_on
   491 000003B3 31C0                        xor ax, ax
   492 000003B5 8ED8                        mov ds, ax
   493 000003B7 C3                          ret
   494                                  
   495                                  ;tell speaker to not shut up
   496                                  speaker_on:
   497 000003B8 FA                          cli
   498 000003B9 E461                        in al, 0x61
   499 000003BB 0C03                        or al, 0b11
   500 000003BD E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   501 000003BF FB                          sti
   502 000003C0 C3                          ret
   503                                  ;tell speaker to shut up
   504                                  speaker_off:
   505 000003C1 FA                          cli
   506 000003C2 E461                        in al, 0x61
   507 000003C4 24FC                        and al, 0b11111100
   508 000003C6 E661                        out 0x61, al
   509 000003C8 FB                          sti
   510 000003C9 C3                          ret
   511                                  
   512                                  
   513                                  print_ax:
   514 000003CA 60                          pusha
   515                                  
   516 000003CB 50                          push ax
   517 000003CC B40E                        mov ah, 0xE
   518 000003CE B030                        mov al, '0'
   519 000003D0 CD10                        int 0x10
   520 000003D2 B40E                        mov ah, 0xE
   521 000003D4 B062                        mov al, 'b'
   522 000003D6 CD10                        int 0x10
   523 000003D8 58                          pop ax
   524                                  
   525 000003D9 89C3                        mov bx, ax
   526 000003DB B91000                      mov cx, 16
   527                                  print_ax_loop:
   528 000003DE 89D8                        mov ax, bx
   529 000003E0 83E001                      and ax, 1
   530 000003E3 83C030                      add ax, '0'
   531 000003E6 B40E                        mov ah, 0xE
   532 000003E8 50                          push ax
   533 000003E9 D1EB                        shr bx, 1
   534 000003EB E2F1                        loop print_ax_loop
   535 000003ED B91000                      mov cx, 16
   536                                  print_ax_loop2:
   537 000003F0 58                          pop ax
   538 000003F1 CD10                        int 0x10
   539 000003F3 E2FB                        loop print_ax_loop2
   540 000003F5 61                          popa
   541 000003F6 C3                          ret
   542                                  
   543                                  print_al:
   544 000003F7 60                          pusha
   545                                  
   546 000003F8 50                          push ax
   547 000003F9 B40E                        mov ah, 0xE
   548 000003FB B030                        mov al, '0'
   549 000003FD CD10                        int 0x10
   550 000003FF B40E                        mov ah, 0xE
   551 00000401 B062                        mov al, 'b'
   552 00000403 CD10                        int 0x10
   553 00000405 58                          pop ax
   554                                  
   555 00000406 30FF                        xor bh, bh
   556 00000408 88C3                        mov bl, al
   557 0000040A B90800                      mov cx, 8
   558                                  print_al_loop:
   559 0000040D 88D8                        mov al, bl
   560 0000040F 2401                        and al, 1
   561 00000411 0430                        add al, '0'
   562 00000413 B40E                        mov ah, 0xE
   563 00000415 50                          push ax
   564 00000416 D0EB                        shr bl, 1
   565 00000418 E2F3                        loop print_al_loop
   566 0000041A B90800                      mov cx, 8
   567                                  print_al_loop2:
   568 0000041D 58                          pop ax
   569 0000041E CD10                        int 0x10
   570 00000420 E2FB                        loop print_al_loop2
   571 00000422 61                          popa
   572 00000423 C3                          ret
   573                                  
   574                                  
   575                                  ;print value of ax in decimal
   576                                  print_ax_decimal:
   577 00000424 60                          pusha
   578                                      ;push 0 for print function to end
   579 00000425 31DB                        xor bx, bx
   580 00000427 53                          push bx
   581                                      ;if ax is already zero, just print a 0
   582 00000428 09C0                        or ax, ax
   583 0000042A 741C                        jz print_ax_decimal_zero
   584                                  print_ax_decimal_loop:
   585 0000042C 09C0                        or ax, ax
   586 0000042E 740D                        jz print_ax_decimal_printloop
   587 00000430 31D2                        xor dx, dx
   588 00000432 BB0A00                      mov bx, 10
   589                                      ;16 bit division, dx:ax / bx = ax, remainder dx
   590 00000435 F7F3                        div bx
   591                                      ;push remainder in ascii
   592 00000437 83C230                      add dx, '0'
   593 0000043A 52                          push dx
   594                                      ;loop
   595 0000043B EBEF                        jmp print_ax_decimal_loop
   596                                  print_ax_decimal_printloop:
   597                                      ;print digits pushed on the stack
   598 0000043D 58                          pop ax
   599                                      ;if popped value is 0, exit
   600 0000043E 09C0                        or ax, ax
   601 00000440 740D                        jz print_ax_decimal_end
   602                                      ;print value
   603 00000442 B40E                        mov ah, 0xE
   604 00000444 CD10                        int 0x10
   605 00000446 EBF5                        jmp print_ax_decimal_printloop
   606                                  print_ax_decimal_zero:
   607 00000448 5B                          pop bx
   608 00000449 B40E                        mov ah, 0xE
   609 0000044B B030                        mov al, '0'
   610 0000044D CD10                        int 0x10
   611                                  print_ax_decimal_end:
   612 0000044F 61                          popa
   613 00000450 C3                          ret
   614                                  
   615                                  
   616 00000451 0D0A                        msg db 0xD, 0xA
   617 00000453 46313A2062696F7320-         db 'F1: bios setup/restart/boot next', 0xD, 0xA
   617 0000045C 73657475702F726573-
   617 00000465 746172742F626F6F74-
   617 0000046E 206E6578740D0A     
   618 00000475 46323A207265737461-         db 'F2: restart (far jump to reset vector)', 0xD, 0xA
   618 0000047E 72742028666172206A-
   618 00000487 756D7020746F207265-
   618 00000490 73657420766563746F-
   618 00000499 72290D0A           
   619 0000049D 46333A20636C656172-         db 'F3: clear screen', 0xD, 0xA
   619 000004A6 2073637265656E0D0A 
   620 000004AF 46343A2068616C740D-         db 'F4: halt', 0xD, 0xA
   620 000004B8 0A                 
   621 000004B9 46353A2042494F5320-         db 'F5: BIOS beep', 0xD, 0xA
   621 000004C2 626565700D0A       
   622 000004C8 46363A206C6F616420-         db 'F6: load kernel and enter protected mode', 0xD, 0xA
   622 000004D1 6B65726E656C20616E-
   622 000004DA 6420656E7465722070-
   622 000004E3 726F74656374656420-
   622 000004EC 6D6F64650D0A       
   623 000004F2 46373A2072656C6F61-         db 'F7: reload NuckBoot from boot device', 0xD, 0xA
   623 000004FB 64204E75636B426F6F-
   623 00000504 742066726F6D20626F-
   623 0000050D 6F7420646576696365-
   623 00000516 0D0A               
   624 00000518 202020205669727475-         db '    Virtual piano:', 0xD, 0xA
   624 00000521 616C207069616E6F3A-
   624 0000052A 0D0A               
   625 0000052C 507265737320272066-         db 'Press ', 0x27, ' for lower octave, Press ', 0x22, ' for higher octave, Press ', 0x3B, ' to reset octave', 0xD, 0xA, 0
   625 00000535 6F72206C6F77657220-
   625 0000053E 6F63746176652C2050-
   625 00000547 72657373202220666F-
   625 00000550 722068696768657220-
   625 00000559 6F63746176652C2050-
   625 00000562 72657373203B20746F-
   625 0000056B 207265736574206F63-
   625 00000574 746176650D0A00     
   626                                  
   627 0000057B 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   627 00000584 206B65726E656C2E2E-
   627 0000058D 2E0D0A00           
   628 00000591 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   628 0000059A 616465642C20737769-
   628 000005A3 746368696E6720746F-
   628 000005AC 2070726F7465637465-
   628 000005B5 64206D6F64652E2E2E-
   628 000005BE 0D0A00             
   629 000005C1 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   630 000005C8 0D0A                        oslogo db 0xD, 0xA
   631 000005CA 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   631 000005D3 2020202020205F2020-
   631 000005DC 205F20202020202020-
   631 000005E5 20202020205F202020-
   631 000005EE 2020205F5F5F5F2020-
   631 000005F7 202020202020202020-
   631 00000600 2020205F2020202020-
   631 00000609 4F532056657273696F-
   631 00000612 6E2020200D0A       
   632 00000618 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.0       ', 0xD, 0xA
   632 00000621 20202020207C205C20-
   632 0000062A 7C207C5F2020205F20-
   632 00000633 205F5F5F7C207C205F-
   632 0000063C 5F207C205F5F202920-
   632 00000645 205F5F5F2020205F5F-
   632 0000064E 5F207C207C5F202020-
   632 00000657 202020312E30202020-
   632 00000660 202020200D0A       
   633 00000666 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   633 0000066F 20202020207C20205C-
   633 00000678 7C207C207C207C207C-
   633 00000681 2F205F5F7C207C2F20-
   633 0000068A 2F207C20205F205C20-
   633 00000693 2F205F205C202F205F-
   633 0000069C 205C7C205F5F7C2020-
   633 000006A5 202020202020202020-
   633 000006AE 202020200D0A       
   634 000006B4 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   634 000006BD 20202020207C207C5C-
   634 000006C6 20207C207C5F7C207C-
   634 000006CF 20285F5F7C2020203C-
   634 000006D8 20207C207C5F29207C-
   634 000006E1 20285F29207C20285F-
   634 000006EA 29207C207C5F202020-
   634 000006F3 202020202020202020-
   634 000006FC 202020200D0A       
   635 00000702 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   635 0000070B 20202020207C5F7C20-
   635 00000714 5C5F7C5C5F5F2C5F7C-
   635 0000071D 5C5F5F5F7C5F7C5C5F-
   635 00000726 5C207C5F5F5F5F2F20-
   635 0000072F 5C5F5F5F2F205C5F5F-
   635 00000738 5F2F205C5F5F7C2020-
   635 00000741 202020202020202020-
   635 0000074A 202020200D0A       
   636 00000750 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   636 00000759 202020202020202020-
   636 00000762 20226F706572617469-
   636 0000076B 6E672073797374656D-
   636 00000774 206F66207468652066-
   636 0000077D 757475726522202854-
   636 00000786 4D290D0A00         
   637                                  
   638 0000078B 00                          hang_virtual_piano_mode db 0b00
   639                                  
   640 0000078C 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   640 00000795 6176650D0A00       
   641 0000079B 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   641 000007A4 650D0A00           
   642 000007A8 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   642 000007B1 76650D0A00         
   643                                  
   644 000007B6 3D00                        keylen dw 61
   645 000007B8 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   645 000007C1 307177657274797569-
   645 000007CA 6F706173646667686A-
   645 000007D3 6B6C7A786376626E6D 
   646 000007DC 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   646 000007E5 455459494F50534447-
   646 000007EE 484A4C5A435642     
   647                                  
   648 000007F5 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   648 000007FE 006E007B00         
   649 00000803 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   649 0000080C 00DC00F600         
   650 00000811 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   650 0000081A 01B801EE01         
   651 0000081F 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   651 00000828 037003DC03         
   652 0000082D 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   652 00000836 06E006B807         
   653 0000083B 2D08                        dw 2093
   654                                  
   655 0000083D 45004E005C00680075-         dw 69, 78, 92, 104, 117
   655 00000846 00                 
   656 00000847 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   656 00000850 00                 
   657 00000851 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   657 0000085A 01                 
   658 0000085B 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   658 00000864 03                 
   659 00000865 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   659 0000086E 07                 
   660                                  
   661 0000086F 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   661 00000878 0037003E00         
   662 0000087D 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   662 00000886 006E007B00         
   663 0000088B 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   663 00000894 00DC00F600         
   664 00000899 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   664 000008A2 01B801EE01         
   665 000008A7 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   665 000008B0 037003DC03         
   666 000008B5 1704                        dw 1047
   667                                  
   668 000008B7 230027002E0034003A-         dw 35, 39, 46, 52, 58
   668 000008C0 00                 
   669 000008C1 45004E005C00680075-         dw 69, 78, 92, 104, 117
   669 000008CA 00                 
   670 000008CB 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   670 000008D4 00                 
   671 000008D5 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   671 000008DE 01                 
   672 000008DF 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   672 000008E8 03                 
   673                                  
   674 000008E9 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   674 000008F2 00DC00F600         
   675 000008F7 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   675 00000900 01B801EE01         
   676 00000905 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   676 0000090E 037003DC03         
   677 00000913 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   677 0000091C 06E006B807         
   678 00000921 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   678 0000092A 0CC00D6F0F         
   679 0000092F 5A10                        dw 4186
   680                                  
   681 00000931 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   681 0000093A 00                 
   682 0000093B 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   682 00000944 01                 
   683 00000945 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   683 0000094E 03                 
   684 0000094F 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   684 00000958 07                 
   685 00000959 A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   685 00000962 0E                 
   686                                  
   687 00000963 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   687 0000096C 6164206661696C7572-
   687 00000975 652C20726573657474-
   687 0000097E 696E672E2E2E0D0A00 
   688 00000987 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   688 00000990 6164206661696C6564-
   688 00000999 2C20676F696E672062-
   688 000009A2 61636B20746F207265-
   688 000009AB 616C206D6F64652E2E-
   688 000009B4 2E0D0A00           
   689 000009B8 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   689 000009C1 616420737563636573-
   689 000009CA 730D0A00           
   690                                  
   691 000009CE 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   691 000009D7 6F6E74726F6C6C6572-
   691 000009E0 20696E666F20737563-
   691 000009E9 63657373210D0A00   
   692 000009F1 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   692 000009FA 6F6E74726F6C6C6572-
   692 00000A03 20696E666F20666169-
   692 00000A0C 6C210D0A5072657373-
   692 00000A15 20616E79206B657920-
   692 00000A1E 746F20636F6E74696E-
   692 00000A27 75652E2E2E0D0A00   
   693                                  
   694 00000A2F 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   694 00000A38 6F6C6C657220696E66-
   694 00000A41 6F3A0D0A00         
   695 00000A46 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   695 00000A4F 6F6465732070747228-
   695 00000A58 7365673A6F6666293A-
   695 00000A61 2000               
   696                                  
   697 00000A63 56424520676574206D-         VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   697 00000A6C 6F646520696E666F20-
   697 00000A75 6661696C210D0A5072-
   697 00000A7E 65737320616E79206B-
   697 00000A87 657920746F20636F6E-
   697 00000A90 74696E75652E2E2E0D-
   697 00000A99 0A00               
   698                                  
   699 00000A9B 206270703A00                print_VBE_mode_text_msg db " bpp:", 0
   700 00000AA1 2070697463683A00            print_VBE_mode_text_msg1 db " pitch:", 0
   701 00000AA9 206D6D3A00                  print_VBE_mode_text_msg2 db " mm:", 0
   702                                  
   703 00000AAE 42657374206D6F6465-         VBEStuff_iter_modes_best_mode_msg db "Best mode: ", 0xD, 0xA, 0
   703 00000AB7 3A200D0A00         
   704 00000ABC 537769746368696E67-         VBEStuff_iter_modes_best_mode_msg1 db "Switching to VBE graphics mode... ", 0xD, 0xA, 0
   704 00000AC5 20746F205642452067-
   704 00000ACE 72617068696373206D-
   704 00000AD7 6F64652E2E2E200D0A-
   704 00000AE0 00                 
   705                                  
   706 00000AE1 [ED0A]                      VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
   707 00000AE3 [E50A]                      dw VBE_mode_info_block_fb_support_t
   708                                  
   709 00000AE5 4C46423A204A4100            VBE_mode_info_block_fb_support_t db "LFB: JA", 0
   710 00000AED 4C46423A204E45494E-         VBE_mode_info_block_fb_support_f db "LFB: NEIN", 0
   710 00000AF6 00                 
   711                                  
   712                                  
   713 00000AF7 0000                        current_mode_number dw 0
   714                                  
   715 00000AF9 2076616C696400              check_VBE_mode_msg db ' valid', 0
   716 00000B00 206265737400                check_VBE_mode_msg1 db ' best', 0
   717                                  
   718 00000B06 0000                        check_VBE_mode_best_mode_number dw 0
   719                                  
   720 00000B08 0000                        check_VBE_mode_best_area_high dw 0
   721 00000B0A 0000                        check_VBE_mode_best_area_low dw 0
   722                                  
   723 00000B0C 0000                        check_VBE_mode_best_screen_width dw 0
   724                                  
   725                                  ;code segment descriptor
   726                                  ;Base            32b: starting location of segment
   727                                  ;Limit           20b: size of limit
   728                                  ;Present          1b: Is this segment used/is a valid segment
   729                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   730                                  ;Type             1b: 1 if segment is code or data segment
   731                                  ;Flags(1b):
   732                                  ;  Type flags(4b):
   733                                  ;    1. Code? Will segment contain code
   734                                  ;    2. Conforming: can this code be executed from lower privileged segments
   735                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   736                                  ;            becomes an expand down segment
   737                                  ;    3. Readable, can this segment be read?
   738                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   739                                  ;            segment becomes read only
   740                                  ;    4. Accessed: set to 1 when CPU is using the segment
   741                                  ;  Other flags(4b):
   742                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   743                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   744                                  ;    3 & 4: 64 bit tetio, just set to 0
   745                                  
   746                                  ;offset of the segment descriptors relative to the beginning of the GDT
   747                                  CODE_SEG equ GDT_code - GDT_start
   748                                  DATA_SEG equ GDT_data - GDT_start
   749                                  
   750                                  ;kernel location is 0x10000
   751                                  KERNEL_LOCATION equ 0x1000
   752                                  
   753                                  GDT_start:
   754                                      GDT_null:
   755 00000B0E 00000000                        dd 0 ;(32 bits)
   756 00000B12 00000000                        dd 0 ;(32 bits)
   757                                      GDT_code:
   758                                          ;base: 0
   759                                          ;limit: 0xFFFFF
   760                                          ;PPT: 1001
   761                                          ;Type: 1010
   762                                          ;Other: 1100
   763                                  
   764                                          ;first 16 bits of limit
   765 00000B16 FFFF                            dw 0xFFFF
   766                                          ;first 24 bits of base
   767 00000B18 0000                            dw 0x0000 ;16 bits
   768 00000B1A 00                              db 0x00   ; 8 bits
   769                                          ;PPT + Type
   770 00000B1B 9A                              db 0b10011010
   771                                          ;other + last 4 bits of limit
   772 00000B1C CF                              db 0b11001111
   773                                          ;last 8 bits of base
   774 00000B1D 00                              db 0x00
   775                                      GDT_data:
   776                                          ;base: 0
   777                                          ;limit: 0xFFFFF
   778                                          ;PPT: 1001
   779                                          ;Type: 0010
   780                                          ;Other: 1100
   781                                  
   782                                          ;first 16 bits of limit
   783 00000B1E FFFF                            dw 0xFFFF
   784                                          ;first 24 bits of base
   785 00000B20 0000                            dw 0x0000 ;16 bits
   786 00000B22 00                              db 0x00   ; 8 bits
   787                                          ;PPT + Type
   788 00000B23 92                              db 0b10010010
   789                                          ;other + last 4 bits of limit
   790 00000B24 CF                              db 0b11001111
   791                                          ;last 8 bits of base
   792 00000B25 00                              db 0b00000000
   793                                  GDT_end:
   794                                  GDT_descriptor:
   795                                      ;size of GDT(16 bits)
   796 00000B26 1700                        dw GDT_end - GDT_start - 1
   797                                      ;start of GDT(32 bits)
   798 00000B28 [0E0B0000]                  dd GDT_start
   799                                  
   800                                  
   801                                  _kernel_load:
   802 00000B2C 31FF                        xor di, di ;counter for retry
   803                                  _kernel_load_loop:
   804                                  
   805 00000B2E 31C0                        xor ax, ax
   806 00000B30 8ED8                        mov ds, ax
   807 00000B32 BE[CF00]                    mov si, disk_read_msg ;Reading from disk: diskNum
   808 00000B35 E861F5                      call _printstr
   809                                  
   810                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   811 00000B38 B84002                      mov ax, 0x0240 ;ah=scancode, Read sectors | al=number of sectors to read
   812 00000B3B B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
   813 00000B3E 30F6                        xor dh, dh ;head number CHS
   814 00000B40 8A16[E200]                  mov dl, [diskNum] ;drive number
   815                                      ;Address to store values in: es:bx
   816 00000B44 BB0010                      mov bx, 0x1000
   817 00000B47 8EC3                        mov es, bx
   818 00000B49 31DB                        xor bx, bx
   819                                  
   820 00000B4B CD13                        int 0x13 ;disk read
   821 00000B4D 720D                        jc __kernel_load_fail
   822                                  
   823                                      ;disk read success
   824 00000B4F 31C0                        xor ax, ax
   825 00000B51 8ED8                        mov ds, ax
   826 00000B53 8EC0                        mov es, ax
   827 00000B55 BE[B809]                    mov si, kernel_load_success
   828 00000B58 E83EF5                      call _printstr
   829                                      
   830 00000B5B C3                          ret
   831                                  
   832                                  __kernel_load_fail:
   833                                      ;if number of attempts is over or equal 8
   834 00000B5C 83FF08                      cmp di, 8
   835 00000B5F 7D2D                        jge __kernel_load_fail_final
   836                                  
   837 00000B61 31C0                        xor ax, ax
   838 00000B63 8ED8                        mov ds, ax
   839 00000B65 BE[6309]                    mov si, kernel_load_fail
   840 00000B68 E82EF5                      call _printstr
   841                                  
   842                                      ;attempt to reset disk
   843 00000B6B 31C0                        xor ax, ax ;scancode ah = 0
   844 00000B6D 8A16[E200]                  mov dl, [diskNum]
   845 00000B71 CD13                        int 0x13 ;reset disk system
   846                                  
   847 00000B73 47                          inc di
   848                                      ;update number of attempts
   849 00000B74 89F8                        mov ax, di
   850 00000B76 83C030                      add ax, '0'
   851 00000B79 A2[EE00]                    mov [attempt_num], al
   852                                  
   853 00000B7C 31C0                        xor ax, ax
   854 00000B7E 8ED8                        mov ds, ax
   855 00000B80 BE[E600]                    mov si, attempts_msg
   856 00000B83 E813F5                      call _printstr
   857                                  
   858 00000B86 B90020                      mov cx, 0x2000
   859 00000B89 E839F5                      call _wait
   860                                  
   861 00000B8C EBA0                        jmp _kernel_load_loop
   862                                  
   863                                  __kernel_load_fail_final:
   864 00000B8E 31C0                        xor ax, ax
   865 00000B90 8ED8                        mov ds, ax
   866 00000B92 BE[8709]                    mov si, kernel_load_fail_final
   867 00000B95 E801F5                      call _printstr
   868 00000B98 58                          pop ax
   869 00000B99 E974F6                      jmp hang  ;go back to 16 bit hang loop if fail
   870                                  
   871                                  
   872                                  
   873                                  
   874                                  ;FAILSTATES
   875                                  VBEStuff_get_controller_info_fail:
   876 00000B9C 31C0                        xor ax, ax
   877 00000B9E 8ED8                        mov ds, ax
   878 00000BA0 BE[F109]                    mov si, VBEStuff_get_controller_info_fail_msg
   879 00000BA3 E8F3F4                      call _printstr
   880                                      ;blocking keyboard input
   881 00000BA6 31C0                        xor ax, ax
   882 00000BA8 CD16                        int 0x16 ;keyboard services
   883 00000BAA E9FDF4                      jmp biosboot_pc
   884                                  VBEStuff_get_mode_info_fail:
   885 00000BAD 31C0                        xor ax, ax
   886 00000BAF 8ED8                        mov ds, ax
   887 00000BB1 BE[630A]                    mov si, VBEStuff_get_mode_info_fail_msg
   888 00000BB4 E8E2F4                      call _printstr
   889                                      ;blocking keyboard input
   890 00000BB7 31C0                        xor ax, ax
   891 00000BB9 CD16                        int 0x16 ;keyboard services
   892 00000BBB E9ECF4                      jmp biosboot_pc
   893                                  
   894                                  
   895                                  
   896                                  
   897                                  VBEStuff:
   898                                      ;get controller info
   899 00000BBE 31C0                        xor ax, ax ;es:di
   900 00000BC0 8EC0                        mov es, ax
   901 00000BC2 BF[310E]                    mov di, VBE_info_block_start    
   902 00000BC5 B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
   903 00000BC8 CD10                        int 0x10
   904 00000BCA 83F84F                      cmp ax, 0x004F
   905 00000BCD 75CD                        jne VBEStuff_get_controller_info_fail
   906                                  
   907 00000BCF 31C0                        xor ax, ax
   908 00000BD1 8ED8                        mov ds, ax
   909 00000BD3 BE[CE09]                    mov si, VBEStuff_get_controller_info_success_msg
   910 00000BD6 E8C0F4                      call _printstr
   911                                  
   912                                      ;print controller info
   913 00000BD9 31C0                        xor ax, ax
   914 00000BDB 8ED8                        mov ds, ax
   915 00000BDD BE[2F0A]                    mov si, VBEStuff_get_controller_info_print_msg
   916 00000BE0 E8B6F4                      call _printstr
   917                                  
   918 00000BE3 A0[310E]                    mov al, [VBE_info_block_signature]
   919 00000BE6 B40E                        mov ah, 0xE
   920 00000BE8 CD10                        int 0x10
   921 00000BEA A1[320E]                    mov ax, [VBE_info_block_signature+1]
   922 00000BED B40E                        mov ah, 0xE
   923 00000BEF CD10                        int 0x10
   924 00000BF1 A1[330E]                    mov ax, [VBE_info_block_signature+2]
   925 00000BF4 B40E                        mov ah, 0xE
   926 00000BF6 CD10                        int 0x10
   927 00000BF8 A1[340E]                    mov ax, [VBE_info_block_signature+3]
   928 00000BFB B40E                        mov ah, 0xE
   929 00000BFD CD10                        int 0x10
   930 00000BFF B8200E                      mov ax, 0xE20
   931 00000C02 CD10                        int 0x10
   932 00000C04 A1[350E]                    mov ax, [VBE_info_block_version]
   933 00000C07 B00E                        mov al, 0xE
   934 00000C09 86C4                        xchg ah, al
   935 00000C0B 0430                        add al, '0'
   936 00000C0D CD10                        int 0x10
   937                                  
   938 00000C0F 31C0                        xor ax, ax
   939 00000C11 8ED8                        mov ds, ax
   940 00000C13 BE[460A]                    mov si, VBEStuff_get_controller_info_print_msg1
   941 00000C16 E880F4                      call _printstr
   942                                  
   943 00000C19 A1[410E]                    mov ax, [VBE_info_block_video_mode_segment]
   944 00000C1C E8ABF7                      call print_ax
   945 00000C1F B40E                        mov ah, 0xE
   946 00000C21 B03A                        mov al, ':'
   947 00000C23 CD10                        int 0x10
   948 00000C25 A1[3F0E]                    mov ax, [VBE_info_block_video_mode_offset]
   949 00000C28 E89FF7                      call print_ax
   950                                  
   951 00000C2B B80D0E                      mov ax, 0x0E0D
   952 00000C2E CD10                        int 0x10
   953 00000C30 B80A0E                      mov ax, 0x0E0A
   954 00000C33 CD10                        int 0x10
   955                                  
   956                                      ;iter mode numbers and find the good one
   957                                      ;get start of modes array and put into fs:si
   958 00000C35 A1[410E]                    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
   959 00000C38 8EE0                        mov fs, ax
   960 00000C3A 8B36[3F0E]                  mov si, [VBE_info_block_video_mode_offset]
   961                                  VBEStuff_iter_modes_loop:
   962 00000C3E 648B04                      mov ax, fs:[si] ;ax = current mode number
   963                                  
   964 00000C41 50                          push ax
   965 00000C42 0FA0                        push fs
   966 00000C44 56                          push si
   967                                      ;now print mode in text form
   968 00000C45 E85400                      call print_VBE_mode_text
   969 00000C48 5E                          pop si
   970 00000C49 0FA1                        pop fs
   971 00000C4B 58                          pop ax
   972                                  
   973                                      ;if mode number is 0xFFFF, exit program
   974 00000C4C 83F8FF                      cmp ax, 0xFFFF
   975 00000C4F 740B                        je VBEStuff_iter_modes_exit
   976                                  
   977                                      ;increment si
   978 00000C51 83C602                      add si, 2
   979                                      ;wait a tiny bit of time
   980 00000C54 B90003                      mov cx, 0x300
   981 00000C57 E86BF4                      call _wait
   982                                  
   983 00000C5A EBE2                        jmp VBEStuff_iter_modes_loop
   984                                  VBEStuff_iter_modes_exit:
   985                                      ;print best mode number
   986 00000C5C 31C0                        xor ax, ax
   987 00000C5E 8ED8                        mov ds, ax
   988 00000C60 BE[AE0A]                    mov si, VBEStuff_iter_modes_best_mode_msg
   989 00000C63 E833F4                      call _printstr
   990                                  
   991 00000C66 A1[060B]                    mov ax, [check_VBE_mode_best_mode_number]
   992 00000C69 E83000                      call print_VBE_mode_text
   993                                  
   994 00000C6C B90010                      mov cx, 0x1000
   995 00000C6F E853F4                      call _wait
   996                                  
   997                                      ;switch to the mode
   998 00000C72 31C0                        xor ax, ax
   999 00000C74 8ED8                        mov ds, ax
  1000 00000C76 BE[BC0A]                    mov si, VBEStuff_iter_modes_best_mode_msg1
  1001 00000C79 E81DF4                      call _printstr
  1002                                  
  1003 00000C7C B90010                      mov cx, 0x1000
  1004 00000C7F E843F4                      call _wait
  1005                                  
  1006                                      ;set video mode
  1007 00000C82 31C0                        xor ax, ax
  1008 00000C84 8ED8                        mov ds, ax
  1009 00000C86 8EC0                        mov es, ax
  1010 00000C88 89C6                        mov si, ax
  1011 00000C8A 89C7                        mov di, ax
  1012 00000C8C B8024F                      mov ax, 0x4F02
  1013 00000C8F 8B1E[060B]                  mov bx, [check_VBE_mode_best_mode_number]
  1014 00000C93 CD10                        int 0x10
  1015                                  
  1016 00000C95 B90010                      mov cx, 0x1000
  1017 00000C98 E82AF4                      call _wait
  1018 00000C9B C3                          ret
  1019                                  
  1020                                  
  1021                                  
  1022                                  print_VBE_mode_text:
  1023                                      ;save mode number here
  1024 00000C9C A3[F70A]                    mov [current_mode_number], ax
  1025                                  
  1026                                      ;if mode number is 0xFFFF, exit program
  1027 00000C9F 83F8FF                      cmp ax, 0xFFFF
  1028 00000CA2 0F849900                    je print_VBE_mode_text_end
  1029                                  
  1030                                      ;print value in ax
  1031 00000CA6 E821F7                      call print_ax
  1032                                  
  1033                                      ;print space
  1034 00000CA9 89C3                        mov bx, ax
  1035 00000CAB B8200E                      mov ax, 0x0E20
  1036 00000CAE CD10                        int 0x10
  1037 00000CB0 89D8                        mov ax, bx
  1038                                  
  1039                                      ;now get mode info
  1040 00000CB2 31DB                        xor bx, bx
  1041 00000CB4 8EDB                        mov ds, bx
  1042                                  
  1043 00000CB6 89C1                        mov cx, ax ;cx = mode number
  1044 00000CB8 B8014F                      mov ax, 0x4F01 ;scancode
  1045                                      ;es:di = 256b buffer
  1046 00000CBB 31D2                        xor dx, dx
  1047 00000CBD 8EC2                        mov es, dx
  1048 00000CBF BF[3110]                    mov di, VBE_mode_info_block_start
  1049 00000CC2 CD10                        int 0x10
  1050 00000CC4 83F84F                      cmp ax, 0x004F
  1051 00000CC7 0F85E2FE                    jne VBEStuff_get_mode_info_fail
  1052                                  
  1053                                  
  1054                                      ;now print out width and height
  1055 00000CCB 31C0                        xor ax, ax
  1056 00000CCD 8ED8                        mov ds, ax
  1057 00000CCF A1[4310]                    mov ax, [VBE_mode_info_block_width]
  1058 00000CD2 E84FF7                      call print_ax_decimal
  1059 00000CD5 B40E                        mov ah, 0xE
  1060 00000CD7 B078                        mov al, 'x'
  1061 00000CD9 CD10                        int 0x10
  1062 00000CDB 31C0                        xor ax, ax
  1063 00000CDD 8ED8                        mov ds, ax
  1064 00000CDF A1[4510]                    mov ax, [VBE_mode_info_block_height]
  1065 00000CE2 E83FF7                      call print_ax_decimal
  1066 00000CE5 B8200E                      mov ax, 0x0E20
  1067 00000CE8 CD10                        int 0x10
  1068                                      ;print if it supports linear framebuffer or not
  1069 00000CEA 31C0                        xor ax, ax
  1070 00000CEC 8ED8                        mov ds, ax
  1071 00000CEE 8B1E[3110]                  mov bx, [VBE_mode_info_block_attributes]
  1072 00000CF2 81E38000                    and bx, 0b10000000 ;if bit 7 is 1 it supports
  1073 00000CF6 C1EB06                      shr bx, 6
  1074 00000CF9 81C3[E10A]                  add bx, VBE_mode_info_block_fb_support
  1075 00000CFD 8B37                        mov si, [bx] ;pointer array shenanigans
  1076 00000CFF E897F3                      call _printstr
  1077                                      ;print space and msg
  1078 00000D02 BE[9B0A]                    mov si, print_VBE_mode_text_msg
  1079 00000D05 E891F3                      call _printstr
  1080                                      ;print bits per pixel
  1081 00000D08 31C0                        xor ax, ax
  1082 00000D0A A0[4A10]                    mov al, [VBE_mode_info_block_bpp]
  1083 00000D0D E814F7                      call print_ax_decimal
  1084                                      ;print space and msg
  1085 00000D10 BE[A90A]                    mov si, print_VBE_mode_text_msg2
  1086 00000D13 E883F3                      call _printstr
  1087                                      ;print memory model
  1088 00000D16 31C0                        xor ax, ax
  1089 00000D18 A0[4C10]                    mov al, [VBE_mode_info_block_memory_model]
  1090 00000D1B E806F7                      call print_ax_decimal
  1091                                      ;print space and msg
  1092 00000D1E 31C0                        xor ax, ax
  1093 00000D20 8ED8                        mov ds, ax
  1094 00000D22 BE[A10A]                    mov si, print_VBE_mode_text_msg1
  1095 00000D25 E871F3                      call _printstr
  1096                                      ;print pitch
  1097 00000D28 A1[4110]                    mov ax, [VBE_mode_info_block_pitch]
  1098 00000D2B E8F6F6                      call print_ax_decimal
  1099                                  
  1100                                      ;now check if the mode is actually good & find best one
  1101 00000D2E E80F00                      call check_VBE_mode
  1102                                  
  1103 00000D31 B80D0E                      mov ax, 0x0E0D
  1104 00000D34 CD10                        int 0x10
  1105 00000D36 B80A0E                      mov ax, 0x0E0A
  1106 00000D39 CD10                        int 0x10
  1107                                  
  1108 00000D3B 31C0                        xor ax, ax
  1109 00000D3D 8ED8                        mov ds, ax
  1110                                  print_VBE_mode_text_end:
  1111 00000D3F C3                          ret
  1112                                  
  1113                                  
  1114                                  
  1115                                  check_VBE_mode:
  1116                                      
  1117                                      ;if LFB is false, exit
  1118 00000D40 A1[3110]                    mov ax, [VBE_mode_info_block_attributes]
  1119 00000D43 258000                      and ax, 0b10000000 ;if bit 7 is 1 it supports
  1120 00000D46 09C0                        or ax, ax
  1121 00000D48 7470                        jz check_VBE_mode_exit
  1122                                  
  1123                                      ;if mm is not 6, exit
  1124 00000D4A 31C0                        xor ax, ax
  1125 00000D4C A0[4C10]                    mov al, [VBE_mode_info_block_memory_model]
  1126 00000D4F 3C06                        cmp al, 6
  1127 00000D51 7567                        jne check_VBE_mode_exit
  1128                                  
  1129                                      ;if bpp is not 32, exit
  1130 00000D53 31C0                        xor ax, ax
  1131 00000D55 A0[4A10]                    mov al, [VBE_mode_info_block_bpp]
  1132 00000D58 3C20                        cmp al, 32
  1133 00000D5A 755E                        jne check_VBE_mode_exit
  1134                                  
  1135                                      ;print valid
  1136 00000D5C 31C0                        xor ax, ax
  1137 00000D5E 8ED8                        mov ds, ax
  1138 00000D60 BE[F90A]                    mov si, check_VBE_mode_msg
  1139 00000D63 E833F3                      call _printstr
  1140                                  
  1141                                      ;get current mode's area
  1142 00000D66 A1[4310]                    mov ax, [VBE_mode_info_block_width]
  1143 00000D69 8B1E[4510]                  mov bx, [VBE_mode_info_block_height]
  1144 00000D6D F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1145                                      ;compare high word of current with best high word
  1146 00000D6F 8B1E[080B]                  mov bx, [check_VBE_mode_best_area_high]
  1147 00000D73 39DA                        cmp dx, bx
  1148 00000D75 7C43                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1149 00000D77 7F19                        jg check_VBE_mode_update ;if current > highest, update values
  1150                                      ;if equal, check low word
  1151 00000D79 8B1E[0A0B]                  mov bx, [check_VBE_mode_best_area_low]
  1152 00000D7D 39DA                        cmp dx, bx
  1153 00000D7F 7C39                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1154 00000D81 7F0F                        jg check_VBE_mode_update ;if current > highest, update values
  1155                                  
  1156                                      ;if still equal, that means it's the exact same resolution
  1157                                      ;check if current screen width is more than best screen width
  1158 00000D83 A1[4310]                    mov ax, [VBE_mode_info_block_width]
  1159 00000D86 8B1E[0C0B]                  mov bx, [check_VBE_mode_best_screen_width]
  1160 00000D8A 39D8                        cmp ax, bx
  1161 00000D8C 7C2C                        jl check_VBE_mode_exit ;if current < highest, nuh uh
  1162 00000D8E 7F02                        jg check_VBE_mode_update ;if current > highest, update values
  1163                                  
  1164 00000D90 EB28                        jmp check_VBE_mode_exit
  1165                                  check_VBE_mode_update:
  1166                                      ;restore current mode number
  1167 00000D92 8B1E[F70A]                  mov bx, [current_mode_number]
  1168                                      ;update best mode number
  1169 00000D96 891E[060B]                  mov [check_VBE_mode_best_mode_number], bx
  1170                                      ;update best area
  1171 00000D9A A1[4310]                    mov ax, [VBE_mode_info_block_width]
  1172 00000D9D 8B1E[4510]                  mov bx, [VBE_mode_info_block_height]
  1173 00000DA1 F7E3                        mul bx ;ax * bx = dx:ax, 32-bit multiplication
  1174 00000DA3 8916[080B]                  mov [check_VBE_mode_best_area_high], dx
  1175 00000DA7 A3[0A0B]                    mov [check_VBE_mode_best_area_low], ax
  1176                                      ;update best screen width
  1177 00000DAA A1[4310]                    mov ax, [VBE_mode_info_block_width]
  1178 00000DAD A3[0C0B]                    mov [check_VBE_mode_best_screen_width], ax
  1179                                  
  1180                                      ;print best
  1181 00000DB0 31C0                        xor ax, ax
  1182 00000DB2 8ED8                        mov ds, ax
  1183 00000DB4 BE[000B]                    mov si, check_VBE_mode_msg1
  1184 00000DB7 E8DFF2                      call _printstr
  1185                                  check_VBE_mode_exit:
  1186 00000DBA 31C0                        xor ax, ax
  1187 00000DBC 8ED8                        mov ds, ax
  1188 00000DBE C3                          ret
  1189                                  
  1190                                  
  1191                                  
  1192                                  
  1193                                  
  1194                                  
  1195                                  
  1196                                  boot_pmode:
  1197 00000DBF 31C0                        xor ax, ax
  1198 00000DC1 8ED8                        mov ds, ax
  1199 00000DC3 BE[7B05]                    mov si, boot_pmode_msg
  1200 00000DC6 E8D0F2                      call _printstr
  1201                                  
  1202 00000DC9 E860FD                      call _kernel_load
  1203                                  
  1204 00000DCC 31C0                        xor ax, ax
  1205 00000DCE 8ED8                        mov ds, ax
  1206 00000DD0 BE[9105]                    mov si, kernel_loaded_msg
  1207 00000DD3 E8C3F2                      call _printstr
  1208                                  
  1209 00000DD6 B90010                      mov cx, 0x1000
  1210 00000DD9 E8E9F2                      call _wait
  1211                                  
  1212 00000DDC B93200                      mov cx, 50
  1213                                  clear_loop:
  1214 00000DDF B80D0E                      mov ax, 0x0E0D
  1215 00000DE2 CD10                        int 0x10
  1216 00000DE4 B80A0E                      mov ax, 0x0E0A
  1217 00000DE7 CD10                        int 0x10
  1218 00000DE9 E2F4                        loop clear_loop
  1219                                      
  1220                                      ;set new graphics mode
  1221                                  
  1222                                      ;Mode 3h
  1223                                      ;VGA 80x25 text mode
  1224 00000DEB B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1225 00000DEE CD10                        int 0x10 ;bios call video services
  1226                                      ;disable cursor
  1227 00000DF0 B401                        mov ah, 0x01
  1228 00000DF2 B90020                      mov cx, 0x2000 ;disable cursor
  1229 00000DF5 CD10                        int 0x10 ;int 0x10, 1: set cursor type
  1230                                  
  1231                                      ;Mode 12h
  1232                                      ;VGA 640x480 16 color
  1233                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1234                                      ;int 0x10 ;bios call video services
  1235                                  
  1236                                      ;VBE graphics
  1237 00000DF7 E8C4FD                      call VBEStuff
  1238                                  
  1239 00000DFA B90010                      mov cx, 0x1000
  1240 00000DFD E8C5F2                      call _wait
  1241                                  
  1242 00000E00 FA                          cli
  1243 00000E01 0F0116[260B]                lgdt [GDT_descriptor] ;load GDT
  1244                                      
  1245                                      ;change last bit of cr0 to 1
  1246 00000E06 0F20C0                      mov eax, cr0
  1247 00000E09 6683C801                    or eax, 1
  1248 00000E0D 0F22C0                      mov cr0, eax
  1249                                      
  1250                                      ;PROTECTED MODE!
  1251                                      ;far jump to code segment
  1252 00000E10 EA[150E]0800                jmp CODE_SEG:pmode
  1253                                  
  1254                                  BITS 32
  1255                                  pmode:
  1256 00000E15 66B81000                    mov ax, DATA_SEG ;setup segments
  1257 00000E19 8ED8                        mov ds, ax
  1258 00000E1B 8ED0                        mov ss, ax
  1259 00000E1D 8EC0                        mov es, ax
  1260 00000E1F 8EE0                        mov fs, ax
  1261 00000E21 8EE8                        mov gs, ax
  1262 00000E23 BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1263 00000E28 89EC                        mov esp, ebp
  1264                                  
  1265                                      ;jump to loaded kernel
  1266 00000E2A E9(00000100)                jmp 0x10000
  1267 00000E2F EBFE                        jmp $
  1268                                  
  1269                                  
  1270                                  
  1271                                  ; TOTAL of 512 bytes
  1272                                  VBE_info_block_start:
  1273 00000E31 4E45494E                    VBE_info_block_signature db 'NEIN'
  1274 00000E35 0000                        VBE_info_block_version dw 0
  1275 00000E37 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
  1276 00000E3B 00000000                    VBE_info_block_capabilities dd 0
  1277 00000E3F 0000                        VBE_info_block_video_mode_offset dw 0
  1278 00000E41 0000                        VBE_info_block_video_mode_segment dw 0
  1279 00000E43 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
  1280 00000E45 00<rep 1ECh>                times 492 db 0 ;reserved
  1281                                  VBE_info_block_end:
  1282                                  ; TOTAL of 256 bytes
  1283                                  VBE_mode_info_block_start:
  1284 00001031 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
  1285 00001033 00                          VBE_mode_info_block_window_a db 0 ;deprecated
  1286 00001034 00                          VBE_mode_info_block_window_b db 0 ;deprecated
  1287 00001035 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
  1288 00001037 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
  1289 00001039 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
  1290 0000103B 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
  1291 0000103D 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
  1292 00001041 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
  1293                                  
  1294 00001043 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
  1295 00001045 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
  1296 00001047 00                          VBE_mode_info_block_char_width db 0 ;in pixels, unused
  1297 00001048 00                          VBE_mode_info_block_char_height db 0 ;in pixels, unused
  1298 00001049 00                          VBE_mode_info_block_planes_count db 0
  1299 0000104A 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
  1300 0000104B 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
  1301 0000104C 00                          VBE_mode_info_block_memory_model db 0
  1302 0000104D 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
  1303 0000104E 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
  1304 0000104F 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
  1305                                  
  1306                                      ;size and pos of masks
  1307 00001050 00                          VBE_mode_info_block_red_mask db 0
  1308 00001051 00                          VBE_mode_info_block_red_pos db 0
  1309 00001052 00                          VBE_mode_info_block_green_mask db 0
  1310 00001053 00                          VBE_mode_info_block_green_pos db 0
  1311 00001054 00                          VBE_mode_info_block_blue_mask db 0
  1312 00001055 00                          VBE_mode_info_block_blue_pos db 0
  1313 00001056 00                          VBE_mode_info_block_reserved_mask db 0
  1314 00001057 00                          VBE_mode_info_block_reserved_pos db 0
  1315 00001058 00                          VBE_mode_info_block_direct_color_attributes db 0
  1316                                  
  1317                                      ;added in revision 2.0
  1318 00001059 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
  1319 0000105D 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
  1320 00001061 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
  1321 00001063 00<rep CEh>                 VBE_mode_info_block_reserved times 206 db 0 ;available in revision 3.0, useless
  1322                                  VBE_mode_info_block_end:
  1323                                  
  1324                                  
  1325                                  
  1326                                  
  1327                                  
  1328 00001131 00<rep 16CFh>           times 10240-($-$$) db 0 ;total length of binary 20 sector
  1329                                                          ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:codedb 0x69
