#include "framebuf.h"

int deadbeef() {
  return 0xDEADBEEF;
}

int kmain() {
  // Clear screen
  for (int i = 0; i < FB_LENGTH; i++) {
    fb_write_cell(i, 'A', 0, 0);
  }
  fb_write("\n\nHello, world!\n\n");
  return deadbeef();
}
