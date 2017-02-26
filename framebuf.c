static char *framebuf = (char *)0x000B8000;

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg) {
  framebuf[2*i] = c;
  framebuf[2*i+1] = ((bg & 0x0F) << 4) | (fg & 0x0f);
}
