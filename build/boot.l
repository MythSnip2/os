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
    18                                  
    19                                      ;save the disk number
    20 00000008 8816[E000]                  mov [diskNum], dl
    21                                  
    22                                      ;initialize stack
    23 0000000C 8ED0                        mov ss, ax
    24 0000000E BCFF7B                      mov sp, 0x7BFF ;stack grows below bootloader
    25                                  
    26                                      ;set video mode to text mode(80x25)
    27 00000011 B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
    28 00000014 CD10                        int 0x10 ;bios call video services
    29                                  
    30                                  
    31                                      ;enable interrupts
    32 00000016 FB                          sti
    33                                  
    34 00000017 31C0                        xor ax, ax       ;print bootloader start msg
    35 00000019 8ED8                        mov ds, ax
    36 0000001B BE[F500]                    mov si, startup_msg
    37 0000001E E87600                      call _printstr
    38                                  
    39 00000021 E80300                      call _disk_read ;read bootloader code to ram
    40                                  
    41 00000024 E9D903                      jmp main
    42                                  
    43                                  _disk_read:
    44 00000027 31FF                        xor di, di ;counter for retry
    45                                  _disk_read_loop:
    46                                  
    47 00000029 31C0                        xor ax, ax
    48 0000002B 8ED8                        mov ds, ax
    49 0000002D BE[CD00]                    mov si, disk_read_msg ;Reading from disk: diskNum
    50 00000030 E86400                      call _printstr
    51                                  
    52                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    53                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    54 00000033 B81302                      mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    55 00000036 B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    56 00000039 30F6                        xor dh, dh ;head number CHS
    57 0000003B 8A16[E000]                  mov dl, [diskNum] ;drive number
    58                                      ;Address to store values in: es:bx which is 0:7E00
    59 0000003F 31DB                        xor bx, bx
    60 00000041 8EC3                        mov es, bx
    61 00000043 BB007E                      mov bx, 0x7E00
    62 00000046 CD13                        int 0x13 ;disk read
    63 00000048 720B                        jc __disk_read_fail
    64                                  
    65                                      ;disk read success
    66 0000004A 31C0                        xor ax, ax
    67 0000004C 8ED8                        mov ds, ax
    68 0000004E BE[5C01]                    mov si, disk_read_success
    69 00000051 E84300                      call _printstr
    70 00000054 C3                          ret
    71                                  
    72                                  __disk_read_fail:
    73                                      ;if number of attempts is over or equal 8
    74 00000055 83FF08                      cmp di, 8
    75 00000058 7D2D                        jge __disk_read_fail_final
    76                                  
    77 0000005A 31C0                        xor ax, ax
    78 0000005C 8ED8                        mov ds, ax
    79 0000005E BE[0901]                    mov si, disk_read_fail
    80 00000061 E83300                      call _printstr
    81                                  
    82                                      ;attempt to reset disk
    83 00000064 31C0                        xor ax, ax ;scancode ah = 0
    84 00000066 8A16[E000]                  mov dl, [diskNum]
    85 0000006A CD13                        int 0x13 ;reset disk system
    86                                  
    87 0000006C 47                          inc di
    88                                      ;update number of attempts
    89 0000006D 89F8                        mov ax, di
    90 0000006F 83C030                      add ax, '0'
    91 00000072 A2[EC00]                    mov [attempt_num], al
    92                                  
    93 00000075 31C0                        xor ax, ax
    94 00000077 8ED8                        mov ds, ax
    95 00000079 BE[E400]                    mov si, attempts_msg
    96 0000007C E81800                      call _printstr
    97                                  
    98 0000007F B90020                      mov cx, 0x2000
    99 00000082 E83E00                      call _wait
   100                                  
   101 00000085 EBA2                        jmp _disk_read_loop
   102                                  
   103                                  __disk_read_fail_final:
   104 00000087 31C0                        xor ax, ax
   105 00000089 8ED8                        mov ds, ax
   106 0000008B BE[2B01]                    mov si, disk_read_fail_final
   107 0000008E E80600                      call _printstr
   108                                      ;blocking keyboard input
   109 00000091 31C0                        xor ax, ax
   110 00000093 CD16                        int 0x16 ;keyboard services
   111 00000095 EB11                        jmp biosboot_pc
   112                                  
   113                                  ; subroutine to print a string until null terminator
   114                                  ; address of string: ds:si
   115                                  _printstr:
   116 00000097 FC                          cld ;clear DF flag in FLAGS
   117                                  __printstr_loop:
   118 00000098 8A04                        mov al, [si]
   119 0000009A 46                          inc si
   120                                  
   121 0000009B 08C0                        or al, al ;if al = 0
   122 0000009D 7408                        jz __printstr_exit ;exit loop
   123                                  
   124 0000009F B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   125 000000A1 31DB                        xor bx, bx ;bh = 0
   126 000000A3 CD10                        int 0x10 ;bios call video services
   127 000000A5 EBF1                        jmp __printstr_loop
   128                                  __printstr_exit:
   129 000000A7 C3                          ret
   130                                  
   131                                  biosboot_pc:
   132 000000A8 31C0                        xor ax, ax
   133 000000AA 8ED8                        mov ds, ax
   134 000000AC BE[7001]                    mov si, biosboot_msg
   135 000000AF E8E5FF                      call _printstr
   136 000000B2 CD19                        int 0x19
   137                                  
   138                                  restart_pc:
   139 000000B4 31C0                        xor ax, ax
   140 000000B6 8ED8                        mov ds, ax
   141 000000B8 BE[8D01]                    mov si, restart_msg
   142 000000BB E8D9FF                      call _printstr
   143                                      ;jump to reset vector
   144 000000BE EA0000FFFF                  jmp 0xFFFF:0x0000
   145                                  
   146                                  ; subroutine to delay cpu ticks
   147                                  _wait:
   148 000000C3 51                          push cx
   149 000000C4 B9FFFF                      mov cx, 0xFFFF
   150                                  __wait_innerloop:
   151 000000C7 E2FE                        loop __wait_innerloop
   152 000000C9 59                          pop cx
   153 000000CA E2F7                        loop _wait
   154 000000CC C3                          ret
   155                                  
   156 000000CD 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   156 000000D6 726F6D206469736B3A-
   156 000000DF 20                 
   157 000000E0 00                          diskNum db 0 ;reserved for BIOS drive number
   158 000000E1 0D0A00                      db 0xD, 0xA, 0
   159                                  
   160 000000E4 417474656D707420            attempts_msg db 'Attempt '
   161 000000EC 00                          attempt_num db 0
   162 000000ED 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   163                                  
   164 000000F5 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   164 000000FE 6F746C6F616465720D-
   164 00000107 0A00               
   165 00000109 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   165 00000112 206661696C7572652C-
   165 0000011B 20726573657474696E-
   165 00000124 672E2E2E0D0A00     
   166 0000012B 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   166 00000134 206661696C65642C20-
   166 0000013D 707265737320616E79-
   166 00000146 206B657920746F2063-
   166 0000014F 6F6E74696E75652E2E-
   166 00000158 2E0D0A00           
   167 0000015C 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   167 00000165 20737563636573730D-
   167 0000016E 0A00               
   168                                  
   169 00000170 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   169 00000179 6E746F2042494F5320-
   169 00000182 73657475702E2E2E0D-
   169 0000018B 0A00               
   170 0000018D 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   170 00000196 672E2E2E0D0A00     
   171 0000019D 00<rep 21h>                 times 446-($-$$) db 0 ;446B bootloader code
   172                                      ;MBR partition table(64B)
   173                                      ;
   174                                      ;bootable, start 2048 end 124927 size 60MiB
   175                                      ;
   176                                      ;first entry
   177 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   178                                      ;chs addressing of first sector
   179 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   180 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   181 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   182 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   183                                      ;chs addressing of last sector
   184 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   185 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   186 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   187 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   188 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   189                                      ;other entries
   190 000001CE 00<rep 30h>                 times 3*16 db 0
   191                                  
   192                                  times 510-($-$$) db 0 ;510B excluding boot signature
   193 000001FE 55AA                    db 0x55, 0xAA
   194                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   195                                  ; buffer sector(s)
   196 00000200 00<rep 200h>            times 512 db 0
   197                                  
   198                                  
   199                                  
   200                                  main:
   201 00000400 31C0                        xor ax, ax
   202 00000402 8ED8                        mov ds, ax
   203 00000404 BE[9B07]                    mov si, oslogo
   204 00000407 E88DFC                      call _printstr
   205                                  
   206                                      ;print a helpful message
   207 0000040A BE[2406]                    mov si, msg
   208 0000040D E887FC                      call _printstr
   209                                  
   210                                  hang:
   211 00000410 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   212 00000412 CD16                        int 0x16 ;keyboard services
   213                                      ;return: AL = character, AH = scan code
   214 00000414 74FA                        jz hang ;if key not pressed jump back
   215                                      ;if there is a key use int 0x16,0 to get the results
   216 00000416 31C0                        xor ax, ax
   217 00000418 CD16                        int 0x16 ;ah = scancode, al = char
   218                                  
   219                                      ;print char
   220 0000041A 50                          push ax
   221 0000041B B40E                        mov ah, 0x0E
   222 0000041D CD10                        int 0x10
   223 0000041F 58                          pop ax
   224                                  
   225 00000420 80FC3B                      cmp ah, 0x3B
   226 00000423 0F8481FC                    je biosboot_pc
   227 00000427 80FC3C                      cmp ah, 0x3C
   228 0000042A 0F8486FC                    je restart_pc
   229 0000042E 80FC3D                      cmp ah, 0x3D
   230 00000431 0F84F400                    je cls
   231 00000435 80FC3E                      cmp ah, 0x3E
   232 00000438 0F841201                    je halt
   233 0000043C 80FC3F                      cmp ah, 0x3F
   234 0000043F 0F84F800                    je biosbeep
   235 00000443 80FC40                      cmp ah, 0x40
   236 00000446 0F84C80E                    je boot_pmode
   237 0000044A 80FC41                      cmp ah, 0x41
   238 0000044D 7407                        je retest
   239                                  
   240 0000044F 50                          push ax
   241 00000450 E84800                      call hang_virtual_piano
   242 00000453 58                          pop ax
   243                                  
   244 00000454 EBBA                        jmp hang
   245                                  
   246                                  ;subroutine to retest nuck os
   247                                  retest:
   248 00000456 8A16[E000]                  mov dl, [diskNum]
   249 0000045A 52                          push dx
   250 0000045B E80600                      call retest_disk_read
   251                                      ;jump to the start
   252 0000045E 5A                          pop dx
   253 0000045F EA0000C007                  jmp 0x07C0:0x0000
   254                                  
   255                                  
   256                                  retest_disk_read:
   257 00000464 31FF                        xor di, di ;counter for retry
   258                                  retest_disk_read_loop:
   259                                  
   260                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   261                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   262 00000466 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   263 00000469 B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   264 0000046C 30F6                        xor dh, dh ;head number CHS
   265 0000046E 8A16[E000]                  mov dl, [diskNum] ;drive number
   266                                      ;Address to store values in: es:bx which is 0:7E00
   267 00000472 31DB                        xor bx, bx
   268 00000474 8EC3                        mov es, bx
   269 00000476 BB007C                      mov bx, 0x7C00
   270 00000479 CD13                        int 0x13 ;disk read
   271 0000047B 7201                        jc retest__disk_read_fail
   272                                  
   273                                      ;disk read success
   274 0000047D C3                          ret
   275                                  
   276                                  retest__disk_read_fail:
   277                                      ;if number of attempts is over or equal 8
   278 0000047E 83FF08                      cmp di, 8
   279 00000481 7D11                        jge retest__disk_read_fail_final
   280                                  
   281                                      ;attempt to reset disk
   282 00000483 31C0                        xor ax, ax ;scancode ah = 0
   283 00000485 8A16[E000]                  mov dl, [diskNum]
   284 00000489 CD13                        int 0x13 ;reset disk system
   285                                  
   286 0000048B 47                          inc di
   287                                  
   288 0000048C B90020                      mov cx, 0x2000
   289 0000048F E831FC                      call _wait
   290                                  
   291 00000492 EBD2                        jmp retest_disk_read_loop
   292                                  
   293                                  retest__disk_read_fail_final:
   294                                      ;blocking keyboard input
   295 00000494 31C0                        xor ax, ax
   296 00000496 CD16                        int 0x16 ;keyboard services
   297 00000498 E90DFC                      jmp biosboot_pc
   298                                  
   299                                  
   300                                  
   301                                  ;subroutine to play a note in virtual piano
   302                                  ;key: al
   303                                  hang_virtual_piano:
   304                                      ;change mode
   305 0000049B 50                          push ax
   306                                  
   307 0000049C 3C3B                        cmp al, 0x3B
   308 0000049E 740A                        je hang_virtual_piano_mode_rst
   309 000004A0 3C27                        cmp al, 0x27
   310 000004A2 7415                        je hang_virtual_piano_mode_1
   311 000004A4 3C22                        cmp al, 0x22
   312 000004A6 7423                        je hang_virtual_piano_mode_2
   313 000004A8 EB31                        jmp hang_virtual_piano_mode_done
   314                                  hang_virtual_piano_mode_rst:
   315 000004AA 31C0                        xor ax, ax
   316 000004AC A2[5E09]                    mov [hang_virtual_piano_mode], al
   317 000004AF 8ED8                        mov ds, ax
   318 000004B1 BE[5F09]                    mov si, mode_rst_msg
   319 000004B4 E8E0FB                      call _printstr
   320 000004B7 EB22                        jmp hang_virtual_piano_mode_done
   321                                  hang_virtual_piano_mode_1:
   322 000004B9 B80100                      mov ax, 0x0001
   323 000004BC A2[5E09]                    mov [hang_virtual_piano_mode], al
   324 000004BF 31C0                        xor ax, ax
   325 000004C1 8ED8                        mov ds, ax
   326 000004C3 BE[6E09]                    mov si, mode_1_msg
   327 000004C6 E8CEFB                      call _printstr    
   328 000004C9 EB10                        jmp hang_virtual_piano_mode_done
   329                                  hang_virtual_piano_mode_2:
   330 000004CB B80200                      mov ax, 0x0002
   331 000004CE A2[5E09]                    mov [hang_virtual_piano_mode], al
   332 000004D1 31C0                        xor ax, ax
   333 000004D3 8ED8                        mov ds, ax
   334 000004D5 BE[7B09]                    mov si, mode_2_msg
   335 000004D8 E8BCFB                      call _printstr
   336                                  hang_virtual_piano_mode_done:
   337                                      ;load difference in di
   338 000004DB 31C0                        xor ax, ax
   339 000004DD A0[5E09]                    mov al, [hang_virtual_piano_mode]
   340 000004E0 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   341 000004E3 31D2                        xor dx, dx
   342 000004E5 F7E3                        mul bx
   343 000004E7 89C7                        mov di, ax
   344 000004E9 58                          pop ax
   345                                  
   346 000004EA 31C9                        xor cx, cx             ;i = 0
   347 000004EC 8B16[8909]                  mov dx, [keylen]       ;k = 10
   348                                  hang_virtual_piano_loop:
   349 000004F0 39D1                        cmp cx, dx
   350 000004F2 0F8D1AFF                    jge hang               ;return if i >= k
   351 000004F6 89CE                        mov si, cx             ;si = i
   352 000004F8 8A9C[8B09]                  mov bl, [keys + si]    ;bl = keys[i]
   353 000004FC 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   354 000004FE 7403                        je hang_virtual_piano_play
   355                                  
   356 00000500 41                          inc cx                 ;i++
   357 00000501 EBED                        jmp hang_virtual_piano_loop
   358                                  
   359                                  hang_virtual_piano_play:
   360 00000503 89C8                        mov ax, cx
   361 00000505 B90200                      mov cx, 2
   362 00000508 F7E1                        mul cx
   363 0000050A 89C6                        mov si, ax
   364 0000050C B8[C809]                    mov ax, notes
   365 0000050F 01F8                        add ax, di
   366 00000511 01F0                        add ax, si
   367 00000513 89C3                        mov bx, ax
   368 00000515 8B07                        mov ax, [bx]
   369                                      
   370 00000517 E87900                      call _tone
   371 0000051A B9FFFF                      mov cx, 0xFFFF
   372 0000051D BA0500                      mov dx, 0x5
   373 00000520 E84300                      call _wait_PIT
   374 00000523 E89B00                      call speaker_off
   375 00000526 E9E7FE                      jmp hang
   376                                  
   377                                  cls:
   378 00000529 B93200                      mov cx, 50
   379                                  cls_loop:
   380 0000052C B80D0E                      mov ax, 0x0E0D
   381 0000052F CD10                        int 0x10
   382 00000531 B80A0E                      mov ax, 0x0E0A
   383 00000534 CD10                        int 0x10
   384 00000536 E2F4                        loop cls_loop
   385 00000538 E9D5FE                      jmp hang
   386                                  
   387                                  ;bios beep tone
   388                                  biosbeep:
   389 0000053B 31C0                        xor ax, ax
   390 0000053D 8ED8                        mov ds, ax
   391 0000053F BE[9407]                    mov si, beep_msg
   392 00000542 E852FB                      call _printstr
   393 00000545 B90001                      mov cx, 0x100
   394 00000548 E878FB                      call _wait
   395 0000054B E9C2FE                      jmp hang
   396                                  
   397                                  halt:
   398 0000054E B93200                      mov cx, 50
   399                                  halt_cls_loop:
   400 00000551 B80D0E                      mov ax, 0x0E0D
   401 00000554 CD10                        int 0x10
   402 00000556 B80A0E                      mov ax, 0x0E0A
   403 00000559 CD10                        int 0x10
   404 0000055B E2F4                        loop halt_cls_loop
   405                                      ;disable cursor
   406 0000055D B401                        mov ah, 0x01
   407 0000055F B90020                      mov cx, 0x2000 ;disable cursor
   408 00000562 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   409                                  
   410 00000564 FA                          cli
   411 00000565 F4                          hlt
   412                                  
   413                                  ;dx*cx is amount of ticks to wait
   414                                  _wait_PIT:
   415 00000566 51                          push cx
   416 00000567 E80500                      call _wait_PIT_once
   417 0000056A 59                          pop cx
   418 0000056B 4A                          dec dx
   419 0000056C 75F8                        jnz _wait_PIT
   420 0000056E C3                          ret
   421                                  
   422                                  ;cx, starting
   423                                  ;cx is amount of ticks to wait
   424                                  _wait_PIT_once:
   425 0000056F 51                          push cx
   426 00000570 E81100                      call _read_PIT_ticks
   427 00000573 53                          push bx ;bx = starting count
   428                                  _wait_PIT_once_loop:
   429 00000574 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   430                                      ;compute time difference = current count - start count
   431 00000577 58                          pop ax      ;current count is bx, starting count is ax
   432 00000578 29C3                        sub bx, ax  ;bx = time diff
   433 0000057A 59                          pop cx
   434 0000057B 51                          push cx
   435 0000057C 50                          push ax
   436 0000057D 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   437 0000057F 7CF3                        jl _wait_PIT_once_loop
   438 00000581 58                          pop ax
   439 00000582 58                          pop ax
   440 00000583 C3                          ret
   441                                  
   442                                  ;returns PIT ticks stored in bx
   443                                  _read_PIT_ticks:
   444 00000584 FA                          cli
   445 00000585 31C0                        xor ax, ax
   446 00000587 E643                        out 0x43, al
   447 00000589 E440                        in al, 0x40 ;LSB
   448 0000058B 88C3                        mov bl, al
   449 0000058D E440                        in al, 0x40 ;MSB
   450 0000058F 88C7                        mov bh, al
   451 00000591 FB                          sti
   452 00000592 C3                          ret
   453                                  
   454                                  ;PIT notes
   455                                  ;I/O port     Usage
   456                                  ;0x40         Channel 0 data port (read/write)
   457                                  ;0x41         Channel 1 data port (read/write)
   458                                  ;0x42         Channel 2 data port (read/write)
   459                                  ;0x43         Mode/Command register (write only, a read is ignored)
   460                                  ;
   461                                  ;Bits:  7 6 5 4 3 2 1 0
   462                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   463                                  ;       | | | | +--+-- Mode (0–5)
   464                                  ;       | | +-----+-- Access Mode: 
   465                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   466                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   467                                  ;subroutine to play a tone
   468                                  ;ax: frequency
   469                                  _tone:
   470 00000593 50                          push ax
   471                                      ;calculate divisor from frequency
   472                                      ;divisor = 1193182 / freq
   473                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   474 00000594 BA1200                      mov dx, 0x12
   475 00000597 B8DE34                      mov ax, 0x34DE
   476                                      ;load denominator into bx(frequency)
   477 0000059A 5B                          pop bx
   478                                      ;divide
   479 0000059B F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   480 0000059D 50                          push ax ;save on stack
   481                                  
   482 0000059E E82000                      call speaker_off
   483                                      ;write to PIT control register
   484 000005A1 B0B6                        mov al, 0b10110110
   485 000005A3 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   486                                      ;write divisor to channel 2 data port
   487 000005A5 58                          pop ax         ; Divisor
   488 000005A6 89C3                        mov bx, ax
   489 000005A8 88D8                        mov al, bl
   490 000005AA E642                        out 0x42, al         ; LSB first
   491 000005AC 88F8                        mov al, bh
   492 000005AE E642                        out 0x42, al         ; Then MSB
   493                                      
   494 000005B0 E80500                      call speaker_on
   495 000005B3 31C0                        xor ax, ax
   496 000005B5 8ED8                        mov ds, ax
   497 000005B7 C3                          ret
   498                                  
   499                                  ;tell speaker to not shut up
   500                                  speaker_on:
   501 000005B8 FA                          cli
   502 000005B9 E461                        in al, 0x61
   503 000005BB 0C03                        or al, 0b11
   504 000005BD E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   505 000005BF FB                          sti
   506 000005C0 C3                          ret
   507                                  ;tell speaker to shut up
   508                                  speaker_off:
   509 000005C1 FA                          cli
   510 000005C2 E461                        in al, 0x61
   511 000005C4 24FC                        and al, 0b11111100
   512 000005C6 E661                        out 0x61, al
   513 000005C8 FB                          sti
   514 000005C9 C3                          ret
   515                                  
   516                                  
   517                                  
   518                                  print_ax:
   519 000005CA 60                          pusha
   520                                  
   521 000005CB 50                          push ax
   522 000005CC B40E                        mov ah, 0xE
   523 000005CE B030                        mov al, '0'
   524 000005D0 CD10                        int 0x10
   525 000005D2 B40E                        mov ah, 0xE
   526 000005D4 B062                        mov al, 'b'
   527 000005D6 CD10                        int 0x10
   528 000005D8 58                          pop ax
   529                                  
   530 000005D9 89C3                        mov bx, ax
   531 000005DB B91000                      mov cx, 16
   532                                  print_ax_loop:
   533 000005DE 89D8                        mov ax, bx
   534 000005E0 83E001                      and ax, 1
   535 000005E3 83C030                      add ax, '0'
   536 000005E6 B40E                        mov ah, 0xE
   537 000005E8 50                          push ax
   538 000005E9 D1EB                        shr bx, 1
   539 000005EB E2F1                        loop print_ax_loop
   540 000005ED B91000                      mov cx, 16
   541                                  print_ax_loop2:
   542 000005F0 58                          pop ax
   543 000005F1 CD10                        int 0x10
   544 000005F3 E2FB                        loop print_ax_loop2
   545 000005F5 61                          popa
   546 000005F6 C3                          ret
   547                                  
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
   581 00000624 0D0A                        msg db 0xD, 0xA
   582 00000626 46313A2062696F7320-         db 'F1: bios setup/restart/boot next', 0xD, 0xA
   582 0000062F 73657475702F726573-
   582 00000638 746172742F626F6F74-
   582 00000641 206E6578740D0A     
   583 00000648 46323A207265737461-         db 'F2: restart (far jump to reset vector)', 0xD, 0xA
   583 00000651 72742028666172206A-
   583 0000065A 756D7020746F207265-
   583 00000663 73657420766563746F-
   583 0000066C 72290D0A           
   584 00000670 46333A20636C656172-         db 'F3: clear screen', 0xD, 0xA
   584 00000679 2073637265656E0D0A 
   585 00000682 46343A2068616C740D-         db 'F4: halt', 0xD, 0xA
   585 0000068B 0A                 
   586 0000068C 46353A2042494F5320-         db 'F5: BIOS beep', 0xD, 0xA
   586 00000695 626565700D0A       
   587 0000069B 46363A206C6F616420-         db 'F6: load kernel and enter protected mode', 0xD, 0xA
   587 000006A4 6B65726E656C20616E-
   587 000006AD 6420656E7465722070-
   587 000006B6 726F74656374656420-
   587 000006BF 6D6F64650D0A       
   588 000006C5 46373A2072656C6F61-         db 'F7: reload NuckBoot from boot device', 0xD, 0xA
   588 000006CE 64204E75636B426F6F-
   588 000006D7 742066726F6D20626F-
   588 000006E0 6F7420646576696365-
   588 000006E9 0D0A               
   589 000006EB 202020205669727475-         db '    Virtual piano:', 0xD, 0xA
   589 000006F4 616C207069616E6F3A-
   589 000006FD 0D0A               
   590 000006FF 507265737320272066-         db 'Press ', 0x27, ' for lower octave, Press ', 0x22, ' for higher octave, Press ', 0x3B, ' to reset octave', 0xD, 0xA, 0
   590 00000708 6F72206C6F77657220-
   590 00000711 6F63746176652C2050-
   590 0000071A 72657373202220666F-
   590 00000723 722068696768657220-
   590 0000072C 6F63746176652C2050-
   590 00000735 72657373203B20746F-
   590 0000073E 207265736574206F63-
   590 00000747 746176650D0A00     
   591                                  
   592 0000074E 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   592 00000757 206B65726E656C2E2E-
   592 00000760 2E0D0A00           
   593 00000764 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   593 0000076D 616465642C20737769-
   593 00000776 746368696E6720746F-
   593 0000077F 2070726F7465637465-
   593 00000788 64206D6F64652E2E2E-
   593 00000791 0D0A00             
   594 00000794 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   595 0000079B 0D0A                        oslogo db 0xD, 0xA
   596 0000079D 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   596 000007A6 2020202020205F2020-
   596 000007AF 205F20202020202020-
   596 000007B8 20202020205F202020-
   596 000007C1 2020205F5F5F5F2020-
   596 000007CA 202020202020202020-
   596 000007D3 2020205F2020202020-
   596 000007DC 4F532056657273696F-
   596 000007E5 6E2020200D0A       
   597 000007EB 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.0       ', 0xD, 0xA
   597 000007F4 20202020207C205C20-
   597 000007FD 7C207C5F2020205F20-
   597 00000806 205F5F5F7C207C205F-
   597 0000080F 5F207C205F5F202920-
   597 00000818 205F5F5F2020205F5F-
   597 00000821 5F207C207C5F202020-
   597 0000082A 202020312E30202020-
   597 00000833 202020200D0A       
   598 00000839 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   598 00000842 20202020207C20205C-
   598 0000084B 7C207C207C207C207C-
   598 00000854 2F205F5F7C207C2F20-
   598 0000085D 2F207C20205F205C20-
   598 00000866 2F205F205C202F205F-
   598 0000086F 205C7C205F5F7C2020-
   598 00000878 202020202020202020-
   598 00000881 202020200D0A       
   599 00000887 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   599 00000890 20202020207C207C5C-
   599 00000899 20207C207C5F7C207C-
   599 000008A2 20285F5F7C2020203C-
   599 000008AB 20207C207C5F29207C-
   599 000008B4 20285F29207C20285F-
   599 000008BD 29207C207C5F202020-
   599 000008C6 202020202020202020-
   599 000008CF 202020200D0A       
   600 000008D5 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   600 000008DE 20202020207C5F7C20-
   600 000008E7 5C5F7C5C5F5F2C5F7C-
   600 000008F0 5C5F5F5F7C5F7C5C5F-
   600 000008F9 5C207C5F5F5F5F2F20-
   600 00000902 5C5F5F5F2F205C5F5F-
   600 0000090B 5F2F205C5F5F7C2020-
   600 00000914 202020202020202020-
   600 0000091D 202020200D0A       
   601 00000923 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   601 0000092C 202020202020202020-
   601 00000935 20226F706572617469-
   601 0000093E 6E672073797374656D-
   601 00000947 206F66207468652066-
   601 00000950 757475726522202854-
   601 00000959 4D290D0A00         
   602                                  
   603 0000095E 00                          hang_virtual_piano_mode db 0b00
   604                                  
   605 0000095F 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   605 00000968 6176650D0A00       
   606 0000096E 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   606 00000977 650D0A00           
   607 0000097B 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   607 00000984 76650D0A00         
   608                                  
   609 00000989 3D00                        keylen dw 61
   610 0000098B 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   610 00000994 307177657274797569-
   610 0000099D 6F706173646667686A-
   610 000009A6 6B6C7A786376626E6D 
   611 000009AF 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   611 000009B8 455459494F50534447-
   611 000009C1 484A4C5A435642     
   612                                  
   613 000009C8 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   613 000009D1 006E007B00         
   614 000009D6 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   614 000009DF 00DC00F600         
   615 000009E4 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   615 000009ED 01B801EE01         
   616 000009F2 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   616 000009FB 037003DC03         
   617 00000A00 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   617 00000A09 06E006B807         
   618 00000A0E 2D08                        dw 2093
   619                                  
   620 00000A10 45004E005C00680075-         dw 69, 78, 92, 104, 117
   620 00000A19 00                 
   621 00000A1A 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   621 00000A23 00                 
   622 00000A24 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   622 00000A2D 01                 
   623 00000A2E 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   623 00000A37 03                 
   624 00000A38 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   624 00000A41 07                 
   625                                  
   626 00000A42 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   626 00000A4B 0037003E00         
   627 00000A50 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   627 00000A59 006E007B00         
   628 00000A5E 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   628 00000A67 00DC00F600         
   629 00000A6C 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   629 00000A75 01B801EE01         
   630 00000A7A 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   630 00000A83 037003DC03         
   631 00000A88 1704                        dw 1047
   632                                  
   633 00000A8A 230027002E0034003A-         dw 35, 39, 46, 52, 58
   633 00000A93 00                 
   634 00000A94 45004E005C00680075-         dw 69, 78, 92, 104, 117
   634 00000A9D 00                 
   635 00000A9E 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   635 00000AA7 00                 
   636 00000AA8 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   636 00000AB1 01                 
   637 00000AB2 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   637 00000ABB 03                 
   638                                  
   639 00000ABC 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   639 00000AC5 00DC00F600         
   640 00000ACA 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   640 00000AD3 01B801EE01         
   641 00000AD8 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   641 00000AE1 037003DC03         
   642 00000AE6 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   642 00000AEF 06E006B807         
   643 00000AF4 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   643 00000AFD 0CC00D6F0F         
   644 00000B02 5A10                        dw 4186
   645                                  
   646 00000B04 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   646 00000B0D 00                 
   647 00000B0E 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   647 00000B17 01                 
   648 00000B18 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   648 00000B21 03                 
   649 00000B22 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   649 00000B2B 07                 
   650 00000B2C A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   650 00000B35 0E                 
   651                                  
   652                                  
   653 00000B36 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   653 00000B3F 6164206661696C7572-
   653 00000B48 652C20726573657474-
   653 00000B51 696E672E2E2E0D0A00 
   654 00000B5A 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   654 00000B63 6164206661696C6564-
   654 00000B6C 2C20676F696E672062-
   654 00000B75 61636B20746F207265-
   654 00000B7E 616C206D6F64652E2E-
   654 00000B87 2E0D0A00           
   655 00000B8B 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   655 00000B94 616420737563636573-
   655 00000B9D 730D0A00           
   656                                  
   657 00000BA1 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   657 00000BAA 6F6E74726F6C6C6572-
   657 00000BB3 20696E666F20737563-
   657 00000BBC 63657373210D0A00   
   658 00000BC4 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   658 00000BCD 6F6E74726F6C6C6572-
   658 00000BD6 20696E666F20666169-
   658 00000BDF 6C210D0A5072657373-
   658 00000BE8 20616E79206B657920-
   658 00000BF1 746F20636F6E74696E-
   658 00000BFA 75652E2E2E0D0A00   
   659                                  
   660 00000C02 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   660 00000C0B 6F6C6C657220696E66-
   660 00000C14 6F3A0D0A00         
   661 00000C19 0D0A546F74616C206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Total memory(64KB blocks): ", 0
   661 00000C22 656D6F72792836344B-
   661 00000C2B 4220626C6F636B7329-
   661 00000C34 3A2000             
   662 00000C37 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg2 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   662 00000C40 6F6465732070747228-
   662 00000C49 7365673A6F6666293A-
   662 00000C52 2000               
   663                                  
   664 00000C54 56424520566964656F-         VBEStuff_iter_modes_not_found_msg db "VBE Video mode 0b00000001 00011011 not found! (1280x1024 8:8:8)", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   664 00000C5D 206D6F646520306230-
   664 00000C66 303030303030312030-
   664 00000C6F 30303131303131206E-
   664 00000C78 6F7420666F756E6421-
   664 00000C81 202831323830783130-
   664 00000C8A 323420383A383A3829-
   664 00000C93 0D0A50726573732061-
   664 00000C9C 6E79206B657920746F-
   664 00000CA5 20636F6E74696E7565-
   664 00000CAE 2E2E2E0D0A00       
   665 00000CB4 56424520566964656F-         VBEStuff_iter_modes_found_msg db "VBE Video mode (1280x1024 8:8:8) found!", 0xD, 0xA, 0
   665 00000CBD 206D6F646520283132-
   665 00000CC6 383078313032342038-
   665 00000CCF 3A383A382920666F75-
   665 00000CD8 6E64210D0A00       
   666 00000CDE 56424520676574206D-         VBEStuff_mode_info_fail_msg db "VBE get mode info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   666 00000CE7 6F646520696E666F20-
   666 00000CF0 6661696C210D0A5072-
   666 00000CF9 65737320616E79206B-
   666 00000D02 657920746F20636F6E-
   666 00000D0B 74696E75652E2E2E0D-
   666 00000D14 0A00               
   667 00000D16 564245207365742076-         VBEStuff_set_video_mode_fail db "VBE set video mode fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   667 00000D1F 6964656F206D6F6465-
   667 00000D28 206661696C210D0A50-
   667 00000D31 7265737320616E7920-
   667 00000D3A 6B657920746F20636F-
   667 00000D43 6E74696E75652E2E2E-
   667 00000D4C 0D0A00             
   668                                  
   669                                  
   670                                  ; TOTAL of 512 bytes
   671                                  VBE_info_block_start:
   672 00000D4F 4E45494E                    VBE_info_block_signature db 'NEIN'
   673 00000D53 0000                        VBE_info_block_version dw 0
   674 00000D55 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
   675 00000D59 00000000                    VBE_info_block_capabilities dd 0
   676 00000D5D 0000                        VBE_info_block_video_mode_offset dw 0
   677 00000D5F 0000                        VBE_info_block_video_mode_segment dw 0
   678 00000D61 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
   679 00000D63 00<rep 1ECh>                times 492 db 0 ;reserved
   680                                  VBE_info_block_end:
   681                                  
   682                                  ; TOTAL of 256 bytes
   683                                  VBE_mode_info_block_start:
   684 00000F4F 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
   685 00000F51 00                          VBE_mode_info_block_window_a db 0 ;deprecated
   686 00000F52 00                          VBE_mode_info_block_window_b db 0 ;deprecated
   687 00000F53 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
   688 00000F55 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
   689 00000F57 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
   690 00000F59 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
   691 00000F5B 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
   692 00000F5F 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
   693                                  
   694 00000F61 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
   695 00000F63 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
   696 00000F65 0000                        VBE_mode_info_block_char_width dw 0 ;in pixels, unused
   697 00000F67 0000                        VBE_mode_info_block_char_height dw 0 ;in pixels, unused
   698 00000F69 00                          VBE_mode_info_block_planes_count db 0
   699 00000F6A 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
   700 00000F6B 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
   701 00000F6C 00                          VBE_mode_info_block_memory_model db 0
   702 00000F6D 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
   703 00000F6E 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
   704 00000F6F 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
   705                                  
   706                                      ;size and pos of masks
   707 00000F70 00                          VBE_mode_info_block_red_mask db 0
   708 00000F71 00                          VBE_mode_info_block_red_pos db 0
   709 00000F72 00                          VBE_mode_info_block_green_mask db 0
   710 00000F73 00                          VBE_mode_info_block_green_pos db 0
   711 00000F74 00                          VBE_mode_info_block_blue_mask db 0
   712 00000F75 00                          VBE_mode_info_block_blue_pos db 0
   713 00000F76 00                          VBE_mode_info_block_reserved_mask db 0
   714 00000F77 00                          VBE_mode_info_block_reserved_pos db 0
   715 00000F78 00                          VBE_mode_info_block_direct_color_attributes db 0
   716                                  
   717                                      ;added in revision 2.0
   718 00000F79 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
   719 00000F7D 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
   720 00000F81 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
   721 00000F83 CE                          VBE_mode_info_block_reserved db 206 ;available in revision 3.0, useless
   722                                  VBE_mode_info_block_end:
   723                                  
   724                                  ;code segment descriptor
   725                                  ;Base            32b: starting location of segment
   726                                  ;Limit           20b: size of limit
   727                                  ;Present          1b: Is this segment used/is a valid segment
   728                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   729                                  ;Type             1b: 1 if segment is code or data segment
   730                                  ;Flags(1b):
   731                                  ;  Type flags(4b):
   732                                  ;    1. Code? Will segment contain code
   733                                  ;    2. Conforming: can this code be executed from lower privileged segments
   734                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   735                                  ;            becomes an expand down segment
   736                                  ;    3. Readable, can this segment be read?
   737                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   738                                  ;            segment becomes read only
   739                                  ;    4. Accessed: set to 1 when CPU is using the segment
   740                                  ;  Other flags(4b):
   741                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   742                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   743                                  ;    3 & 4: 64 bit tetio, just set to 0
   744                                  
   745                                  ;offset of the segment descriptors relative to the beginning of the GDT
   746                                  CODE_SEG equ GDT_code - GDT_start
   747                                  DATA_SEG equ GDT_data - GDT_start
   748                                  
   749                                  ;kernel location is 0x10000
   750                                  KERNEL_LOCATION equ 0x1000
   751                                  
   752                                  GDT_start:
   753                                      GDT_null:
   754 00000F84 00000000                        dd 0 ;(32 bits)
   755 00000F88 00000000                        dd 0 ;(32 bits)
   756                                      GDT_code:
   757                                          ;base: 0
   758                                          ;limit: 0xFFFFF
   759                                          ;PPT: 1001
   760                                          ;Type: 1010
   761                                          ;Other: 1100
   762                                  
   763                                          ;first 16 bits of limit
   764 00000F8C FFFF                            dw 0xFFFF
   765                                          ;first 24 bits of base
   766 00000F8E 0000                            dw 0x0000 ;16 bits
   767 00000F90 00                              db 0x00   ; 8 bits
   768                                          ;PPT + Type
   769 00000F91 9A                              db 0b10011010
   770                                          ;other + last 4 bits of limit
   771 00000F92 CF                              db 0b11001111
   772                                          ;last 8 bits of base
   773 00000F93 00                              db 0b00000000
   774                                      GDT_data:
   775                                          ;base: 0
   776                                          ;limit: 0xFFFFF
   777                                          ;PPT: 1001
   778                                          ;Type: 0010
   779                                          ;Other: 1100
   780                                  
   781                                          ;first 16 bits of limit
   782 00000F94 FFFF                            dw 0xFFFF
   783                                          ;first 24 bits of base
   784 00000F96 0000                            dw 0x0000 ;16 bits
   785 00000F98 00                              db 0x00   ; 8 bits
   786                                          ;PPT + Type
   787 00000F99 92                              db 0b10010010
   788                                          ;other + last 4 bits of limit
   789 00000F9A CF                              db 0b11001111
   790                                          ;last 8 bits of base
   791 00000F9B 00                              db 0b00000000
   792                                  GDT_end:
   793                                  GDT_descriptor:
   794                                      ;size of GDT(16 bits)
   795 00000F9C 1700                        dw GDT_end - GDT_start - 1
   796                                      ;start of GDT(32 bits)
   797 00000F9E [840F0000]                  dd GDT_start
   798                                  
   799                                  
   800                                  _kernel_load:
   801 00000FA2 31FF                        xor di, di ;counter for retry
   802                                  _kernel_load_loop:
   803                                  
   804 00000FA4 31C0                        xor ax, ax
   805 00000FA6 8ED8                        mov ds, ax
   806 00000FA8 BE[CD00]                    mov si, disk_read_msg ;Reading from disk: diskNum
   807 00000FAB E8E9F0                      call _printstr
   808                                  
   809                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   810 00000FAE B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
   811 00000FB1 B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
   812 00000FB4 30F6                        xor dh, dh ;head number CHS
   813 00000FB6 8A16[E000]                  mov dl, [diskNum] ;drive number
   814                                      ;Address to store values in: es:bx
   815 00000FBA BB0010                      mov bx, 0x1000
   816 00000FBD 8EC3                        mov es, bx
   817 00000FBF 31DB                        xor bx, bx
   818                                  
   819 00000FC1 CD13                        int 0x13 ;disk read
   820 00000FC3 720B                        jc __kernel_load_fail
   821                                  
   822                                      ;disk read success
   823 00000FC5 31C0                        xor ax, ax
   824 00000FC7 8ED8                        mov ds, ax
   825 00000FC9 BE[8B0B]                    mov si, kernel_load_success
   826 00000FCC E8C8F0                      call _printstr
   827 00000FCF C3                          ret
   828                                  
   829                                  __kernel_load_fail:
   830                                      ;if number of attempts is over or equal 8
   831 00000FD0 83FF08                      cmp di, 8
   832 00000FD3 7D2D                        jge __kernel_load_fail_final
   833                                  
   834 00000FD5 31C0                        xor ax, ax
   835 00000FD7 8ED8                        mov ds, ax
   836 00000FD9 BE[360B]                    mov si, kernel_load_fail
   837 00000FDC E8B8F0                      call _printstr
   838                                  
   839                                      ;attempt to reset disk
   840 00000FDF 31C0                        xor ax, ax ;scancode ah = 0
   841 00000FE1 8A16[E000]                  mov dl, [diskNum]
   842 00000FE5 CD13                        int 0x13 ;reset disk system
   843                                  
   844 00000FE7 47                          inc di
   845                                      ;update number of attempts
   846 00000FE8 89F8                        mov ax, di
   847 00000FEA 83C030                      add ax, '0'
   848 00000FED A2[EC00]                    mov [attempt_num], al
   849                                  
   850 00000FF0 31C0                        xor ax, ax
   851 00000FF2 8ED8                        mov ds, ax
   852 00000FF4 BE[E400]                    mov si, attempts_msg
   853 00000FF7 E89DF0                      call _printstr
   854                                  
   855 00000FFA B90020                      mov cx, 0x2000
   856 00000FFD E8C3F0                      call _wait
   857                                  
   858 00001000 EBA2                        jmp _kernel_load_loop
   859                                  
   860                                  __kernel_load_fail_final:
   861 00001002 31C0                        xor ax, ax
   862 00001004 8ED8                        mov ds, ax
   863 00001006 BE[5A0B]                    mov si, kernel_load_fail_final
   864 00001009 E88BF0                      call _printstr
   865 0000100C 58                          pop ax
   866 0000100D E900F4                      jmp hang  ;go back to 16 bit hang loop if fail
   867                                  
   868                                  
   869                                  
   870                                  
   871                                  
   872                                  
   873                                  VBEStuff:
   874 00001010 31C0                        xor ax, ax
   875 00001012 8EC0                        mov es, ax
   876 00001014 BF[4F0D]                    mov di, VBE_info_block_start
   877                                  
   878                                      ;get controller info
   879 00001017 F8                          clc
   880 00001018 B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
   881 0000101B CD10                        int 0x10
   882 0000101D 83F84F                      cmp ax, 0x004F
   883 00001020 0F859A00                    jne VBEStuff_get_controller_info_fail
   884                                  
   885 00001024 31C0                        xor ax, ax
   886 00001026 8ED8                        mov ds, ax
   887 00001028 BE[A10B]                    mov si, VBEStuff_get_controller_info_success_msg
   888 0000102B E869F0                      call _printstr
   889                                  
   890                                      ;print controller info
   891 0000102E 31C0                        xor ax, ax
   892 00001030 8ED8                        mov ds, ax
   893 00001032 BE[020C]                    mov si, VBEStuff_get_controller_info_print_msg
   894 00001035 E85FF0                      call _printstr
   895                                  
   896 00001038 A0[4F0D]                    mov al, [VBE_info_block_signature]
   897 0000103B B40E                        mov ah, 0xE
   898 0000103D CD10                        int 0x10
   899 0000103F A1[500D]                    mov ax, [VBE_info_block_signature+1]
   900 00001042 B40E                        mov ah, 0xE
   901 00001044 CD10                        int 0x10
   902 00001046 A1[510D]                    mov ax, [VBE_info_block_signature+2]
   903 00001049 B40E                        mov ah, 0xE
   904 0000104B CD10                        int 0x10
   905 0000104D A1[520D]                    mov ax, [VBE_info_block_signature+3]
   906 00001050 B40E                        mov ah, 0xE
   907 00001052 CD10                        int 0x10
   908 00001054 B8200E                      mov ax, 0xE20
   909 00001057 CD10                        int 0x10
   910 00001059 A1[530D]                    mov ax, [VBE_info_block_version]
   911 0000105C B00E                        mov al, 0xE
   912 0000105E 86C4                        xchg ah, al
   913 00001060 0430                        add al, '0'
   914 00001062 CD10                        int 0x10
   915                                  
   916 00001064 31C0                        xor ax, ax
   917 00001066 8ED8                        mov ds, ax
   918 00001068 BE[190C]                    mov si, VBEStuff_get_controller_info_print_msg1
   919 0000106B E829F0                      call _printstr
   920                                  
   921 0000106E A1[610D]                    mov ax, [VBE_info_block_total_memory]
   922 00001071 E856F5                      call print_ax
   923                                  
   924 00001074 31C0                        xor ax, ax
   925 00001076 8ED8                        mov ds, ax
   926 00001078 BE[370C]                    mov si, VBEStuff_get_controller_info_print_msg2
   927 0000107B E819F0                      call _printstr
   928                                  
   929 0000107E A1[5F0D]                    mov ax, [VBE_info_block_video_mode_segment]
   930 00001081 E846F5                      call print_ax
   931 00001084 B40E                        mov ah, 0xE
   932 00001086 B03A                        mov al, ':'
   933 00001088 CD10                        int 0x10
   934 0000108A A1[5D0D]                    mov ax, [VBE_info_block_video_mode_offset]
   935 0000108D E83AF5                      call print_ax
   936                                  
   937 00001090 B80D0E                      mov ax, 0x0E0D
   938 00001093 CD10                        int 0x10
   939 00001095 B80A0E                      mov ax, 0x0E0A
   940 00001098 CD10                        int 0x10
   941                                  
   942                                      ;iter mode numbers and find the good one
   943                                      ;get start of modes array and put into es:si
   944 0000109A A1[5F0D]                    mov ax, [VBE_info_block_video_mode_segment]
   945 0000109D 8EC0                        mov es, ax
   946 0000109F 8B36[5D0D]                  mov si, [VBE_info_block_video_mode_offset]
   947                                  VBEStuff_iter_modes_loop:
   948 000010A3 268B04                      mov ax, es:[si]
   949                                      ;now print mode in text form
   950 000010A6 E88600                      call print_VBE_mode_text
   951                                      ;check if mode number is the GOOD one(1280x1024 8:8:8)
   952 000010A9 3D1B01                      cmp ax, 0x011B
   953 000010AC 7443                        je VBEStuff_iter_modes_found
   954                                  
   955                                      ;if mode number is 0xFFFF, exit program
   956 000010AE 83F8FF                      cmp ax, 0xFFFF
   957 000010B1 741C                        je VBEStuff_iter_modes_exit
   958                                      
   959                                      ;increment si
   960 000010B3 83C602                      add si, 2
   961                                      ;wait a tiny bit of time
   962 000010B6 B90001                      mov cx, 0x100
   963 000010B9 E807F0                      call _wait
   964                                  
   965 000010BC EBE5                        jmp VBEStuff_iter_modes_loop
   966                                  VBEStuff_get_controller_info_fail:
   967 000010BE 31C0                        xor ax, ax
   968 000010C0 8ED8                        mov ds, ax
   969 000010C2 BE[C40B]                    mov si, VBEStuff_get_controller_info_fail_msg
   970 000010C5 E8CFEF                      call _printstr
   971                                      ;blocking keyboard input
   972 000010C8 31C0                        xor ax, ax
   973 000010CA CD16                        int 0x16 ;keyboard services
   974 000010CC E9D9EF                      jmp biosboot_pc
   975                                  VBEStuff_iter_modes_exit:
   976                                      ;not found
   977 000010CF 31C0                        xor ax, ax
   978 000010D1 8ED8                        mov ds, ax
   979 000010D3 BE[540C]                    mov si, VBEStuff_iter_modes_not_found_msg
   980 000010D6 E8BEEF                      call _printstr
   981                                      ;blocking keyboard input
   982 000010D9 31C0                        xor ax, ax
   983 000010DB CD16                        int 0x16 ;keyboard services
   984 000010DD E9C8EF                      jmp biosboot_pc
   985                                  VBEStuff_get_mode_info_fail:
   986 000010E0 31C0                        xor ax, ax
   987 000010E2 8ED8                        mov ds, ax
   988 000010E4 BE[DE0C]                    mov si, VBEStuff_mode_info_fail_msg
   989 000010E7 E8ADEF                      call _printstr
   990                                      ;blocking keyboard input
   991 000010EA 31C0                        xor ax, ax
   992 000010EC CD16                        int 0x16 ;keyboard services
   993 000010EE E9B7EF                      jmp biosboot_pc
   994                                  
   995                                  
   996                                  VBEStuff_iter_modes_found:
   997                                      ;found
   998 000010F1 31C0                        xor ax, ax
   999 000010F3 8ED8                        mov ds, ax
  1000 000010F5 BE[B40C]                    mov si, VBEStuff_iter_modes_found_msg
  1001 000010F8 E89CEF                      call _printstr
  1002                                  
  1003 000010FB B90020                      mov cx, 0x2000
  1004 000010FE E8C2EF                      call _wait
  1005                                      
  1006                                      
  1007                                      ;continue execution, get mode info
  1008 00001101 B8014F                      mov ax, 0x4F01 ;scancode
  1009 00001104 B91B01                      mov cx, 0x011B ;THE good mode
  1010                                      ;es:di = 256b buffer
  1011 00001107 31D2                        xor dx, dx
  1012 00001109 8EC2                        mov es, dx
  1013 0000110B BF[4F0F]                    mov di, VBE_mode_info_block_start
  1014 0000110E CD10                        int 0x10
  1015 00001110 83F84F                      cmp ax, 0x004F
  1016 00001113 75CB                        jne VBEStuff_get_mode_info_fail
  1017                                  
  1018                                      
  1019 00001115 B90020                      mov cx, 0x2000
  1020 00001118 E8A8EF                      call _wait
  1021                                  
  1022                                      ;set video mode
  1023 0000111B B8024F                      mov ax, 0x4F02 ;scancode
  1024 0000111E BB1B01                      mov bx, 0x011B ;bx = mode number
  1025 00001121 81CB0040                    or bx, 0x4000 ;use linear framebuffer
  1026 00001125 CD10                        int 0x10
  1027 00001127 83F84F                      cmp ax, 0x004F
  1028 0000112A 0F85E8FB                    jne VBEStuff_set_video_mode_fail
  1029                                  
  1030 0000112E C3                          ret
  1031                                  
  1032                                  
  1033                                  
  1034                                  
  1035                                  
  1036                                  
  1037                                  
  1038                                  
  1039                                  
  1040                                  
  1041                                  
  1042                                  print_VBE_mode_text:
  1043 0000112F 60                          pusha
  1044 00001130 83F8FF                      cmp ax, 0xFFFF
  1045 00001133 7434                        je print_VBE_mode_text_end
  1046 00001135 80E401                      and ah, 1
  1047 00001138 80FC01                      cmp ah, 1
  1048 0000113B 7402                        je print_VBE_mode_text_VBE_defined
  1049 0000113D EB2A                        jmp print_VBE_mode_text_end
  1050                                  print_VBE_mode_text_VBE_defined:
  1051                                      ;al is the mode
  1052                                      ;Eliminate modes that are not in the range 0x10 - 0x1B (inclusive)
  1053 0000113F 3C1B                        cmp al, 0x1B
  1054 00001141 7726                        ja print_VBE_mode_text_end
  1055                                      ;print the string
  1056 00001143 E8B1F4                      call print_al
  1057 00001146 89C3                        mov bx, ax
  1058 00001148 B8200E                      mov ax, 0x0E20
  1059 0000114B CD10                        int 0x10
  1060 0000114D 89D8                        mov ax, bx
  1061 0000114F BB[6B11]                    mov bx, print_VBE_mode_text_ptr_arr
  1062 00001152 30E4                        xor ah, ah
  1063 00001154 01C3                        add bx, ax
  1064 00001156 01C3                        add bx, ax
  1065 00001158 89DE                        mov si, bx
  1066 0000115A 8B34                        mov si, [si]
  1067 0000115C E838EF                      call _printstr
  1068 0000115F B80D0E                      mov ax, 0x0E0D
  1069 00001162 CD10                        int 0x10
  1070 00001164 B80A0E                      mov ax, 0x0E0A
  1071 00001167 CD10                        int 0x10
  1072                                  print_VBE_mode_text_end:
  1073 00001169 61                          popa
  1074 0000116A C3                          ret
  1075                                  
  1076                                  print_VBE_mode_text_ptr_arr:
  1077 0000116B [A411]                      dw print_VBE_mode_text_0100
  1078 0000116D [B611]                      dw print_VBE_mode_text_0101
  1079 0000116F [C811]                      dw print_VBE_mode_text_0102
  1080 00001171 [D911]                      dw print_VBE_mode_text_0103
  1081 00001173 [EB11]                      dw print_VBE_mode_text_0104
  1082 00001175 [FD11]                      dw print_VBE_mode_text_0105
  1083 00001177 [1012]                      dw print_VBE_mode_text_0106
  1084 00001179 [2312]                      dw print_VBE_mode_text_0107
  1085 0000117B [A311]                      dw print_VBE_mode_text_invalid
  1086 0000117D [A311]                      dw print_VBE_mode_text_invalid
  1087 0000117F [A311]                      dw print_VBE_mode_text_invalid
  1088 00001181 [A311]                      dw print_VBE_mode_text_invalid
  1089 00001183 [A311]                      dw print_VBE_mode_text_invalid
  1090 00001185 [3712]                      dw print_VBE_mode_text_010D
  1091 00001187 [4512]                      dw print_VBE_mode_text_010E
  1092 00001189 [5312]                      dw print_VBE_mode_text_010F
  1093 0000118B [6112]                      dw print_VBE_mode_text_0110
  1094 0000118D [6F12]                      dw print_VBE_mode_text_0111
  1095 0000118F [7D12]                      dw print_VBE_mode_text_0112
  1096 00001191 [8B12]                      dw print_VBE_mode_text_0113
  1097 00001193 [9912]                      dw print_VBE_mode_text_0114
  1098 00001195 [A712]                      dw print_VBE_mode_text_0115
  1099 00001197 [B512]                      dw print_VBE_mode_text_0116
  1100 00001199 [C412]                      dw print_VBE_mode_text_0117
  1101 0000119B [D312]                      dw print_VBE_mode_text_0118
  1102 0000119D [E212]                      dw print_VBE_mode_text_0119
  1103 0000119F [F212]                      dw print_VBE_mode_text_011A
  1104 000011A1 [0213]                      dw print_VBE_mode_text_011B
  1105 000011A3 00                      print_VBE_mode_text_invalid db 0
  1106 000011A4 363430783430302032-     print_VBE_mode_text_0100 db '640x400 256-color', 0
  1106 000011AD 35362D636F6C6F7200 
  1107 000011B6 363430783438302032-     print_VBE_mode_text_0101 db '640x480 256-color', 0
  1107 000011BF 35362D636F6C6F7200 
  1108 000011C8 383030783630302031-     print_VBE_mode_text_0102 db '800x600 16-color', 0
  1108 000011D1 362D636F6C6F7200   
  1109 000011D9 383030783630302032-     print_VBE_mode_text_0103 db '800x600 256-color', 0
  1109 000011E2 35362D636F6C6F7200 
  1110 000011EB 313032347837363820-     print_VBE_mode_text_0104 db '1024x768 16-color', 0
  1110 000011F4 31362D636F6C6F7200 
  1111 000011FD 313032347837363820-     print_VBE_mode_text_0105 db '1024x768 256-color', 0
  1111 00001206 3235362D636F6C6F72-
  1111 0000120F 00                 
  1112 00001210 313238307831303234-     print_VBE_mode_text_0106 db '1280x1024 16-color', 0
  1112 00001219 2031362D636F6C6F72-
  1112 00001222 00                 
  1113 00001223 313238307831303234-     print_VBE_mode_text_0107 db '1280x1024 256-color', 0
  1113 0000122C 203235362D636F6C6F-
  1113 00001235 7200               
  1114 00001237 333230783230302035-     print_VBE_mode_text_010D db '320x200 5:5:5', 0
  1114 00001240 3A353A3500         
  1115 00001245 333230783230302035-     print_VBE_mode_text_010E db '320x200 5:6:5', 0
  1115 0000124E 3A363A3500         
  1116 00001253 333230783230302038-     print_VBE_mode_text_010F db '320x200 8:8:8', 0
  1116 0000125C 3A383A3800         
  1117 00001261 363430783438302035-     print_VBE_mode_text_0110 db '640x480 5:5:5', 0
  1117 0000126A 3A353A3500         
  1118 0000126F 363430783438302035-     print_VBE_mode_text_0111 db '640x480 5:6:5', 0
  1118 00001278 3A363A3500         
  1119 0000127D 363430783438302038-     print_VBE_mode_text_0112 db '640x480 8:8:8', 0
  1119 00001286 3A383A3800         
  1120 0000128B 383030783630302035-     print_VBE_mode_text_0113 db '800x600 5:5:5', 0
  1120 00001294 3A353A3500         
  1121 00001299 383030783630302035-     print_VBE_mode_text_0114 db '800x600 5:6:5', 0
  1121 000012A2 3A363A3500         
  1122 000012A7 383030783630302038-     print_VBE_mode_text_0115 db '800x600 8:8:8', 0
  1122 000012B0 3A383A3800         
  1123 000012B5 313032347837363820-     print_VBE_mode_text_0116 db '1024x768 5:5:5', 0
  1123 000012BE 353A353A3500       
  1124 000012C4 313032347837363820-     print_VBE_mode_text_0117 db '1024x768 5:6:5', 0
  1124 000012CD 353A363A3500       
  1125 000012D3 313032347837363820-     print_VBE_mode_text_0118 db '1024x768 8:8:8', 0
  1125 000012DC 383A383A3800       
  1126 000012E2 313238307831303234-     print_VBE_mode_text_0119 db '1280x1024 5:5:5', 0
  1126 000012EB 20353A353A3500     
  1127 000012F2 313238307831303234-     print_VBE_mode_text_011A db '1280x1024 5:6:5', 0
  1127 000012FB 20353A363A3500     
  1128 00001302 313238307831303234-     print_VBE_mode_text_011B db '1280x1024 8:8:8', 0
  1128 0000130B 20383A383A3800     
  1129                                  
  1130                                  boot_pmode:
  1131 00001312 31C0                        xor ax, ax
  1132 00001314 8ED8                        mov ds, ax
  1133 00001316 BE[4E07]                    mov si, boot_pmode_msg
  1134 00001319 E87BED                      call _printstr
  1135                                  
  1136 0000131C E883FC                      call _kernel_load
  1137                                  
  1138 0000131F 31C0                        xor ax, ax
  1139 00001321 8ED8                        mov ds, ax
  1140 00001323 BE[6407]                    mov si, kernel_loaded_msg
  1141 00001326 E86EED                      call _printstr
  1142                                  
  1143 00001329 B90030                      mov cx, 0x3000
  1144 0000132C E894ED                      call _wait
  1145                                  
  1146 0000132F B93200                      mov cx, 50
  1147                                  clear_loop:
  1148 00001332 B80D0E                      mov ax, 0x0E0D
  1149 00001335 CD10                        int 0x10
  1150 00001337 B80A0E                      mov ax, 0x0E0A
  1151 0000133A CD10                        int 0x10
  1152 0000133C E2F4                        loop clear_loop
  1153                                      
  1154                                      ;set new graphics mode
  1155                                  
  1156                                      ;Mode 3h
  1157                                      ;VGA 80x25 text mode
  1158 0000133E B80300                      mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1159 00001341 CD10                        int 0x10 ;bios call video services
  1160                                      ;disable cursor
  1161 00001343 B401                        mov ah, 0x01
  1162 00001345 B90020                      mov cx, 0x2000 ;disable cursor
  1163 00001348 CD10                        int 0x10    ;int 0x10, 1: set cursor type
  1164                                  
  1165                                      ;Mode 12h
  1166                                      ;VGA 640x480 16 color
  1167                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1168                                      ;int 0x10 ;bios call video services
  1169                                  
  1170                                      ;VBE graphics
  1171 0000134A FA                          cli
  1172                                      ;call VBEStuff
  1173                                      
  1174 0000134B 0F0116[9C0F]                lgdt [GDT_descriptor] ;load GDT
  1175                                      ;change last bit of cr0 to 1
  1176 00001350 0F20C0                      mov eax, cr0
  1177 00001353 6683C801                    or eax, 1
  1178 00001357 0F22C0                      mov cr0, eax
  1179                                      ;PROTECTED MODE!
  1180                                      ;far jump to code segment
  1181 0000135A EA[5F13]0800                jmp CODE_SEG:pmode
  1182                                  
  1183                                  BITS 32
  1184                                  pmode:
  1185 0000135F EBFE                        jmp $
  1186 00001361 66B81000                    mov ax, DATA_SEG ;setup segments
  1187 00001365 8ED8                        mov ds, ax
  1188 00001367 8ED0                        mov ss, ax
  1189 00001369 8EC0                        mov es, ax
  1190 0000136B 8EE0                        mov fs, ax
  1191 0000136D 8EE8                        mov gs, ax
  1192 0000136F BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1193 00001374 89EC                        mov esp, ebp
  1194                                  
  1195                                      ;jump to loaded kernel
  1196 00001376 E9(00000100)                jmp 0x10000
  1197 0000137B EBFE                        jmp $
  1198                                  
  1199 0000137D 00<rep 1483h>           times 10240-($-$$) db 0 ;total length of binary 20 sector
  1200                                                          ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:codedb 0x69
