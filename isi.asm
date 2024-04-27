; shoutouts to the folks
 ; of the x16 discord, who
  ; helped me understand how
   ; this whole thing works.
    ; especially squall_ff8 and
     ; mooinglemur, the writers of
      ; some of this code (you can
       ; probably find it in #asm-dev
        ; lol)     - ss[motan]

.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"
  jmp start

; VRAM MAP
; $00000-$04000 -> charset
; $04001-$0FFFF -> text

; KERNAL calls
KBDPEEK = $FEBD
MEMCOPY = $FEE7
SETLFS  = $FFBA
SETNAM  = $FFBD
LOAD    = $FFD5
GETIN   = $FFE4

; KERNAL vectors
CINV    = $0314 ; 2 bytes - to $0315

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
r0_L    = $02
r0_H    = $03
r1_L    = $04
r1_H    = $05
r2_L    = $06
r2_H    = $07
r3_L    = $08
r3_H    = $09
r4_L    = $0A
r4_H    = $0B
r5_L    = $0C
r5_H    = $0D
CURCLR  = $22   ; current color
CLRSEL  = $23   ; select fg/bg color change
CARTCHE = $24   ; cartouche on/off
COLOURS = $25   ; to $35 - 16 bytes
INDEX_L = $36   ; low byte of 16 bit address
INDEX_H = $37   ; high byte of 16 bit address
NAMELEN = $38   ; how long do we need this to be
AUTHOR  = $39   ; author name (to $48 - 16 bytes)
TITLE   = $49   ; title name (to $68 - 32 bytes)
TVRAM_L = $69   ; \_ temp storage for old VRAM address
TVRAM_M = $6A   ; /- used in `cartouche`
TTAB    = $6B   ; temp address for subtraction in `tab`
LINE    = $6C   ; current line
COLUMN  = $6D   ; current column
CINDX_L = $6E   ; low byte of cursor index
CINDX_H = $6F   ; high byte of cursor index
ERRORID = $70   ; error id
VERSION = $71   ; version number
CTIMER  = $72   ; how many frames until cursor sprite toggles on/off
CHANGED = $73   ; did something change
CHARACT = $74
MODE    = $75   ; $00 - input
TXLEN_L = $76   ; low byte of character count
TXLEN_H = $77   ; high byte of character count
TCINX_L = $78   ; low byte of temp index for charcount
TCINX_H = $79   ; high byte of temp index for charcount

TXSTART = $A000 ; text data start (to $BFFF - 2048 bytes)

FONT: .literal "FONT.BIN"
TEXT: .literal "MOTAN.ISI"
ERROR: .byte $F2,$70,$92,$B9,$FF

        ; translate from PETSCII to ISI encoding, $FF - ignore
        ;      x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
KEYMAP: .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F9,$FF,$FF ;0x
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;1x
        .byte $10,$11,$12,$13,$FF,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F ;2x
        .byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F ;3x
        .byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F ;4x
        .byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$FF,$3D,$3E,$3F ;5x
        .byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F ;6x
        .byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$FF,$FF,$FF,$FF,$FF ;7x
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;8x
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;9x
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;Ax
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;Bx
        .byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F ;Cx
        .byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$FF,$FF,$FF,$FF,$FF ;Dx
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;Ex
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ;Fx


; 8 colours:        #444    #FFF    #F44    #FF4    #4F4    #4FF    #44F    #F4F    #444
DEFAULTCLR: .byte $44,$04,$FF,$0F,$44,$0F,$F4,$0F,$F4,$04,$FF,$04,$4F,$04,$4F,$0F,$44,$04

oldirq: .res 2

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

; stp

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

; stp

  lda #$FF
  sta TXSTART ; makes sure `update` doesn't break when there's nothing to load

  ldx #(<TXSTART+1)
  ldy #>TXSTART

; lda #$09
; ldx #<TEXT
; ldy #>TEXT
; jsr SETNAM
;
; lda #$01
; ldx #$08
; ldy #$00
; jsr SETLFS
;
; lda #$00
; ldx #<TXSTART ; should point to 1:$a000
; ldy #>TXSTART
; jsr LOAD

  stx CINDX_L   ; put cursor after the end of loaded text
  sty CINDX_H

;  bcc :++
;  sta ERRORID
;  ldx #0
;: lda ERROR,x
;  sta TXSTART,x
;  cmp #$FF
;  beq :+
;  inx
;  bra :-

: lda #1
  sta CHANGED

; stp
  stz r0_L      ; set up 16 bit registers for memory_copy
  lda #$01      ; r0 = $A000, r1 = $A001
  sta r1_L
  lda #$A0
  sta r0_H
  sta r1_H

  lda CINDX_L   ; put cursor AT the end of loaded text
  bne :+
  dec CINDX_H
: dec CINDX_L

  ; setup vblank
  php       
  sei
  lda CINV
  sta oldirq
  lda CINV+1
  sta oldirq+1
  lda #<vblank
  sta CINV
  lda #>vblank
  sta CINV+1
  cli
  plp

  jsr update

; stp

loop:
  nop
  bra loop
; stp

