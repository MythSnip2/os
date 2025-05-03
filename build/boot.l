     1                                  BITS 16
     2                                  ORG 0x7C00
     3                                  
     4                                  
     5                                  start_boot:
     6                                  
     7                                  
     8                                      ;set positive direction DF=0
     9 00000000 FC                          cld
    10                                  
    11                                      ;disable interrupts
    12 00000001 FA                          cli
    13                                  
    14                                      ;zero out the segment registers
    15 00000002 31C0                        xor ax, ax
    16 00000004 8ED8                        mov ds, ax
    17 00000006 8EC0                        mov es, ax
    18 00000008 8EE0                        mov fs, ax
    19                                  
    20                                      ;save the disk number
    21 0000000A 8816[E200]                  mov [diskNum], dl
    22                                  
    23                                      ;initialize stack
    24 0000000E 8ED0                        mov ss, ax
    25 00000010 BCFF7B                      mov sp, 0x7BFF ;stack grows below bootloader
    26                                  
    27                                      ;set video mode to text mode(80x25)
    28 00000013 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    29 00000016 CD10                        int 0x10 ;bios call video services
    30                                  
    31                                  
    32                                      ;enable interrupts
    33 00000018 FB                          sti
    34                                  
    35 00000019 31C0                        xor ax, ax       ;print bootloader start msg
    36 0000001B 8ED8                        mov ds, ax
    37 0000001D BE[F700]                    mov si, startup_msg
    38 00000020 E87600                      call _printstr
    39                                  
    40 00000023 E80300                      call _disk_read ;read bootloader code to ram
    41                                  
    42 00000026 E9D703                      jmp main
    43                                  
    44                                  _disk_read:
    45 00000029 31FF                        xor di, di ;counter for retry
    46                                  _disk_read_loop:
    47                                  
    48 0000002B 31C0                        xor ax, ax
    49 0000002D 8ED8                        mov ds, ax
    50 0000002F BE[CF00]                    mov si, disk_read_msg ;Reading from disk: diskNum
    51 00000032 E86400                      call _printstr
    52                                  
    53                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    54                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    55 00000035 B81302                      mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    56 00000038 B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    57 0000003B 30F6                        xor dh, dh ;head number CHS
    58 0000003D 8A16[E200]                  mov dl, [diskNum] ;drive number
    59                                      ;Address to store values in: es:bx which is 0:7E00
    60 00000041 31DB                        xor bx, bx
    61 00000043 8EC3                        mov es, bx
    62 00000045 BB007E                      mov bx, 0x7E00
    63 00000048 CD13                        int 0x13 ;disk read
    64 0000004A 720B                        jc __disk_read_fail
    65                                  
    66                                      ;disk read success
    67 0000004C 31C0                        xor ax, ax
    68 0000004E 8ED8                        mov ds, ax
    69 00000050 BE[5E01]                    mov si, disk_read_success
    70 00000053 E84300                      call _printstr
    71 00000056 C3                          ret
    72                                  
    73                                  __disk_read_fail:
    74                                      ;if number of attempts is over or equal 8
    75 00000057 83FF08                      cmp di, 8
    76 0000005A 7D2D                        jge __disk_read_fail_final
    77                                  
    78 0000005C 31C0                        xor ax, ax
    79 0000005E 8ED8                        mov ds, ax
    80 00000060 BE[0B01]                    mov si, disk_read_fail
    81 00000063 E83300                      call _printstr
    82                                  
    83                                      ;attempt to reset disk
    84 00000066 31C0                        xor ax, ax ;scancode ah = 0
    85 00000068 8A16[E200]                  mov dl, [diskNum]
    86 0000006C CD13                        int 0x13 ;reset disk system
    87                                  
    88 0000006E 47                          inc di
    89                                      ;update number of attempts
    90 0000006F 89F8                        mov ax, di
    91 00000071 83C030                      add ax, '0'
    92 00000074 A2[EE00]                    mov [attempt_num], al
    93                                  
    94 00000077 31C0                        xor ax, ax
    95 00000079 8ED8                        mov ds, ax
    96 0000007B BE[E600]                    mov si, attempts_msg
    97 0000007E E81800                      call _printstr
    98                                  
    99 00000081 B90020                      mov cx, 0x2000
   100 00000084 E83E00                      call _wait
   101                                  
   102 00000087 EBA2                        jmp _disk_read_loop
   103                                  
   104                                  __disk_read_fail_final:
   105 00000089 31C0                        xor ax, ax
   106 0000008B 8ED8                        mov ds, ax
   107 0000008D BE[2D01]                    mov si, disk_read_fail_final
   108 00000090 E80600                      call _printstr
   109                                      ;blocking keyboard input
   110 00000093 31C0                        xor ax, ax
   111 00000095 CD16                        int 0x16 ;keyboard services
   112 00000097 EB11                        jmp biosboot_pc
   113                                  
   114                                  ; subroutine to print a string until null terminator
   115                                  ; address of string: ds:si
   116                                  _printstr:
   117 00000099 FC                          cld ;clear DF flag in FLAGS
   118                                  __printstr_loop:
   119 0000009A 8A04                        mov al, [si]
   120 0000009C 46                          inc si
   121                                  
   122 0000009D 08C0                        or al, al ;if al = 0
   123 0000009F 7408                        jz __printstr_exit ;exit loop
   124                                  
   125 000000A1 B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   126 000000A3 31DB                        xor bx, bx ;bh = 0
   127 000000A5 CD10                        int 0x10 ;bios call video services
   128 000000A7 EBF1                        jmp __printstr_loop
   129                                  __printstr_exit:
   130 000000A9 C3                          ret
   131                                  
   132                                  biosboot_pc:
   133 000000AA 31C0                        xor ax, ax
   134 000000AC 8ED8                        mov ds, ax
   135 000000AE BE[7201]                    mov si, biosboot_msg
   136 000000B1 E8E5FF                      call _printstr
   137 000000B4 CD19                        int 0x19
   138                                  
   139                                  restart_pc:
   140 000000B6 31C0                        xor ax, ax
   141 000000B8 8ED8                        mov ds, ax
   142 000000BA BE[8F01]                    mov si, restart_msg
   143 000000BD E8D9FF                      call _printstr
   144                                      ;jump to reset vector
   145 000000C0 EA0000FFFF                  jmp 0xFFFF:0x0000
   146                                  
   147                                  ; subroutine to delay cpu ticks
   148                                  _wait:
   149 000000C5 51                          push cx
   150 000000C6 B9FFFF                      mov cx, 0xFFFF
   151                                  __wait_innerloop:
   152 000000C9 E2FE                        loop __wait_innerloop
   153 000000CB 59                          pop cx
   154 000000CC E2F7                        loop _wait
   155 000000CE C3                          ret
   156                                  
   157 000000CF 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   157 000000D8 726F6D206469736B3A-
   157 000000E1 20                 
   158 000000E2 00                          diskNum db 0 ;reserved for BIOS drive number
   159 000000E3 0D0A00                      db 0xD, 0xA, 0
   160                                  
   161 000000E6 417474656D707420            attempts_msg db 'Attempt '
   162 000000EE 00                          attempt_num db 0
   163 000000EF 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   164                                  
   165 000000F7 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   165 00000100 6F746C6F616465720D-
   165 00000109 0A00               
   166 0000010B 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   166 00000114 206661696C7572652C-
   166 0000011D 20726573657474696E-
   166 00000126 672E2E2E0D0A00     
   167 0000012D 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   167 00000136 206661696C65642C20-
   167 0000013F 707265737320616E79-
   167 00000148 206B657920746F2063-
   167 00000151 6F6E74696E75652E2E-
   167 0000015A 2E0D0A00           
   168 0000015E 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   168 00000167 20737563636573730D-
   168 00000170 0A00               
   169                                  
   170 00000172 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   170 0000017B 6E746F2042494F5320-
   170 00000184 73657475702E2E2E0D-
   170 0000018D 0A00               
   171 0000018F 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   171 00000198 672E2E2E0D0A00     
   172 0000019F 00<rep 1Fh>                 times 446-($-$$) db 0 ;446B bootloader code
   173                                      ;MBR partition table(64B)
   174                                      ;
   175                                      ;bootable, start 2048 end 124927 size 60MiB
   176                                      ;
   177                                      ;first entry
   178 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   179                                      ;chs addressing of first sector
   180 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   181 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   182 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   183 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   184                                      ;chs addressing of last sector
   185 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   186 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   187 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   188 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   189 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   190                                      ;other entries
   191 000001CE 00<rep 30h>                 times 3*16 db 0
   192                                  
   193                                  times 510-($-$$) db 0 ;510B excluding boot signature
   194 000001FE 55AA                    db 0x55, 0xAA
   195                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   196                                  ; buffer sector(s)
   197 00000200 00<rep 200h>            times 512 db 0
   198                                  
   199                                  
   200                                  
   201                                  main:
   202 00000400 31C0                        xor ax, ax
   203 00000402 8ED8                        mov ds, ax
   204 00000404 BE[C807]                    mov si, oslogo
   205 00000407 E88FFC                      call _printstr
   206                                  
   207                                      ;print a helpful message
   208 0000040A BE[5106]                    mov si, msg
   209 0000040D E889FC                      call _printstr
   210                                  
   211                                  hang:
   212 00000410 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   213 00000412 CD16                        int 0x16 ;keyboard services
   214                                      ;return: AL = character, AH = scan code
   215 00000414 74FA                        jz hang ;if key not pressed jump back
   216                                      ;if there is a key use int 0x16,0 to get the results
   217 00000416 31C0                        xor ax, ax
   218 00000418 CD16                        int 0x16 ;ah = scancode, al = char
   219                                  
   220                                      ;print char
   221 0000041A 50                          push ax
   222 0000041B B40E                        mov ah, 0x0E
   223 0000041D CD10                        int 0x10
   224 0000041F 58                          pop ax
   225                                  
   226 00000420 80FC3B                      cmp ah, 0x3B
   227 00000423 0F8483FC                    je biosboot_pc
   228 00000427 80FC3C                      cmp ah, 0x3C
   229 0000042A 0F8488FC                    je restart_pc
   230 0000042E 80FC3D                      cmp ah, 0x3D
   231 00000431 0F84F400                    je cls
   232 00000435 80FC3E                      cmp ah, 0x3E
   233 00000438 0F841201                    je halt
   234 0000043C 80FC3F                      cmp ah, 0x3F
   235 0000043F 0F84F800                    je biosbeep
   236 00000443 80FC40                      cmp ah, 0x40
   237 00000446 0F844C0A                    je boot_pmode
   238 0000044A 80FC41                      cmp ah, 0x41
   239 0000044D 7407                        je retest
   240                                  
   241 0000044F 50                          push ax
   242 00000450 E84800                      call hang_virtual_piano
   243 00000453 58                          pop ax
   244                                  
   245 00000454 EBBA                        jmp hang
   246                                  
   247                                  ;subroutine to retest nuck os
   248                                  retest:
   249 00000456 8A16[E200]                  mov dl, [diskNum]
   250 0000045A 52                          push dx
   251 0000045B E80600                      call retest_disk_read
   252                                      ;jump to the start
   253 0000045E 5A                          pop dx
   254 0000045F EA0000C007                  jmp 0x07C0:0x0000
   255                                  
   256                                  
   257                                  retest_disk_read:
   258 00000464 31FF                        xor di, di ;counter for retry
   259                                  retest_disk_read_loop:
   260                                  
   261                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   262                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   263 00000466 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   264 00000469 B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   265 0000046C 30F6                        xor dh, dh ;head number CHS
   266 0000046E 8A16[E200]                  mov dl, [diskNum] ;drive number
   267                                      ;Address to store values in: es:bx which is 0:7E00
   268 00000472 31DB                        xor bx, bx
   269 00000474 8EC3                        mov es, bx
   270 00000476 BB007C                      mov bx, 0x7C00
   271 00000479 CD13                        int 0x13 ;disk read
   272 0000047B 7201                        jc retest__disk_read_fail
   273                                  
   274                                      ;disk read success
   275 0000047D C3                          ret
   276                                  
   277                                  retest__disk_read_fail:
   278                                      ;if number of attempts is over or equal 8
   279 0000047E 83FF08                      cmp di, 8
   280 00000481 7D11                        jge retest__disk_read_fail_final
   281                                  
   282                                      ;attempt to reset disk
   283 00000483 31C0                        xor ax, ax ;scancode ah = 0
   284 00000485 8A16[E200]                  mov dl, [diskNum]
   285 00000489 CD13                        int 0x13 ;reset disk system
   286                                  
   287 0000048B 47                          inc di
   288                                  
   289 0000048C B90020                      mov cx, 0x2000
   290 0000048F E833FC                      call _wait
   291                                  
   292 00000492 EBD2                        jmp retest_disk_read_loop
   293                                  
   294                                  retest__disk_read_fail_final:
   295                                      ;blocking keyboard input
   296 00000494 31C0                        xor ax, ax
   297 00000496 CD16                        int 0x16 ;keyboard services
   298 00000498 E90FFC                      jmp biosboot_pc
   299                                  
   300                                  
   301                                  
   302                                  ;subroutine to play a note in virtual piano
   303                                  ;key: al
   304                                  hang_virtual_piano:
   305                                      ;change mode
   306 0000049B 50                          push ax
   307                                  
   308 0000049C 3C3B                        cmp al, 0x3B
   309 0000049E 740A                        je hang_virtual_piano_mode_rst
   310 000004A0 3C27                        cmp al, 0x27
   311 000004A2 7415                        je hang_virtual_piano_mode_1
   312 000004A4 3C22                        cmp al, 0x22
   313 000004A6 7423                        je hang_virtual_piano_mode_2
   314 000004A8 EB31                        jmp hang_virtual_piano_mode_done
   315                                  hang_virtual_piano_mode_rst:
   316 000004AA 31C0                        xor ax, ax
   317 000004AC A2[8B09]                    mov [hang_virtual_piano_mode], al
   318 000004AF 8ED8                        mov ds, ax
   319 000004B1 BE[8C09]                    mov si, mode_rst_msg
   320 000004B4 E8E2FB                      call _printstr
   321 000004B7 EB22                        jmp hang_virtual_piano_mode_done
   322                                  hang_virtual_piano_mode_1:
   323 000004B9 B80100                      mov ax, 0x0001
   324 000004BC A2[8B09]                    mov [hang_virtual_piano_mode], al
   325 000004BF 31C0                        xor ax, ax
   326 000004C1 8ED8                        mov ds, ax
   327 000004C3 BE[9B09]                    mov si, mode_1_msg
   328 000004C6 E8D0FB                      call _printstr    
   329 000004C9 EB10                        jmp hang_virtual_piano_mode_done
   330                                  hang_virtual_piano_mode_2:
   331 000004CB B80200                      mov ax, 0x0002
   332 000004CE A2[8B09]                    mov [hang_virtual_piano_mode], al
   333 000004D1 31C0                        xor ax, ax
   334 000004D3 8ED8                        mov ds, ax
   335 000004D5 BE[A809]                    mov si, mode_2_msg
   336 000004D8 E8BEFB                      call _printstr
   337                                  hang_virtual_piano_mode_done:
   338                                      ;load difference in di
   339 000004DB 31C0                        xor ax, ax
   340 000004DD A0[8B09]                    mov al, [hang_virtual_piano_mode]
   341 000004E0 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   342 000004E3 31D2                        xor dx, dx
   343 000004E5 F7E3                        mul bx
   344 000004E7 89C7                        mov di, ax
   345 000004E9 58                          pop ax
   346                                  
   347 000004EA 31C9                        xor cx, cx             ;i = 0
   348 000004EC 8B16[B609]                  mov dx, [keylen]       ;k = 10
   349                                  hang_virtual_piano_loop:
   350 000004F0 39D1                        cmp cx, dx
   351 000004F2 0F8D1AFF                    jge hang               ;return if i >= k
   352 000004F6 89CE                        mov si, cx             ;si = i
   353 000004F8 8A9C[B809]                  mov bl, [keys + si]    ;bl = keys[i]
   354 000004FC 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   355 000004FE 7403                        je hang_virtual_piano_play
   356                                  
   357 00000500 41                          inc cx                 ;i++
   358 00000501 EBED                        jmp hang_virtual_piano_loop
   359                                  
   360                                  hang_virtual_piano_play:
   361 00000503 89C8                        mov ax, cx
   362 00000505 B90200                      mov cx, 2
   363 00000508 F7E1                        mul cx
   364 0000050A 89C6                        mov si, ax
   365 0000050C B8[F509]                    mov ax, notes
   366 0000050F 01F8                        add ax, di
   367 00000511 01F0                        add ax, si
   368 00000513 89C3                        mov bx, ax
   369 00000515 8B07                        mov ax, [bx]
   370                                      
   371 00000517 E87900                      call _tone
   372 0000051A B9FFFF                      mov cx, 0xFFFF
   373 0000051D BA0500                      mov dx, 0x5
   374 00000520 E84300                      call _wait_PIT
   375 00000523 E89B00                      call speaker_off
   376 00000526 E9E7FE                      jmp hang
   377                                  
   378                                  cls:
   379 00000529 B93200                      mov cx, 50
   380                                  cls_loop:
   381 0000052C B80D0E                      mov ax, 0x0E0D
   382 0000052F CD10                        int 0x10
   383 00000531 B80A0E                      mov ax, 0x0E0A
   384 00000534 CD10                        int 0x10
   385 00000536 E2F4                        loop cls_loop
   386 00000538 E9D5FE                      jmp hang
   387                                  
   388                                  ;bios beep tone
   389                                  biosbeep:
   390 0000053B 31C0                        xor ax, ax
   391 0000053D 8ED8                        mov ds, ax
   392 0000053F BE[C107]                    mov si, beep_msg
   393 00000542 E854FB                      call _printstr
   394 00000545 B90001                      mov cx, 0x100
   395 00000548 E87AFB                      call _wait
   396 0000054B E9C2FE                      jmp hang
   397                                  
   398                                  halt:
   399 0000054E B93200                      mov cx, 50
   400                                  halt_cls_loop:
   401 00000551 B80D0E                      mov ax, 0x0E0D
   402 00000554 CD10                        int 0x10
   403 00000556 B80A0E                      mov ax, 0x0E0A
   404 00000559 CD10                        int 0x10
   405 0000055B E2F4                        loop halt_cls_loop
   406                                      ;disable cursor
   407 0000055D B401                        mov ah, 0x01
   408 0000055F B90020                      mov cx, 0x2000 ;disable cursor
   409 00000562 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   410                                  
   411 00000564 FA                          cli
   412 00000565 F4                          hlt
   413                                  
   414                                  ;dx*cx is amount of ticks to wait
   415                                  _wait_PIT:
   416 00000566 51                          push cx
   417 00000567 E80500                      call _wait_PIT_once
   418 0000056A 59                          pop cx
   419 0000056B 4A                          dec dx
   420 0000056C 75F8                        jnz _wait_PIT
   421 0000056E C3                          ret
   422                                  
   423                                  ;cx, starting
   424                                  ;cx is amount of ticks to wait
   425                                  _wait_PIT_once:
   426 0000056F 51                          push cx
   427 00000570 E81100                      call _read_PIT_ticks
   428 00000573 53                          push bx ;bx = starting count
   429                                  _wait_PIT_once_loop:
   430 00000574 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   431                                      ;compute time difference = current count - start count
   432 00000577 58                          pop ax      ;current count is bx, starting count is ax
   433 00000578 29C3                        sub bx, ax  ;bx = time diff
   434 0000057A 59                          pop cx
   435 0000057B 51                          push cx
   436 0000057C 50                          push ax
   437 0000057D 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   438 0000057F 7CF3                        jl _wait_PIT_once_loop
   439 00000581 58                          pop ax
   440 00000582 58                          pop ax
   441 00000583 C3                          ret
   442                                  
   443                                  ;returns PIT ticks stored in bx
   444                                  _read_PIT_ticks:
   445 00000584 FA                          cli
   446 00000585 31C0                        xor ax, ax
   447 00000587 E643                        out 0x43, al
   448 00000589 E440                        in al, 0x40 ;LSB
   449 0000058B 88C3                        mov bl, al
   450 0000058D E440                        in al, 0x40 ;MSB
   451 0000058F 88C7                        mov bh, al
   452 00000591 FB                          sti
   453 00000592 C3                          ret
   454                                  
   455                                  ;PIT notes
   456                                  ;I/O port     Usage
   457                                  ;0x40         Channel 0 data port (read/write)
   458                                  ;0x41         Channel 1 data port (read/write)
   459                                  ;0x42         Channel 2 data port (read/write)
   460                                  ;0x43         Mode/Command register (write only, a read is ignored)
   461                                  ;
   462                                  ;Bits:  7 6 5 4 3 2 1 0
   463                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   464                                  ;       | | | | +--+-- Mode (0–5)
   465                                  ;       | | +-----+-- Access Mode: 
   466                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   467                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   468                                  ;subroutine to play a tone
   469                                  ;ax: frequency
   470                                  _tone:
   471 00000593 50                          push ax
   472                                      ;calculate divisor from frequency
   473                                      ;divisor = 1193182 / freq
   474                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   475 00000594 BA1200                      mov dx, 0x12
   476 00000597 B8DE34                      mov ax, 0x34DE
   477                                      ;load denominator into bx(frequency)
   478 0000059A 5B                          pop bx
   479                                      ;divide
   480 0000059B F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   481 0000059D 50                          push ax ;save on stack
   482                                  
   483 0000059E E82000                      call speaker_off
   484                                      ;write to PIT control register
   485 000005A1 B0B6                        mov al, 0b10110110
   486 000005A3 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   487                                      ;write divisor to channel 2 data port
   488 000005A5 58                          pop ax         ; Divisor
   489 000005A6 89C3                        mov bx, ax
   490 000005A8 88D8                        mov al, bl
   491 000005AA E642                        out 0x42, al         ; LSB first
   492 000005AC 88F8                        mov al, bh
   493 000005AE E642                        out 0x42, al         ; Then MSB
   494                                      
   495 000005B0 E80500                      call speaker_on
   496 000005B3 31C0                        xor ax, ax
   497 000005B5 8ED8                        mov ds, ax
   498 000005B7 C3                          ret
   499                                  
   500                                  ;tell speaker to not shut up
   501                                  speaker_on:
   502 000005B8 FA                          cli
   503 000005B9 E461                        in al, 0x61
   504 000005BB 0C03                        or al, 0b11
   505 000005BD E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   506 000005BF FB                          sti
   507 000005C0 C3                          ret
   508                                  ;tell speaker to shut up
   509                                  speaker_off:
   510 000005C1 FA                          cli
   511 000005C2 E461                        in al, 0x61
   512 000005C4 24FC                        and al, 0b11111100
   513 000005C6 E661                        out 0x61, al
   514 000005C8 FB                          sti
   515 000005C9 C3                          ret
   516                                  
   517                                  
   518                                  
   519                                  print_ax:
   520 000005CA 60                          pusha
   521                                  
   522 000005CB 50                          push ax
   523 000005CC B40E                        mov ah, 0xE
   524 000005CE B030                        mov al, '0'
   525 000005D0 CD10                        int 0x10
   526 000005D2 B40E                        mov ah, 0xE
   527 000005D4 B062                        mov al, 'b'
   528 000005D6 CD10                        int 0x10
   529 000005D8 58                          pop ax
   530                                  
   531 000005D9 89C3                        mov bx, ax
   532 000005DB B91000                      mov cx, 16
   533                                  print_ax_loop:
   534 000005DE 89D8                        mov ax, bx
   535 000005E0 83E001                      and ax, 1
   536 000005E3 83C030                      add ax, '0'
   537 000005E6 B40E                        mov ah, 0xE
   538 000005E8 50                          push ax
   539 000005E9 D1EB                        shr bx, 1
   540 000005EB E2F1                        loop print_ax_loop
   541 000005ED B91000                      mov cx, 16
   542                                  print_ax_loop2:
   543 000005F0 58                          pop ax
   544 000005F1 CD10                        int 0x10
   545 000005F3 E2FB                        loop print_ax_loop2
   546 000005F5 61                          popa
   547 000005F6 C3                          ret
   548                                  
   549                                  print_al:
   550 000005F7 60                          pusha
   551                                  
   552 000005F8 50                          push ax
   553 000005F9 B40E                        mov ah, 0xE
   554 000005FB B030                        mov al, '0'
   555 000005FD CD10                        int 0x10
   556 000005FF B40E                        mov ah, 0xE
   557 00000601 B062                        mov al, 'b'
   558 00000603 CD10                        int 0x10
   559 00000605 58                          pop ax
   560                                  
   561 00000606 30FF                        xor bh, bh
   562 00000608 88C3                        mov bl, al
   563 0000060A B90800                      mov cx, 8
   564                                  print_al_loop:
   565 0000060D 88D8                        mov al, bl
   566 0000060F 2401                        and al, 1
   567 00000611 0430                        add al, '0'
   568 00000613 B40E                        mov ah, 0xE
   569 00000615 50                          push ax
   570 00000616 D0EB                        shr bl, 1
   571 00000618 E2F3                        loop print_al_loop
   572 0000061A B90800                      mov cx, 8
   573                                  print_al_loop2:
   574 0000061D 58                          pop ax
   575 0000061E CD10                        int 0x10
   576 00000620 E2FB                        loop print_al_loop2
   577 00000622 61                          popa
   578 00000623 C3                          ret
   579                                  
   580                                  
   581                                  ;print value of ax in decimal
   582                                  print_ax_decimal:
   583 00000624 60                          pusha
   584                                      ;push 0 for print function to end
   585 00000625 31DB                        xor bx, bx
   586 00000627 53                          push bx
   587                                      ;if ax is already zero, just print a 0
   588 00000628 09C0                        or ax, ax
   589 0000062A 741C                        jz print_ax_decimal_zero
   590                                  print_ax_decimal_loop:
   591 0000062C 09C0                        or ax, ax
   592 0000062E 740D                        jz print_ax_decimal_printloop
   593 00000630 31D2                        xor dx, dx
   594 00000632 BB0A00                      mov bx, 10
   595                                      ;16 bit division, dx:ax / bx = ax, remainder dx
   596 00000635 F7F3                        div bx
   597                                      ;push remainder in ascii
   598 00000637 83C230                      add dx, '0'
   599 0000063A 52                          push dx
   600                                      ;loop
   601 0000063B EBEF                        jmp print_ax_decimal_loop
   602                                  print_ax_decimal_printloop:
   603                                      ;print digits pushed on the stack
   604 0000063D 58                          pop ax
   605                                      ;if popped value is 0, exit
   606 0000063E 09C0                        or ax, ax
   607 00000640 740D                        jz print_ax_decimal_end
   608                                      ;print value
   609 00000642 B40E                        mov ah, 0xE
   610 00000644 CD10                        int 0x10
   611 00000646 EBF5                        jmp print_ax_decimal_printloop
   612                                  print_ax_decimal_zero:
   613 00000648 5B                          pop bx
   614 00000649 B40E                        mov ah, 0xE
   615 0000064B B030                        mov al, '0'
   616 0000064D CD10                        int 0x10
   617                                  print_ax_decimal_end:
   618 0000064F 61                          popa
   619 00000650 C3                          ret
   620                                  
   621                                  
   622                                  
   623                                  
   624                                  
   625                                  
   626 00000651 0D0A                        msg db 0xD, 0xA
   627 00000653 46313A2062696F7320-         db 'F1: bios setup/restart/boot next', 0xD, 0xA
   627 0000065C 73657475702F726573-
   627 00000665 746172742F626F6F74-
   627 0000066E 206E6578740D0A     
   628 00000675 46323A207265737461-         db 'F2: restart (far jump to reset vector)', 0xD, 0xA
   628 0000067E 72742028666172206A-
   628 00000687 756D7020746F207265-
   628 00000690 73657420766563746F-
   628 00000699 72290D0A           
   629 0000069D 46333A20636C656172-         db 'F3: clear screen', 0xD, 0xA
   629 000006A6 2073637265656E0D0A 
   630 000006AF 46343A2068616C740D-         db 'F4: halt', 0xD, 0xA
   630 000006B8 0A                 
   631 000006B9 46353A2042494F5320-         db 'F5: BIOS beep', 0xD, 0xA
   631 000006C2 626565700D0A       
   632 000006C8 46363A206C6F616420-         db 'F6: load kernel and enter protected mode', 0xD, 0xA
   632 000006D1 6B65726E656C20616E-
   632 000006DA 6420656E7465722070-
   632 000006E3 726F74656374656420-
   632 000006EC 6D6F64650D0A       
   633 000006F2 46373A2072656C6F61-         db 'F7: reload NuckBoot from boot device', 0xD, 0xA
   633 000006FB 64204E75636B426F6F-
   633 00000704 742066726F6D20626F-
   633 0000070D 6F7420646576696365-
   633 00000716 0D0A               
   634 00000718 202020205669727475-         db '    Virtual piano:', 0xD, 0xA
   634 00000721 616C207069616E6F3A-
   634 0000072A 0D0A               
   635 0000072C 507265737320272066-         db 'Press ', 0x27, ' for lower octave, Press ', 0x22, ' for higher octave, Press ', 0x3B, ' to reset octave', 0xD, 0xA, 0
   635 00000735 6F72206C6F77657220-
   635 0000073E 6F63746176652C2050-
   635 00000747 72657373202220666F-
   635 00000750 722068696768657220-
   635 00000759 6F63746176652C2050-
   635 00000762 72657373203B20746F-
   635 0000076B 207265736574206F63-
   635 00000774 746176650D0A00     
   636                                  
   637 0000077B 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   637 00000784 206B65726E656C2E2E-
   637 0000078D 2E0D0A00           
   638 00000791 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   638 0000079A 616465642C20737769-
   638 000007A3 746368696E6720746F-
   638 000007AC 2070726F7465637465-
   638 000007B5 64206D6F64652E2E2E-
   638 000007BE 0D0A00             
   639 000007C1 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   640 000007C8 0D0A                        oslogo db 0xD, 0xA
   641 000007CA 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   641 000007D3 2020202020205F2020-
   641 000007DC 205F20202020202020-
   641 000007E5 20202020205F202020-
   641 000007EE 2020205F5F5F5F2020-
   641 000007F7 202020202020202020-
   641 00000800 2020205F2020202020-
   641 00000809 4F532056657273696F-
   641 00000812 6E2020200D0A       
   642 00000818 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.0       ', 0xD, 0xA
   642 00000821 20202020207C205C20-
   642 0000082A 7C207C5F2020205F20-
   642 00000833 205F5F5F7C207C205F-
   642 0000083C 5F207C205F5F202920-
   642 00000845 205F5F5F2020205F5F-
   642 0000084E 5F207C207C5F202020-
   642 00000857 202020312E30202020-
   642 00000860 202020200D0A       
   643 00000866 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   643 0000086F 20202020207C20205C-
   643 00000878 7C207C207C207C207C-
   643 00000881 2F205F5F7C207C2F20-
   643 0000088A 2F207C20205F205C20-
   643 00000893 2F205F205C202F205F-
   643 0000089C 205C7C205F5F7C2020-
   643 000008A5 202020202020202020-
   643 000008AE 202020200D0A       
   644 000008B4 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   644 000008BD 20202020207C207C5C-
   644 000008C6 20207C207C5F7C207C-
   644 000008CF 20285F5F7C2020203C-
   644 000008D8 20207C207C5F29207C-
   644 000008E1 20285F29207C20285F-
   644 000008EA 29207C207C5F202020-
   644 000008F3 202020202020202020-
   644 000008FC 202020200D0A       
   645 00000902 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   645 0000090B 20202020207C5F7C20-
   645 00000914 5C5F7C5C5F5F2C5F7C-
   645 0000091D 5C5F5F5F7C5F7C5C5F-
   645 00000926 5C207C5F5F5F5F2F20-
   645 0000092F 5C5F5F5F2F205C5F5F-
   645 00000938 5F2F205C5F5F7C2020-
   645 00000941 202020202020202020-
   645 0000094A 202020200D0A       
   646 00000950 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   646 00000959 202020202020202020-
   646 00000962 20226F706572617469-
   646 0000096B 6E672073797374656D-
   646 00000974 206F66207468652066-
   646 0000097D 757475726522202854-
   646 00000986 4D290D0A00         
   647                                  
   648 0000098B 00                          hang_virtual_piano_mode db 0b00
   649                                  
   650 0000098C 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   650 00000995 6176650D0A00       
   651 0000099B 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   651 000009A4 650D0A00           
   652 000009A8 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   652 000009B1 76650D0A00         
   653                                  
   654 000009B6 3D00                        keylen dw 61
   655 000009B8 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   655 000009C1 307177657274797569-
   655 000009CA 6F706173646667686A-
   655 000009D3 6B6C7A786376626E6D 
   656 000009DC 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   656 000009E5 455459494F50534447-
   656 000009EE 484A4C5A435642     
   657                                  
   658 000009F5 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   658 000009FE 006E007B00         
   659 00000A03 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   659 00000A0C 00DC00F600         
   660 00000A11 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   660 00000A1A 01B801EE01         
   661 00000A1F 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   661 00000A28 037003DC03         
   662 00000A2D 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   662 00000A36 06E006B807         
   663 00000A3B 2D08                        dw 2093
   664                                  
   665 00000A3D 45004E005C00680075-         dw 69, 78, 92, 104, 117
   665 00000A46 00                 
   666 00000A47 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   666 00000A50 00                 
   667 00000A51 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   667 00000A5A 01                 
   668 00000A5B 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   668 00000A64 03                 
   669 00000A65 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   669 00000A6E 07                 
   670                                  
   671 00000A6F 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   671 00000A78 0037003E00         
   672 00000A7D 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   672 00000A86 006E007B00         
   673 00000A8B 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   673 00000A94 00DC00F600         
   674 00000A99 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   674 00000AA2 01B801EE01         
   675 00000AA7 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   675 00000AB0 037003DC03         
   676 00000AB5 1704                        dw 1047
   677                                  
   678 00000AB7 230027002E0034003A-         dw 35, 39, 46, 52, 58
   678 00000AC0 00                 
   679 00000AC1 45004E005C00680075-         dw 69, 78, 92, 104, 117
   679 00000ACA 00                 
   680 00000ACB 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   680 00000AD4 00                 
   681 00000AD5 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   681 00000ADE 01                 
   682 00000ADF 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   682 00000AE8 03                 
   683                                  
   684 00000AE9 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   684 00000AF2 00DC00F600         
   685 00000AF7 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   685 00000B00 01B801EE01         
   686 00000B05 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   686 00000B0E 037003DC03         
   687 00000B13 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   687 00000B1C 06E006B807         
   688 00000B21 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   688 00000B2A 0CC00D6F0F         
   689 00000B2F 5A10                        dw 4186
   690                                  
   691 00000B31 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   691 00000B3A 00                 
   692 00000B3B 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   692 00000B44 01                 
   693 00000B45 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   693 00000B4E 03                 
   694 00000B4F 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   694 00000B58 07                 
   695 00000B59 A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   695 00000B62 0E                 
   696                                  
   697                                  
   698 00000B63 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   698 00000B6C 6164206661696C7572-
   698 00000B75 652C20726573657474-
   698 00000B7E 696E672E2E2E0D0A00 
   699 00000B87 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   699 00000B90 6164206661696C6564-
   699 00000B99 2C20676F696E672062-
   699 00000BA2 61636B20746F207265-
   699 00000BAB 616C206D6F64652E2E-
   699 00000BB4 2E0D0A00           
   700 00000BB8 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   700 00000BC1 616420737563636573-
   700 00000BCA 730D0A00           
   701                                  
   702                                  
   703                                  
   704                                  ;code segment descriptor
   705                                  ;Base            32b: starting location of segment
   706                                  ;Limit           20b: size of limit
   707                                  ;Present          1b: Is this segment used/is a valid segment
   708                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   709                                  ;Type             1b: 1 if segment is code or data segment
   710                                  ;Flags(1b):
   711                                  ;  Type flags(4b):
   712                                  ;    1. Code? Will segment contain code
   713                                  ;    2. Conforming: can this code be executed from lower privileged segments
   714                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   715                                  ;            becomes an expand down segment
   716                                  ;    3. Readable, can this segment be read?
   717                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   718                                  ;            segment becomes read only
   719                                  ;    4. Accessed: set to 1 when CPU is using the segment
   720                                  ;  Other flags(4b):
   721                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   722                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   723                                  ;    3 & 4: 64 bit tetio, just set to 0
   724                                  
   725                                  ;offset of the segment descriptors relative to the beginning of the GDT
   726                                  CODE_SEG equ GDT_code - GDT_start
   727                                  DATA_SEG equ GDT_data - GDT_start
   728                                  
   729                                  ;kernel location is 0x10000
   730                                  KERNEL_LOCATION equ 0x1000
   731                                  
   732                                  GDT_start:
   733                                      GDT_null:
   734 00000BCE 00000000                        dd 0 ;(32 bits)
   735 00000BD2 00000000                        dd 0 ;(32 bits)
   736                                      GDT_code:
   737                                          ;base: 0
   738                                          ;limit: 0xFFFFF
   739                                          ;PPT: 1001
   740                                          ;Type: 1010
   741                                          ;Other: 1100
   742                                  
   743                                          ;first 16 bits of limit
   744 00000BD6 FFFF                            dw 0xFFFF
   745                                          ;first 24 bits of base
   746 00000BD8 0000                            dw 0x0000 ;16 bits
   747 00000BDA 00                              db 0x00   ; 8 bits
   748                                          ;PPT + Type
   749 00000BDB 9A                              db 0b10011010
   750                                          ;other + last 4 bits of limit
   751 00000BDC CF                              db 0b11001111
   752                                          ;last 8 bits of base
   753 00000BDD 00                              db 0b00000000
   754                                      GDT_data:
   755                                          ;base: 0
   756                                          ;limit: 0xFFFFF
   757                                          ;PPT: 1001
   758                                          ;Type: 0010
   759                                          ;Other: 1100
   760                                  
   761                                          ;first 16 bits of limit
   762 00000BDE FFFF                            dw 0xFFFF
   763                                          ;first 24 bits of base
   764 00000BE0 0000                            dw 0x0000 ;16 bits
   765 00000BE2 00                              db 0x00   ; 8 bits
   766                                          ;PPT + Type
   767 00000BE3 92                              db 0b10010010
   768                                          ;other + last 4 bits of limit
   769 00000BE4 CF                              db 0b11001111
   770                                          ;last 8 bits of base
   771 00000BE5 00                              db 0b00000000
   772                                  GDT_end:
   773                                  GDT_descriptor:
   774                                      ;size of GDT(16 bits)
   775 00000BE6 1700                        dw GDT_end - GDT_start - 1
   776                                      ;start of GDT(32 bits)
   777 00000BE8 [CE0B0000]                  dd GDT_start
   778                                  
   779                                  
   780                                  _kernel_load:
   781 00000BEC 31FF                        xor di, di ;counter for retry
   782                                  _kernel_load_loop:
   783                                  
   784 00000BEE 31C0                        xor ax, ax
   785 00000BF0 8ED8                        mov ds, ax
   786 00000BF2 BE[CF00]                    mov si, disk_read_msg ;Reading from disk: diskNum
   787 00000BF5 E8A1F4                      call _printstr
   788                                  
   789                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   790 00000BF8 B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
   791 00000BFB B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
   792 00000BFE 30F6                        xor dh, dh ;head number CHS
   793 00000C00 8A16[E200]                  mov dl, [diskNum] ;drive number
   794                                      ;Address to store values in: es:bx
   795 00000C04 BB0010                      mov bx, 0x1000
   796 00000C07 8EC3                        mov es, bx
   797 00000C09 31DB                        xor bx, bx
   798                                  
   799 00000C0B CD13                        int 0x13 ;disk read
   800 00000C0D 720B                        jc __kernel_load_fail
   801                                  
   802                                      ;disk read success
   803 00000C0F 31C0                        xor ax, ax
   804 00000C11 8ED8                        mov ds, ax
   805 00000C13 BE[B80B]                    mov si, kernel_load_success
   806 00000C16 E880F4                      call _printstr
   807 00000C19 C3                          ret
   808                                  
   809                                  __kernel_load_fail:
   810                                      ;if number of attempts is over or equal 8
   811 00000C1A 83FF08                      cmp di, 8
   812 00000C1D 7D2D                        jge __kernel_load_fail_final
   813                                  
   814 00000C1F 31C0                        xor ax, ax
   815 00000C21 8ED8                        mov ds, ax
   816 00000C23 BE[630B]                    mov si, kernel_load_fail
   817 00000C26 E870F4                      call _printstr
   818                                  
   819                                      ;attempt to reset disk
   820 00000C29 31C0                        xor ax, ax ;scancode ah = 0
   821 00000C2B 8A16[E200]                  mov dl, [diskNum]
   822 00000C2F CD13                        int 0x13 ;reset disk system
   823                                  
   824 00000C31 47                          inc di
   825                                      ;update number of attempts
   826 00000C32 89F8                        mov ax, di
   827 00000C34 83C030                      add ax, '0'
   828 00000C37 A2[EE00]                    mov [attempt_num], al
   829                                  
   830 00000C3A 31C0                        xor ax, ax
   831 00000C3C 8ED8                        mov ds, ax
   832 00000C3E BE[E600]                    mov si, attempts_msg
   833 00000C41 E855F4                      call _printstr
   834                                  
   835 00000C44 B90020                      mov cx, 0x2000
   836 00000C47 E87BF4                      call _wait
   837                                  
   838 00000C4A EBA2                        jmp _kernel_load_loop
   839                                  
   840                                  __kernel_load_fail_final:
   841 00000C4C 31C0                        xor ax, ax
   842 00000C4E 8ED8                        mov ds, ax
   843 00000C50 BE[870B]                    mov si, kernel_load_fail_final
   844 00000C53 E843F4                      call _printstr
   845 00000C56 58                          pop ax
   846 00000C57 E9B6F7                      jmp hang  ;go back to 16 bit hang loop if fail
   847                                  
   848                                  
   849                                  
   850                                  
   851                                  
   852                                  
   853                                  
   854                                  
   855                                  
   856                                  
   857                                  
   858                                  
   859                                  
   860                                  
   861                                  
   862                                  
   863 00000C5A 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   863 00000C63 6F6E74726F6C6C6572-
   863 00000C6C 20696E666F20737563-
   863 00000C75 63657373210D0A00   
   864 00000C7D 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   864 00000C86 6F6E74726F6C6C6572-
   864 00000C8F 20696E666F20666169-
   864 00000C98 6C210D0A5072657373-
   864 00000CA1 20616E79206B657920-
   864 00000CAA 746F20636F6E74696E-
   864 00000CB3 75652E2E2E0D0A00   
   865                                  
   866 00000CBB 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   866 00000CC4 6F6C6C657220696E66-
   866 00000CCD 6F3A0D0A00         
   867 00000CD2 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   867 00000CDB 6F6465732070747228-
   867 00000CE4 7365673A6F6666293A-
   867 00000CED 2000               
   868                                  
   869 00000CEF 56424520676574206D-         VBEStuff_get_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   869 00000CF8 6F646520696E666F20-
   869 00000D01 6661696C210D0A5072-
   869 00000D0A 65737320616E79206B-
   869 00000D13 657920746F20636F6E-
   869 00000D1C 74696E75652E2E2E0D-
   869 00000D25 0A00               
   870                                  
   871 00000D27 206270703A2000              print_VBE_mode_text_msg db " bpp: ", 0
   872                                  
   873 00000D2E [440D]                      VBE_mode_info_block_fb_support dw VBE_mode_info_block_fb_support_f
   874 00000D30 [320D]                      dw VBE_mode_info_block_fb_support_t
   875                                  
   876 00000D32 4C696E656172204642-         VBE_mode_info_block_fb_support_t db "Linear FB: YUH UH", 0
   876 00000D3B 3A2059554820554800 
   877 00000D44 4C696E656172204642-         VBE_mode_info_block_fb_support_f db "Linear FB: NUH UH", 0
   877 00000D4D 3A204E554820554800 
   878                                  
   879                                      
   880                                  
   881                                  ;FAILSTATES
   882                                  VBEStuff_get_controller_info_fail:
   883 00000D56 31C0                        xor ax, ax
   884 00000D58 8ED8                        mov ds, ax
   885 00000D5A BE[7D0C]                    mov si, VBEStuff_get_controller_info_fail_msg
   886 00000D5D E839F3                      call _printstr
   887                                      ;blocking keyboard input
   888 00000D60 31C0                        xor ax, ax
   889 00000D62 CD16                        int 0x16 ;keyboard services
   890 00000D64 E943F3                      jmp biosboot_pc
   891                                  VBEStuff_get_mode_info_fail:
   892 00000D67 31C0                        xor ax, ax
   893 00000D69 8ED8                        mov ds, ax
   894 00000D6B BE[EF0C]                    mov si, VBEStuff_get_mode_info_fail_msg
   895 00000D6E E828F3                      call _printstr
   896                                      ;blocking keyboard input
   897 00000D71 31C0                        xor ax, ax
   898 00000D73 CD16                        int 0x16 ;keyboard services
   899 00000D75 E932F3                      jmp biosboot_pc
   900                                  
   901                                  
   902                                  
   903                                  
   904                                  VBEStuff:
   905                                      ;get controller info
   906 00000D78 31C0                        xor ax, ax ;es:di
   907 00000D7A 8EC0                        mov es, ax
   908 00000D7C BF[020F]                    mov di, VBE_info_block_start    
   909 00000D7F B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
   910 00000D82 CD10                        int 0x10
   911 00000D84 83F84F                      cmp ax, 0x004F
   912 00000D87 75CD                        jne VBEStuff_get_controller_info_fail
   913                                  
   914 00000D89 31C0                        xor ax, ax
   915 00000D8B 8ED8                        mov ds, ax
   916 00000D8D BE[5A0C]                    mov si, VBEStuff_get_controller_info_success_msg
   917 00000D90 E806F3                      call _printstr
   918                                  
   919                                      ;print controller info
   920 00000D93 31C0                        xor ax, ax
   921 00000D95 8ED8                        mov ds, ax
   922 00000D97 BE[BB0C]                    mov si, VBEStuff_get_controller_info_print_msg
   923 00000D9A E8FCF2                      call _printstr
   924                                  
   925 00000D9D A0[020F]                    mov al, [VBE_info_block_signature]
   926 00000DA0 B40E                        mov ah, 0xE
   927 00000DA2 CD10                        int 0x10
   928 00000DA4 A1[030F]                    mov ax, [VBE_info_block_signature+1]
   929 00000DA7 B40E                        mov ah, 0xE
   930 00000DA9 CD10                        int 0x10
   931 00000DAB A1[040F]                    mov ax, [VBE_info_block_signature+2]
   932 00000DAE B40E                        mov ah, 0xE
   933 00000DB0 CD10                        int 0x10
   934 00000DB2 A1[050F]                    mov ax, [VBE_info_block_signature+3]
   935 00000DB5 B40E                        mov ah, 0xE
   936 00000DB7 CD10                        int 0x10
   937 00000DB9 B8200E                      mov ax, 0xE20
   938 00000DBC CD10                        int 0x10
   939 00000DBE A1[060F]                    mov ax, [VBE_info_block_version]
   940 00000DC1 B00E                        mov al, 0xE
   941 00000DC3 86C4                        xchg ah, al
   942 00000DC5 0430                        add al, '0'
   943 00000DC7 CD10                        int 0x10
   944                                  
   945 00000DC9 31C0                        xor ax, ax
   946 00000DCB 8ED8                        mov ds, ax
   947 00000DCD BE[D20C]                    mov si, VBEStuff_get_controller_info_print_msg1
   948 00000DD0 E8C6F2                      call _printstr
   949                                  
   950 00000DD3 A1[120F]                    mov ax, [VBE_info_block_video_mode_segment]
   951 00000DD6 E8F1F7                      call print_ax
   952 00000DD9 B40E                        mov ah, 0xE
   953 00000DDB B03A                        mov al, ':'
   954 00000DDD CD10                        int 0x10
   955 00000DDF A1[100F]                    mov ax, [VBE_info_block_video_mode_offset]
   956 00000DE2 E8E5F7                      call print_ax
   957                                  
   958 00000DE5 B80D0E                      mov ax, 0x0E0D
   959 00000DE8 CD10                        int 0x10
   960 00000DEA B80A0E                      mov ax, 0x0E0A
   961 00000DED CD10                        int 0x10
   962                                  
   963                                      ;iter mode numbers and find the good one
   964                                      ;get start of modes array and put into fs:si
   965 00000DEF A1[120F]                    mov ax, [VBE_info_block_video_mode_segment] ;make sure fs is the correct value
   966 00000DF2 8EE0                        mov fs, ax
   967 00000DF4 8B36[100F]                  mov si, [VBE_info_block_video_mode_offset]
   968                                  VBEStuff_iter_modes_loop: ;cannot change fs, si 
   969 00000DF8 648B04                      mov ax, fs:[si] ;ax = current mode number
   970                                  
   971 00000DFB 50                          push ax
   972 00000DFC 0FA0                        push fs
   973 00000DFE 56                          push si
   974                                      ;now print mode in text form
   975 00000DFF E81500                      call print_VBE_mode_text
   976 00000E02 5E                          pop si
   977 00000E03 0FA1                        pop fs
   978 00000E05 58                          pop ax
   979                                  
   980                                      ;if mode number is 0xFFFF, exit program
   981 00000E06 83F8FF                      cmp ax, 0xFFFF
   982 00000E09 740B                        je VBEStuff_iter_modes_exit
   983                                  
   984                                      ;BRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR BOMBARDIRO CROCODILO
   985                                      
   986                                      ;increment si
   987 00000E0B 83C602                      add si, 2
   988                                      ;wait a tiny bit of time
   989 00000E0E B90001                      mov cx, 0x100
   990 00000E11 E8B1F2                      call _wait
   991                                  
   992 00000E14 EBE2                        jmp VBEStuff_iter_modes_loop
   993                                  VBEStuff_iter_modes_exit:
   994 00000E16 C3                          ret
   995                                  
   996                                  
   997                                  
   998                                  
   999                                  
  1000                                  
  1001                                  
  1002                                  
  1003                                  print_VBE_mode_text:
  1004                                      ;print value in ax
  1005 00000E17 E8B0F7                      call print_ax
  1006                                  
  1007                                      ;print space
  1008 00000E1A 89C3                        mov bx, ax
  1009 00000E1C B8200E                      mov ax, 0x0E20
  1010 00000E1F CD10                        int 0x10
  1011 00000E21 89D8                        mov ax, bx
  1012                                  
  1013                                      ;if mode number is 0xFFFF, exit program
  1014 00000E23 83F8FF                      cmp ax, 0xFFFF
  1015 00000E26 746D                        je print_VBE_mode_text_end
  1016                                  
  1017                                      ;now get mode info
  1018 00000E28 31DB                        xor bx, bx
  1019 00000E2A 8EDB                        mov ds, bx
  1020                                  
  1021 00000E2C 89C1                        mov cx, ax ;cx = mode number
  1022 00000E2E B8014F                      mov ax, 0x4F01 ;scancode
  1023                                      ;es:di = 256b buffer
  1024 00000E31 31D2                        xor dx, dx
  1025 00000E33 8EC2                        mov es, dx
  1026 00000E35 BF[0211]                    mov di, VBE_mode_info_block_start
  1027 00000E38 CD10                        int 0x10
  1028 00000E3A 83F84F                      cmp ax, 0x004F
  1029 00000E3D 0F8526FF                    jne VBEStuff_get_mode_info_fail
  1030                                  
  1031                                  
  1032                                      ;now print out width and height
  1033 00000E41 31C0                        xor ax, ax
  1034 00000E43 8ED8                        mov ds, ax
  1035 00000E45 A1[1411]                    mov ax, [VBE_mode_info_block_width]
  1036 00000E48 E8D9F7                      call print_ax_decimal
  1037 00000E4B B40E                        mov ah, 0xE
  1038 00000E4D B078                        mov al, 'x'
  1039 00000E4F CD10                        int 0x10
  1040 00000E51 A1[1611]                    mov ax, [VBE_mode_info_block_height]
  1041 00000E54 E8CDF7                      call print_ax_decimal
  1042 00000E57 B8200E                      mov ax, 0x0E20
  1043 00000E5A CD10                        int 0x10
  1044                                      ;print space
  1045 00000E5C B8200E                      mov ax, 0x0E20
  1046 00000E5F CD10                        int 0x10
  1047                                      ;print if it supports linear framebuffer or not
  1048 00000E61 8B1E[0211]                  mov bx, [VBE_mode_info_block_attributes]
  1049 00000E65 81E38000                    and bx, 0b10000000 ;if bit 7 is 1 it supports
  1050 00000E69 C1EB06                      shr bx, 6
  1051 00000E6C 81C3[2E0D]                  add bx, VBE_mode_info_block_fb_support
  1052 00000E70 31C0                        xor ax, ax
  1053 00000E72 8ED8                        mov ds, ax
  1054 00000E74 8B37                        mov si, [bx] ;pointer array shenanigans
  1055 00000E76 E820F2                      call _printstr
  1056                                      ;print space and msg
  1057 00000E79 31C0                        xor ax, ax
  1058 00000E7B 8ED8                        mov ds, ax
  1059 00000E7D BE[270D]                    mov si, print_VBE_mode_text_msg
  1060 00000E80 E816F2                      call _printstr
  1061                                      ;print bits per pixel
  1062 00000E83 31C0                        xor ax, ax
  1063 00000E85 A0[1D11]                    mov al, [VBE_mode_info_block_bpp]
  1064 00000E88 E899F7                      call print_ax_decimal
  1065                                  
  1066 00000E8B B80D0E                      mov ax, 0x0E0D
  1067 00000E8E CD10                        int 0x10
  1068 00000E90 B80A0E                      mov ax, 0x0E0A
  1069 00000E93 CD10                        int 0x10
  1070                                  print_VBE_mode_text_end:
  1071 00000E95 C3                          ret
  1072                                  
  1073                                  
  1074                                  
  1075                                  
  1076                                  
  1077                                  
  1078                                  
  1079                                  
  1080                                  
  1081                                  
  1082                                  boot_pmode:
  1083 00000E96 31C0                        xor ax, ax
  1084 00000E98 8ED8                        mov ds, ax
  1085 00000E9A BE[7B07]                    mov si, boot_pmode_msg
  1086 00000E9D E8F9F1                      call _printstr
  1087                                  
  1088 00000EA0 E849FD                      call _kernel_load
  1089                                  
  1090 00000EA3 31C0                        xor ax, ax
  1091 00000EA5 8ED8                        mov ds, ax
  1092 00000EA7 BE[9107]                    mov si, kernel_loaded_msg
  1093 00000EAA E8ECF1                      call _printstr
  1094                                  
  1095 00000EAD B90030                      mov cx, 0x3000
  1096 00000EB0 E812F2                      call _wait
  1097                                  
  1098 00000EB3 B93200                      mov cx, 50
  1099                                  clear_loop:
  1100 00000EB6 B80D0E                      mov ax, 0x0E0D
  1101 00000EB9 CD10                        int 0x10
  1102 00000EBB B80A0E                      mov ax, 0x0E0A
  1103 00000EBE CD10                        int 0x10
  1104 00000EC0 E2F4                        loop clear_loop
  1105                                      
  1106                                      ;set new graphics mode
  1107                                  
  1108                                      ;Mode 3h
  1109                                      ;VGA 80x25 text mode
  1110 00000EC2 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1111 00000EC5 CD10                        int 0x10 ;bios call video services
  1112                                      ;disable cursor
  1113 00000EC7 B401                        mov ah, 0x01
  1114 00000EC9 B90020                      mov cx, 0x2000 ;disable cursor
  1115 00000ECC CD10                        int 0x10 ;int 0x10, 1: set cursor type
  1116                                  
  1117                                      ;Mode 12h
  1118                                      ;VGA 640x480 16 color
  1119                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1120                                      ;int 0x10 ;bios call video services
  1121                                  
  1122                                      ;VBE graphics
  1123 00000ECE E8A7FE                      call VBEStuff
  1124                                  
  1125 00000ED1 FA                          cli
  1126 00000ED2 0F0116[E60B]                lgdt [GDT_descriptor] ;load GDT
  1127                                      
  1128                                      ;change last bit of cr0 to 1
  1129 00000ED7 0F20C0                      mov eax, cr0
  1130 00000EDA 6683C801                    or eax, 1
  1131 00000EDE 0F22C0                      mov cr0, eax
  1132                                      
  1133                                      ;PROTECTED MODE!
  1134                                      ;far jump to code segment
  1135 00000EE1 EA[E60E]0800                jmp CODE_SEG:pmode
  1136                                  
  1137                                  BITS 32
  1138                                  pmode:
  1139 00000EE6 66B81000                    mov ax, DATA_SEG ;setup segments
  1140 00000EEA 8ED8                        mov ds, ax
  1141 00000EEC 8ED0                        mov ss, ax
  1142 00000EEE 8EC0                        mov es, ax
  1143 00000EF0 8EE0                        mov fs, ax
  1144 00000EF2 8EE8                        mov gs, ax
  1145 00000EF4 BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1146 00000EF9 89EC                        mov esp, ebp
  1147                                  
  1148                                      ;jump to loaded kernel
  1149 00000EFB E9(00000100)                jmp 0x10000
  1150 00000F00 EBFE                        jmp $
  1151                                  
  1152                                  
  1153                                  
  1154                                  
  1155                                  
  1156                                  
  1157                                  
  1158                                  
  1159                                  
  1160                                  
  1161                                  ; TOTAL of 512 bytes
  1162                                  VBE_info_block_start:
  1163 00000F02 4E45494E                    VBE_info_block_signature db 'NEIN'
  1164 00000F06 0000                        VBE_info_block_version dw 0
  1165 00000F08 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
  1166 00000F0C 00000000                    VBE_info_block_capabilities dd 0
  1167 00000F10 0000                        VBE_info_block_video_mode_offset dw 0
  1168 00000F12 0000                        VBE_info_block_video_mode_segment dw 0
  1169 00000F14 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
  1170 00000F16 00<rep 1ECh>                times 492 db 0 ;reserved
  1171                                  VBE_info_block_end:
  1172                                  
  1173                                  ; TOTAL of 256 bytes
  1174                                  VBE_mode_info_block_start:
  1175 00001102 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
  1176 00001104 00                          VBE_mode_info_block_window_a db 0 ;deprecated
  1177 00001105 00                          VBE_mode_info_block_window_b db 0 ;deprecated
  1178 00001106 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
  1179 00001108 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
  1180 0000110A 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
  1181 0000110C 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
  1182 0000110E 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
  1183 00001112 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
  1184                                  
  1185 00001114 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
  1186 00001116 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
  1187 00001118 0000                        VBE_mode_info_block_char_width dw 0 ;in pixels, unused
  1188 0000111A 0000                        VBE_mode_info_block_char_height dw 0 ;in pixels, unused
  1189 0000111C 00                          VBE_mode_info_block_planes_count db 0
  1190 0000111D 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
  1191 0000111E 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
  1192 0000111F 00                          VBE_mode_info_block_memory_model db 0
  1193 00001120 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
  1194 00001121 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
  1195 00001122 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
  1196                                  
  1197                                      ;size and pos of masks
  1198 00001123 00                          VBE_mode_info_block_red_mask db 0
  1199 00001124 00                          VBE_mode_info_block_red_pos db 0
  1200 00001125 00                          VBE_mode_info_block_green_mask db 0
  1201 00001126 00                          VBE_mode_info_block_green_pos db 0
  1202 00001127 00                          VBE_mode_info_block_blue_mask db 0
  1203 00001128 00                          VBE_mode_info_block_blue_pos db 0
  1204 00001129 00                          VBE_mode_info_block_reserved_mask db 0
  1205 0000112A 00                          VBE_mode_info_block_reserved_pos db 0
  1206 0000112B 00                          VBE_mode_info_block_direct_color_attributes db 0
  1207                                  
  1208                                      ;added in revision 2.0
  1209 0000112C 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
  1210 00001130 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
  1211 00001134 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
  1212 00001136 CE                          VBE_mode_info_block_reserved db 206 ;available in revision 3.0, useless
  1213                                  VBE_mode_info_block_end:
  1214                                  
  1215                                  
  1216                                  
  1217                                  
  1218 00001137 00<rep 16C9h>           times 10240-($-$$) db 0 ;total length of binary 20 sector
  1219                                                          ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:codedb 0x69
