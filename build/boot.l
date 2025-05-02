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
    20 00000008 8816[E600]                  mov [diskNum], dl
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
    31                                      ;enable cursor
    32 00000016 B401                        mov ah, 0x01 ;ah = 1
    33 00000018 31C9                        xor cx, cx ;ch = start scanline, cl = end scanline
    34 0000001A CD10                        int 0x10
    35                                  
    36                                      ;enable interrupts
    37 0000001C FB                          sti
    38                                  
    39 0000001D 31C0                        xor ax, ax       ;print bootloader start msg
    40 0000001F 8ED8                        mov ds, ax
    41 00000021 BE[FB00]                    mov si, startup_msg
    42 00000024 E87600                      call _printstr
    43                                  
    44 00000027 E80300                      call _disk_read ;read bootloader code to ram
    45                                  
    46 0000002A E9D303                      jmp main
    47                                  
    48                                  _disk_read:
    49 0000002D 31FF                        xor di, di ;counter for retry
    50                                  _disk_read_loop:
    51                                  
    52 0000002F 31C0                        xor ax, ax
    53 00000031 8ED8                        mov ds, ax
    54 00000033 BE[D300]                    mov si, disk_read_msg ;Reading from disk: diskNum
    55 00000036 E86400                      call _printstr
    56                                  
    57                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
    58                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
    59 00000039 B81302                      mov ax, 0x0213 ;ah=scancode, Read sectors | al=number of sectors to read
    60 0000003C B90200                      mov cx, 0x0002 ;ch=cylinder number CHS | cl=sector number CHS
    61 0000003F 30F6                        xor dh, dh ;head number CHS
    62 00000041 8A16[E600]                  mov dl, [diskNum] ;drive number
    63                                      ;Address to store values in: es:bx which is 0:7E00
    64 00000045 31DB                        xor bx, bx
    65 00000047 8EC3                        mov es, bx
    66 00000049 BB007E                      mov bx, 0x7E00
    67 0000004C CD13                        int 0x13 ;disk read
    68 0000004E 720B                        jc __disk_read_fail
    69                                  
    70                                      ;disk read success
    71 00000050 31C0                        xor ax, ax
    72 00000052 8ED8                        mov ds, ax
    73 00000054 BE[6201]                    mov si, disk_read_success
    74 00000057 E84300                      call _printstr
    75 0000005A C3                          ret
    76                                  
    77                                  __disk_read_fail:
    78                                      ;if number of attempts is over or equal 8
    79 0000005B 83FF08                      cmp di, 8
    80 0000005E 7D2D                        jge __disk_read_fail_final
    81                                  
    82 00000060 31C0                        xor ax, ax
    83 00000062 8ED8                        mov ds, ax
    84 00000064 BE[0F01]                    mov si, disk_read_fail
    85 00000067 E83300                      call _printstr
    86                                  
    87                                      ;attempt to reset disk
    88 0000006A 31C0                        xor ax, ax ;scancode ah = 0
    89 0000006C 8A16[E600]                  mov dl, [diskNum]
    90 00000070 CD13                        int 0x13 ;reset disk system
    91                                  
    92 00000072 47                          inc di
    93                                      ;update number of attempts
    94 00000073 89F8                        mov ax, di
    95 00000075 83C030                      add ax, '0'
    96 00000078 A2[F200]                    mov [attempt_num], al
    97                                  
    98 0000007B 31C0                        xor ax, ax
    99 0000007D 8ED8                        mov ds, ax
   100 0000007F BE[EA00]                    mov si, attempts_msg
   101 00000082 E81800                      call _printstr
   102                                  
   103 00000085 B90020                      mov cx, 0x2000
   104 00000088 E83E00                      call _wait
   105                                  
   106 0000008B EBA2                        jmp _disk_read_loop
   107                                  
   108                                  __disk_read_fail_final:
   109 0000008D 31C0                        xor ax, ax
   110 0000008F 8ED8                        mov ds, ax
   111 00000091 BE[3101]                    mov si, disk_read_fail_final
   112 00000094 E80600                      call _printstr
   113                                      ;blocking keyboard input
   114 00000097 31C0                        xor ax, ax
   115 00000099 CD16                        int 0x16 ;keyboard services
   116 0000009B EB11                        jmp biosboot_pc
   117                                  
   118                                  ; subroutine to print a string until null terminator
   119                                  ; address of string: ds:si
   120                                  _printstr:
   121 0000009D FC                          cld ;clear DF flag in FLAGS
   122                                  __printstr_loop:
   123 0000009E 8A04                        mov al, [si]
   124 000000A0 46                          inc si
   125                                  
   126 000000A1 08C0                        or al, al ;if al = 0
   127 000000A3 7408                        jz __printstr_exit ;exit loop
   128                                  
   129 000000A5 B40E                        mov ah, 0x0E ;write character in TTY mode (bios call)
   130 000000A7 31DB                        xor bx, bx ;bh = 0
   131 000000A9 CD10                        int 0x10 ;bios call video services
   132 000000AB EBF1                        jmp __printstr_loop
   133                                  __printstr_exit:
   134 000000AD C3                          ret
   135                                  
   136                                  biosboot_pc:
   137 000000AE 31C0                        xor ax, ax
   138 000000B0 8ED8                        mov ds, ax
   139 000000B2 BE[7601]                    mov si, biosboot_msg
   140 000000B5 E8E5FF                      call _printstr
   141 000000B8 CD19                        int 0x19
   142                                  
   143                                  restart_pc:
   144 000000BA 31C0                        xor ax, ax
   145 000000BC 8ED8                        mov ds, ax
   146 000000BE BE[9301]                    mov si, restart_msg
   147 000000C1 E8D9FF                      call _printstr
   148                                      ;jump to reset vector
   149 000000C4 EA0000FFFF                  jmp 0xFFFF:0x0000
   150                                  
   151                                  ; subroutine to delay cpu ticks
   152                                  _wait:
   153 000000C9 51                          push cx
   154 000000CA B9FFFF                      mov cx, 0xFFFF
   155                                  __wait_innerloop:
   156 000000CD E2FE                        loop __wait_innerloop
   157 000000CF 59                          pop cx
   158 000000D0 E2F7                        loop _wait
   159 000000D2 C3                          ret
   160                                  
   161 000000D3 52656164696E672066-         disk_read_msg db 'Reading from disk: '
   161 000000DC 726F6D206469736B3A-
   161 000000E5 20                 
   162 000000E6 00                          diskNum db 0 ;reserved for BIOS drive number
   163 000000E7 0D0A00                      db 0xD, 0xA, 0
   164                                  
   165 000000EA 417474656D707420            attempts_msg db 'Attempt '
   166 000000F2 00                          attempt_num db 0
   167 000000F3 206F6620380D0A00            db ' of 8', 0xD, 0xA, 0
   168                                  
   169 000000FB 4E75636B4F5320626F-         startup_msg db 'NuckOS bootloader', 0xD, 0xA, 0
   169 00000104 6F746C6F616465720D-
   169 0000010D 0A00               
   170 0000010F 4469736B2072656164-         disk_read_fail db 'Disk read failure, resetting...', 0xD, 0xA, 0
   170 00000118 206661696C7572652C-
   170 00000121 20726573657474696E-
   170 0000012A 672E2E2E0D0A00     
   171 00000131 4469736B2072656164-         disk_read_fail_final db 'Disk read failed, press any key to continue...', 0xD, 0xA, 0
   171 0000013A 206661696C65642C20-
   171 00000143 707265737320616E79-
   171 0000014C 206B657920746F2063-
   171 00000155 6F6E74696E75652E2E-
   171 0000015E 2E0D0A00           
   172 00000162 4469736B2072656164-         disk_read_success db 'Disk read success', 0xD, 0xA, 0
   172 0000016B 20737563636573730D-
   172 00000174 0A00               
   173                                  
   174 00000176 426F6F74696E672069-         biosboot_msg db 'Booting into BIOS setup...', 0xD, 0xA, 0
   174 0000017F 6E746F2042494F5320-
   174 00000188 73657475702E2E2E0D-
   174 00000191 0A00               
   175 00000193 52657374617274696E-         restart_msg db 'Restarting...', 0xD, 0xA, 0
   175 0000019C 672E2E2E0D0A00     
   176 000001A3 00<rep 1Bh>                 times 446-($-$$) db 0 ;446B bootloader code
   177                                      ;MBR partition table(64B)
   178                                      ;
   179                                      ;bootable, start 2048 end 124927 size 60MiB
   180                                      ;
   181                                      ;first entry
   182 000001BE 80                          db 0b10000000 ;bit 7: bootable flag
   183                                      ;chs addressing of first sector
   184 000001BF 20                          db 0b00100000 ;head (bits 0-7)
   185 000001C0 21                          db 0b00100001 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   186 000001C1 00                          db 0b00000000 ;cylinder(bits 0-7)
   187 000001C2 0C                          db 0x0C ;partition type (W95 FAT32 (LBA))
   188                                      ;chs addressing of last sector
   189 000001C3 C5                          db 0b11000101 ;head (bits 0-7)
   190 000001C4 3E                          db 0b00111110 ;sector(bits 0-5, bits 6-7 are high bits for cylinder(8-9))
   191 000001C5 07                          db 0b00000111 ;cylinder(bits 0-7)
   192 000001C6 00080000                    dd 0x00000800 ;LBA for first sector
   193 000001CA 00E00100                    dd 0x0001E000 ;Number of sectors in partition
   194                                      ;other entries
   195 000001CE 00<rep 30h>                 times 3*16 db 0
   196                                  
   197                                  times 510-($-$$) db 0 ;510B excluding boot signature
   198 000001FE 55AA                    db 0x55, 0xAA
   199                                  ; end of first sector, 512B -----------------------------------------------------------------------------------------------
   200                                  ; buffer sector(s)
   201 00000200 00<rep 200h>            times 512 db 0
   202                                  
   203                                  
   204                                  
   205                                  main:
   206 00000400 31C0                        xor ax, ax
   207 00000402 8ED8                        mov ds, ax
   208 00000404 BE[9D07]                    mov si, oslogo
   209 00000407 E893FC                      call _printstr
   210                                  
   211                                      ;print a helpful message
   212 0000040A BE[2406]                    mov si, msg
   213 0000040D E88DFC                      call _printstr
   214                                  
   215                                  hang:
   216 00000410 B401                        mov ah, 0x01;ah = 1, get keyboard status(check if a key is pressed)
   217 00000412 CD16                        int 0x16 ;keyboard services
   218                                      ;return: AL = character, AH = scan code
   219 00000414 74FA                        jz hang ;if key not pressed jump back
   220                                      ;if there is a key use int 0x16,0 to get the results
   221 00000416 31C0                        xor ax, ax
   222 00000418 CD16                        int 0x16 ;ah = scancode, al = char
   223                                  
   224                                      ;print char
   225 0000041A 50                          push ax
   226 0000041B B40E                        mov ah, 0x0E
   227 0000041D CD10                        int 0x10
   228 0000041F 58                          pop ax
   229                                  
   230 00000420 80FC3B                      cmp ah, 0x3B
   231 00000423 0F8487FC                    je biosboot_pc
   232 00000427 80FC3C                      cmp ah, 0x3C
   233 0000042A 0F848CFC                    je restart_pc
   234 0000042E 80FC3D                      cmp ah, 0x3D
   235 00000431 0F84F400                    je cls
   236 00000435 80FC3E                      cmp ah, 0x3E
   237 00000438 0F841201                    je halt
   238 0000043C 80FC3F                      cmp ah, 0x3F
   239 0000043F 0F84F800                    je biosbeep
   240 00000443 80FC40                      cmp ah, 0x40
   241 00000446 0F843E0E                    je boot_pmode
   242 0000044A 80FC41                      cmp ah, 0x41
   243 0000044D 7407                        je retest
   244                                  
   245 0000044F 50                          push ax
   246 00000450 E84800                      call hang_virtual_piano
   247 00000453 58                          pop ax
   248                                  
   249 00000454 EBBA                        jmp hang
   250                                  
   251                                  ;subroutine to retest nuck os
   252                                  retest:
   253 00000456 8A16[E600]                  mov dl, [diskNum]
   254 0000045A 52                          push dx
   255 0000045B E80600                      call retest_disk_read
   256                                      ;jump to the start
   257 0000045E 5A                          pop dx
   258 0000045F EA0000C007                  jmp 0x07C0:0x0000
   259                                  
   260                                  
   261                                  retest_disk_read:
   262 00000464 31FF                        xor di, di ;counter for retry
   263                                  retest_disk_read_loop:
   264                                  
   265                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   266                                      ;Read 19(0x13) sectors starting from 0:0:2 in drive dl, store in 0x7E00
   267 00000466 B80102                      mov ax, 0x0201 ;ah=scancode, Read sectors | al=number of sectors to read
   268 00000469 B90100                      mov cx, 0x0001 ;ch=cylinder number CHS | cl=sector number CHS
   269 0000046C 30F6                        xor dh, dh ;head number CHS
   270 0000046E 8A16[E600]                  mov dl, [diskNum] ;drive number
   271                                      ;Address to store values in: es:bx which is 0:7E00
   272 00000472 31DB                        xor bx, bx
   273 00000474 8EC3                        mov es, bx
   274 00000476 BB007C                      mov bx, 0x7C00
   275 00000479 CD13                        int 0x13 ;disk read
   276 0000047B 7201                        jc retest__disk_read_fail
   277                                  
   278                                      ;disk read success
   279 0000047D C3                          ret
   280                                  
   281                                  retest__disk_read_fail:
   282                                      ;if number of attempts is over or equal 8
   283 0000047E 83FF08                      cmp di, 8
   284 00000481 7D11                        jge retest__disk_read_fail_final
   285                                  
   286                                      ;attempt to reset disk
   287 00000483 31C0                        xor ax, ax ;scancode ah = 0
   288 00000485 8A16[E600]                  mov dl, [diskNum]
   289 00000489 CD13                        int 0x13 ;reset disk system
   290                                  
   291 0000048B 47                          inc di
   292                                  
   293 0000048C B90020                      mov cx, 0x2000
   294 0000048F E837FC                      call _wait
   295                                  
   296 00000492 EBD2                        jmp retest_disk_read_loop
   297                                  
   298                                  retest__disk_read_fail_final:
   299                                      ;blocking keyboard input
   300 00000494 31C0                        xor ax, ax
   301 00000496 CD16                        int 0x16 ;keyboard services
   302 00000498 E913FC                      jmp biosboot_pc
   303                                  
   304                                  
   305                                  
   306                                  ;subroutine to play a note in virtual piano
   307                                  ;key: al
   308                                  hang_virtual_piano:
   309                                      ;change mode
   310 0000049B 50                          push ax
   311                                  
   312 0000049C 3C3B                        cmp al, 0x3B
   313 0000049E 740A                        je hang_virtual_piano_mode_rst
   314 000004A0 3C27                        cmp al, 0x27
   315 000004A2 7415                        je hang_virtual_piano_mode_1
   316 000004A4 3C22                        cmp al, 0x22
   317 000004A6 7423                        je hang_virtual_piano_mode_2
   318 000004A8 EB31                        jmp hang_virtual_piano_mode_done
   319                                  hang_virtual_piano_mode_rst:
   320 000004AA 31C0                        xor ax, ax
   321 000004AC A2[6009]                    mov [hang_virtual_piano_mode], al
   322 000004AF 8ED8                        mov ds, ax
   323 000004B1 BE[6109]                    mov si, mode_rst_msg
   324 000004B4 E8E6FB                      call _printstr
   325 000004B7 EB22                        jmp hang_virtual_piano_mode_done
   326                                  hang_virtual_piano_mode_1:
   327 000004B9 B80100                      mov ax, 0x0001
   328 000004BC A2[6009]                    mov [hang_virtual_piano_mode], al
   329 000004BF 31C0                        xor ax, ax
   330 000004C1 8ED8                        mov ds, ax
   331 000004C3 BE[7009]                    mov si, mode_1_msg
   332 000004C6 E8D4FB                      call _printstr    
   333 000004C9 EB10                        jmp hang_virtual_piano_mode_done
   334                                  hang_virtual_piano_mode_2:
   335 000004CB B80200                      mov ax, 0x0002
   336 000004CE A2[6009]                    mov [hang_virtual_piano_mode], al
   337 000004D1 31C0                        xor ax, ax
   338 000004D3 8ED8                        mov ds, ax
   339 000004D5 BE[7D09]                    mov si, mode_2_msg
   340 000004D8 E8C2FB                      call _printstr
   341                                  hang_virtual_piano_mode_done:
   342                                      ;load difference in di
   343 000004DB 31C0                        xor ax, ax
   344 000004DD A0[6009]                    mov al, [hang_virtual_piano_mode]
   345 000004E0 BB7A00                      mov bx, 122 ;byte difference between the modes defined contiguously in memory
   346 000004E3 31D2                        xor dx, dx
   347 000004E5 F7E3                        mul bx
   348 000004E7 89C7                        mov di, ax
   349 000004E9 58                          pop ax
   350                                  
   351 000004EA 31C9                        xor cx, cx             ;i = 0
   352 000004EC 8B16[8B09]                  mov dx, [keylen]       ;k = 10
   353                                  hang_virtual_piano_loop:
   354 000004F0 39D1                        cmp cx, dx
   355 000004F2 0F8D1AFF                    jge hang               ;return if i >= k
   356 000004F6 89CE                        mov si, cx             ;si = i
   357 000004F8 8A9C[8D09]                  mov bl, [keys + si]    ;bl = keys[i]
   358 000004FC 38D8                        cmp al, bl             ;if pressed_key == keys[i]
   359 000004FE 7403                        je hang_virtual_piano_play
   360                                  
   361 00000500 41                          inc cx                 ;i++
   362 00000501 EBED                        jmp hang_virtual_piano_loop
   363                                  
   364                                  hang_virtual_piano_play:
   365 00000503 89C8                        mov ax, cx
   366 00000505 B90200                      mov cx, 2
   367 00000508 F7E1                        mul cx
   368 0000050A 89C6                        mov si, ax
   369 0000050C B8[CA09]                    mov ax, notes
   370 0000050F 01F8                        add ax, di
   371 00000511 01F0                        add ax, si
   372 00000513 89C3                        mov bx, ax
   373 00000515 8B07                        mov ax, [bx]
   374                                      
   375 00000517 E87900                      call _tone
   376 0000051A B9FFFF                      mov cx, 0xFFFF
   377 0000051D BA0500                      mov dx, 0x5
   378 00000520 E84300                      call _wait_PIT
   379 00000523 E89B00                      call speaker_off
   380 00000526 E9E7FE                      jmp hang
   381                                  
   382                                  cls:
   383 00000529 B93200                      mov cx, 50
   384                                  cls_loop:
   385 0000052C B80D0E                      mov ax, 0x0E0D
   386 0000052F CD10                        int 0x10
   387 00000531 B80A0E                      mov ax, 0x0E0A
   388 00000534 CD10                        int 0x10
   389 00000536 E2F4                        loop cls_loop
   390 00000538 E9D5FE                      jmp hang
   391                                  
   392                                  ;bios beep tone
   393                                  biosbeep:
   394 0000053B 31C0                        xor ax, ax
   395 0000053D 8ED8                        mov ds, ax
   396 0000053F BE[9607]                    mov si, beep_msg
   397 00000542 E858FB                      call _printstr
   398 00000545 B90001                      mov cx, 0x100
   399 00000548 E87EFB                      call _wait
   400 0000054B E9C2FE                      jmp hang
   401                                  
   402                                  halt:
   403 0000054E B93200                      mov cx, 50
   404                                  halt_cls_loop:
   405 00000551 B80D0E                      mov ax, 0x0E0D
   406 00000554 CD10                        int 0x10
   407 00000556 B80A0E                      mov ax, 0x0E0A
   408 00000559 CD10                        int 0x10
   409 0000055B E2F4                        loop halt_cls_loop
   410                                      ;disable cursor
   411 0000055D B401                        mov ah, 0x01
   412 0000055F B90020                      mov cx, 0x2000 ;disable cursor
   413 00000562 CD10                        int 0x10    ;int 0x10, 1: set cursor type
   414                                  
   415 00000564 FA                          cli
   416 00000565 F4                          hlt
   417                                  
   418                                  ;dx*cx is amount of ticks to wait
   419                                  _wait_PIT:
   420 00000566 51                          push cx
   421 00000567 E80500                      call _wait_PIT_once
   422 0000056A 59                          pop cx
   423 0000056B 4A                          dec dx
   424 0000056C 75F8                        jnz _wait_PIT
   425 0000056E C3                          ret
   426                                  
   427                                  ;cx, starting
   428                                  ;cx is amount of ticks to wait
   429                                  _wait_PIT_once:
   430 0000056F 51                          push cx
   431 00000570 E81100                      call _read_PIT_ticks
   432 00000573 53                          push bx ;bx = starting count
   433                                  _wait_PIT_once_loop:
   434 00000574 E80D00                      call _read_PIT_ticks ;read the count again, store in bx
   435                                      ;compute time difference = current count - start count
   436 00000577 58                          pop ax      ;current count is bx, starting count is ax
   437 00000578 29C3                        sub bx, ax  ;bx = time diff
   438 0000057A 59                          pop cx
   439 0000057B 51                          push cx
   440 0000057C 50                          push ax
   441 0000057D 39CB                        cmp bx, cx  ;if time diff < wait ticks, loop again
   442 0000057F 7CF3                        jl _wait_PIT_once_loop
   443 00000581 58                          pop ax
   444 00000582 58                          pop ax
   445 00000583 C3                          ret
   446                                  
   447                                  ;returns PIT ticks stored in bx
   448                                  _read_PIT_ticks:
   449 00000584 FA                          cli
   450 00000585 31C0                        xor ax, ax
   451 00000587 E643                        out 0x43, al
   452 00000589 E440                        in al, 0x40 ;LSB
   453 0000058B 88C3                        mov bl, al
   454 0000058D E440                        in al, 0x40 ;MSB
   455 0000058F 88C7                        mov bh, al
   456 00000591 FB                          sti
   457 00000592 C3                          ret
   458                                  
   459                                  ;PIT notes
   460                                  ;I/O port     Usage
   461                                  ;0x40         Channel 0 data port (read/write)
   462                                  ;0x41         Channel 1 data port (read/write)
   463                                  ;0x42         Channel 2 data port (read/write)
   464                                  ;0x43         Mode/Command register (write only, a read is ignored)
   465                                  ;
   466                                  ;Bits:  7 6 5 4 3 2 1 0
   467                                  ;       | | | | | | | +-- BCD (0 = binary, 1 = BCD)
   468                                  ;       | | | | +--+-- Mode (0–5)
   469                                  ;       | | +-----+-- Access Mode: 
   470                                  ;       | |          01 = LSB, 10 = MSB, 11 = LSB+MSB
   471                                  ;       +---- Channel (00 = ch0, 01 = ch1, 10 = ch2)
   472                                  ;subroutine to play a tone
   473                                  ;ax: frequency
   474                                  _tone:
   475 00000593 50                          push ax
   476                                      ;calculate divisor from frequency
   477                                      ;divisor = 1193182 / freq
   478                                      ;load numerator into dx:ax (1193182)(0x1234DE)
   479 00000594 BA1200                      mov dx, 0x12
   480 00000597 B8DE34                      mov ax, 0x34DE
   481                                      ;load denominator into bx(frequency)
   482 0000059A 5B                          pop bx
   483                                      ;divide
   484 0000059B F7F3                        div bx ;dx:ax / bx, quotient ax, remainder dx
   485 0000059D 50                          push ax ;save on stack
   486                                  
   487 0000059E E82000                      call speaker_off
   488                                      ;write to PIT control register
   489 000005A1 B0B6                        mov al, 0b10110110
   490 000005A3 E643                        out 0x43, al ;channel 2, LSB+MSB, mode 3, binary
   491                                      ;write divisor to channel 2 data port
   492 000005A5 58                          pop ax         ; Divisor
   493 000005A6 89C3                        mov bx, ax
   494 000005A8 88D8                        mov al, bl
   495 000005AA E642                        out 0x42, al         ; LSB first
   496 000005AC 88F8                        mov al, bh
   497 000005AE E642                        out 0x42, al         ; Then MSB
   498                                      
   499 000005B0 E80500                      call speaker_on
   500 000005B3 31C0                        xor ax, ax
   501 000005B5 8ED8                        mov ds, ax
   502 000005B7 C3                          ret
   503                                  
   504                                  ;tell speaker to not shut up
   505                                  speaker_on:
   506 000005B8 FA                          cli
   507 000005B9 E461                        in al, 0x61
   508 000005BB 0C03                        or al, 0b11
   509 000005BD E661                        out 0x61, al ;bit 0 enable speaker, bit 1 enable timer 2 gate(PIT square wave)
   510 000005BF FB                          sti
   511 000005C0 C3                          ret
   512                                  ;tell speaker to shut up
   513                                  speaker_off:
   514 000005C1 FA                          cli
   515 000005C2 E461                        in al, 0x61
   516 000005C4 24FC                        and al, 0b11111100
   517 000005C6 E661                        out 0x61, al
   518 000005C8 FB                          sti
   519 000005C9 C3                          ret
   520                                  
   521                                  
   522                                  
   523                                  print_ax:
   524 000005CA 60                          pusha
   525                                  
   526 000005CB 50                          push ax
   527 000005CC B40E                        mov ah, 0xE
   528 000005CE B030                        mov al, '0'
   529 000005D0 CD10                        int 0x10
   530 000005D2 B40E                        mov ah, 0xE
   531 000005D4 B062                        mov al, 'b'
   532 000005D6 CD10                        int 0x10
   533 000005D8 58                          pop ax
   534                                  
   535 000005D9 89C3                        mov bx, ax
   536 000005DB B91000                      mov cx, 16
   537                                  print_ax_loop:
   538 000005DE 89D8                        mov ax, bx
   539 000005E0 83E001                      and ax, 1
   540 000005E3 83C030                      add ax, '0'
   541 000005E6 B40E                        mov ah, 0xE
   542 000005E8 50                          push ax
   543 000005E9 D1EB                        shr bx, 1
   544 000005EB E2F1                        loop print_ax_loop
   545 000005ED B91000                      mov cx, 16
   546                                  print_ax_loop2:
   547 000005F0 58                          pop ax
   548 000005F1 CD10                        int 0x10
   549 000005F3 E2FB                        loop print_ax_loop2
   550 000005F5 61                          popa
   551 000005F6 C3                          ret
   552                                  
   553                                  
   554                                  print_al:
   555 000005F7 60                          pusha
   556                                  
   557 000005F8 50                          push ax
   558 000005F9 B40E                        mov ah, 0xE
   559 000005FB B030                        mov al, '0'
   560 000005FD CD10                        int 0x10
   561 000005FF B40E                        mov ah, 0xE
   562 00000601 B062                        mov al, 'b'
   563 00000603 CD10                        int 0x10
   564 00000605 58                          pop ax
   565                                  
   566 00000606 30FF                        xor bh, bh
   567 00000608 88C3                        mov bl, al
   568 0000060A B90800                      mov cx, 8
   569                                  print_al_loop:
   570 0000060D 88D8                        mov al, bl
   571 0000060F 2401                        and al, 1
   572 00000611 0430                        add al, '0'
   573 00000613 B40E                        mov ah, 0xE
   574 00000615 50                          push ax
   575 00000616 D0EB                        shr bl, 1
   576 00000618 E2F3                        loop print_al_loop
   577 0000061A B90800                      mov cx, 8
   578                                  print_al_loop2:
   579 0000061D 58                          pop ax
   580 0000061E CD10                        int 0x10
   581 00000620 E2FB                        loop print_al_loop2
   582 00000622 61                          popa
   583 00000623 C3                          ret
   584                                  
   585                                  
   586 00000624 0D0A                        msg db 0xD, 0xA
   587 00000626 46313A2062696F7320-         db 'F1: bios setup/restart/boot next', 0xD, 0xA
   587 0000062F 73657475702F726573-
   587 00000638 746172742F626F6F74-
   587 00000641 206E6578740D0A     
   588 00000648 46323A207265737461-         db 'F2: restart (far jump to reset vector)', 0xD, 0xA
   588 00000651 72742028666172206A-
   588 0000065A 756D7020746F207265-
   588 00000663 73657420766563746F-
   588 0000066C 72290D0A           
   589 00000670 46333A20636C656172-         db 'F3: clear screen', 0xD, 0xA
   589 00000679 2073637265656E0D0A 
   590 00000682 46343A2068616C740D-         db 'F4: halt', 0xD, 0xA
   590 0000068B 0A                 
   591 0000068C 46353A2042494F5320-         db 'F5: BIOS beep', 0xD, 0xA
   591 00000695 626565700D0A       
   592 0000069B 46363A206C6F616420-         db 'F6: load kernel and enter protected mode', 0xD, 0xA
   592 000006A4 6B65726E656C20616E-
   592 000006AD 6420656E7465722070-
   592 000006B6 726F74656374656420-
   592 000006BF 6D6F64650D0A       
   593 000006C5 46373A2072656C6F61-         db 'F7: reload NuckBoot from boot device', 0xD, 0xA
   593 000006CE 64204E75636B426F6F-
   593 000006D7 742066726F6D20626F-
   593 000006E0 6F7420646576696365-
   593 000006E9 0D0A               
   594 000006EB 202020205669727475-         db '    Virtual piano:', 0xD, 0xA
   594 000006F4 616C207069616E6F3A-
   594 000006FD 0D0A               
   595 000006FF 507265737320272066-         db 'Press ', 0x27, ' for lower octave', 0xD, 0xA
   595 00000708 6F72206C6F77657220-
   595 00000711 6F63746176650D0A   
   596 00000719 507265737320222066-         db 'Press ', 0x22, ' for higher octave', 0xD, 0xA
   596 00000722 6F7220686967686572-
   596 0000072B 206F63746176650D0A 
   597 00000734 5072657373203B2074-         db 'Press ', 0x3B, ' to reset octave', 0xD, 0xA, 0xD, 0xA, 0
   597 0000073D 6F207265736574206F-
   597 00000746 63746176650D0A0D0A-
   597 0000074F 00                 
   598                                  
   599 00000750 0D0A6C6F6164696E67-         boot_pmode_msg db 0xD, 0xA, 'loading kernel...', 0xD, 0xA, 0
   599 00000759 206B65726E656C2E2E-
   599 00000762 2E0D0A00           
   600 00000766 6B65726E656C206C6F-         kernel_loaded_msg db 'kernel loaded, switching to protected mode...', 0xD, 0xA, 0
   600 0000076F 616465642C20737769-
   600 00000778 746368696E6720746F-
   600 00000781 2070726F7465637465-
   600 0000078A 64206D6F64652E2E2E-
   600 00000793 0D0A00             
   601 00000796 4F41480D0A0700              beep_msg db 'OAH', 0xD, 0xA, 0x7, 0
   602 0000079D 0D0A                        oslogo db 0xD, 0xA
   603 0000079F 202020202020202020-         db '               _   _            _      ____              _     OS Version   ', 0xD, 0xA
   603 000007A8 2020202020205F2020-
   603 000007B1 205F20202020202020-
   603 000007BA 20202020205F202020-
   603 000007C3 2020205F5F5F5F2020-
   603 000007CC 202020202020202020-
   603 000007D5 2020205F2020202020-
   603 000007DE 4F532056657273696F-
   603 000007E7 6E2020200D0A       
   604 000007ED 202020202020202020-         db '              | \ | |_   _  ___| | __ | __ )  ___   ___ | |_      1.0       ', 0xD, 0xA
   604 000007F6 20202020207C205C20-
   604 000007FF 7C207C5F2020205F20-
   604 00000808 205F5F5F7C207C205F-
   604 00000811 5F207C205F5F202920-
   604 0000081A 205F5F5F2020205F5F-
   604 00000823 5F207C207C5F202020-
   604 0000082C 202020312E30202020-
   604 00000835 202020200D0A       
   605 0000083B 202020202020202020-         db '              |  \| | | | |/ __| |/ / |  _ \ / _ \ / _ \| __|               ', 0xD, 0xA
   605 00000844 20202020207C20205C-
   605 0000084D 7C207C207C207C207C-
   605 00000856 2F205F5F7C207C2F20-
   605 0000085F 2F207C20205F205C20-
   605 00000868 2F205F205C202F205F-
   605 00000871 205C7C205F5F7C2020-
   605 0000087A 202020202020202020-
   605 00000883 202020200D0A       
   606 00000889 202020202020202020-         db '              | |\  | |_| | (__|   <  | |_) | (_) | (_) | |_                ', 0xD, 0xA
   606 00000892 20202020207C207C5C-
   606 0000089B 20207C207C5F7C207C-
   606 000008A4 20285F5F7C2020203C-
   606 000008AD 20207C207C5F29207C-
   606 000008B6 20285F29207C20285F-
   606 000008BF 29207C207C5F202020-
   606 000008C8 202020202020202020-
   606 000008D1 202020200D0A       
   607 000008D7 202020202020202020-         db '              |_| \_|\__,_|\___|_|\_\ |____/ \___/ \___/ \__|               ', 0xD, 0xA
   607 000008E0 20202020207C5F7C20-
   607 000008E9 5C5F7C5C5F5F2C5F7C-
   607 000008F2 5C5F5F5F7C5F7C5C5F-
   607 000008FB 5C207C5F5F5F5F2F20-
   607 00000904 5C5F5F5F2F205C5F5F-
   607 0000090D 5F2F205C5F5F7C2020-
   607 00000916 202020202020202020-
   607 0000091F 202020200D0A       
   608 00000925 202020202020202020-         db '                   ', 34, 'operating system of the future', 34, ' ', 40, 'TM', 41, 0xD, 0xA, 0
   608 0000092E 202020202020202020-
   608 00000937 20226F706572617469-
   608 00000940 6E672073797374656D-
   608 00000949 206F66207468652066-
   608 00000952 757475726522202854-
   608 0000095B 4D290D0A00         
   609                                  
   610 00000960 00                          hang_virtual_piano_mode db 0b00
   611                                  
   612 00000961 5265736574206F6374-         mode_rst_msg db 'Reset octave', 0xD, 0xA, 0
   612 0000096A 6176650D0A00       
   613 00000970 4C6F77206F63746176-         mode_1_msg db 'Low octave', 0xD, 0xA, 0
   613 00000979 650D0A00           
   614 0000097D 48696768206F637461-         mode_2_msg db 'High octave', 0xD, 0xA, 0
   614 00000986 76650D0A00         
   615                                  
   616 0000098B 3D00                        keylen dw 61
   617 0000098D 313233343536373839-         keys db '1234567890qwertyuiopasdfghjklzxcvbnm'
   617 00000996 307177657274797569-
   617 0000099F 6F706173646667686A-
   617 000009A8 6B6C7A786376626E6D 
   618 000009B1 214024255E2A285157-         db '!@$%^*', 40, 'QWETYIOPSDGHJLZCVB'
   618 000009BA 455459494F50534447-
   618 000009C3 484A4C5A435642     
   619                                  
   620 000009CA 410049005200570062-         notes dw 65, 73, 82, 87, 98, 110, 123
   620 000009D3 006E007B00         
   621 000009D8 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   621 000009E1 00DC00F600         
   622 000009E6 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   622 000009EF 01B801EE01         
   623 000009F4 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   623 000009FD 037003DC03         
   624 00000A02 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   624 00000A0B 06E006B807         
   625 00000A10 2D08                        dw 2093
   626                                  
   627 00000A12 45004E005C00680075-         dw 69, 78, 92, 104, 117
   627 00000A1B 00                 
   628 00000A1C 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   628 00000A25 00                 
   629 00000A26 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   629 00000A2F 01                 
   630 00000A30 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   630 00000A39 03                 
   631 00000A3A 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   631 00000A43 07                 
   632                                  
   633 00000A44 2100250029002C0031-         notes_low dw 33, 37, 41, 44, 49, 55, 62
   633 00000A4D 0037003E00         
   634 00000A52 410049005200570062-         dw 65, 73, 82, 87, 98, 110, 123
   634 00000A5B 006E007B00         
   635 00000A60 83009300A400AE00C4-         dw 131, 147, 164, 174, 196, 220, 246
   635 00000A69 00DC00F600         
   636 00000A6E 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   636 00000A77 01B801EE01         
   637 00000A7C 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   637 00000A85 037003DC03         
   638 00000A8A 1704                        dw 1047
   639                                  
   640 00000A8C 230027002E0034003A-         dw 35, 39, 46, 52, 58
   640 00000A95 00                 
   641 00000A96 45004E005C00680075-         dw 69, 78, 92, 104, 117
   641 00000A9F 00                 
   642 00000AA0 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   642 00000AA9 00                 
   643 00000AAA 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   643 00000AB3 01                 
   644 00000AB4 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   644 00000ABD 03                 
   645                                  
   646 00000ABE 83009300A400AE00C4-         notes_high dw 131, 147, 164, 174, 196, 220, 246
   646 00000AC7 00DC00F600         
   647 00000ACC 060126014A015D0188-         dw 262, 294, 330, 349, 392, 440, 494
   647 00000AD5 01B801EE01         
   648 00000ADA 0B024B029302BA0210-         dw 523, 587, 659, 698, 784, 880, 988
   648 00000AE3 037003DC03         
   649 00000AE8 170497042705750520-         dw 1047, 1175, 1319, 1397, 1568, 1760, 1976
   649 00000AF1 06E006B807         
   650 00000AF6 2D082D094D0AEA0A40-         dw 2093, 2349, 2637, 2794, 3136, 3520, 3951
   650 00000AFF 0CC00D6F0F         
   651 00000B04 5A10                        dw 4186
   652                                  
   653 00000B06 8B009C00B900D000E9-         dw 139, 156, 185, 208, 233
   653 00000B0F 00                 
   654 00000B10 1501370172019F01D2-         dw 277, 311, 370, 415, 466
   654 00000B19 01                 
   655 00000B1A 2A026E02E4023F03A4-         dw 554, 622, 740, 831, 932
   655 00000B23 03                 
   656 00000B24 5504DD04C8057D0649-         dw 1109, 1245, 1480, 1661, 1865
   656 00000B2D 07                 
   657 00000B2E A908B909900BFA0C91-         dw 2217, 2489, 2960, 3322, 3729
   657 00000B37 0E                 
   658                                  
   659                                  
   660 00000B38 4B65726E656C206C6F-         kernel_load_fail db 'Kernel load failure, resetting...', 0xD, 0xA, 0
   660 00000B41 6164206661696C7572-
   660 00000B4A 652C20726573657474-
   660 00000B53 696E672E2E2E0D0A00 
   661 00000B5C 4B65726E656C206C6F-         kernel_load_fail_final db 'Kernel load failed, going back to real mode...', 0xD, 0xA, 0
   661 00000B65 6164206661696C6564-
   661 00000B6E 2C20676F696E672062-
   661 00000B77 61636B20746F207265-
   661 00000B80 616C206D6F64652E2E-
   661 00000B89 2E0D0A00           
   662 00000B8D 4B65726E656C206C6F-         kernel_load_success db 'Kernel load success', 0xD, 0xA, 0
   662 00000B96 616420737563636573-
   662 00000B9F 730D0A00           
   663                                  
   664 00000BA3 564245206765742063-         VBEStuff_get_controller_info_success_msg db "VBE get controller info success!", 0xD, 0xA, 0
   664 00000BAC 6F6E74726F6C6C6572-
   664 00000BB5 20696E666F20737563-
   664 00000BBE 63657373210D0A00   
   665 00000BC6 564245206765742063-         VBEStuff_get_controller_info_fail_msg db "VBE get controller info fail!", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   665 00000BCF 6F6E74726F6C6C6572-
   665 00000BD8 20696E666F20666169-
   665 00000BE1 6C210D0A5072657373-
   665 00000BEA 20616E79206B657920-
   665 00000BF3 746F20636F6E74696E-
   665 00000BFC 75652E2E2E0D0A00   
   666                                  
   667 00000C04 56424520636F6E7472-         VBEStuff_get_controller_info_print_msg db "VBE controller info:", 0xD, 0xA, 0
   667 00000C0D 6F6C6C657220696E66-
   667 00000C16 6F3A0D0A00         
   668 00000C1B 0D0A546F74616C206D-         VBEStuff_get_controller_info_print_msg1 db 0xD, 0xA, "Total memory(64KB blocks): ", 0
   668 00000C24 656D6F72792836344B-
   668 00000C2D 4220626C6F636B7329-
   668 00000C36 3A2000             
   669 00000C39 0D0A566964656F206D-         VBEStuff_get_controller_info_print_msg2 db 0xD, 0xA, "Video modes ptr(seg:off): ", 0
   669 00000C42 6F6465732070747228-
   669 00000C4B 7365673A6F6666293A-
   669 00000C54 2000               
   670                                  
   671 00000C56 56424520566964656F-         VBEStuff_iter_modes_not_found_msg db "VBE Video mode 0b00000001 00011011 not found! (1280x1024 8:8:8)", 0xD, 0xA, "Press any key to continue...", 0xD, 0xA, 0
   671 00000C5F 206D6F646520306230-
   671 00000C68 303030303030312030-
   671 00000C71 30303131303131206E-
   671 00000C7A 6F7420666F756E6421-
   671 00000C83 202831323830783130-
   671 00000C8C 323420383A383A3829-
   671 00000C95 0D0A50726573732061-
   671 00000C9E 6E79206B657920746F-
   671 00000CA7 20636F6E74696E7565-
   671 00000CB0 2E2E2E0D0A00       
   672 00000CB6 56424520566964656F-         VBEStuff_iter_modes_found_msg db "VBE Video mode (1280x1024 8:8:8) found!", 0xD, 0xA, 0
   672 00000CBF 206D6F646520283132-
   672 00000CC8 383078313032342038-
   672 00000CD1 3A383A382920666F75-
   672 00000CDA 6E64210D0A00       
   673                                  
   674                                  
   675                                  ; TOTAL of 512 bytes
   676                                  VBE_info_block_start:
   677 00000CE0 4E45494E                    VBE_info_block_signature db 'NEIN'
   678 00000CE4 0000                        VBE_info_block_version dw 0
   679 00000CE6 00000000                    VBE_info_block_OEM_name_ptr dd 0 ;far ptr 32b
   680 00000CEA 00000000                    VBE_info_block_capabilities dd 0
   681 00000CEE 0000                        VBE_info_block_video_mode_offset dw 0
   682 00000CF0 0000                        VBE_info_block_video_mode_segment dw 0
   683 00000CF2 0000                        VBE_info_block_total_memory dw 0 ;count of 64k blocks
   684 00000CF4 00<rep 1ECh>                times 492 db 0 ;reserved
   685                                  VBE_info_block_end:
   686                                  
   687                                  ; TOTAL of 256 bytes
   688                                  VBE_mode_info_block_start:
   689 00000EE0 0000                        VBE_mode_info_block_attributes dw 0 ;deprecated, if bit 7 is 1 supports a linear frame buffer
   690 00000EE2 00                          VBE_mode_info_block_window_a db 0 ;deprecated
   691 00000EE3 00                          VBE_mode_info_block_window_b db 0 ;deprecated
   692 00000EE4 0000                        VBE_mode_info_block_granularity dw 0 ;in KB, deprecated
   693 00000EE6 0000                        VBE_mode_info_block_window_size dw 0 ;in KB
   694 00000EE8 0000                        VBE_mode_info_block_segment_a dw 0 ;0 if not supported
   695 00000EEA 0000                        VBE_mode_info_block_segment_b dw 0 ;0 if not supported
   696 00000EEC 00000000                    VBE_mode_info_block_win_func_ptr dd 0  ;deprecated, used to switch banks in pmode without going to real
   697 00000EF0 0000                        VBE_mode_info_block_pitch dw 0 ;bytes of vram to skip to go down a line
   698                                  
   699 00000EF2 0000                        VBE_mode_info_block_width dw 0 ;in pixels(graphics)/columns(text)
   700 00000EF4 0000                        VBE_mode_info_block_height dw 0 ;in pixels(graphics)/columns(text)
   701 00000EF6 0000                        VBE_mode_info_block_char_width dw 0 ;in pixels, unused
   702 00000EF8 0000                        VBE_mode_info_block_char_height dw 0 ;in pixels, unused
   703 00000EFA 00                          VBE_mode_info_block_planes_count db 0
   704 00000EFB 00                          VBE_mode_info_block_bpp db 0 ;bits per pixel
   705 00000EFC 00                          VBE_mode_info_block_banks_count db 0 ;deprecated, total amount of banks in the mode
   706 00000EFD 00                          VBE_mode_info_block_memory_model db 0
   707 00000EFE 00                          VBE_mode_info_block_bank_size db 0 ;in KB, deprecated, size of a bank
   708 00000EFF 00                          VBE_mode_info_block_image_pages_count db 0 ;count - 1
   709 00000F00 00                          VBE_mode_info_block_reserved0 db 0 ;0 in revision 1.0-2.0, 1 in revision 3.0
   710                                  
   711                                      ;size and pos of masks
   712 00000F01 00                          VBE_mode_info_block_red_mask db 0
   713 00000F02 00                          VBE_mode_info_block_red_pos db 0
   714 00000F03 00                          VBE_mode_info_block_green_mask db 0
   715 00000F04 00                          VBE_mode_info_block_green_pos db 0
   716 00000F05 00                          VBE_mode_info_block_blue_mask db 0
   717 00000F06 00                          VBE_mode_info_block_blue_pos db 0
   718 00000F07 00                          VBE_mode_info_block_reserved_mask db 0
   719 00000F08 00                          VBE_mode_info_block_reserved_pos db 0
   720 00000F09 00                          VBE_mode_info_block_direct_color_attributes db 0
   721                                  
   722                                      ;added in revision 2.0
   723 00000F0A 00000000                    VBE_mode_info_block_framebuffer dd 0 ;physical address of the framebuffer, write here
   724 00000F0E 00000000                    VBE_mode_info_block_off_screen_mem_offset dd 0 
   725 00000F12 0000                        VBE_mode_info_block_off_screen_mem_size dw 0 ;in KB, size of memory in framebuffer but not being displayed on the screen
   726 00000F14 CE                          VBE_mode_info_block_reserved db 206 ;available in revision 3.0, useless
   727                                  VBE_mode_info_block_end:
   728                                  
   729                                  ;code segment descriptor
   730                                  ;Base            32b: starting location of segment
   731                                  ;Limit           20b: size of limit
   732                                  ;Present          1b: Is this segment used/is a valid segment
   733                                  ;Privilege        2b: (00, 01, 10, 11), 00 is highest privilege
   734                                  ;Type             1b: 1 if segment is code or data segment
   735                                  ;Flags(1b):
   736                                  ;  Type flags(4b):
   737                                  ;    1. Code? Will segment contain code
   738                                  ;    2. Conforming: can this code be executed from lower privileged segments
   739                                  ;            For data segment, this flag becomes direction flag, if direction=1, segment
   740                                  ;            becomes an expand down segment
   741                                  ;    3. Readable, can this segment be read?
   742                                  ;            For data segment, this flag becomes writable flag, if writable=0,
   743                                  ;            segment becomes read only
   744                                  ;    4. Accessed: set to 1 when CPU is using the segment
   745                                  ;  Other flags(4b):
   746                                  ;    1. Granularity: when it is set to one the limit is multiplied by 0x1000(4096)
   747                                  ;    2. 32 bits: Is this segment going to use 32 bit memory?
   748                                  ;    3 & 4: 64 bit tetio, just set to 0
   749                                  
   750                                  ;offset of the segment descriptors relative to the beginning of the GDT
   751                                  CODE_SEG equ GDT_code - GDT_start
   752                                  DATA_SEG equ GDT_data - GDT_start
   753                                  
   754                                  ;kernel location is 0x10000
   755                                  KERNEL_LOCATION equ 0x1000
   756                                  
   757                                  GDT_start:
   758                                      GDT_null:
   759 00000F15 00000000                        dd 0 ;(32 bits)
   760 00000F19 00000000                        dd 0 ;(32 bits)
   761                                      GDT_code:
   762                                          ;base: 0
   763                                          ;limit: 0xFFFFF
   764                                          ;PPT: 1001
   765                                          ;Type: 1010
   766                                          ;Other: 1100
   767                                  
   768                                          ;first 16 bits of limit
   769 00000F1D FFFF                            dw 0xFFFF
   770                                          ;first 24 bits of base
   771 00000F1F 0000                            dw 0x0000 ;16 bits
   772 00000F21 00                              db 0x00   ; 8 bits
   773                                          ;PPT + Type
   774 00000F22 9A                              db 0b10011010
   775                                          ;other + last 4 bits of limit
   776 00000F23 CF                              db 0b11001111
   777                                          ;last 8 bits of base
   778 00000F24 00                              db 0b00000000
   779                                      GDT_data:
   780                                          ;base: 0
   781                                          ;limit: 0xFFFFF
   782                                          ;PPT: 1001
   783                                          ;Type: 0010
   784                                          ;Other: 1100
   785                                  
   786                                          ;first 16 bits of limit
   787 00000F25 FFFF                            dw 0xFFFF
   788                                          ;first 24 bits of base
   789 00000F27 0000                            dw 0x0000 ;16 bits
   790 00000F29 00                              db 0x00   ; 8 bits
   791                                          ;PPT + Type
   792 00000F2A 92                              db 0b10010010
   793                                          ;other + last 4 bits of limit
   794 00000F2B CF                              db 0b11001111
   795                                          ;last 8 bits of base
   796 00000F2C 00                              db 0b00000000
   797                                  GDT_end:
   798                                  
   799                                  GDT_descriptor:
   800                                      ;size of GDT(16 bits)
   801 00000F2D 1700                        dw GDT_end - GDT_start - 1
   802                                      ;start of GDT(32 bits)
   803 00000F2F [150F0000]                  dd GDT_start
   804                                  
   805                                  
   806                                  _kernel_load:
   807 00000F33 31FF                        xor di, di ;counter for retry
   808                                  _kernel_load_loop:
   809                                  
   810 00000F35 31C0                        xor ax, ax
   811 00000F37 8ED8                        mov ds, ax
   812 00000F39 BE[D300]                    mov si, disk_read_msg ;Reading from disk: diskNum
   813 00000F3C E85EF1                      call _printstr
   814                                  
   815                                      ;Read (al) number of sectors from ch, dh, cl, drive dl, store in es:bx
   816 00000F3F B88002                      mov ax, 0x0280 ;ah=scancode, Read sectors | al=number of sectors to read
   817 00000F42 B91500                      mov cx, 0x0015 ;ch=cylinder number CHS | cl=sector number CHS = 21 = 0x15
   818 00000F45 30F6                        xor dh, dh ;head number CHS
   819 00000F47 8A16[E600]                  mov dl, [diskNum] ;drive number
   820                                      ;Address to store values in: es:bx
   821 00000F4B BB0010                      mov bx, 0x1000
   822 00000F4E 8EC3                        mov es, bx
   823 00000F50 31DB                        xor bx, bx
   824                                  
   825 00000F52 CD13                        int 0x13 ;disk read
   826 00000F54 720B                        jc __kernel_load_fail
   827                                  
   828                                      ;disk read success
   829 00000F56 31C0                        xor ax, ax
   830 00000F58 8ED8                        mov ds, ax
   831 00000F5A BE[8D0B]                    mov si, kernel_load_success
   832 00000F5D E83DF1                      call _printstr
   833 00000F60 C3                          ret
   834                                  
   835                                  __kernel_load_fail:
   836                                      ;if number of attempts is over or equal 8
   837 00000F61 83FF08                      cmp di, 8
   838 00000F64 7D2D                        jge __kernel_load_fail_final
   839                                  
   840 00000F66 31C0                        xor ax, ax
   841 00000F68 8ED8                        mov ds, ax
   842 00000F6A BE[380B]                    mov si, kernel_load_fail
   843 00000F6D E82DF1                      call _printstr
   844                                  
   845                                      ;attempt to reset disk
   846 00000F70 31C0                        xor ax, ax ;scancode ah = 0
   847 00000F72 8A16[E600]                  mov dl, [diskNum]
   848 00000F76 CD13                        int 0x13 ;reset disk system
   849                                  
   850 00000F78 47                          inc di
   851                                      ;update number of attempts
   852 00000F79 89F8                        mov ax, di
   853 00000F7B 83C030                      add ax, '0'
   854 00000F7E A2[F200]                    mov [attempt_num], al
   855                                  
   856 00000F81 31C0                        xor ax, ax
   857 00000F83 8ED8                        mov ds, ax
   858 00000F85 BE[EA00]                    mov si, attempts_msg
   859 00000F88 E812F1                      call _printstr
   860                                  
   861 00000F8B B90020                      mov cx, 0x2000
   862 00000F8E E838F1                      call _wait
   863                                  
   864 00000F91 EBA2                        jmp _kernel_load_loop
   865                                  
   866                                  __kernel_load_fail_final:
   867 00000F93 31C0                        xor ax, ax
   868 00000F95 8ED8                        mov ds, ax
   869 00000F97 BE[5C0B]                    mov si, kernel_load_fail_final
   870 00000F9A E800F1                      call _printstr
   871 00000F9D 58                          pop ax
   872 00000F9E E96FF4                      jmp hang  ;go back to 16 bit hang loop if fail
   873                                  
   874 00000FA1 FA                          cli
   875 00000FA2 F4                          hlt
   876                                  
   877                                  VBEStuff:
   878 00000FA3 31C0                        xor ax, ax
   879 00000FA5 8EC0                        mov es, ax
   880 00000FA7 BF[E00C]                    mov di, VBE_info_block_start
   881                                  
   882                                      ;get controller info
   883 00000FAA F8                          clc
   884 00000FAB B8004F                      mov ax, 0x4F00 ;int 0x10, 0x4F00: get controller info
   885 00000FAE CD10                        int 0x10
   886 00000FB0 83F84F                      cmp ax, 0x004F
   887 00000FB3 0F859A00                    jne VBEStuff_get_controller_info_fail
   888                                  
   889 00000FB7 31C0                        xor ax, ax
   890 00000FB9 8ED8                        mov ds, ax
   891 00000FBB BE[A30B]                    mov si, VBEStuff_get_controller_info_success_msg
   892 00000FBE E8DCF0                      call _printstr
   893                                  
   894                                      ;print controller info
   895 00000FC1 31C0                        xor ax, ax
   896 00000FC3 8ED8                        mov ds, ax
   897 00000FC5 BE[040C]                    mov si, VBEStuff_get_controller_info_print_msg
   898 00000FC8 E8D2F0                      call _printstr
   899                                  
   900 00000FCB A0[E00C]                    mov al, [VBE_info_block_signature]
   901 00000FCE B40E                        mov ah, 0xE
   902 00000FD0 CD10                        int 0x10
   903 00000FD2 A1[E10C]                    mov ax, [VBE_info_block_signature+1]
   904 00000FD5 B40E                        mov ah, 0xE
   905 00000FD7 CD10                        int 0x10
   906 00000FD9 A1[E20C]                    mov ax, [VBE_info_block_signature+2]
   907 00000FDC B40E                        mov ah, 0xE
   908 00000FDE CD10                        int 0x10
   909 00000FE0 A1[E30C]                    mov ax, [VBE_info_block_signature+3]
   910 00000FE3 B40E                        mov ah, 0xE
   911 00000FE5 CD10                        int 0x10
   912 00000FE7 B8200E                      mov ax, 0xE20
   913 00000FEA CD10                        int 0x10
   914 00000FEC A1[E40C]                    mov ax, [VBE_info_block_version]
   915 00000FEF B00E                        mov al, 0xE
   916 00000FF1 86C4                        xchg ah, al
   917 00000FF3 0430                        add al, '0'
   918 00000FF5 CD10                        int 0x10
   919                                  
   920 00000FF7 31C0                        xor ax, ax
   921 00000FF9 8ED8                        mov ds, ax
   922 00000FFB BE[1B0C]                    mov si, VBEStuff_get_controller_info_print_msg1
   923 00000FFE E89CF0                      call _printstr
   924                                  
   925 00001001 A1[F20C]                    mov ax, [VBE_info_block_total_memory]
   926 00001004 E8C3F5                      call print_ax
   927                                  
   928 00001007 31C0                        xor ax, ax
   929 00001009 8ED8                        mov ds, ax
   930 0000100B BE[390C]                    mov si, VBEStuff_get_controller_info_print_msg2
   931 0000100E E88CF0                      call _printstr
   932                                  
   933 00001011 A1[F00C]                    mov ax, [VBE_info_block_video_mode_segment]
   934 00001014 E8B3F5                      call print_ax
   935 00001017 B40E                        mov ah, 0xE
   936 00001019 B03A                        mov al, ':'
   937 0000101B CD10                        int 0x10
   938 0000101D A1[EE0C]                    mov ax, [VBE_info_block_video_mode_offset]
   939 00001020 E8A7F5                      call print_ax
   940                                  
   941 00001023 B80D0E                      mov ax, 0x0E0D
   942 00001026 CD10                        int 0x10
   943 00001028 B80A0E                      mov ax, 0x0E0A
   944 0000102B CD10                        int 0x10
   945                                  
   946                                      ;iter mode numbers and find the good one
   947                                      ;get start of modes array and put into es:si
   948 0000102D A1[F00C]                    mov ax, [VBE_info_block_video_mode_segment]
   949 00001030 8EC0                        mov es, ax
   950 00001032 8B36[EE0C]                  mov si, [VBE_info_block_video_mode_offset]
   951                                  VBEStuff_iter_modes_loop:
   952 00001036 268B04                      mov ax, es:[si]
   953                                      ;now print mode in text form
   954 00001039 E86900                      call print_VBE_mode_text
   955                                      ;check if mode numnber is the GOOD one(1280x1024 8:8:8)
   956 0000103C 3D1B01                      cmp ax, 0x011B
   957 0000103F 7432                        je VBEStuff_iter_modes_found
   958                                  
   959                                      ;if mode number is 0xFFFF, exit program
   960 00001041 83F8FF                      cmp ax, 0xFFFF
   961 00001044 741C                        je VBEStuff_iter_modes_exit
   962                                      
   963                                      ;increment si
   964 00001046 83C602                      add si, 2
   965                                      ;wait a tiny bit of time
   966 00001049 B90001                      mov cx, 0x100
   967 0000104C E87AF0                      call _wait
   968                                  
   969 0000104F EBE5                        jmp VBEStuff_iter_modes_loop
   970                                  VBEStuff_get_controller_info_fail:
   971 00001051 31C0                        xor ax, ax
   972 00001053 8ED8                        mov ds, ax
   973 00001055 BE[C60B]                    mov si, VBEStuff_get_controller_info_fail_msg
   974 00001058 E842F0                      call _printstr
   975                                      ;blocking keyboard input
   976 0000105B 31C0                        xor ax, ax
   977 0000105D CD16                        int 0x16 ;keyboard services
   978 0000105F E94CF0                      jmp biosboot_pc
   979                                  VBEStuff_iter_modes_exit:
   980                                      ;not found
   981 00001062 31C0                        xor ax, ax
   982 00001064 8ED8                        mov ds, ax
   983 00001066 BE[560C]                    mov si, VBEStuff_iter_modes_not_found_msg
   984 00001069 E831F0                      call _printstr
   985                                      ;blocking keyboard input
   986 0000106C 31C0                        xor ax, ax
   987 0000106E CD16                        int 0x16 ;keyboard services
   988 00001070 E93BF0                      jmp biosboot_pc
   989                                  
   990                                  VBEStuff_iter_modes_found:
   991                                      ;found
   992 00001073 31C0                        xor ax, ax
   993 00001075 8ED8                        mov ds, ax
   994 00001077 BE[B60C]                    mov si, VBEStuff_iter_modes_found_msg
   995 0000107A E820F0                      call _printstr
   996                                  
   997 0000107D B90020                      mov cx, 0x2000
   998 00001080 E846F0                      call _wait
   999                                      
  1000 00001083 A1[E60E]                    mov ax, [VBE_mode_info_block_window_size]
  1001 00001086 E841F5                      call print_ax
  1002                                  
  1003                                      ;continue execution, get mode info
  1004 00001089 B8014F                      mov ax, 0x4F01 ;scancode
  1005 0000108C B91B01                      mov cx, 0x011B ;THE good mode
  1006                                      ;es:di = 256b buffer
  1007 0000108F 31C0                        xor ax, ax
  1008 00001091 8EC0                        mov es, ax
  1009 00001093 BF[E00E]                    mov di, VBE_mode_info_block_start
  1010 00001096 CD10                        int 0x10
  1011                                  
  1012                                      ;set video mode
  1013 00001098 B8024F                      mov ax, 0x4F02 ;scancode
  1014 0000109B BB1B01                      mov bx, 0x011B ;bx = mode number
  1015 0000109E 81CB0040                    or bx, 0x4000 ;use linear framebuffer
  1016 000010A2 CD10                        int 0x10
  1017 000010A4 C3                          ret
  1018                                  
  1019                                  print_VBE_mode_text:
  1020 000010A5 60                          pusha
  1021 000010A6 83F8FF                      cmp ax, 0xFFFF
  1022 000010A9 7434                        je print_VBE_mode_text_end
  1023 000010AB 80E401                      and ah, 1
  1024 000010AE 80FC01                      cmp ah, 1
  1025 000010B1 7402                        je print_VBE_mode_text_VBE_defined
  1026 000010B3 EB2A                        jmp print_VBE_mode_text_end
  1027                                  print_VBE_mode_text_VBE_defined:
  1028                                      ;al is the mode
  1029                                      ;Eliminate modes that are not in the range 0x10 - 0x1B (inclusive)
  1030 000010B5 3C1B                        cmp al, 0x1B
  1031 000010B7 7726                        ja print_VBE_mode_text_end
  1032                                      ;print the string
  1033 000010B9 E83BF5                      call print_al
  1034 000010BC 89C3                        mov bx, ax
  1035 000010BE B8200E                      mov ax, 0x0E20
  1036 000010C1 CD10                        int 0x10
  1037 000010C3 89D8                        mov ax, bx
  1038 000010C5 BB[E110]                    mov bx, print_VBE_mode_text_ptr_arr
  1039 000010C8 30E4                        xor ah, ah
  1040 000010CA 01C3                        add bx, ax
  1041 000010CC 01C3                        add bx, ax
  1042 000010CE 89DE                        mov si, bx
  1043 000010D0 8B34                        mov si, [si]
  1044 000010D2 E8C8EF                      call _printstr
  1045 000010D5 B80D0E                      mov ax, 0x0E0D
  1046 000010D8 CD10                        int 0x10
  1047 000010DA B80A0E                      mov ax, 0x0E0A
  1048 000010DD CD10                        int 0x10
  1049                                  print_VBE_mode_text_end:
  1050 000010DF 61                          popa
  1051 000010E0 C3                          ret
  1052                                  
  1053                                  print_VBE_mode_text_ptr_arr:
  1054 000010E1 [1A11]                      dw print_VBE_mode_text_0100
  1055 000010E3 [2C11]                      dw print_VBE_mode_text_0101
  1056 000010E5 [3E11]                      dw print_VBE_mode_text_0102
  1057 000010E7 [4F11]                      dw print_VBE_mode_text_0103
  1058 000010E9 [6111]                      dw print_VBE_mode_text_0104
  1059 000010EB [7311]                      dw print_VBE_mode_text_0105
  1060 000010ED [8611]                      dw print_VBE_mode_text_0106
  1061 000010EF [9911]                      dw print_VBE_mode_text_0107
  1062 000010F1 [1911]                      dw print_VBE_mode_text_invalid
  1063 000010F3 [1911]                      dw print_VBE_mode_text_invalid
  1064 000010F5 [1911]                      dw print_VBE_mode_text_invalid
  1065 000010F7 [1911]                      dw print_VBE_mode_text_invalid
  1066 000010F9 [1911]                      dw print_VBE_mode_text_invalid
  1067 000010FB [AD11]                      dw print_VBE_mode_text_010D
  1068 000010FD [BB11]                      dw print_VBE_mode_text_010E
  1069 000010FF [C911]                      dw print_VBE_mode_text_010F
  1070 00001101 [D711]                      dw print_VBE_mode_text_0110
  1071 00001103 [E511]                      dw print_VBE_mode_text_0111
  1072 00001105 [F311]                      dw print_VBE_mode_text_0112
  1073 00001107 [0112]                      dw print_VBE_mode_text_0113
  1074 00001109 [0F12]                      dw print_VBE_mode_text_0114
  1075 0000110B [1D12]                      dw print_VBE_mode_text_0115
  1076 0000110D [2B12]                      dw print_VBE_mode_text_0116
  1077 0000110F [3A12]                      dw print_VBE_mode_text_0117
  1078 00001111 [4912]                      dw print_VBE_mode_text_0118
  1079 00001113 [5812]                      dw print_VBE_mode_text_0119
  1080 00001115 [6812]                      dw print_VBE_mode_text_011A
  1081 00001117 [7812]                      dw print_VBE_mode_text_011B
  1082 00001119 00                      print_VBE_mode_text_invalid db 0
  1083 0000111A 363430783430302032-     print_VBE_mode_text_0100 db '640x400 256-color', 0
  1083 00001123 35362D636F6C6F7200 
  1084 0000112C 363430783438302032-     print_VBE_mode_text_0101 db '640x480 256-color', 0
  1084 00001135 35362D636F6C6F7200 
  1085 0000113E 383030783630302031-     print_VBE_mode_text_0102 db '800x600 16-color', 0
  1085 00001147 362D636F6C6F7200   
  1086 0000114F 383030783630302032-     print_VBE_mode_text_0103 db '800x600 256-color', 0
  1086 00001158 35362D636F6C6F7200 
  1087 00001161 313032347837363820-     print_VBE_mode_text_0104 db '1024x768 16-color', 0
  1087 0000116A 31362D636F6C6F7200 
  1088 00001173 313032347837363820-     print_VBE_mode_text_0105 db '1024x768 256-color', 0
  1088 0000117C 3235362D636F6C6F72-
  1088 00001185 00                 
  1089 00001186 313238307831303234-     print_VBE_mode_text_0106 db '1280x1024 16-color', 0
  1089 0000118F 2031362D636F6C6F72-
  1089 00001198 00                 
  1090 00001199 313238307831303234-     print_VBE_mode_text_0107 db '1280x1024 256-color', 0
  1090 000011A2 203235362D636F6C6F-
  1090 000011AB 7200               
  1091 000011AD 333230783230302035-     print_VBE_mode_text_010D db '320x200 5:5:5', 0
  1091 000011B6 3A353A3500         
  1092 000011BB 333230783230302035-     print_VBE_mode_text_010E db '320x200 5:6:5', 0
  1092 000011C4 3A363A3500         
  1093 000011C9 333230783230302038-     print_VBE_mode_text_010F db '320x200 8:8:8', 0
  1093 000011D2 3A383A3800         
  1094 000011D7 363430783438302035-     print_VBE_mode_text_0110 db '640x480 5:5:5', 0
  1094 000011E0 3A353A3500         
  1095 000011E5 363430783438302035-     print_VBE_mode_text_0111 db '640x480 5:6:5', 0
  1095 000011EE 3A363A3500         
  1096 000011F3 363430783438302038-     print_VBE_mode_text_0112 db '640x480 8:8:8', 0
  1096 000011FC 3A383A3800         
  1097 00001201 383030783630302035-     print_VBE_mode_text_0113 db '800x600 5:5:5', 0
  1097 0000120A 3A353A3500         
  1098 0000120F 383030783630302035-     print_VBE_mode_text_0114 db '800x600 5:6:5', 0
  1098 00001218 3A363A3500         
  1099 0000121D 383030783630302038-     print_VBE_mode_text_0115 db '800x600 8:8:8', 0
  1099 00001226 3A383A3800         
  1100 0000122B 313032347837363820-     print_VBE_mode_text_0116 db '1024x768 5:5:5', 0
  1100 00001234 353A353A3500       
  1101 0000123A 313032347837363820-     print_VBE_mode_text_0117 db '1024x768 5:6:5', 0
  1101 00001243 353A363A3500       
  1102 00001249 313032347837363820-     print_VBE_mode_text_0118 db '1024x768 8:8:8', 0
  1102 00001252 383A383A3800       
  1103 00001258 313238307831303234-     print_VBE_mode_text_0119 db '1280x1024 5:5:5', 0
  1103 00001261 20353A353A3500     
  1104 00001268 313238307831303234-     print_VBE_mode_text_011A db '1280x1024 5:6:5', 0
  1104 00001271 20353A363A3500     
  1105 00001278 313238307831303234-     print_VBE_mode_text_011B db '1280x1024 8:8:8', 0
  1105 00001281 20383A383A3800     
  1106                                  
  1107                                  boot_pmode:
  1108 00001288 31C0                        xor ax, ax
  1109 0000128A 8ED8                        mov ds, ax
  1110 0000128C BE[5007]                    mov si, boot_pmode_msg
  1111 0000128F E80BEE                      call _printstr
  1112                                  
  1113 00001292 E89EFC                      call _kernel_load
  1114                                  
  1115 00001295 31C0                        xor ax, ax
  1116 00001297 8ED8                        mov ds, ax
  1117 00001299 BE[6607]                    mov si, kernel_loaded_msg
  1118 0000129C E8FEED                      call _printstr
  1119                                  
  1120 0000129F B90030                      mov cx, 0x3000
  1121 000012A2 E824EE                      call _wait
  1122                                  
  1123 000012A5 B93200                      mov cx, 50
  1124                                  clear_loop:
  1125 000012A8 B80D0E                      mov ax, 0x0E0D
  1126 000012AB CD10                        int 0x10
  1127 000012AD B80A0E                      mov ax, 0x0E0A
  1128 000012B0 CD10                        int 0x10
  1129 000012B2 E2F4                        loop clear_loop
  1130                                      
  1131                                      ;set new graphics mode
  1132                                  
  1133                                      ;Mode 3h
  1134                                      ;VGA 80x25 text mode
  1135                                      ;mov ax, 0x0003 ;ah = 0(function code), al = video mode flag
  1136                                      ;int 0x10 ;bios call video services
  1137                                      ;disable cursor
  1138                                      ;mov ah, 0x01
  1139                                      ;mov cx, 0x2000 ;disable cursor
  1140                                      ;int 0x10    ;int 0x10, 1: set cursor type
  1141                                  
  1142                                      ;Mode 12h
  1143                                      ;VGA 640x480 16 color
  1144                                      ;mov ax, 0x0012 ;ah = 0(function code), al = video mode flag
  1145                                      ;int 0x10 ;bios call video services
  1146                                  
  1147                                      ;VBE graphics
  1148 000012B4 E8ECFC                      call VBEStuff
  1149                                  
  1150 000012B7 FA                          cli
  1151 000012B8 0F0116[2D0F]                lgdt [GDT_descriptor] ;load GDT
  1152                                      ;change last bit of cr0 to 1
  1153 000012BD 0F20C0                      mov eax, cr0
  1154 000012C0 6683C801                    or eax, 1
  1155 000012C4 0F22C0                      mov cr0, eax
  1156                                      ;PROTECTED MODE!
  1157                                      ;far jump to code segment
  1158 000012C7 EA[CC12]0800                jmp CODE_SEG:pmode
  1159                                  
  1160                                  BITS 32
  1161                                  pmode:
  1162 000012CC 66B81000                    mov ax, DATA_SEG ;setup segments
  1163 000012D0 8ED8                        mov ds, ax
  1164 000012D2 8ED0                        mov ss, ax
  1165 000012D4 8EC0                        mov es, ax
  1166 000012D6 8EE0                        mov fs, ax
  1167 000012D8 8EE8                        mov gs, ax
  1168 000012DA BDFFFF0700                  mov ebp, 0x7FFFF ;stack
  1169 000012DF 89EC                        mov esp, ebp
  1170                                  
  1171                                      ;jump to loaded kernel
  1172 000012E1 E9(00000100)                jmp 0x10000
  1173 000012E6 EBFE                        jmp $
  1174                                  
  1175 000012E8 00<rep 1518h>           times 10240-($-$$) db 0 ;total length of binary 20 sector
  1176                                                          ;total length of disk 22 sectors, 1:code, 2-3:partition info 4-10:codedb 0x69
