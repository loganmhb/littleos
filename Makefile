os.iso: kernel.elf
	genisoimage -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -A os -input-\
charset utf8 -quiet -boot-info-table -o os.iso iso

kernel.elf: loader.o
	ld -T link.ld -melf_i386 loader.o -o kernel.elf

loader.o: loader.s
	nasm -f elf32 loader.s
