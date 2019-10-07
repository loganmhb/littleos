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
    dd lit
    dd 4
    dd lit
    dd 2
    dd interpret
    dd quit

    F_IMMED equ 0x80
    F_HIDDEN equ 0x20
    F_LENMASK equ 0x1F

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
    db %1
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
    dw '+ '

    defcode "word",4,wrd
    call _wrd
    push edi                    ; base address
    push ecx                    ; length
    next

_wrd:
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

    ;; Return word length in ecx, start in edi
    sub edi, wordbuffer
    mov ecx, edi
    mov edi, wordbuffer
    ret

section .bss

wordbuffer:
    resb 32

    defcode "number",6,number
    call _number
    push eax
    next

_number:
    ;; todo implement for real
    push 2

%macro defvar 3-5 0, 0
    defcode %1, %2, %3, %4
    push var_%3
    next

section .data
align 4
var_%3:
    dd %5
%endmacro

    defvar "latest",6,latest,0,name_fbwritecell ; dictionary start
    defvar "here",4,here                 ; next available memory
    defvar "state",5,state,0,0             ; compiling?
    defvar "s0",2,sz                     ; top of param stack
    defvar "base",4,base                 ; base of param stack

;; Find a word in the dictionary
    defcode "find",4,find
    pop ecx                     ; length
    pop edi                     ; address
    call _find
    push eax                    ; address of dictionary entry, or NUL
    next

_find:
    push esi
    mov edx, [var_latest]
.checkentry:
    test edx, edx               ; nul pointer?
    je .notfound

    xor eax, eax
    mov al, [edx + 4]           ; al = flags + length field
    and al, F_HIDDEN | F_LENMASK
    cmp al, cl
    jne .nextword

;; The length is correct, so compare the strings in detail.
    push ecx
    push edi
    lea esi, [edx + 5]
    repe cmpsb
    pop edi
    pop ecx
    jne .nextword

;; Found it!
    pop esi
    mov eax, edx
    ret

.nextword:
    mov edx, [edx]
    jmp .checkentry

.notfound:
    pop esi
    xor eax, eax
    ret

    defcode ">cfa",4,tcfa
    pop edi
    call _tcfa
    push edi
    next

_tcfa:
    xor eax, eax
    add edi, 4                  ; skip link
    mov al, [edi]               ; load length byte
    inc edi
    and al, F_LENMASK
    add edi, eax
    add edi, 3
    and edi, ~3
    ret

    ;; Create a dictionary header for a word
    defcode "create",6,create
    pop ecx                     ; length of name
    pop ebx                     ; address of name

    mov edi, var_here
    mov eax, var_latest
    stosd

    mov al, cl
    stosb
    push esi
    mov esi, ebx
    rep movsb
    pop esi
    add edi, 3
    and edi, ~3
    mov eax, var_here
    mov [var_latest], eax
    mov [var_here], edi
    next

    defcode ",",1,comma
    pop eax
    call _comma
    next

_comma:
    mov edi, var_here
    stosd
    mov [var_here], edi
    ret

    defcode "[",1,lbrac,F_IMMED
    xor eax, eax
    mov [var_state], eax
    next

    defcode "]",1,rbrac
    mov [var_state], dword 1
    next

    defword ":",1,colon
    dd wrd
    dd create
    dd lit
    dd docol
    dd comma
    dd latest
    dd fetch
    dd hidden
    dd rbrac
    dd exit

    defword ";",1,semicolon
    dd lit
    dd exit
    dd comma
    dd latest
    dd fetch
    dd hidden
    dd lbrac
    dd exit

    defcode "immediate",9,immediate
    mov edi, var_latest
    add edi, 4
    xor [edi], dword F_IMMED
    next

    defcode "hidden",6,hidden
    pop edi
    add edi, 4
    xor [edi], dword F_HIDDEN
    next

    defword "hide",4,hide
    dd wrd
    dd find
    dd hidden
    dd exit

    defcode "interpret",9,interpret
    call _wrd

    xor eax, eax
    mov [interpret_is_lit], eax
    call _find
    test eax, eax

    jz .notfound

    mov edi, eax
    mov al, [edi + 4]
    push ax
    call _tcfa
    pop ax
    and al, F_IMMED
    mov eax, edi
    jnz .execute

    jmp .compileorexecute

.notfound:
    inc dword [interpret_is_lit]        ; assume it's a number
    call _number
    test ecx, ecx
    jnz .error
    mov ebx, eax
    mov eax, lit

.compileorexecute:
    mov edx, [var_state]
    test edx, edx
    jz .execute

    call _comma
    mov ecx, interpret_is_lit
    test ecx, ecx
    jz .next
    mov eax, ebx                ; append literal number
    call _comma

.next:
    next

.execute:
    mov ecx, [interpret_is_lit]
    test ecx, ecx
    jnz .executelit

    ;; this doesn't return, but the codeword will call next which will re-enter the loop
    jmp [eax]

.executelit:
    push ebx
    next

.error:
    ;; todo
    next

section .data
align 4
interpret_is_lit:
    dd 0

;; TODO: implement `number` to read a numeric literal

    defcode "quit",4,quit
    pop eax
    jmp loop
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
