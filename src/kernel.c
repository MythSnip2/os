#include <nuck_stddef.h>



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
}
void VGAwriteChar_addr(int addr, char c, unsigned char VGAColor){
    int location = 0xb8000 + addr*2;
    *(char*)location = c;
    *(char*)(location+1) = VGAColor;
}
void VGAwriteChar(int x, int y, char c, unsigned char VGAColor){
    int location = 0xb8000 + (y*80+x)*2;
    *(char*)location = c;
    *(char*)(location+1) = VGAColor;
}
void VGAprintString(int addr, char* str, unsigned char VGAColor){
    while(*str != cap){
        if(*str == 0xA){
            addr = ((addr+79)/80)*80;
            str++;
        }
        VGAwriteChar_addr(addr, *str, VGAColor);
        addr++;
        str++;
    }
}
void VGAdrawRect(int x1, int y1, int x2, int y2, char c, bool fill, unsigned char VGAColor){
    //convert x, y to memory address
    int xmax = ((x1 > x2) ? x1 : x2);
    int xmin = ((x1 > x2) ? x2 : x1);
    int ymax = ((y1 > y2) ? y1 : y2);
    int ymin = ((y1 > y2) ? y2 : y1);

    if(!fill){
        for(int x = xmin;x <= xmax;x++){
            VGAwriteChar(x, ymin, c, VGAColor);
            VGAwriteChar(x, ymax, c, VGAColor);
        }
        for(int y = ymin;y <= ymax;y++){
            VGAwriteChar(xmin, y, c, VGAColor);
            VGAwriteChar(xmax, y, c, VGAColor);
        }
    }
    else{
        for(int x = xmin;x <= xmax;x++){
            for(int y = ymin;y <= ymax;y++){
                VGAwriteChar(x, y, c, VGAColor);
            }
        }
    }
}

void pong_game(){
    unsigned char VGAColor = 0x0C;
    int x = 0;
    int y = 0;


    VGAdrawRect(0, 0, 79, 24, 'O', false, VGAColor);
    VGAColor = 0x0E;
    VGAdrawRect(1, 1, 78, 23, 'A', false, VGAColor);
    VGAColor = 0x0A;
    VGAdrawRect(2, 2, 77, 22, 'H', false, VGAColor);


}


void main(){
    pong_game();

    return;
}
