#ifndef INCLUDE_IO_H
#define INCLUDE_IO_H

/* outb - defined in io.s
 * Send data to an I/O port.
 */
void outb(unsigned short port, unsigned char data);

#endif
