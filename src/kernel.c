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
    return ret;
}
static inline void io_wait(){
    outb(0x80, 0);
}



static volatile uint32_t PIT_ticks = 0;
void PIT_isr_handler() {
    PIT_ticks++;
    outb(0x20, 0x20); // Send End of Interrupt to PIC
}
void PIT_init(uint32_t frequency) {
    uint32_t divisor = 1193182 / frequency;

    outb(0x43, 0x36); // Channel 0, Access mode: lobyte/hibyte, Mode 3
    outb(0x40, divisor & 0xFF);
    outb(0x40, (divisor >> 8) & 0xFF);
}
void PIT_wait_ticks(uint32_t ticks_to_wait) {
    uint32_t start_tick = PIT_ticks;
    while ((PIT_ticks - start_tick) < ticks_to_wait) {
        __asm__ __volatile__("hlt");
    }
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
    while(*str != cap){
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

static inline void VGASetPlane(uint8_t plane) {
    outb(0x3C4, 0x02);              // Select Map Mask register
    outb(0x3C5, 1 << plane);        // Enable write to one plane
}

static inline void VGAPutPixel(int x, int y, unsigned char color) {
    unsigned char* vram = (unsigned char*) 0xA0000;
    int offset = (y * 80) + (x / 8);
    int bit = 7 - (x % 8); // VGA pixels are packed MSB first in each byte

    for(int plane = 0; plane < 4; plane++) {
        VGASetPlane(plane);
        unsigned char* addr = vram + offset;
        uint8_t bit_val = (color >> plane) & 1;
        
        unsigned char o = *addr;
        if (bit_val){
            *addr |= (1 << bit);
        }
        else{
            *addr &= ~(1 << bit);
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
        for(int y = ymin;y <= ymax;y++){
            VGAPutPixel(xmin, y, VGAColor);
            VGAPutPixel(xmax, y, VGAColor);
        }
    }
    else{
        for(int x = xmin;x <= xmax;x++){
            for(int y = ymin;y <= ymax;y++){
                VGAPutPixel(x, y, VGAColor);
            }
        }
    }
}

void pong_game(){
    VGADrawRect(0, 0, 639, 479, true, 0x3);


}


void main(){

    pong_game();

    return;
}
