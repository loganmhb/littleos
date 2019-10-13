\ -*- Fundamental -*-
\ Forth kernel

\ CONTROL STRUCTURES
\
\ if syntax: `<condition> if <true clause> [else <false clause>] then`
\ compiles to `condition branch0 <else clause loc> <true clause> branch <thenloc> | <else clause>
: if immediate   \ compile a branch with a dummy offset, and save the location on the stack
    ' 0branch ,  \ so we can edit it later in `else` or `then`
    here @
    0 , ;

: then immediate
    dup
    here @ swap - \ calculate the offset from the address on the stack
    swap ! ;      \ and store it

: else immediate
    ' branch ,    \ branch over the else clause to end the if section
    here @
    0 ,           \ dummy offset to be filled in by then
    swap dup      \ fill in offset for first branch
    here @
    swap -
    swap ! ;

\ begin ... until loop
: begin immediate
  here @ ;

: until immediate
  ' 0branch ,
  here @ -        \ calculate offset from value stored by `begin`
  , ;

: again immediate \ infinite loop, break via `exit`
  ' branch ,
  here @ -
  , ;

\ begin <condition> while <body> repeat
: while immediate
  ' 0branch ,
  here @
  0 , ;

: repeat immediate
  ' branch ,
  swap
  here @ - ,
  dup
  here @ swap -
  swap ! ;

: framebuf-size 80 25 * ;

: framebuf-start 753664 ;

: fb-write-cell 2 * framebuf-start + c! ;

: fb-clear-cell
  0 swap
  2 * framebuf-start + 1 +
  c! ;

: clear-screen
  0                 \ start index
  begin
  dup fb-clear-cell
  1 +
  dup framebuf-size =
  until ;

clear-screen
end
