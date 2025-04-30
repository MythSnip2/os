BITS 32

extern loadIDT
extern main

call loadIDT
call main

jmp $