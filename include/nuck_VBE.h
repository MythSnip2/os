#ifndef NUCK_VBE_H
#define NUCK_VBE_H

#include <nuck_stddef.h>

struct __attribute__((packed)) VBE_info_block{
    char signature[4];
    uint16_t version;              // 0x0300 for VBE 3.0
    uint16_t OEMStringPtr[2];         // VBE far ptr
    uint8_t capabilities[4];
    uint16_t videoModePtrOffset;         // segment:offset
    uint16_t videoModePtrSegment;
    uint16_t totalMemory;             // number of 64KB blocks
    uint8_t reserved69[492];
};

struct __attribute__((packed)) VBE_mode_info_block{
    uint16_t attributes;		// deprecated, only bit 7 should be of interest to you, and it indicates the mode supports a linear frame buffer.
	uint8_t windowA;			// deprecated
	uint8_t windowB;			// deprecated
	uint16_t granularity;		// deprecated; used while calculating bank numbers
	uint16_t windowSize;
	uint16_t segmentA;
	uint16_t segmentB;
	uint32_t winFuncPtr;    // deprecated; used to switch banks from protected mode without returning to real mode
	uint16_t pitch;			// number of bytes per horizontal line
	
	uint16_t width;			// width in pixels
	uint16_t height;			// height in pixels
	uint8_t charWidth;			// unused...
	uint8_t charHeight;			// ...
	uint8_t planes;
	uint8_t bpp;			// bits per pixel in this mode
	uint8_t banks;			// deprecated; total number of banks in this mode
	uint8_t memoryModel;
	uint8_t bankSize;   	// deprecated; size of a bank, almost always 64 KB but may be 16 KB...
	uint8_t imagePages;
	uint8_t reserved0;

	uint8_t redMask;
	uint8_t redPos;
	uint8_t greenMask;
	uint8_t greenPos;
	uint8_t blueMask;
	uint8_t bluePos;
	uint8_t reservedMask;
	uint8_t reservedPos;
	uint8_t directColorAttributes;

	uint32_t framebuffer;		// physical address of the linear frame buffer; write here to draw to the screen
	uint32_t offScreenMemOffset;
	uint16_t offScreenMemSize;	// size of memory in the framebuffer but not being displayed on the screen
	uint8_t reserved[206];
};

#endif
