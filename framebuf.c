#include "io.h"
#include "framebuf.h"
#define FRAMEBUF_LOC 0x000B8000

struct fb_cell {
  char character;
  char color;
} __attribute((packed));


static struct fb_cell *framebuf = (struct fb_cell *)FRAMEBUF_LOC;
// static struct fb_cell *fb_idx = (struct fb_cell *)FRAMEBUF_LOC; // current position

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg) {
  framebuf[i].character = c;
  framebuf[i].color = ((bg & 0x0F) << 4) | (fg & 0x0f);
}

void fb_move_cursor(unsigned short pos) {
  outb(FB_COMMAND_PORT, FB_HIGH_BYTE_COMMAND);
  outb(FB_DATA_PORT, ((pos >> 8) & 0x00FF));
  outb(FB_COMMAND_PORT, FB_LOW_BYTE_COMMAND);
  outb(FB_DATA_PORT, pos & 0x00FF);
}
