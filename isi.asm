; shoutouts to the folks
 ; of the x16 discord, who
  ; helped me understand how
   ; this whole thing works.
    ; especially squall_ff8, the
     ; writer of some of this code
      ; (you can probably find it in
       ; #asm-dev lol)     - ss[motan]

.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"
  jmp start

; VRAM MAP
; $00000-$04000 -> charset
; $04001-$0FFFF -> text

; KERNAL calls
LOAD    = $FFD5
SETLFS  = $FFBA
SETNAM  = $FFBD

; VERA registers
V_ADDRx_L     = $9F20
V_ADDRx_M     = $9F21
V_ADDRx_H     = $9F22
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
PALETTE   = $1FA00  ; palette data until $1FBFF

; RAM addresses
BANK    = $00
CLCOUNT = $22       ; unused
CURCLR  = $23
CLRSEL  = $24
COLOURS = $25       ; until $43
INDEX_L = $45
INDEX_H = $46
TXSTART = $A000

FONT: .literal "FONT.BIN"
TEXT: .literal "TEXT.ISI"

; 8 colours:        #444    #FFF    #F44    #FF4    #4F4    #4FF    #44F    #F4F
DEFAULTCLR: .byte $44,$04,$FF,$0F,$44,$0F,$F4,$0F,$F4,$04,$FF,$04,$4F,$04,$4F,$0F
; ca65 is deciding to only store 6 of them in the list file. wtf.

;                   ni  li  pona ala pona    cs  c3  T   cs  c4  E   c6  S   T   eof
TESTMESSAGE: .byte $B1,$92,$C5, $62,$C5,$10,$F8,$F3,$54,$F8,$F4,$45,$F6,$53,$54,$FF

start:

; stp

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

  jsr defaultpalette

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

  lda #(1<<4 + ^L0_START)   ; address increment - 1, highest bit of address
  sta V_ADDRx_H
  lda #>L0_START            ; middle byte of address
  sta V_ADDRx_M
  lda #<L0_START            ; low byte of address
  sta V_ADDRx_L
  
  lda #$10
  sta CURCLR
  stz CLRSEL

  jsr L0_clearloop 

  ldx #0
: lda TESTMESSAGE,x
  sta TXSTART,x
  cmp #$FF
  beq :+
  inx
  bra :-

: jsr update

  rts

defaultpalette:

  lda #0
: tax
  lda DEFAULTCLR,x
  sta COLOURS,x
  txa 
  ina
  cmp #$10
  bne :-

loadpalette:

  lda #(1<<4 + ^PALETTE)
  sta V_ADDRx_H
  lda #>PALETTE
  sta V_ADDRx_M
  lda #<PALETTE
  sta V_ADDRx_L

  lda #0
: tax
  lda COLOURS,x
  sta V_DATA0
  txa 
  ina
  cmp #$10
  bne :-

  rts

L0_clearloop:

  lda V_ADDRx_M
  cmp #$60
  beq L1_clearloop
  lda #$10      ; space
  sta V_DATA0
  lda #$10      ; white on grey
  sta V_DATA0

L0_checkaddr:

  lda V_ADDRx_L
  cmp #$A0      ; check if V_ADDRx_L=$A0
  bne L0_clearloop
  inc V_ADDRx_M
  stz V_ADDRx_L
  bne L0_clearloop
  
L1_clearloop:

  lda V_ADDRx_M
  cmp #$80
  beq RAM_clearloop
  lda #$10      ; space
  sta V_DATA0
  lda #$10      ; white on transparent
  sta V_DATA0

L1_checkaddr:

  lda V_ADDRx_L
  cmp #$A0      ; check if V_ADDRx_L=$A0
  bne L1_clearloop
  inc V_ADDRx_M
  stz V_ADDRx_L
  bne L1_clearloop

RAM_clearloop:
  
; stp

  lda #<TXSTART
  sta INDEX_L
  lda #>TXSTART
  sta INDEX_H
: lda #$10
  sta (INDEX_L)
  inc INDEX_L
  lda INDEX_L
  bne :+
  inc INDEX_H
; stp
: lda INDEX_H
  cmp #$C0
  bcc :--

  rts

;--- everything below here is unfinished and will not run

nextindex:
  
  inc INDEX_L
  bne checkchar
  inc INDEX_H
  bra checkchar

update:
  
  stp

  lda #(1<<4 + ^L0_START) ; set cursor to upper left
  sta V_ADDRx_H
  lda #>L0_START
  sta V_ADDRx_M
  lda #<L0_START
  sta V_ADDRx_L 

  lda #<TXSTART
  sta INDEX_L
  lda #>TXSTART
  sta INDEX_H
  
checkchar:

  lda (INDEX_L)
  cmp #$FF      ; character >= $FF? (EOF)
  bne :+        ; if not, branch
  rts
: cmp #$EF      ; character >= $EF? (visible symbol)
  bcc :+        ; if not, branch
  jsr checkmeta
  bra nextindex

: sta V_DATA0
  lda CURCLR
  sta V_DATA0

  bra nextindex

checkmeta:

  cmp #$F8      ; character >= $F8?
  bcs :+        ; if yes, branch
  jsr setcolour
  rts

: bne :+        ; if not equal, branch
  pha
  lda CLRSEL
  eor #1
  sta CLRSEL
  pla

: rts

setcolour:

  and #$0F
  ldx CLRSEL
  cpx #1      ; CRLSEL = 1?
  bne :+      ; if not, branch

  asl a       ; set bg colour
  asl a
  asl a
  asl a       ; eg. $F5 -> $50
  pha
  lda CURCLR
  and #$0F
  sta CURCLR
  pla
  ora CURCLR
  sta CURCLR
  rts

: pha         ; set fg colour
  lda CURCLR
  and #$F0
  sta CURCLR
  pla
  ora CURCLR
  sta CURCLR

  rts
