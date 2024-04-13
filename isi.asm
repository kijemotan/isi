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
CLCOUNT = $22   ; unused
CURCLR  = $23   ; current color
CLRSEL  = $24   ; select fg/bg color change
CARTCHE = $25   ; cartouche on/off
COLOURS = $26   ; to $35 - 16 bytes
INDEX_L = $36   ; low byte of 16 bit address
INDEX_H = $37   ; high byte of 16 bit address
NAMELEN = $38   ; how long do we need this to be
AUTHOR  = $39   ; author name (to $37 - 16 bytes)
TITLE   = $49   ; title name (to $67 - 32 bytes)
TVRAM_L = $68   ; \_ temp storage for old VRAM address
TVRAM_M = $69   ; /- used in `cartouche`
TTAB    = $6A   ; temp address for subtraction in `tab`
LINE    = $6B   ; current line
COLUMN  = $6C   ; current column
TXSTART = $A000 ; text data start (to $BFFF - 2048 bytes)

FONT: .literal "FONT.BIN"
TEXT: .literal "TEXT.ISI"

; 8 colours:        #444    #FFF    #F44    #FF4    #4F4    #4FF    #44F    #F4F
DEFAULTCLR: .byte $44,$04,$FF,$0F,$44,$0F,$F4,$0F,$F4,$04,$FF,$04,$4F,$04,$4F,$0F
; ca65 is deciding to only store 6 of them in the list file. wtf.

;;                   ni  li  pona ala pona    cs  c3  T   cs  c4  E   c6  S   T       soweli sewi sc  monsi .   tan :   ec  nl  c2  cs  c1  mi  wawa a   nl  1   tb  mi  ike ala nl  2   tb  mi  ike ala eof
;TESTMESSAGE: .byte $B1,$92,$C5, $62,$C5,$10,$F8,$F3,$54,$F8,$F4,$45,$F6,$53,$54,$10,$D4,   $CB, $ED,$A5,  $EB,$D9,$EC,$EE,$F9,$f2,$f8,$F1,$A0,$E8, $60,$F9,$01,$FA,$A0,$6F,$62,$F9,$02,$FA,$A0,$6F,$62,$FF

TESTMESSAGE: .byte $F8,$F2,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$FA,$FA,$34,$F9,$F3,$25,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$FA,$FA,$25,$F9,$F3,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$FA,$FA,$25,$F9,$F4,$33,$FA,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$FA,$33,$F9,$F4,$FA,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$FA,$33,$F9,$F5,$34,$FA,$FA,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$34,$F9,$F5,$FA,$FA,$FA,$34,$21,$22,$10,$34,$25,$33,$34,$FA,$34,$FF

;TESTMESSAGE: .byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
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
  stp
: lda TESTMESSAGE,x
  sta TXSTART,x
  cmp #$FF

  beq :+
  inx
  bra :-

: jsr update

; loop:
;   inc TESTMESSAGE
;   jsr update
;   bra loop

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

; stp

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
  ldy #32       ; title length
  sty NAMELEN
  ldx #$10      ; offset from AUTHOR to TITLE
  jsr name

: cmp #$FC
  bne :+
  ldy #16       ; author length
  sty NAMELEN
  ldx #0        ; no offset
  jsr name

  ; if $FD isn't preceded by either $FB or $FC and then some other stuff, ignore it

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
  and #3      ; mod 4
  sta TTAB
  lda #4
  sec
  sbc TTAB
 
: ldx #$10      ; space
  stx V_DATA0
  ldx CURCLR
  stx V_DATA0
  dea
  bne :-

  rts

name:

  inc INDEX_L
  bne :+
  inc INDEX_H
  lda (INDEX_L)

: cmp #$FD
  beq :+

  sta AUTHOR,x
  inx

  cpx NAMELEN ; are we over the limit yet?
  bcs :+      ; make sure to branch if it somehow gets bigger than NAMELEN

  bra name

: rts
