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
V_ADDRx_L     = $9F20 ; VERA address low byte
V_ADDRx_M     = $9F21 ; VERA address middle byte
V_ADDRx_H     = $9F22 ; VERA address inc, dec on/off; nibble inc, address; address high byte
V_DATA0       = $9F23 ; VERA data port 0
V_DATA1       = $9F24 ; VERA data port 1
V_CTRL        = $9F25 ; reset, DCSEL, ADDRSEL
V_DC_VIDEO    = $9F29
V_L0_CONFIG   = $9F2D
V_L0_MAPBASE  = $9F2E
V_L0_TILEBASE = $9F2F
V_L1_CONFIG   = $9F34
V_L1_MAPBASE  = $9F35
V_L1_TILEBASE = $9F36

; VRAM addresses
L0_START  = $00000  ; text
L1_START  = $02000  ; cartouche lines, maybe menus?
CHARSET   = $04000  ; to $04FFF
PALETTE   = $1FA00  ; palette data (to $1FBFF)

; RAM addresses
BANK    = $00
CLCOUNT = $22       ; unused
CURCLR  = $23       ; current color
CLRSEL  = $24       ; select fg/bg color change
CARTCHE = $25       ; cartouche on/off
COLOURS = $26       ; to $35 - 16 bytes
INDEX_L = $36       ; low byte of 16 bit address
INDEX_H = $37       ; high byte of 16 bit address
AUTHOR  = $38       ; author name (to $37 - 16 bytes)
TITLE   = $48       ; title name (to $67 - 32 bytes)
TVRAM_L = $49       ; \_ temp storage for old VRAM address \
TVRAM_M = $4A       ; /- used in `cartouche`               /
TXSTART = $A000     ; text data start (to $BFFF - 2048 bytes)

FONT: .literal "FONT.BIN"
TEXT: .literal "TEXT.ISI"

; 8 colours:        #444    #FFF    #F44    #FF4    #4F4    #4FF    #44F    #F4F
DEFAULTCLR: .byte $44,$04,$FF,$0F,$44,$0F,$F4,$0F,$F4,$04,$FF,$04,$4F,$04,$4F,$0F
; ca65 is deciding to only store 6 of them in the list file. wtf.

;                   ni  li  pona ala pona    cs  c3  T   cs  c4  E   c6  S   T       soweli sewi sc  monsi .   tan :   ec  eof
TESTMESSAGE: .byte $B1,$92,$C5, $62,$C5,$10,$F8,$F3,$54,$F8,$F4,$45,$F6,$53,$54,$10,$D4,   $CB, $ED,$A5,  $EB,$D9,$EC,$EE,$FF

;-----------------------------

start:

; stp

  stz V_CTRL
  lda #%01110001  ; sprites on, L1 on, L0 on, VGA on
  sta V_DC_VIDEO

  ; h=32(0), w=128(2), t256c(0), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 0<<3 + 0<<2 + 0)
  sta V_L0_CONFIG

  lda #(L0_START>>9)
  sta V_L0_MAPBASE

  ; tilebase address = $04000, h=16(1), w=8(0)
  lda #(CHARSET>>9 + %10)
  sta V_L0_TILEBASE

  ; h=32(0), w=128(2), t256c(0), !bitmap(0), 1bpp(0)
  lda #(0<<6 + 2<<4 + 0<<3 + 0<<2 + 0)
  sta V_L1_CONFIG

  lda #(L1_START>>9)
  sta V_L1_MAPBASE

  ; tilebase address = $04000, h=16(1), w=8(0)
  lda #(CHARSET>>9 + %10)
  sta V_L1_TILEBASE

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

  lda #$06  ; load location - VRAM from $04000
  ldx #<CHARSET
  ldy #>CHARSET
  jsr LOAD

  lda #(1<<4 + ^L0_START)   ; address increment - 1, highest bit of address
  sta V_ADDRx_H
  lda #>L0_START            ; middle byte of address
  sta V_ADDRx_M
  lda #<L0_START            ; low byte of address
  sta V_ADDRx_L

  lda #1
  sta V_CTRL
  lda #(1<<4 + ^L1_START)
  sta V_ADDRx_H
  stz V_CTRL

  lda #$10
  sta CURCLR
  stz CLRSEL

  stz CARTCHE

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

;----------------------------- colour loading

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

;----------------------------- clear screen

L0_clearloop:

  lda V_ADDRx_M
  cmp #$20
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
  cmp #$40
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

;----------------------------- screen update

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
: cmp #$EF      ; character == $EF? (visible symbol)
  bcc :+        ; if not, branch
  jsr checkmeta
  bra nextindex
  
: cmp #$EE      ; character == $EE? (cartouche end)
  bcc :+        ; if not, branch
  stz CARTCHE   ; cartouche off

: pha
  lda CARTCHE   ; CARTCHE == 0?
  beq :+        ; if so, branch
  jsr cartouche
: pla

  sta V_DATA0   ; show the character
  
  cmp #$ED      ; character == $ED? (cartouche start)
  bcc :+        ; if not, branch
  lda #$01      ; cartouche on
  sta CARTCHE

: lda CURCLR
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

cartouche:

  lda V_ADDRx_L
  sta TVRAM_L ; save old address
  lda V_ADDRx_M
  sta TVRAM_M
  
  lda #$01
  sta V_CTRL  ; ADDRSEL = 1 -> data port 1 selected

  lda TVRAM_L
  sta V_ADDRx_L
  lda TVRAM_M
  ora #$20    ; +$02000
  sta V_ADDRx_M

  lda #$EF    ; cartouche line character
  sta V_DATA1
  lda CURCLR
  and #$F0    ; ensures transparent bg  
  sta V_DATA1

  stz V_CTRL  ; ADDRSEL = 0 -> data port 0 selected
  ; no need to restore TVRAM_# to V_ADDRx_#
  ; since they haven't changed

  rts
