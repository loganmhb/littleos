global loader

    MAGIC_NUMBER equ 0x1BADB002
    FLAGS equ 0x0
    CHECKSUM equ -MAGIC_NUMBER
    KERNEL_STACK_SIZE equ 4096


section .text:
align 4
    dd MAGIC_NUMBER
    dd FLAGS
    dd CHECKSUM

loader:
    mov eax, 0xCAFEBABE
.loop:
    jmp .loop
    
