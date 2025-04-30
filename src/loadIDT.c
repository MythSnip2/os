
//total of 256 entries, each entry 64b
// entry:
// offset(low)(16b), address of the interrupt service routine
// segment selector(16b), must point to valid code segment in GDT
// reserved(8b)
// gate type(4b): define type of gate it represents
//   0x5: task gate, in this case, offset value is unused and should be set to 0
//   0x6: 16bit interrupt gate
//   0x7: 16bit trap gate
//   0xE: 32bit interrupt gate
//   0xF: 32bit trap gate
// reserved(1b): 0
// DPL(2b): what ring is allowed to use this interrupt, hardware interrupts bypass this
// Present bit(1b): 1 if interrupt descriptor is valid
// offset(high)(16b), address of interrupt service routine

void loadIDT(){

    return;
}






