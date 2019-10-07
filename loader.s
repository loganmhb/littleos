;; -*- NASM -*-
global loader

MAGIC_NUMBER equ 0x1BADB002
FLAGS equ 0x0
CHECKSUM equ -MAGIC_NUMBER
PARAMETER_STACK_SIZE equ 4096
RETURN_STACK_SIZE equ 4096
FRAMEBUF_LOC equ 0x000B8000
FRAMEBUF_MAX equ 80 * 25

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
    mov [ebp], %1
%endmacro

%macro poprsp 1
    mov %1, [ebp]
    lea ebp, [ebp + 4]
%endmacro

loader:
    mov esp, parameter_stack + PARAMETER_STACK_SIZE
    mov ebp, return_stack + RETURN_STACK_SIZE
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
    dd wrd
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

    ;; lit reads a literal value onto the stack. It works by first
    ;; reading the value into eax and advancing the stack pointer
    ;; (conveniently one instruction) and then pushing eax onto the
    ;; stack.
    defcode "lit",3,lit
    lodsd
    push eax
    next

    ;; Stack manipulation primitives
    defcode "drop",4,drop
    pop eax
    next

    defcode "dup",3,dup
    mov eax, [esp]
    push eax
    next

    defcode "swap",4,swap
    pop eax
    pop ebx
    push eax
    push ebx
    next

    defcode "rot",3,rot
    pop eax
    pop ebx
    pop ecx
    push ebx
    push eax
    push ecx
    next

    defcode "over",4,over
    mov eax, [esp + 4]
    push eax
    next

;; Arithmetic primitives
    defcode "+",1,plus
    pop eax
    add [esp], eax
    next

    defcode "*",1,multiply
    pop eax
    pop ebx
    imul eax, ebx
    push eax
    next

;; Return stack manipulation
    defcode ">r",2,pushr
    pop eax
    pushrsp eax
    next

    defcode "<r",2,popr
    poprsp eax
    push eax
    next

;; Memory manipulation
    defcode "!",1,store
    pop ebx
    pop eax
    mov [ebx], eax
    next

    defcode "@",1,fetch
    pop ebx
    mov eax, [ebx]
    push eax
    next

    defcode "C!",2,storebyte
    pop ebx
    pop eax
    mov [ebx], al
    next

    defcode "C@",2,fetchbyte
    pop ebx
    xor eax, eax
    mov al, [ebx]
    push eax
    next

;; Write to the framebuffer
%macro defword 3-4 0
section .rodata
align 4
global name_%3
name_%3:
    dd link
%define link name_%3
    db %4+%2
    dw %1
align 4
global %3
%3:
    dd docol
%endmacro

    defword "times2",6,timestwo
    dd dup
    dd plus
    dd exit

    ;; ( char cell )
    defword "fb-write-cell",13,fbwritecell
    dd lit
    dd 16                       ; framebuf cell size
    dd multiply
    dd lit
    dd FRAMEBUF_LOC
    dd plus
    dd storebyte
    dd exit

;; Comparison primitives

;; Control flow (conditional and unconditional branches)
    defcode "branch",6,branch
    add esi, [esi]
    next

    defcode "0branch",7,zbranch
    pop eax
    test eax, eax
    jz code_branch
    lodsd
    next

;; Internal control flow stuff
    defcode "exit",4,exit
    poprsp esi
    next

    defcode "quit",4,quit
    pop eax
    jmp loop

;; Since we have no stdin, key will start reading from an arbitrary buffer.
    defcode "key",3,key
    call _key
    push eax
    next

_key:
;; TODO: track when out of input and fetch more
    mov ebx, [currkey]
    xor eax, eax
    mov al, [ebx]
    inc ebx
    mov [currkey], ebx
    ret

section .data
currkey:
    dd input_buffer
input_buffer:
    dw 'dup + '

    defcode "word",4,wrd
    call _wrd
    push edi                    ; base address
    push ecx                    ; length
    next

_wrd:
;; First, skip blank characters.
.skipblanks:
    call _key
    cmp al, ' '
    jbe .skipblanks
    mov edi, wordbuffer
.findend:
    stosb
    call _key
    cmp al, ' '
    ja .findend

    sub edi, wordbuffer
    mov ecx, edi
    mov edi, wordbuffer
    ret


section .data
blank:
    dw ' '

wordbuffer:
    resb 32
