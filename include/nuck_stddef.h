#ifndef NUCK_STDDEF_H
#define NUCK_STDDEF_H

#define NULL ((void*)0)

#define true 1
#define false 0

typedef unsigned int size_t;

typedef int intptr_t;
typedef unsigned int uintptr_t;

typedef signed char int8_t;
typedef unsigned char uint8_t;

typedef signed short int16_t;
typedef unsigned short uint16_t;

typedef signed int int32_t;
typedef unsigned int uint32_t;



static inline void outb(unsigned short port, unsigned char val){
    __asm__ __volatile__ (
        "out dx, al" 
        :
        :"d"(port), "a"(val)
    );
}
static inline unsigned char inb(unsigned short port){
    unsigned char ret;
    __asm__ __volatile__ (
        "in al, dx" 
        :"=a"(ret)
        :"d"(port)
    );
    return ret;
}
static inline void io_wait(){
    outb(0x80, 0);
}




#define JA 1
#define NEIN 0

#define YUHUH 1
#define NUHUH 0

#define nocap 1
#define cap 0

#endif
