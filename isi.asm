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

start:

  stz V_CTRL
  lda #%01010001  ; VGA, layer 0, sprites
  sta V_DC_VIDEO

  ; h=32(0), w=128(2), t256c(1), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 1<<3 + 0<<2 + 0)
  sta V_L0_CONFIG

  rts
