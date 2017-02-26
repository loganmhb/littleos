#include "io.h"

#ifndef INCLUDE_FRAMEBUF_H
#define INCLUDE_FRAMEBUF_H
#define FB_GREEN 2
#define FB_DARK_GRAY 12
#define FB_LENGTH 80*25

#define FB_COMMAND_PORT 0x3D4
#define FB_DATA_PORT 0x3D5
#define FB_LOW_BYTE_COMMAND 15
#define FB_HIGH_BYTE_COMMAND 14

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg);

void fb_move_cursor(unsigned short pos); 
#endif
