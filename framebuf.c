#include "io.h"
#include "framebuf.h"
#define FRAMEBUF_LOC 0x000B8000
#define FRAMEBUF_MAX 80 * 25

struct fb_cell {
  char character;
  char color;
} __attribute__((packed));


static struct fb_cell *framebuf = (struct fb_cell *)FRAMEBUF_LOC;
static int fb_offset = 0; // current position

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

/* Scroll one line by copying each row into the previous and clearing
   the last one. */
void fb_scroll() {
  for (int row=0; row < 24; row++) {
    for (int col=0; col < 80; col++) {
      framebuf[80*row + col] = framebuf[(80*(row+1))+col];
    }
  }
  struct fb_cell empty_cell;
  empty_cell.character = 'A';
  empty_cell.color = 0x00;
  for (int col=0; col<80; col++) {
    framebuf[80*24 + col] = empty_cell;
  }
}

/* Append a single char to the framebuffer, scrolling if necessary. */
void fb_append_char(char c) {
  if (c == '\n') fb_offset += 80 - (fb_offset % 80);
  if (fb_offset >= FRAMEBUF_MAX) {
    fb_scroll();
    fb_offset -= 80;
  }
  if (c != '\n')
    fb_write_cell(fb_offset++, c, FB_GREEN, 0);
}

void fb_write(char *buf) {
  while(*buf != 0) fb_append_char(*buf++);
}
