#include "framebuf.h"

int deadbeef() {
  return 0xDEADBEEF;
}

int kmain() {
  // Clear screen
  for (int i = 0; i < FB_LENGTH; i++) {
    fb_write_cell(i, 'A', 0, 0);
  }
  char *hello = "Hello, world!";
  int i = 0;
  while (hello[i] != 0) {
    fb_write_cell(i, hello[i], FB_GREEN, 0);
    i++;
  }

  fb_move_cursor(80);
  return deadbeef();
}
