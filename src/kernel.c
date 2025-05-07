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
static inline void wait_ticks(int t){
    for(int i=0;i<t;i++){
        io_wait();
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



static inline void VESAPutPixel(int x, int y, uint32_t color, char* vram){
    if (x < 0 || x >= width-1 || y < 0 || y >= height-1){
        return;
    }
    *(uint32_t*)(y * (pitch) + (vram) + x * 4) = color;
}
void VESADrawRect(int x1, int y1, int x2, int y2, bool fill, uint32_t color, char* vram){
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
        for(int y = ymin;y <= ymax;y++){
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
static inline uint32_t hex(uint8_t r, uint8_t g, uint8_t b){
    return ((uint32_t)0 << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

void* memcpy(void* dest, void* src, size_t size){
    uint8_t* d = (uint8_t*)dest;
    uint8_t* s = (uint8_t*)src;
    while(size--){
        *d++ = *s++;
    }
    return dest;
}

void flipVram(char* vram, char* backbuffer, uint32_t vramSize){
    memcpy(vram, backbuffer, vramSize);
}

void VESATerminal(uint8_t charWidth, uint8_t charHeight, void* fontPtr){
    VESADrawRect(1, 1, width, height, true, hex(0, 0, 0), width, height, pitch, vram);
    uint16_t screenW = width / charWidth;
    uint16_t screenH = width / charHeight;
    uint16_t cursorX = 0;
    uint16_t cursorY = 0;
}




struct VBE_info_block* VESAControllerInfo; //Fixed address
struct VBE_mode_info_block* VESAModeInfo; //Fixed address

uint16_t width;
uint16_t height;
uint16_t pitch;
char* vram;
char* backbuffer;

uint32_t vramSize;

char fontMap[] = {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0},
};

void main(){
    char* str = "   --- NUCK OS KERNEL RUNNING VGA---                            ";
    VGAPrintString(0, str, 0xD);


    uint32_t kernelDataOffset = 0x7C00 + 0x915;

    VBE_info_block* VESAControllerInfo = (struct VBE_info_block*) ((uint32_t)(kernelDataOffset + 1)); //Fixed address
    VBE_mode_info_block* VESAModeInfo = (struct VBE_mode_info_block*) ((uint32_t)(kernelDataOffset + 0x201)); //Fixed address

    width = (uint16_t)VESAModeInfo->width;
    height = (uint16_t)VESAModeInfo->height;
    pitch = (uint16_t)VESAModeInfo->pitch;
    vram = (char*)VESAModeInfo->framebuffer;
    backbuffer = (char*)0x100000;

    vramSize = height*pitch;


    char testMode = *(char*) kernelDataOffset;
    if(testMode == 1){
        for(uint32_t o=0;true;o+=(50*pitch)){
            flipVram(vram, (char*)o, vramSize);
        }
    }
    else if(testMode == 2){
        int x = 100;
        int y = 100;
        int w = 160;
        int h = 160;
    
        int velx = 16;
        int vely = 7;
    
        while(true){
            x += velx;
            y += vely;
    
            //detect collision
            if(y + h > height-1){
                y = height-1 - h;
                vely = -vely;
            }
            if(y < 0){
                y = 0;
                vely = -vely;
            }
            if(x + w > width-1){
                x = width-1 - w;
                velx = -velx;
            }
            if(x < 0){
                x = 0;
                velx = -velx;
            }
    
            VESADrawRect(0, 0, width-1, height-1, true, hex(0, 0, 0), backbuffer);
            VESADrawRect(x, y, x+w, y+h, true, hex(0xB1, 0xE3, 0x82), backbuffer);
            flipVram(vram, backbuffer, vramSize);
        }
    }
    else if(testMode == 3){
        //calculate one stripe
        uint16_t frac = (height-1)/5;
        VESADrawRect(0, 0, width-1, frac, true, hex(0x55, 0xCD, 0xFC), width, height, pitch, backbuffer);
        VESADrawRect(0, frac+1, width-1, frac*2, true, hex(0xF7, 0xA8, 0xB8), width, height, pitch, backbuffer);
        VESADrawRect(0, frac*2+1, width-1, frac*3, true, hex(0xFF, 0xFF, 0xFF), width, height, pitch, backbuffer);
        VESADrawRect(0, frac*3+1, width-1, frac*4, true, hex(0xF7, 0xA8, 0xB8), width, height, pitch, backbuffer);
        VESADrawRect(0, frac*4+1, width-1, frac*5, true, hex(0x55, 0xCD, 0xFC), width, height, pitch, backbuffer);
        flipVram(vram, backbuffer, vramSize);
    }
    else if(testMode == 4){
        //VESATerminalPrint();
    }

    return;
}





