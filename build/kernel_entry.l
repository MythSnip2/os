     1                                  BITS 32
     2                                  
     3                                  extern loadIDT
     4                                  extern main
     5                                  
     6 00000000 E8(00000000)            call loadIDT
     7 00000005 E8(00000000)            call main
     8                                  
     9 0000000A EBFE                    jmp $
    10                                  
    11                                  
    12                                  
    13                                  
    14                                  
    15                                  
    16                                  
    17                                  
    18                                  
