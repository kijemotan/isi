; shoutouts to the folks
 ; of the x16 discord, who
  ; helped me understand how
   ; this whole thing works.
    ; especially squall_ff8, the
     ; writer of some of this code
      ; (you can probably find it in
       ; #asm-dev lol)     - ss[motan]

.org $080d
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

; VRAM MAP
; $00000-$04000 -> charset
; $04001-$0FFFF -> text

; KERNAL calls
CHROUT  = $FFD2
LOAD    = $FFD5
SETLFS  = $FFBA
SETNAM  = $FFBD

; VERA registers
V_CTRL      = $9F25
V_DC_VIDEO  = $9F29
V_L0_CONFIG = $9F2D

; VRAM addresses
CHARSET = $00000
CONTENT = $04001

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

  stz V_CTRL
  lda #%01010001  ; VGA, layer 0, sprites
  sta V_DC_VIDEO

  ; h=32(0), w=128(2), t256c(1), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 1<<3 + 0<<2 + 0)
  sta V_L0_CONFIG

  rts
