#include <nuck_stddef.h>


volatile uint32_t PIT_ticks = 0;
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
    unsigned char VGAColor = 0;
    int x = 0;
    int y = 0;

    VGAColor = 0xCC;
    VGAdrawRect(0, 0, 79, 24, '.', false, VGAColor);
    VGAColor = 0xEE;
    VGAdrawRect(1, 1, 78, 23, '.', false, VGAColor);
    
    VGAColor = 0xAA;
    VGAdrawRect(2, 2, 77, 22, '.', false, VGAColor);
    VGAColor = 0xBB;
    VGAdrawRect(3, 3, 76, 21, '.', false, VGAColor);
    VGAColor = 0x99;
    VGAdrawRect(4, 4, 75, 20, '.', false, VGAColor);
    VGAColor = 0xDD;
    VGAdrawRect(5, 5, 74, 19, '.', false, VGAColor);
    VGAColor = 0xFF;
    VGAdrawRect(6, 6, 73, 18, '.', false, VGAColor);
    VGAColor = 0x88;
    VGAdrawRect(7, 7, 72, 17, '.', false, VGAColor);

}


void main(){

    pong_game();

    return;
}
