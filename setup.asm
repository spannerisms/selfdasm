Vector_Reset:
	SEI
	REP #$09
	XCE
	JML.l Reset_Fast

#Reset_Fast:
	ROL.w $420D ; fast ROM
	STZ.w NMITIMEN

	PEA.w $2100
	PLD

	LDX.b #$80
	PHX
	PLB

	STX.b INIDISP
	STX.b VMAIN

	STZ.b CGADD ; black bg
	STZ.b CGDATA
	STZ.b CGDATA

	STZ.b WMADDH

	STZ.b BGMODE
	STZ.b MOSAIC

	LDA.b #$02
	STA.b BG1SC
	DEC
	STA.b BG12NBA

	STZ.b BG1HOFS
	STZ.b BG1HOFS
	STZ.b BG1VOFS
	STZ.b BG1VOFS

	STZ.b W12SEL

	LDA.b #$01
	STA.b TM
	STA.b TS

	STZ.b TMW
	STZ.b TSW

	STZ.b CGWSEL
	STZ.b SETINI

	REP #$20
	STZ.b VMADDR ; reset write address for VRAM and WRAM
	STZ.b WMADDL

#ZeroLand:
	LDA.w #$4300
	TCD

	LDA.w #ZeroLand+1
	STA.b $4302
	STA.b $4312
	STA.b $4322

	STX.b $4304
	STX.b $4314
	STX.b $4324

	LDA.w #$1809
	STA.b $4300 ; write type for VRAM

	LDA.w #$8008
	STA.b $4310 ; write type for WRAM
	STA.b $4320

	LDX.b #$03
	STX.w $420B

	; now bank 7F
	LDX.b #$01
	STX.w WMADDH
	STZ.w WMADDR

	LDX.b #$04
	STX.w $420B


	; now add the gfx in
	LDA.w #GFX
	STA.b $4302

	LDA.w #$1801
	TAX
	STA.b $4300

	LDA.w #$0800
	STA.b $4305

	LDA.w #$1000
	STA.w VMADDR

	STX.w $420B

	STA.b $4305

	LDA.w #$1800
	STA.w VMADDR

	STX.w $420B

	TAX
	STX.w CGADD

	LDA.w #$2202
	STA.b $4300

	LDX.b #$40
	STX.b $4305

	LDX.b #$01
	STX.w $420B

	LDA.w #$1FFD
	TCS
	PLD

	JML Disassemble_Start

Vector_NMI:
	REP #$30
	PHA
	PHY
	PHX
	PHB
	PHD

	LDA.w #$0000
	TCD

	SEP #$31
	AND.l RDNMI

	BIT.b DP.DO_DRAW
	BPL .skip

	JML .fast

.fast
	LDA.b #$80
	PHA
	PLB

	STA.w INIDISP
	STZ.b DP.DO_DRAW

	REP #$20
	LDA.b DP.VRAM_LOC
	STA.w VMADDR

	LDX.b #00

--	LDA.b DP.DRAW_BUFFER, X
	STA.w VMDATA
	INX
	INX
	CPX.b #64
	BCC --

	SEP #$30
	LDA.b #$0F
	STA.w INIDISP

.skip
	PLD
	PLB
	REP #$30
	PLX
	PLY
	PLA
	RTI

Vector_IRQ:
	RTI

Vector_COP:
	RTI

Vector_Unused:
	RTI

Vector_Abort:
	RTI

Vector_BRK:
	RTI

GFX:
incbin "opcodesgfx.2bpp"
incbin "hexgfx1.2bpp"
incbin "hexgfx2.2bpp"

Palettes:
%col4($000000, $F8F8F8, $F80000, $000000)
%col4($000000, $F8F8F8, $F8E800, $000000)
%col4($000000, $00FFE8, $1098F8, $C000C8)
%col4($000000, $F8F8F8, $1098F8, $00FFE8)

%col4($000000, $F8F8F8, $F85000, $000000)
%col4($000000, $F8F8F8, $F8F8F8, $00FFE8)
%col4($000000, $F8F8F8, $1098F8, $000000)
%col4($000000, $F8F8F8, $0058D8, $000000)

