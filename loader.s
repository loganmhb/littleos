;; -*- NASM -*-
global loader

MAGIC_NUMBER equ 0x1BADB002
FLAGS equ 0x0
CHECKSUM equ -MAGIC_NUMBER
PARAMETER_STACK_SIZE equ 4096
RETURN_STACK_SIZE equ 4096

section .bss
align 4

parameter_stack:
    resb PARAMETER_STACK_SIZE

return_stack:
    resb RETURN_STACK_SIZE


section .text
align 4
    dd MAGIC_NUMBER
    dd FLAGS
    dd CHECKSUM

%macro next 0
    lodsd
    jmp [eax]
%endmacro

;; Push and pop for the return stack
%macro pushrsp 1
    lea ebp, [ebp - 4]
    mov ebp, %1
%endmacro

%macro poprsp 1
    mov %1, [ebp]
    lea ebp, [ebp + 4]
%endmacro

loader:
    mov esp, parameter_stack + PARAMETER_STACK_SIZE
    mov ebp, return_stack + RETURN_STACK_SIZE
    mov eax, 0xDEADBEEF
    mov esi, cold_start         ; Initialize the interpreter
    next

docol:
    pushrsp esi

    add eax, 4                 ; eax points at the codeword, which lets us
    mov esi, eax               ; point esi at the first data word
    next

loop:
    jmp loop

section .rodata

dictionary_end:                           ; Initialize the empty dictionary
    dd 0

%define link dictionary_end

cold_start:
    dd quit

;; DEFCODE - macro for defining Forth words implemented in assembly
;;
;; This does two things: adds a new dictionary entry to the head of
;; the dictionary linked list, and points it at the assembly
;; implementation to the .text section
;;
;; args: name, name length, label, flags
    %macro defcode 3-4 0
section .rodata
align 4

    ;; Dictionary entry
global %3_label
%3_label:
    dd link
%define link %3_label
    db %4+%2
    dd %1
    align 4

global %3
%3:
    dd code_%3

    ;; Implementation
section .text
global code_%3
code_%3:
;; (asm implementation follows macro invocation)
    %endmacro

    defcode "quit",4,quit
    mov eax, 0xDEADBEEF
    jmp loop
