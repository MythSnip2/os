#include <nuck_stddef.h>
#include <nuck_VBE.h>

static inline void outb(unsigned short port, unsigned char val);
static inline unsigned char inb(unsigned short port);
static inline void io_wait();

void VGATextWriteChar_addr(int addr, char c, unsigned char VGAColor);
void VGATextWriteChar(int x, int y, char c, unsigned char VGAColor);
void VGAPrintString(int addr, char* str, unsigned char VGAColor);
void VGAPrintChars(int addr, char* str, int num, unsigned char VGAColor);
void VGATextDrawRect(int x1, int y1, int x2, int y2, char c, bool fill, unsigned char VGAColor);

static inline void VGASetPlane(unsigned char plane);
void VGAPutPixel(int x, int y, unsigned char color);
void VGADrawRect(int x1, int y1, int x2, int y2, bool fill, unsigned char VGAColor);

void VESAPutPixel(int x, int y, uint32_t color, uint16_t width, uint16_t height, uint16_t pitch, char* vram);
void VESADrawRect(int x1, int y1, int x2, int y2, bool fill, uint32_t color, uint16_t width, uint16_t height, uint16_t pitch, char* vram);
void VESADrawRect2(int x1, int y1, int x2, int y2, uint32_t color1, uint32_t color2, uint16_t width, uint16_t height, uint16_t pitch, char* vram);
static inline uint32_t hex(uint8_t r, uint8_t g, uint8_t b);

void main(){
    uint16_t VBEBlockOffset = 0xE31;

    struct VBE_info_block* VESAControllerInfo = (struct VBE_info_block*) ((uint32_t)(0x7C00 + VBEBlockOffset)); //Fixed address
    struct VBE_mode_info_block* VESAModeInfo = (struct VBE_mode_info_block*) ((uint32_t)(0x7C00 + VBEBlockOffset + 0x200)); //Fixed address

    uint16_t width = (uint16_t)VESAModeInfo->width;
    uint16_t height = (uint16_t)VESAModeInfo->height;
    uint16_t pitch = (uint16_t)VESAModeInfo->pitch;
    char* vram = (char*)VESAModeInfo->framebuffer;

    char* str = "   --- NUCK OS KERNEL RUNNING ---                                    ";
    VGAPrintString(0, str, 0xD);

    VESADrawRect(0*width, 0*height, 0.5*width, 0.5*height, true, hex(0x55, 0xCD, 0xFC), width, height, pitch, vram);
    VESADrawRect2(0.5*width+1, 0.5*height+1, 1*width, 1*height, hex(0x00, 0x00, 0xFF), hex(0xFF, 0x00, 0xFF), width, height, pitch, vram);
    
    for(int i=0;i<1000;i++){
        vram[i*4]=0xFF;
        vram[i*4+1]=0xFF;
        vram[i*4+2]=0xFF;
        vram[i*4+3]=0xFF;
    }

    return;
}


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
void VGAPrintString(int addr, char* str, unsigned char VGAColor){
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
void VGAPrintChars(int addr, char* str, int num, unsigned char VGAColor){
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

static inline void VGASetPlane(unsigned char plane){
    outb(0x3C4, 0x02);              // Select Map Mask register
    outb(0x3C5, 1 << plane);        // Enable write to one plane
}
void VGAPutPixel(int x, int y, unsigned char color){
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

void VESAPutPixel(int x, int y, uint32_t color, uint16_t width, uint16_t height, uint16_t pitch, char* vram){
    if (x < 0 || x >= (width - 1) || y < 0 || y >= (height - 1)){
        return;
    }
    char* offset = (char*)(y * (pitch) + (vram) + x * 4);
    *(uint32_t*)offset = color;
}
void VESADrawRect(int x1, int y1, int x2, int y2, bool fill, uint32_t color, uint16_t width, uint16_t height, uint16_t pitch, char* vram){
    //convert x, y to memory address
    int xmax = ((x1 > x2) ? x1 : x2);
    int xmin = ((x1 > x2) ? x2 : x1);
    int ymax = ((y1 > y2) ? y1 : y2);
    int ymin = ((y1 > y2) ? y2 : y1);

    if(!fill){
        for(int x = xmin;x <= xmax;x++){
            VESAPutPixel(x, ymin, color, width, height, pitch, vram);
            VESAPutPixel(x, ymax, color, width, height, pitch, vram);
        }
        for(int y = ymin+1;y < ymax;y++){
            VESAPutPixel(xmin, y, color, width, height, pitch, vram);
            VESAPutPixel(xmax, y, color, width, height, pitch, vram);
        }
    }
    else{
        for(int y = ymin;y <= ymax;y++){
            for(int x = xmin;x <= xmax;x++){
                VESAPutPixel(x, y, color, width, height, pitch, vram);
            }
        }
    }
}
void VESADrawRect2(int x1, int y1, int x2, int y2, uint32_t color1, uint32_t color2, uint16_t width, uint16_t height, uint16_t pitch, char* vram){
    //convert x, y to memory address
    int xmax = ((x1 > x2) ? x1 : x2);
    int xmin = ((x1 > x2) ? x2 : x1);
    int ymax = ((y1 > y2) ? y1 : y2);
    int ymin = ((y1 > y2) ? y2 : y1);

    uint8_t r1 = color1 >> 16 & 0xFF;
    uint8_t g1 = color1 >> 8 & 0xFF;
    uint8_t b1 = color1 & 0xFF;
    uint8_t r2 = color2 >> 16 & 0xFF;
    uint8_t g2 = color2 >> 8 & 0xFF;
    uint8_t b2 = color2 & 0xFF;

    uint8_t r;
    uint8_t g;
    uint8_t b;

    for(int y = ymin;y <= ymax;y++){
        for(int x = xmin;x <= xmax;x++){
            r = r1 + (r2-r1) * ((y-ymin)/(ymax-ymin));
            g = g1;
            b = b1;
            VESAPutPixel(x, y, hex(r, g, b), width, height, pitch, vram);
        }
    }
    
}
static inline uint32_t hex(uint8_t r, uint8_t g, uint8_t b){
    return ((uint32_t)0 << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}












