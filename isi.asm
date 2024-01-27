.org $080d
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

CHROUT  = $ffd2
CHARSET = 

print_hex:
  pha           ; push original a to stack
  lsr
  lsr
  lsr
  lsr           ; a = a >> 4
  jsr print_hex_digit
  pla           ; pull original a back from stack
  and #$0f      ; a = a & 0b00001111
  jsr print_hex_digit
  rts
print_hex_digit:
  cmp #$0a
  bpl @letter
  ora #$30      ; petscii numbers: 1=$31, 2=$32, etc.
  bra @print
@letter:
  clc
  adc #$37      ; petscii letters: a=$41, b=$42, etc.
@print:
  jsr CHROUT
  rts

start:

  lda $0000
  jsr print_hex
  rts
