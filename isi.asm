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
V_ADDR0_L     = $9F20
V_ADDR0_M     = $9F21
V_ADDR0_H     = $9F22
V_DATA0       = $9F23
V_CTRL        = $9F25
V_DC_VIDEO    = $9F29
V_L0_CONFIG   = $9F2D
V_L0_MAPBASE  = $9F2E
V_L0_TILEBASE = $9F2F

; VRAM addresses
CHARSET   = $00000
L0_START  = $04000  ; text
L1_START  = $06000  ; cartouche lines, maybe menus?

; RAM addresses
BANK    = $00
CLCOUNT = $22
L0START = $A000
L0END   = $BFFF
L1START = $C000
L1END   = $DFFF


FONT: .literal "FONT.BIN"
TEXT: .literal "TEXT.ISI"

start:

  stz V_CTRL
  lda #%01010001  ; VGA, layer 1, layer 0, sprites
  sta V_DC_VIDEO

  ; h=32(0), w=128(2), t256c(0), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 0<<3 + 0<<2 + 0)
  sta V_L0_CONFIG

  lda #(L0_START>>9)
  sta V_L0_MAPBASE
  
  ; tilebase address = $00000, h=16(1), w=8(0)
  lda #%00000010
  sta V_L0_TILEBASE

  ; load charset
  lda #$08  ; FONT filename length
  ldx #<FONT
  ldy #>FONT
  jsr SETNAM

  lda #$01  ; logical file number - 1
  ldx #$08  ; device number - SD card
  ldy #$00  ; secondary address - load
  jsr SETLFS

  lda #$02  ; load location - VRAM from $00000
  ldx #<CHARSET
  ldy #>CHARSET
  jsr LOAD

  lda #(1<<4 + ^L0_START)  ; address increment - 1, highest bit of address
  sta V_ADDR0_H
  lda #>L0_START           ; middle byte of address
  sta V_ADDR0_M
  lda #<L0_START           ; low byte of address
  sta V_ADDR0_L
  
; lda #$DE
; sta V_DATA0
; lda #$01
; sta V_DATA0
; lda #$60
; sta V_DATA0
; lda #$01
; sta V_DATA0

L0_clearloop:
  lda V_ADDR0_M
  cmp #$60
  beq L1_escape
  lda #$10      ; space
  sta V_DATA0
  lda #$10      ; white on black
  sta V_DATA0
L0_checkaddr:
  lda V_ADDR0_L
  cmp #$A0      ; check if V_ADDR0_L=$A0
  bne L0_clearloop
  inc V_ADDR0_M
  stz V_ADDR0_L
  bne L0_clearloop
L1_clearloop:
  lda V_ADDR0_M
  cmp #$80
  beq L1_escape
  lda #$10      ; space
  sta V_DATA0
  lda #$10      ; white on transparent
  sta V_DATA0
L1_checkaddr:
  lda V_ADDR0_L
  cmp #$A0      ; check if V_ADDR0_L=$A0
  bne L1_clearloop
  inc V_ADDR0_M
  stz V_ADDR0_L
  bne L1_clearloop
L1_escape:
  

; lda #$08  ; TEXT filename length
; ldx #<TEXT
; ldy #>TEXT
; jsr SETNAM

; lda #$02
; ldx #<L0_START
; ldy #>L0_START
; jsr LOAD

  rts
