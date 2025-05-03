#include <nuck_stddef.h>
#include <nuck_VBE.h>


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



void VGATextWriteChar_addr(int addr, char c, unsigned char VGAColor){
    int location = 0xb8000 + addr*2;
    *(char*)location = c;
    *(char*)(location+1) = VGAColor;
}
void VGATextWriteChar(int x, int y, char c, unsigned char VGAColor){
    int location = 0xb8000 + (y*80+x)*2;
    *(char*)location = c;
    *(char*)(location+1) = VGAColor;
}
void VGAprintString(int addr, char* str, unsigned char VGAColor){
    while(*str != false){
        if(*str == 0xA){
            addr = ((addr+79)/80)*80;
            str++;
        }
        VGATextWriteChar_addr(addr, *str, VGAColor);
        addr++;
        str++;
    }
}
void VGAprintChars(int addr, char* str, int num, unsigned char VGAColor){
    for(int i=0;i<num;i++){
        if(*str == 0xA){
            addr = ((addr+79)/80)*80;
            str++;
        }
        VGATextWriteChar_addr(addr, *str, VGAColor);
        addr++;
        str++;
    }
}
void VGATextDrawRect(int x1, int y1, int x2, int y2, char c, bool fill, unsigned char VGAColor){
    //convert x, y to memory address
    int xmax = ((x1 > x2) ? x1 : x2);
    int xmin = ((x1 > x2) ? x2 : x1);
    int ymax = ((y1 > y2) ? y1 : y2);
    int ymin = ((y1 > y2) ? y2 : y1);

    if(!fill){
        for(int x = xmin;x <= xmax;x++){
            VGATextWriteChar(x, ymin, c, VGAColor);
            VGATextWriteChar(x, ymax, c, VGAColor);
        }
        for(int y = ymin;y <= ymax;y++){
            VGATextWriteChar(xmin, y, c, VGAColor);
            VGATextWriteChar(xmax, y, c, VGAColor);
        }
    }
    else{
        for(int x = xmin;x <= xmax;x++){
            for(int y = ymin;y <= ymax;y++){
                VGATextWriteChar(x, y, c, VGAColor);
            }
        }
    }
}

static inline void VGASetPlane(unsigned char plane) {
    outb(0x3C4, 0x02);              // Select Map Mask register
    outb(0x3C5, 1 << plane);        // Enable write to one plane
}
static inline void VGAPutPixel(int x, int y, unsigned char color) {
    if (x < 0 || x >= 640 || y < 0 || y >= 480){
        return;
    }

    unsigned int offset = (y * 80) + (x / 8);
    unsigned char bit = 7 - (x % 8); // MSB first
    unsigned char mask = 1 << bit;

    unsigned char* vram = (unsigned char*)0xA0000;
    unsigned char* addr = (unsigned char*)(vram + offset);

    for(int plane = 0; plane < 4; plane++){
        VGASetPlane(plane);
        
        unsigned char bit_val = (color >> plane) & 1;
        
        if(bit_val){
            *addr |= mask;
        }
        else{
            *addr &= ~mask;
        }
    }
}
void VGADrawRect(int x1, int y1, int x2, int y2, bool fill, unsigned char VGAColor){
    //convert x, y to memory address
    int xmax = ((x1 > x2) ? x1 : x2);
    int xmin = ((x1 > x2) ? x2 : x1);
    int ymax = ((y1 > y2) ? y1 : y2);
    int ymin = ((y1 > y2) ? y2 : y1);

    if(!fill){
        for(int x = xmin;x <= xmax;x++){
            VGAPutPixel(x, ymin, VGAColor);
            VGAPutPixel(x, ymax, VGAColor);
        }
        for(int y = ymin+1;y < ymax;y++){
            VGAPutPixel(xmin, y, VGAColor);
            VGAPutPixel(xmax, y, VGAColor);
        }
    }
    else{
        for(int y = ymin;y <= ymax;y++){
            for(int x = xmin;x <= xmax;x++){
                VGAPutPixel(x, y, VGAColor);
            }
        }
    }
}



void main(){

    struct VBE_info_block* VBEControllerInfo = (struct VBE_info_block*)(0x7C00 + 0xD51); //Fixed address
    struct VBE_mode_info_block* VBEModeInfo = (struct VBE_mode_info_block*)(0x7C00 + 0xF51); //Fixed address
    char* vram = (char*)((uintptr_t)VBEModeInfo->framebuffer);

    for (int i = 0; i < 1000; i++) {
        vram[i * 3 + 0] = 0x00; // Blue
        vram[i * 3 + 1] = 0x00; // Green
        vram[i * 3 + 2] = 0xFF; // Red -> bright red pixel
    }

    VGATextWriteChar_addr(2, 'O', 0x0A);
    VGATextWriteChar_addr(3, 'A', 0x0A);
    VGATextWriteChar_addr(4, 'H', 0x0A);

    return;
}
