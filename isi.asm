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
CHARSET = $00000
CONTENT = $04000

FONT: .literal "FONT.BIN"

start:

  stz V_CTRL
  lda #%01010001  ; VGA, layer 0, sprites
  sta V_DC_VIDEO

  ; h=32(0), w=128(2), t256c(0), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 0<<3 + 0<<2 + 0)
  sta V_L0_CONFIG

  lda #(CONTENT>>9)
  sta V_L0_MAPBASE
  
  ; tilebase address = $00000, h=16(1), w=8(0)
  lda #%00000010
  sta V_L0_TILEBASE

  ; load charset
  lda #$08  ; filename length
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

  lda #(1<<4 + ^CONTENT)  ; address increment - 1, highest bit of address
  sta V_ADDR0_H
  lda #>CONTENT           ; middle byte of address
  sta V_ADDR0_M
  lda #<CONTENT           ; low byte of address
  sta V_ADDR0_L
  
  lda #$DE
  sta V_DATA0
  lda #$01
  sta V_DATA0
  lda #$60
  sta V_DATA0
  lda #$01
  sta V_DATA0

  rts