;   ldx #0
; ; stp
; : lda TESTMESSAGE,x
;   sta TXSTART,x
;   cmp #$FF
;
;   beq :+
;   inx
;   bra :-

;----------------------------- user input

userinput:

; stp

  jsr GETIN
; stp
  bne :+        ; if you didn't read anything, skip 
  rts
: tax 
  lda #1
  sta CHANGED
  lda KEYMAP,x
; stp
  cmp #$FF      ; refer to comment right before KEYMAP
  beq userinput
  pha

  ldy MODE
  bne userinput ; if mode != 0 (edit), skip

  lda (CINDX_L) ; load whatever the cursor's on
  cmp #$FF      ; is it at the end?
  beq :+        ; if so, skip the setup

  jsr cursorcharcount

  ldx CINDX_L
  stx r0_L
  inx
  stx r1_L

  ldx TXLEN_L   ; r2 = character count
  stx r2_L
  ldx TXLEN_H
  stx r2_H

  jsr MEMCOPY

: pla
  sta (CINDX_L)
  inc CINDX_L
  bne userinput
  inc CINDX_H
  bra userinput ; next character in buffer

;----------------------------- colour loading

defaultpalette:

  lda #0
: tax
  lda DEFAULTCLR,x
  sta COLOURS,x
  txa 
  ina
  cmp #$12
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
: lda #$FF
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

; stp

  stz CHANGED
  stz CLRSEL

  lda #(1<<4 + ^L0_START) ; set cursor to upper left
  sta V_ADDRx_H
  lda #>L0_START
  sta V_ADDRx_M
  lda #<L0_START
  sta V_ADDRx_L 

  stz COLUMN
  stz LINE

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
; stp
  stz CARTCHE   ; cartouche off

: pha
  lda CARTCHE   ; CARTCHE == 0?
  beq :+        ; if so, branch
  jsr cartouche
: pla

  sta V_DATA0   ; show the character
  inc COLUMN    ; increment character
  
  cmp #$ED      ; character == $ED? (cartouche start)
  bcc :+        ; if not, branch
  lda #$01      ; cartouche on
  sta CARTCHE

: lda COLUMN
  cmp #$50
  bne :+
  lda CURCLR
  sta V_DATA0
  jsr nextline
  bra nextindex

: lda CURCLR
  sta V_DATA0

  bra nextindex

checkmeta:

; stp

  cmp #$FA
  bne :+
  jsr tab
  rts

: cmp #$F8      ; character >= $F8?
  bcs :+        ; if yes, branch
  jsr setcolour
  rts

: bne :+        ; if not equal, branch
  pha
  lda CLRSEL
  eor #1
  sta CLRSEL
  pla

: cmp #$F9
  bne :+
  jsr nextline

: cmp #$FB
  bne :+
  ldy #$30      ; title length + 16 for the offset
  sty NAMELEN
  ldx #$10      ; offset from AUTHOR to TITLE
  jsr name

: cmp #$FC
  bne :+
  ldy #10       ; author length
  sty NAMELEN
  ldx #0        ; no offset
  jsr name

  ; if $FD isn't preceded by either $FB or $FC at some point, ignore it
  
  cmp #$FE
  bne :+
  sta VERSION

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
  cmp #0
  bne :+
  lda #$90    ; fake black
: sta V_DATA1

  stz V_CTRL  ; ADDRSEL = 0 -> data port 0 selected
  ; no need to restore TVRAM_# to V_ADDRx_#
  ; since they haven't changed

  rts

nextline:

; stp

  stz COLUMN
  inc LINE      ; next line
  stz V_ADDRx_L
  inc V_ADDRx_M
  stz CARTCHE

  rts

tab:

; stp

  lda COLUMN
  and #%00000001  ; mod 2
  bne :+
  lda #2

: ldx #$10        ; space
  stx V_DATA0
  ldx CURCLR
  stx V_DATA0
  pha
  inc COLUMN
  lda COLUMN
  cmp #$50
  bcc :+
  stz COLUMN
  inc LINE
: pla
  dec a
  bne :--

  rts

name:

  inc INDEX_L
  bne :+
  inc INDEX_H

: lda (INDEX_L)
  cmp #$FD
  beq :+

  sta AUTHOR,x
  inx

  cpx NAMELEN ; are we over the limit yet?
  bcs :+      ; make sure to branch if it somehow gets bigger than NAMELEN

  bra name

: rts

;----------------------------- count characters

cursorcharcount:

  lda CINDX_L   ; set TCINX to the current cursor pos
  sta TCINX_L
  lda CINDX_H
  sta TCINX_H

  lda (TCINX_L) ; get character
  cmp #$FF      ; is this the end?
  bne :+        ; if not...
  rts           ;           done!

: inc TCINX_L
  bne :+
  inc TCINX_H

: inc TXLEN_L
  bne cursorcharcount
  inc TXLEN_H
  bra cursorcharcount

;----------------------------- vblank

vblank:

; stp

  jsr userinput
  lda CHANGED
  beq :+      ; if nothing changed, don't update
  jsr update

: jmp (oldirq)
