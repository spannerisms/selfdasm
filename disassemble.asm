Vector_Reset:
	SEI
	REP #$09
	XCE
	JML.l Reset_Fast

#Reset_Fast:
	ROL.w $420D
	STZ.w NMITIMEN

	PEA.w $2100
	PLD

	LDX.b #$80
	PHX
	PLB

	STX.b INIDISP
	STX.b VMAIN

	STZ.b CGADD
	STZ.b CGDATA
	STZ.b CGDATA

	STZ.b WMADDH

	STZ.b BGMODE
	STZ.b MOSAIC

	LDA.b #$02
	STA.b BG1SC
	DEC
	STA.b BG12NBA
	STA.b TM
	STA.b TS
	STZ.b TMW
	STZ.b TSW

	STZ.b BG1HOFS
	STZ.b BG1HOFS
	STZ.b BG1VOFS
	STZ.b BG1VOFS

	STZ.b W12SEL
	STZ.b CGWSEL
	STZ.b SETINI

	REP #$20
	STZ.b VMADDR
	STZ.b WMADDL

#ZeroLand:
	LDA.w #$4300
	TCD

	LDA.w #ZeroLand+1
	STA.b $4302
	STA.b $4312

	STX.b $4304
	STX.b $4314

	LDA.w #$8008
	STA.b $4310

	LDA.w #$1809
	STA.b $4300

	LDX.b #$03
	STX.w $420B

	STX.w WMADDH
	STZ.w WMADDR

	DEX
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

Disassemble_Start:
	REP #$20
	SEP #$10

	LDX.b #$7F
	STX.b DP.REG_SR_BANK

	LDX.b #$0F
	STX.w INIDISP

	JSR RunVector_IRQ
	JSR RunVector_NMI
	JSR RunVector_RESET

	STP

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

Vector_COP:
	RTI

Vector_IRQ:
	RTI

Vector_Unused:
Vector_Abort:
Vector_BRK:
	RTI

RunVector:
.RESET
	REP #$20
	LDA.w #EMU_VECTOR_RST
	STZ.b DP.ROM_READ+1
	STA.b DP.ROM_READ+0

	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ

	STZ.b DP.REG_A
	STZ.b DP.REG_X
	STZ.b DP.REG_Y
	STZ.b DP.REG_D

	LDA.w #$01FF
	STA.b DP.REG_SR

	SEP #$30
	STA.b DP.REG_P.E

	STZ.b DP.REG_DB

	LDA.b #$30
	STA.b DP.REG_P

#Disassemble_Forever:
	JSR Disassemble_Next
	BRA Disassemble_Forever
	RTS

.IRQ
	SEP #$30

	LDA.b DP.REG_P
	ORA.b #$04
	AND.b #$F7
	TAX

	REP #$20
	LDA.w #NAT_VECTOR_IRQ
	BRA DisassembleVector

.NMI
	SEP #$30

	LDA.b DP.REG_P
	AND.b #$F7
	TAX

	REP #$20
	LDA.w #NAT_VECTOR_NMI
	BRA DisassembleVector

PrepSoftwareInterrupt:
	REP #$20
	; since RTI hinges on RTL
	; we need to compensate for the operand size
	DEC.b DP.ROM_READ
	DEC.b DP.ROM_READ
	JSR PushToStack_RTI

	SEP #$30
	LDA.b DP.REG_P
	AND.b #$F7
	ORA.b #$04
	STA.b DP.REG_P

	JSR Sync_REG_P

GetVectorSet:
	SEP #$30
	LDA.b DP.REG_P.E
	AND.b #$80
	LSR
	LSR
	LSR
	TAX
	REP #$20
	RTS

DisassembleVector:
	REP #$20
	STZ.b DP.ROM_READ+1
	STA.b DP.ROM_READ+0

	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ

	STX.b DP.REG_P

	LDA.w #$01FF
	STA.b DP.REG_SR
	BRA .start

#Disassemble_UntilRTI:
.next
	JSR Disassemble_Next

.start
	SEP #$30
	LDA.b [DP.ROM_READ]
	CMP.b #$40
	BNE .next

	JMP OnlyDrawOpcode

Disassemble_Next:
	JSR Sync_REG_P
	JSR DrawOpCode

	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	TAX

	JMP.w (OpCodeRun, X)

PushToStack:
.RTI
	JSR .REG_P

.RTL
	JSR .PROGRAM_BANK
	REP #$20
	LDA.b DP.ROM_READ
	INC
	BRA ++

.RTS
	REP #$20
	LDA.b DP.ROM_READ
++	INC
	INC
	BRA .push_2

.REG_P
	SEP #$20
	LDA.b DP.REG_P
	BRA .push_1

.REG_D
	REP #$20
	LDA.b DP.REG_D
	BRA .push_2

.PROGRAM_BANK
	SEP #$20
	LDA.b DP.ROM_READ.b
	BRA .push_1

.DATA_BANK
	SEP #$20
	LDA.b DP.REG_DB
	BRA .push_1

.address
	REP #$30
	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	BRA .push_2

.REG_X
	REP #$20
	LDA.b DP.REG_X
	BRA .test_px

.REG_Y
	REP #$20
	LDA.b DP.REG_Y
	BRA .test_px

.REG_A
	REP #$20
	LDA.b DP.REG_A

; for A, REG_P.M will be tested in 8 bit for N flag
	SEP #$20

; for X and Y, REG_P.M will be tested in 16 bit
; so it will actually be looking at REG_P.X for N flag
.test_px
	BIT.b DP.REG_P.M
	SEP #$20
	BMI .push_1

.push_2
	SEP #$20
	XBA
	STA.b [DP.REG_SR]

	REP #$20
	DEC.b DP.REG_SR

	XBA

.push_1
	SEP #$20
	STA.b [DP.REG_SR]

	REP #$20
	DEC.b DP.REG_SR

	RTS

PullFromStack:
.RTI
	JSR .RTL

	; bleed into REG_P
.REG_P
	JSR .pull_1
	PHA
	PLP
	JMP Save_REG_P

.RTL
	JSR .RTS
	JSR .pull_1
	STA.b DP.ROM_READ.b
	RTS

.RTS
	JSR .pull_2
	INC
	STA.b DP.ROM_READ
	RTS

.REG_D
	JSR .pull_2
	STA.b DP.REG_D
	JMP SetFlags_from_D

.DATA_BANK
	JSR .pull_1
	STA.b DP.REG_DB
	RTS

.REG_A
	SEP #$20
	BIT.b DP.REG_P.M
	BPL ..do2

	JSR .pull_1
	BRA ..save

..do2
	JSR .pull_2

..save
	STA.b DP.REG_A
	JMP SetFlags_from_A

.REG_X
	SEP #$20
	BIT.b DP.REG_P.X
	BPL ..do2

	JSR .pull_1
	BRA ..save

..do2
	JSR .pull_2

..save
	STA.b DP.REG_X
	JMP SetFlags_from_X

.REG_Y
	SEP #$20
	BIT.b DP.REG_P.X
	BPL ..do2

	JSR .pull_1
	BRA ..save

..do2
	JSR .pull_2

..save
	STA.b DP.REG_Y
	JMP SetFlags_from_Y

.pull_1
	REP #$20
	INC.b DP.REG_SR

	SEP #$20
	LDA.b [DP.REG_SR]

	RTS

.pull_2
	REP #$20
	INC.b DP.REG_SR
	LDA.b [DP.REG_SR]

	INC.b DP.REG_SR
	RTS

Collect_REG_P:
	SEP #$20
	LDA.b DP.REG_P
	PHA
	PLP
	RTS

SetFlags:
.from_B
	SEP #$20
	LDA.b DP.REG_DB
	BRA .continueA

.from_D
	REP #$30
	LDA.b DP.REG_D
	BRA .continueA

.from_A
	REP #$20
	LDA.b DP.REG_A

.continueA
	STA.b DP.TEST
	JSR Collect_REG_P
	LDA.b DP.TEST
	BRA Save_REG_P

.from_X
	REP #$20
	LDA.b DP.REG_X
	BRA .continueX

.from_Y
	REP #$20
	LDA.b DP.REG_Y

.preset
.continueX
	STA.b DP.TEST
	JSR Collect_REG_P
	LDX.b DP.TEST

Save_REG_P:
	PHP
	SEP #$20
	PLA
	STA.b DP.REG_P

Sync_REG_P:
	PHA
	PHX
	PHY
	PHP
	SEP #$30
	LDX.b #8
	LDA.b DP.REG_P

.next
	LSR
	ROR.b DP.REG_P, X
	DEX
	BNE .next

	BIT.b DP.REG_P.X
	BPL .index_fine

	; zero high byte when X=1
	STZ.b DP.REG_X+1
	STZ.b DP.REG_Y+1

.index_fine
	PLP
	PLY
	PLX
	PLA
	RTS

OpCode_NMIWAIT:
	SEP #$10
	LDY.b #$80
	STY.b DP.DO_DRAW

.start
	STY.w NMITIMEN

	WAI
	WAI
	WAI
	WAI

	LDY.b #$00
	STY.w NMITIMEN

	RTS

.no_draw
	SEP #$10
	LDY.b #$80
	RTS
	BRA .start

OnlyDrawOpcode:
	JSR Sync_REG_P

DrawOpCode:
	PHY
	PHP

	JSR .dodraw

	JSR OpCode_NMIWAIT

	PLP
	PLY
	RTS

.dodraw
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	ASL
	STA.b DP.DRAW_READ

	LDA.b DP.VRAM_LOC
	AND.w #$FFC0>>1
	ADC.w #$0042>>1
	CMP.w #$0343
	BCS .next_wait
	JMP .write_addr

.next_wait
	SEP #$30
	LDA.b #$01

	JSR OpCode_NMIWAIT_no_draw
	JSR OpCode_NMIWAIT_no_draw
	JSR OpCode_NMIWAIT_no_draw

--	LDX.w RDNMI
	BPL --
	LDX.b #$80
	STX.w INIDISP
	INC
	INC
	INC
	BEQ .clear

	STA.w BG1VOFS
	STZ.w BG1VOFS
	LDX.b #$0F
	STX.w INIDISP

	BRA --

.clear
	STZ.w BG1VOFS
	STZ.w BG1VOFS
	REP #$20
	LDA.w #ZeroLand+1
	STA.w $4302

	LDX.b #$80
	STX.w INIDISP
	STX.w $4304

	STZ.w VMADDR

	LDA.w #$1809
	STA.w $4300

	LDA.w #$1000
	STA.w $4305

	LDX.b #$01
	STX.w $420B

	DEX
	STX.w INIDISP

	REP #$30
	LDA.w #$0021

.write_addr
	STA.b DP.VRAM_LOC

	LDX.w #64

--	STZ.b DP.DRAW_BUFFER-2, X
	DEX
	DEX
	BNE --

	LDY.w #2

--	LDA.w DP.ROM_READ, Y
	AND.w #$00FF
	ORA.w #$3500
	STA.b DP.DRAW_BUFFER, X
	INX
	INX
	DEY
	BPL --

	LDA.w #$2001 ; colon
	STA.b DP.DRAW_BUFFER+6

	LDY.b DP.DRAW_READ

	LDA.w OpCodeDraw+0, Y
	AND.w #$00FF
	ORA.w #$2800
	STA.b DP.DRAW_BUFFER+8

	LDA.w OpCodeDraw+1, Y
	AND.w #$00FF
	ORA.w #$2800
	STA.b DP.DRAW_BUFFER+10

	LDA.w OpCodeDraw+2, Y
	AND.w #$007F

	ASL
	TAX

	LDA.w DrawAddressingMode, X
	PHA

	LDX.w #12

	LDA.w #$3D00
	SEP #$20
	LDY.w #$2000|A_COL
	STY.w DP.DRAW_BUFFER.A+0

	LDA.b DP.REG_A+0
	TAY
	STY.w DP.DRAW_BUFFER.A+4
	LDA.b DP.REG_A+1
	TAY
	STY.w DP.DRAW_BUFFER.A+2

	LDY.w #$2000|X_COL
	STY.w DP.DRAW_BUFFER.X+0
	LDA.b DP.REG_X+0
	TAY
	STY.w DP.DRAW_BUFFER.X+4
	LDA.b DP.REG_X+1
	TAY
	STY.w DP.DRAW_BUFFER.X+2

	LDY.w #$2000|Y_COL
	STY.w DP.DRAW_BUFFER.Y+0
	LDA.b DP.REG_Y+0
	TAY
	STY.w DP.DRAW_BUFFER.Y+4
	LDA.b DP.REG_Y+1
	TAY
	STY.w DP.DRAW_BUFFER.Y+2

	LDY.w #$2000|P_COL
	STY.w DP.DRAW_BUFFER.P+0
	LDA.b DP.REG_P
	TAY
	STY.w DP.DRAW_BUFFER.P+2

	LDY.w #$2000|S_COL
	STY.w DP.DRAW_BUFFER.S+0
	LDA.b DP.REG_SR+0
	TAY
	STY.w DP.DRAW_BUFFER.S+4
	LDA.b DP.REG_SR+1
	TAY
	STY.w DP.DRAW_BUFFER.S+2

	LDY.w #$2000|D_COL
	STY.w DP.DRAW_BUFFER.D+0
	LDA.b DP.REG_D+0
	TAY
	STY.w DP.DRAW_BUFFER.D+4
	LDA.b DP.REG_D+1
	TAY
	STY.w DP.DRAW_BUFFER.D+2

	LDY.w #$2000|B_COL
	STY.w DP.DRAW_BUFFER.B+0
	LDA.b DP.REG_DB+0
	TAY
	STY.w DP.DRAW_BUFFER.B+2

	REP #$30
	RTS

DrawAddressingMode:
	dw .Draw_IMP-1

	dw .Draw_DP-1
	dw .Draw_DP_X-1
	dw .Draw_DP_Y-1
	dw .Draw_DP_IND-1

	dw .Draw_DP_X_IND-1
	dw .Draw_DP_IND_Y-1
	dw .Draw_DP_IND_L-1
	dw .Draw_DP_IND_L_Y-1

	dw .Draw_ABS-1
	dw .Draw_ABS_X-1
	dw .Draw_ABS_Y-1
	dw .Draw_ABS_IND-1

	dw .Draw_ABS_X_IND-1
	dw .Draw_ABS_IND_L-1
	dw .Draw_LONG-1
	dw .Draw_LONG_X-1

	dw .Draw_IMM-1
	dw .Draw_IMM_L-1
	dw .Draw_IMM_A-1
	dw .Draw_IMM_X-1

	dw .Draw_SR-1
	dw .Draw_SR_IND-1
	dw .Draw_SR_IND_Y-1
	dw .Draw_A_REG-1

	dw .Draw_REL-1
	dw .Draw_REL_L-1
	dw .Draw_JMP_ABS-1
	dw .Draw_JMP_LONG-1

	dw .Draw_BLK-1

.Draw_FirstAddrByte_P
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_P
	BRA .Draw_FirstAddrByte_Arb

.Draw_FirstAddrByte_B
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_B
	BRA .Draw_FirstAddrByte_Arb

.Draw_FirstAddrByte_RELOCATE
	LDA.w #$3500
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_R
	BRA .Draw_FirstAddrByte_Arb

.Draw_FirstAddrByte_IL
	LDA.w #$2500
	STA.b DP.DRAW_COLOR
	BRA .Draw_FirstAddrByte_Icont

.Draw_FirstAddrByte_I
	LDA.w #$2500
	STA.b DP.DRAW_COLOR
	LDA.w #IMD
	JSR .Draw_Any

.Draw_FirstAddrByte_Icont
	LDA.w #DOL_I
	BRA .Draw_FirstAddrByte_Arb

.Draw_FirstAddrByte
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL

..Arb
	STA.b DP.DRAW_BUFFER, X
	INX
	INX

.Draw_AddrByte
	LDA.b [DP.ROM_READ], Y
	AND.w #$00FF
	ORA.b DP.DRAW_COLOR

	STA.b DP.DRAW_BUFFER, X
	INX
	INX

	DEY
	BNE .Draw_AddrByte

.Draw_IMP
	RTS

.Draw_DOL
	LDA.w #DOL_R

.Draw_Any
	STA.b DP.DRAW_BUFFER, X
	INX
	INX
	RTS

.Draw_C_PRN
	LDA.w #C_PRN
	BRA .Draw_Any

.Draw_C_BKT
	LDA.w #C_BKT
	BRA .Draw_Any

.Draw_COM
	LDA.w #COM
	BRA .Draw_Any

.Draw_COM_X
	LDA.w #COM_X
	BRA .Draw_Any

.Draw_COM_Y
	LDA.w #COM_Y
	BRA .Draw_Any

.Draw_COM_S
	LDA.w #COM_S
	BRA .Draw_Any

.Draw_P_COM_Y
	LDA.w #P_COM_Y
	BRA .Draw_Any

.Draw_B_COM_Y
	LDA.w #B_COM_Y
	BRA .Draw_Any

.Draw_A_REG
	LDA.w #A_IMP
	BRA .Draw_Any

.Draw_DP
	LDY.w #1
	JMP .Draw_FirstAddrByte

.Draw_DP_X
	JSR .Draw_DP
	JMP .Draw_COM_X

.Draw_DP_Y
	JSR .Draw_DP
	JMP .Draw_COM_Y

.Draw_DP_IND
	LDY.w #1
	JSR .Draw_FirstAddrByte_P
	JMP .Draw_C_PRN

.Draw_DP_X_IND
	LDY.w #1
	JSR .Draw_FirstAddrByte_P
	JSR .Draw_COM_X
	JMP .Draw_C_PRN

.Draw_DP_IND_Y
	JSR .Draw_DP_IND
	DEX
	DEX
	JMP .Draw_P_COM_Y

.Draw_DP_IND_L
	LDY.w #1
	JSR .Draw_FirstAddrByte_B
	JMP .Draw_C_BKT

.Draw_DP_IND_L_Y
	JSR .Draw_DP_IND_L
	DEX
	DEX
	JMP .Draw_B_COM_Y

.Draw_ABS
	LDY.w #2
	JMP .Draw_FirstAddrByte

.Draw_ABS_X
	JSR .Draw_ABS
	JMP .Draw_COM_X

.Draw_ABS_Y
	JSR .Draw_ABS
	JMP .Draw_COM_Y

.Draw_ABS_IND
	LDY.w #2
	JSR .Draw_FirstAddrByte_P
	JMP .Draw_C_PRN

.Draw_ABS_X_IND
	LDY.w #2
	JSR .Draw_FirstAddrByte_P
	JSR .Draw_COM_X
	JMP .Draw_C_PRN

.Draw_ABS_IND_L
	LDY.w #2
	JSR .Draw_FirstAddrByte_B
	JMP .Draw_C_BKT

.Draw_LONG
	LDY.w #3
	JMP .Draw_FirstAddrByte

.Draw_LONG_X
	JSR .Draw_LONG
	JMP .Draw_COM_X

.Draw_IMM
	LDY.w #1
	JMP .Draw_FirstAddrByte_I

.Draw_IMM_L
	LDY.w #1
	JMP .Draw_FirstAddrByte_IL

.Draw_IMM_A
	BIT.b DP.REG_P.M-1
	BMI .Draw_IMM_1byte

.Draw_IMM_2byte
	LDY.w #2
	BRA .Draw_IMM_adjust

.Draw_IMM_1byte
	LDY.w #1

.Draw_IMM_adjust
	LDA.b DP.DRAW_BUFFER+10
	CPY.w #2
	BCC ..not_w
	ADC.w #15
	STA.b DP.DRAW_BUFFER+10

..not_w
	JMP .Draw_FirstAddrByte_I

.Draw_IMM_X
	BIT.b DP.REG_P.M
	BMI .Draw_IMM_1byte
	BRA .Draw_IMM_2byte

.Draw_SR
	JSR .Draw_IMM_L
	JMP .Draw_COM_S

.Draw_SR_IND
	;JSR .Draw_IMM_L_DOL_P
	LDY.w #1
	JSR .Draw_FirstAddrByte_P
	JSR .Draw_COM_S
	JMP .Draw_C_PRN

.Draw_SR_IND_Y
	JSR .Draw_SR_IND
	DEX
	DEX
	JMP .Draw_P_COM_Y

.Draw_REL
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	BPL ..pos
	ORA.w #$00FF

..pos
	XBA

.Draw_RELATIVE
	SEC
	ADC.b DP.ROM_READ
	INC
	STA.b DP.DRAW_READ

	LDA.w #DOL_R
	JSR .Draw_Any

	LDA.b DP.DRAW_READ
	XBA
	AND.w #$00FF
	ORA.w #$3500
	JSR .Draw_Any

	LDA.b DP.DRAW_READ
	AND.w #$00FF
	ORA.w #$3500
	JMP .Draw_Any

.Draw_REL_L
	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	INC
	BRA .Draw_RELATIVE

.Draw_JMP_ABS
	LDY.w #2
	BRA .JUMP_JMP_ABS

.Draw_JMP_LONG
	LDY.w #3

.JUMP_JMP_ABS
	LDA.w #$3500
	STA.b DP.DRAW_COLOR
	JMP .Draw_FirstAddrByte_RELOCATE

.Draw_BLK
	LDY.w #2

	JSR .Draw_DOL

	LDA.b [DP.ROM_READ], Y
	AND.w #$00FF
	ORA.w #$3500
	JSR .Draw_Any

	JSR .Draw_COM
	JSR .Draw_DOL

	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	AND.w #$00FF
	ORA.w #$3500
	JMP .Draw_Any

NEXT_OP_X:
	REP #$20
	BRA .test

#NEXT_OP_M:
	SEP #$20

.test
	BIT.b DP.REG_P.M
	BMI NEXT_OP_1
	BRA NEXT_OP_2

NEXT_OP_4:
	REP #$20
	INC.b DP.ROM_READ
NEXT_OP_3:
	REP #$20
	INC.b DP.ROM_READ
NEXT_OP_2:
	REP #$20
	INC.b DP.ROM_READ
NEXT_OP_1:
	REP #$20
	INC.b DP.ROM_READ
NEXT_OP_0:
	RTS

DoBranchingLong:
	BPL NEXT_OP_3
	REP #$30
	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	SEC
	BRA BranchDo

DoBranching:
	BPL NEXT_OP_2
	REP #$31
	LDA.w #$FF00
	AND.b [DP.ROM_READ]
	BPL .pos
	ORA.w #$00FF
.pos
	XBA
BranchDo:
	LDY.w #$1
	ADC.b DP.ROM_READ
	INC
	INC
	STA.b DP.ROM_READ
	RTS

GetEffectiveAddress:
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	ASL
	TAX
	LDA.l OpCodeDraw+2, X
	AND.w #$00FF

	ASL
	TAX
	JMP (.addressing_modes, X)

.addressing_modes
	dw .handle_IMP
	dw .handle_DP
	dw .handle_DP_X
	dw .handle_DP_Y
	dw .handle_DP_IND
	dw .handle_DP_X_IND
	dw .handle_DP_IND_Y
	dw .handle_DP_IND_L
	dw .handle_DP_IND_L_Y
	dw .handle_ABS
	dw .handle_ABS_X
	dw .handle_ABS_Y
	dw .handle_ABS_IND
	dw .handle_ABS_X_IND
	dw .handle_ABS_IND_L
	dw .handle_LONG
	dw .handle_LONG_X
	dw .handle_IMM
	dw .handle_IMM_L
	dw .handle_IMM_A
	dw .handle_IMM_X
	dw .handle_SR
	dw .handle_SR_IND
	dw .handle_SR_IND_Y
	dw .handle_A_REG
	dw .handle_REL
	dw .handle_REL_L
	dw .handle_JMP_ABS
	dw .handle_JMP_LONG
	dw .handle_BLK

.get_DP
.handle_DP
	REP #$31
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	XBA
	ADC.b DP.REG_D
	STZ.b DP.SCRATCH+1
	STA.b DP.SCRATCH+0

.handle_IMP
.handle_IMM
.handle_IMM_L
.handle_IMM_A
.handle_IMM_X
.handle_A_REG
.handle_REL
.handle_REL_L
.handle_JMP_ABS
.handle_JMP_LONG
.handle_BLK
	RTS

.handle_DP_X
	JSR .get_DP
	CLC
	ADC.b DP.REG_X
	STZ.b DP.SCRATCH+1
	STA.b DP.SCRATCH+0
	RTS

.handle_DP_Y
	JSR .get_DP
	CLC
	ADC.b DP.REG_Y
	STA.b DP.SCRATCH+0
	RTS

.handle_DP_IND
	JSR .get_DP

.handle_DP_IND_ARB
	SEP #$31
	LDA.b #$7F
	STA.b DP.SCRATCH+2
	LDX.b DP.REG_DB

	REP #$20
	LDY.b #2
	LDA.b [DP.SCRATCH], Y
	TAY
	LDA.b [DP.SCRATCH]
	STA.b DP.SCRATCH+0
	STX.b DP.SCRATCH+2
	RTS

.handle_DP_X_IND
	JSR .handle_DP_X
	BRA .handle_DP_IND_ARB

.handle_DP_IND_Y
	JSR .handle_DP_IND

.handle_DP_IND_Y_ARB
	CLC
	ADC.b DP.REG_Y
	STA.b DP.SCRATCH+0
	RTS

.handle_DP_IND_L
	JSR .handle_DP_IND
	STY.b DP.SCRATCH+2
	RTS

.handle_DP_IND_L_Y
	JSR .handle_DP_IND_L
	BRA .handle_DP_IND_Y_ARB

.get_ABS
.handle_ABS
	REP #$21
	SEP #$10
	LDY.b #1
	LDA.b [DP.ROM_READ], Y
	STA.b DP.SCRATCH+0
	LDY.b DP.REG_DB
	STY.b DP.SCRATCH+2
	RTS

.handle_ABS_X
	JSR .get_ABS
	ADC.b DP.REG_X
	STA.b DP.SCRATCH+0
	RTS

.handle_ABS_Y
	JSR .get_ABS
	ADC.b DP.REG_Y
	STA.b DP.SCRATCH+0
	RTS
	
.handle_SR
	SEP #$10
	LDY.b #$00
	STY.b DP.SCRATCH+2

.do_SR
	REP #$21
	SEP #$10
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	XBA
	ADC.b DP.REG_SR
	STA.b DP.SCRATCH+0
	RTS

.handle_SR_IND
	JSR .do_SR
	LDY.b DP.REG_DB
	BRA .handle_ABS_IND_ARB

.handle_SR_IND_Y
	JSR .handle_SR_IND
	CLC
	ADC.b DP.REG_Y
	STA.b DP.SCRATCH+0
	RTS

.handle_ABS_IND
	JSR .get_ABS

.handle_ABS_IND_ARB
	; if effective address is $2000+, then don't read from WRAM
	CMP.w #$2000
	BCS ..rom_bank

	LDY.b #$7F

..rom_bank
	PHB
	PHY
	PLB

	REP #$10
	TAX

.handle_ABS_IND_ARB_getaddr
	LDA.w $0000, X

	SEP #$10
	PLB

	STA.b DP.SCRATCH+0

..done
	RTS

.handle_ABS_X_IND
	JSR .handle_ABS_X
	BRA .handle_ABS_IND_ARB

.handle_ABS_IND_L
	JSR .get_ABS
	CMP.w #$2000
	BCS ..rom_bank

	LDY.b #$7F

..rom_bank
	PHB
	PHY
	PLB

	REP #$10
	TAX
	LDA.w $0001, X

	STA.b DP.SCRATCH+1
	BRA .handle_ABS_IND_ARB_getaddr

.handle_LONG
	REP #$21
	SEP #$10
	LDY.b #2
	LDA.b [DP.ROM_READ], Y
	STA.b DP.SCRATCH+1

	DEY
	LDA.b [DP.ROM_READ], Y
	STA.b DP.SCRATCH+0
	RTS

.handle_LONG_X
	JSR .handle_LONG
	ADC.b DP.REG_X
	STA.b DP.SCRATCH+0
	RTS

PrepareEffectiveRead:
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	ASL
	TAX

	LDA.b DP.SCRATCH+2
	AND.w #$00FF
	BNE .notwram

.bank00
	LDA.b DP.SCRATCH
	CMP.w #$2000
	BCS .notwrammirror

.wram
	SEP #$20
	LDA.b #$7F
	STA.b DP.SCRATCH+2
	REP #$20
	BRA .not_register

.notwram
	CMP.w #$007F
	BEQ .registercontinue ; check for writing to 7F

	LDA.b DP.SCRATCH

.notwrammirror
	CMP.w #$8000 : BCS .romspace
	CMP.w #$2000 : BCC .wram
	CMP.w #$2100 : BCC .openbus
	CMP.w #$2200 : BCC .registercontinue
	CMP.w #$4016 : BCC .openbus
	CMP.w #$4017 : BEQ .registercontinue
	CMP.w #$4200 : BCC .openbus
	CMP.w #$4210 : BEQ .forcenegativeread
	CMP.w #$4220 : BCC .registercontinue
	CMP.w #$4300 : BCC .openbus
	CMP.w #$4380 : BCS .openbus

.registercontinue
	LDA.l OpCodeDraw+3, X
	AND.w #$00FF
	BEQ .not_register

	CMP.w #PEI_IT : BCS .not_register
	CMP.w #SAVE_A : BEQ .register

	CMP.w #TRB_A : BCC .not_register
	CMP.w #READ_X : BCC .register
	CMP.w #SAVE_Y : BCC .register

	CMP.w #INC_IT : BCC .not_register
	BRA .register

.forcenegativeread

	LDA.w #EMU_VECTOR_UNU>>0
	STA.b DP.SCRATCH+0

	LDA.w #EMU_VECTOR_UNU>>8
	BRA .write_the_plus_one

.openbus
.register
	LDA.w #$6666
	STA.b DP.SCRATCH+0

.write_the_plus_one
	STA.b DP.SCRATCH+1

.romspace
.not_register
	LDA.b DP.SCRATCH
	STA.b DP.EXECUTE+1

	LDA.w #$6B6B ; RTL
	STA.b DP.EXECUTE+3

	LDA.l OpCodeDraw+3, X
	AND.w #$00FF
	CMP.w #PEI_IT
	BCC .set_opcode

	SBC.w #PEI_IT
	ASL
	TAX
	JMP (.exec_op, X)

#EXEC_PEI_IT:
	LDA.b DP.SCRATCH
	JSR PushToStack_push_2
	BRA .set_nothing

#EXEC_RELOCL:
	LDA.b DP.SCRATCH+1
	STA.b DP.ROM_READ+1

#EXEC_RELOC:
	LDA.b DP.SCRATCH
	STA.b DP.ROM_READ

.set_nothing
	LDA.w #0

.set_opcode
	SEP #$30
	TAX
	LDA.l .ops, X
	STA.b DP.EXECUTE
	RTS

.ops
	db $6B ; NOTHIN
	db $8D ; SAVE_A
	db $AD ; READ_A
	db $2D ; AND_A
	db $4D ; EOR_A
	db $0D ; ORA_A
	db $6D ; ADC_A
	db $ED ; SBC_A
	db $CD ; CMP_A
	db $2C ; BIT_A
	db $1C ; TRB_A
	db $0C ; TSB_A
	db $8E ; SAVE_X
	db $AE ; READ_X
	db $EC ; CPX_X
	db $8C ; SAVE_Y
	db $AC ; READ_Y
	db $CC ; CPY_Y
	db $EE ; INC_IT
	db $CE ; DEC_IT
	db $9C ; STZ_IT
	db $0E ; ASL_IT
	db $4E ; LSR_IT
	db $2E ; ROL_IT
	db $6E ; ROR_IT

.exec_op
	dw EXEC_PEI_IT
	dw EXEC_RELOC
	dw EXEC_RELOCL

IsolateAndExecuteSafely_0:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_0

IsolateAndExecuteSafely_1:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_1

IsolateAndExecuteSafely_2:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_2

IsolateAndExecuteSafely_3:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_3

IsolateAndExecuteSafely_4:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_4

IsolateAndExecuteSafely:
	PHX
	PHY
	PHA
	PHP
	PHB

	; get opcode
	JSR GetEffectiveAddress
	JSR PrepareEffectiveRead

	; PREPARE REGISTERS
	; skips DB/D because that's handled above
	SEP #$10
	REP #$20

	LDX.b DP.SCRATCH+2
	PHX
	PLB

	LDX.b DP.REG_P
	PHX

	LDA.b DP.REG_A
	PLP
	PHP

	LDX.b DP.REG_X
	LDY.b DP.REG_Y

	PLP

	; do the code
	JSL.l DP.EXECUTE

	; RESTORE REGISTERS
	PHA
	PHP
	PHP

	SEP #$20
	PLA
	STA.l DP.REG_P

	PLP
	PLA

	REP #$2C
	STA.b DP.REG_A

	TXA
	STA.b DP.REG_X

	TYA
	STA.b DP.REG_Y

.unsafe
	PLB
	PLP
	PLA
	PLY
	PLX
	RTS

.recover_from_thing
	PHP
	REP #$20
	PHA

	REP #$20
	PLA
	PLP
	RTL

IsolateAndExecute_AccumulatorImmediate:
	SEP #$30
	LDX.b #2
	BIT.b DP.REG_P.M
	BMI .1byte

	INX

.1byte
	BRA IsolateAndExecute

IsolateAndExecute_IndexImmediate:
	SEP #$30
	LDX.b #2
	BIT.b DP.REG_P.X
	BMI .1byte

	INX

.1byte
	BRA IsolateAndExecute

; worst case scenario here is we load $EAxx into X
IsolateAndExecute_4:
	LDX.b #4
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_3:
	LDX.b #3
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_2:
	LDX.b #2
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_1:
	LDX.b #1
	NOP
	BRA IsolateAndExecute

; enters with X=number of bytes
IsolateAndExecute:
	SEP #$30

	LDA.b #$6B ; RTL
	STA.b DP.EXECUTE, X

.safe_entry
	LDY.b #$00

.next_copy
	LDA.b [DP.ROM_READ], Y
	STA.w DP.EXECUTE, Y
	INY
	DEX
	BNE .next_copy

	REP #$21
	TYA
	ADC.b DP.ROM_READ
	STA.b DP.ROM_READ

	PHD
	PHB

	; get registers for code
	LDX.b DP.REG_P
	PHX

	LDA.b DP.REG_A
	PLP
	PHP

	LDX.b DP.REG_X
	LDY.b DP.REG_Y

	PEI.b (DP.REG_D)
	PLD

	PLP
	JSL.l DP.EXECUTE

	PHA
	PHP
	PHP

	SEP #$20
	PLA
	STA.l DP.REG_P

	PLP
	PLA

	REP #$2C
	STA.l DP.REG_A

	TXA
	STA.l DP.REG_X

	TYA
	STA.l DP.REG_Y

	TDC
	STA.l DP.REG_D

	PLB
	PLD

	SEP #$30
	RTS

OpCodeRun:
	fillword 0 : fill 256*2

OpCodeDraw:
	fillbyte 0 : fill 256*4

HandleBranches = 0
this = 0
macro addop(bt, nm, op1, op2, op3, dohow, rt)
<nm>:
	;print "<nm> : ", hex(<rt>), "  ", hex(<nm>), "  ", hex(select(equal(<rt>,this), <nm>, <rt>))
	pushpc
	org OpCodeRun+<bt>*2  : dw select(equal(<rt>,this), <nm>, <rt>)
	org OpCodeDraw+<bt>*4 : db <op1>, <op2>, <op3>, <dohow>
	pullpc
endmacro

%addop($00, "OP_00_BRK", BR, K_, IMM, NOTHIN, this)
	JSR PrepSoftwareInterrupt

	STZ.b DP.ROM_READ+1
	LDA.l NAT_VECTOR_BRK

	CPX.b #0
	BEQ .native_mode

.emu_mode
	LDA.w #$0010
	TSB.b DP.REG_P

	LDA.l EMU_VECTOR_IRQ

.native_mode
	STA.b DP.ROM_READ+0
	JMP NEXT_OP_0

%addop($01, "OP_01_ORA_DP_X_IND", OR, Ab, DP_X_IND, ORA_A, IsolateAndExecuteSafely_2)

%addop($02, "OP_02_COP", CO, P_, IMM, NOTHIN, this)
	JSR PrepSoftwareInterrupt

	STZ.b DP.ROM_READ+1
	LDA.l NAT_VECTOR_COP, X

	STA.b DP.ROM_READ+0
	JMP NEXT_OP_0

%addop($03, "OP_03_ORA_SR", OR, A_, SR, ORA_A, IsolateAndExecuteSafely_2)

%addop($04, "OP_04_TSB_DP", TS_, Bb, DP, TSB_A, IsolateAndExecuteSafely_2)

%addop($05, "OP_05_ORA_DP", OR, Ab, DP, ORA_A, IsolateAndExecuteSafely_2)

%addop($06, "OP_06_ASL_DP", AS, Lb, DP, ASL_IT, IsolateAndExecuteSafely_2)

%addop($07, "OP_07_ORA_DP_IND", OR, Ab, DP_IND, ORA_A, IsolateAndExecuteSafely_2)

%addop($08, "OP_08_PHP", PH, P_, IMP, NOTHIN, this)
	JSR PushToStack_REG_P
	JMP NEXT_OP_1

%addop($09, "OP_09_ORA_IMM", OR, Ab, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($0A, "OP_0A_ASL_A", AS, L_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($0B, "OP_0B_PHD", PH, D_, IMP, NOTHIN, this)
	JSR PushToStack_REG_D
	JMP NEXT_OP_1

%addop($0C, "OP_0C_TSB_ADDR", TS_, Bw, ABS, TSB_A, IsolateAndExecuteSafely_3)

%addop($0D, "OP_0D_ORA_ADDR", OR, Aw, ABS, ORA_A, IsolateAndExecuteSafely_3)

%addop($0E, "OP_0E_ASL_ADDR", AS, Lw, ABS, ASL_IT, IsolateAndExecuteSafely_3)

%addop($0F, "OP_0F_ORA_LONG", OR, Al, LONG, ORA_A, IsolateAndExecuteSafely_4)

%addop($10, "OP_10_BPL", BP, L_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.N
	EOR.b #$80
	JMP DoBranching

%addop($11, "OP_11_ORA_DP_IND_Y", OR, Ab, DP_IND_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($12, "OP_12_ORA_DP_IND", OR, Ab, DP_IND, ORA_A, IsolateAndExecuteSafely_2)

%addop($13, "OP_13_ORA_SR_IND_Y", OR, A_, SR_IND_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($14, "OP_14_TRB_DP", TR, Bb, DP, TRB_A, IsolateAndExecuteSafely_2)

%addop($15, "OP_15_ORA_DP_X", OR, Ab, DP_X, ORA_A, IsolateAndExecuteSafely_2)

%addop($16, "OP_16_ASL_DP_X", AS, Lb, DP_X, ASL_IT, IsolateAndExecuteSafely_2)

%addop($17, "OP_17_ORA_DP_IND_L_Y", OR, Ab, DP_IND_L_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($18, "OP_18_CLC", CL, C_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($19, "OP_19_ORA_ABS_Y", OR, Aw, ABS_Y, ORA_A, IsolateAndExecuteSafely_3)

%addop($1A, "OP_1A_INC", IN, C_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($1B, "OP_1B_TCS", TC, S_, IMP, NOTHIN, this)
	REP #$20
	LDA.b DP.REG_A
	STA.b DP.REG_SR
	JMP NEXT_OP_1

%addop($1C, "OP_1C_TRB_ABS", TR, Bw, ABS, TRB_A, IsolateAndExecuteSafely_3)

%addop($1D, "OP_1D_ORA_ABS_X", OR, Aw, ABS_X, ORA_A, IsolateAndExecuteSafely_3)

%addop($1E, "OP_1E_ASL_ABS_X", AS, Lw, ABS_X, ASL_IT, IsolateAndExecuteSafely_3)

%addop($1F, "OP_1F_ORA_LONG_X", OR, Al, LONG_X, ORA_A, IsolateAndExecuteSafely_4)

%addop($20, "OP_20_JSR", JS, R_, JMP_ABS, NOTHIN, this)
	JSR PushToStack_RTS
	REP #$30
	INC.b DP.ROM_READ
	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ
	JMP NEXT_OP_0

%addop($21, "OP_21_AND_DP_X_IND", AN, Db, DP_X_IND, AND_A, IsolateAndExecuteSafely_2)

%addop($22, "OP_22_JSL", JS, L_, JMP_LONG, NOTHIN, this)
	JSR PushToStack_RTL
	REP #$20
	SEP #$10
	LDY.b #3
	LDA.b [DP.ROM_READ], Y
	TAX
	BNE ++
	LDX.b #$7F
++	LDY.b #1
	LDA.b [DP.ROM_READ], Y

	STA.b DP.ROM_READ
	STX.b DP.ROM_READ.b

	JMP NEXT_OP_0

%addop($23, "OP_23_AND_SR", AN, D_, SR, AND_A, IsolateAndExecuteSafely_2)

%addop($24, "OP_24_BIT_DP", BI, Tb, DP, BIT_A, IsolateAndExecuteSafely_2)

%addop($25, "OP_25_AND_DP", AN, Db, DP, AND_A, IsolateAndExecuteSafely_2)

%addop($26, "OP_26_ROL_DP", RO, Lb, DP, ROL_IT, IsolateAndExecuteSafely_2)

%addop($27, "OP_27_AND_DP_IND_L", AN, Db, DP_IND_L, AND_A, IsolateAndExecuteSafely_2)

%addop($28, "OP_28_PLP", PL, P_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_P
	JMP NEXT_OP_1

%addop($29, "OP_29_AND_IMM", AN, Db, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($2A, "OP_2A_ROL", RO, L_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($2B, "OP_2B_PLD", PL, D_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_D
	JMP NEXT_OP_1

%addop($2C, "OP_2C_BIT_ABS", BI, Tw, ABS, BIT_A, IsolateAndExecuteSafely_3)

%addop($2D, "OP_2D_AND_ABS", AN, Dw, ABS, AND_A, IsolateAndExecuteSafely_3)

%addop($2E, "OP_2E_ROL_ABS", RO, Lw, ABS, ROL_IT, IsolateAndExecuteSafely_3)

%addop($2F, "OP_2F_AND_LONG", AN, Dl, LONG, AND_A, IsolateAndExecuteSafely_4)

%addop($30, "OP_30_BMI", BM, I_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.N
	JMP DoBranching

%addop($31, "OP_31_AND_DP_IND_Y", AN, Db, DP_IND_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($32, "OP_32_AND_DP_IND", AN, Db, DP_IND, AND_A, IsolateAndExecuteSafely_2)

%addop($33, "OP_33_AND_SR_IND_Y", AN, D_, SR_IND_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($34, "OP_34_BIT_DP_X", BI, Tb, DP_X, BIT_A, IsolateAndExecuteSafely_2)

%addop($35, "OP_35_AND_DP_X", AN, Db, DP_X, AND_A, IsolateAndExecuteSafely_2)

%addop($36, "OP_36_ROL_DP_X", RO, Lb, DP_X, ROL_IT, IsolateAndExecuteSafely_2)

%addop($37, "OP_37_AND_DP_IND_L_Y", AN, Db, DP_IND_L_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($38, "OP_38_SEC", SE, C_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($39, "OP_39_AND_ABS_Y", AN, Dw, ABS_Y, AND_A, IsolateAndExecuteSafely_3)

%addop($3A, "OP_3A_DEC", DE, C_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($3B, "OP_3B_TSC", TS_, C_, IMP, NOTHIN, this)
	REP #$20
	LDA.b DP.REG_SR
	STA.b DP.REG_A
	JSR SetFlags_from_A
	JMP NEXT_OP_1

%addop($3C, "OP_3C_BIT_ABS_X", BI, Tw, ABS_X, BIT_A, IsolateAndExecuteSafely_3)

%addop($3D, "OP_3D_AND_ABS_X", AN, Dw, ABS_X, AND_A, IsolateAndExecuteSafely_3)

%addop($3E, "OP_3E_ROL_ABS_X", RO, Lw, ABS_X, ROL_IT, IsolateAndExecuteSafely_3)

%addop($3F, "OP_3F_AND_LONG_X", AN, Dl, LONG_X, AND_A, IsolateAndExecuteSafely_4)

%addop($40, "OP_40_RTI", RT, I_, IMP, NOTHIN, this)
	JSR PullFromStack_RTI
	JMP NEXT_OP_0

%addop($41, "OP_41_EOR_DP_X_IND", EO, Rb, DP_X_IND, EOR_A, IsolateAndExecuteSafely_2)

%addop($42, "OP_42_WDM", WD, M_, IMM, NOTHIN, NEXT_OP_2)

%addop($43, "OP_43_EOR_SR", EO, R_, SR, EOR_A, IsolateAndExecuteSafely_2)

%addop($44, "OP_44_MVP_BLK", MV, P_, BLK, NOTHIN, NEXT_OP_3)

%addop($45, "OP_45_EOR_DP", EO, Rb, DP, EOR_A, IsolateAndExecuteSafely_2)

%addop($46, "OP_46_LSR_DP", LS, Rb, DP, LSR_IT, IsolateAndExecuteSafely_2)

%addop($47, "OP_47_EOR_DP_IND_L", EO, Rb, DP_IND_L, EOR_A, IsolateAndExecuteSafely_2)

%addop($48, "OP_48_PHA", PH, A_, IMP, NOTHIN, this)
	JSR PushToStack_REG_A
	JMP NEXT_OP_1

%addop($49, "OP_49_EOR_IMM", EO, Rb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($4A, "OP_4A_LSR", LS, R_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($4B, "OP_4B_PHK", PH, K_, IMP, NOTHIN, this)
	JSR PushToStack_PROGRAM_BANK
	JMP NEXT_OP_1

%addop($4C, "OP_4C_JMP", JM, P_, JMP_ABS, NOTHIN, this)
	REP #$30
	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	STA.b DP.ROM_READ
	JMP NEXT_OP_0

%addop($4D, "OP_4D_EOR_ABS", EO, Rw, ABS, EOR_A, IsolateAndExecuteSafely_3)

%addop($4E, "OP_4E_LSR_ABS", LS, Rw, ABS, LSR_IT, IsolateAndExecuteSafely_3)

%addop($4F, "OP_4F_EOR_LONG", EO, Rl, LONG, EOR_A, IsolateAndExecuteSafely_4)

%addop($50, "OP_50_BVC", BV, C_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.V
	EOR.b #$80
	JMP DoBranching

%addop($51, "OP_51_EOR_DP_IND_Y", EO, Rb, DP_IND_Y, EOR_A, IsolateAndExecuteSafely_2)

%addop($52, "OP_52_EOR_DP_IND", EO, Rb, DP_IND, EOR_A, IsolateAndExecuteSafely_2)

%addop($53, "OP_53_EOR_SR_IND_Y", EO, R_, SR_IND_Y, EOR_A, IsolateAndExecuteSafely_2)

%addop($54, "OP_54_MVN_BLK", MV, N_, BLK, NOTHIN, NEXT_OP_3)

%addop($55, "OP_55_EOR_DP_X", EO, Rb, DP_X, EOR_A, IsolateAndExecuteSafely_2)

%addop($56, "OP_56_LSR_DP_X", LS, Rb, DP_X, LSR_IT, IsolateAndExecuteSafely_2)

%addop($57, "OP_57_EOR_DP_IND_L_Y", EO, Rb, DP_IND_L_Y, EOR_A, IsolateAndExecuteSafely_2)

%addop($58, "OP_58_CLI", CL, I_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($59, "OP_59_EOR_ABS_Y", EO, Rw, ABS_Y, EOR_A, IsolateAndExecuteSafely_3)

%addop($5A, "OP_5A_PHY", PH, Y_, IMP, NOTHIN, this)
	JSR PushToStack_REG_Y
	JMP NEXT_OP_1

%addop($5B, "OP_5B_TCD", TC, D_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($5C, "OP_5C_JML", JM, L_, JMP_LONG, NOTHIN, this)
	REP #$30
	LDY.w #3

	LDA.b [DP.ROM_READ], Y
	TAX

	LDY.w #1
	LDA.b [DP.ROM_READ], Y

	STA.b DP.ROM_READ
	SEP #$30
	STX.b DP.ROM_READ.b

	JMP NEXT_OP_0

%addop($5D, "OP_5D_EOR_ABS_X", EO, Rw, ABS_X, EOR_A, IsolateAndExecuteSafely_3)

%addop($5E, "OP_5E_LSR_ABS_X", LS, Rw, ABS_X, LSR_IT, IsolateAndExecuteSafely_3)

%addop($5F, "OP_5F_EOR_LONG_X", EO, Rl, LONG_X, EOR_A, IsolateAndExecuteSafely_4)

%addop($60, "OP_60_RTS", RT, S_, IMP, NOTHIN, PullFromStack_RTS)

%addop($61, "OP_61_ADC_DP_X_IND", AD, Cb, DP_X_IND, ADC_A, IsolateAndExecuteSafely_2)

%addop($62, "OP_62_PER_REL_L", PE, R_, REL_L, NOTHIN, this)
	REP #$31
	LDY.w #1
	LDA.b [DP.ROM_READ], Y
	INC
	INC
	INC
	ADC.b DP.ROM_READ
	JSR PushToStack_push_2
	JMP NEXT_OP_3

%addop($63, "OP_63_ADC_SR", AD, C_, SR, ADC_A, IsolateAndExecuteSafely_2)

%addop($64, "OP_64_STZ_DP", ST, Zb, DP, STZ_IT, IsolateAndExecuteSafely_2)

%addop($65, "OP_65_ADC_DP", AD, Cb, DP, ADC_A, IsolateAndExecuteSafely_2)

%addop($66, "OP_66_ROR_DP", RO, Rb, DP, ROR_IT, IsolateAndExecuteSafely_2)

%addop($67, "OP_67_ADC_DP_IND_L", AD, Cb, DP_IND_L, ADC_A, IsolateAndExecuteSafely_2)

%addop($68, "OP_68_PLA", PL, A_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_A
	JSR SetFlags_from_A
	JMP NEXT_OP_1

%addop($69, "OP_69_ADC_IMM", AD, Cb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($6A, "OP_6A_ROR", RO, R_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($6B, "OP_6B_RTL", RT, L_, IMP, NOTHIN, PullFromStack_RTL)

%addop($6C, "OP_6C_JMP_ABS_IND", JM, Pw, ABS_IND, RELOC, IsolateAndExecuteSafely_0)

%addop($6D, "OP_6D_ADC_ABS", AD, Cw, ABS, ADC_A, IsolateAndExecuteSafely_3)

%addop($6E, "OP_6E_ROR_ABS", RO, Rw, ABS, ROR_IT, IsolateAndExecuteSafely_3)

%addop($6F, "OP_6F_ADC_LONG", AD, Cl, LONG, ADC_A, IsolateAndExecuteSafely_4)

%addop($70, "OP_70_BVS", BV, S_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.V
	JMP DoBranching

%addop($71, "OP_71_ADC_DP_IND_Y", AD, Cb, DP_IND_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($72, "OP_72_ADC_DP_IND", AD, Cb, DP_IND, ADC_A, IsolateAndExecuteSafely_2)

%addop($73, "OP_73_ADC_SR_IND_Y", AD, C_, SR_IND_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($74, "OP_74_STZ_DP_X", ST, Zb, DP_X, STZ_IT, IsolateAndExecuteSafely_2)

%addop($75, "OP_75_ADC_DP_X", AD, Cb, DP_X, ADC_A, IsolateAndExecuteSafely_2)

%addop($76, "OP_76_ROR_DP_X", RO, Rb, DP_X, ROR_IT, IsolateAndExecuteSafely_2)

%addop($77, "OP_77_ADC_DP_IND_L_Y", AD, Cb, DP_IND_L_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($78, "OP_78_SEI", SE, I_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($79, "OP_79_ADC_ABS_Y", AD, Cw, ABS_Y, ADC_A, IsolateAndExecuteSafely_3)

%addop($7A, "OP_7A_PLY", PL, Y_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_Y
	JMP NEXT_OP_1

%addop($7B, "OP_7B_TDC", TD, C_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($7C, "OP_7C_JMP_ABS_X_IND", JM, Pw, ABS_X_IND, RELOC, this)
	; need to do some dumb stuff here
	; because JSR/JMP (addr, X) is based on program bank, not data
#RELOCATE_JUMP_ABS_X_IND:
	SEP #$20
	LDA.b DP.REG_DB
	PHA

	LDA.b DP.ROM_READ.b
	STA.b DP.REG_DB

	JSR IsolateAndExecuteSafely_0

	SEP #$20
	PLA
	STA.b DP.REG_DB
	JMP NEXT_OP_0
	

%addop($7D, "OP_7D_ADC_ABS_X", AD, Cw, ABS_X, ADC_A, IsolateAndExecuteSafely_3)

%addop($7E, "OP_7E_ROR_ABS_X", RO, Rw, ABS_X, ROR_IT, IsolateAndExecuteSafely_3)

%addop($7F, "OP_7F_ADC_LONG_X", AD, Cl, LONG_X, ADC_A, IsolateAndExecuteSafely_4)

%addop($80, "OP_80_BRA", BR, A_, REL, NOTHIN, this)
	SEP #$80
	JMP DoBranching

%addop($81, "OP_81_STA_DP_X_IND", ST, Ab, DP_X_IND, SAVE_A, IsolateAndExecuteSafely_2)

%addop($82, "OP_82_BRL", BR, L_, REL_L, NOTHIN, DoBranchingLong)

%addop($83, "OP_83_STA_SR", ST, A_, SR, SAVE_A, IsolateAndExecuteSafely_2)

%addop($84, "OP_84_STY_DP", ST, Yb, DP, SAVE_Y, IsolateAndExecuteSafely_2)

%addop($85, "OP_85_STA_DP", ST, Ab, DP, SAVE_A, IsolateAndExecuteSafely_2)

%addop($86, "OP_86_STX_DP", ST, Xb, DP, SAVE_X, IsolateAndExecuteSafely_2)

%addop($87, "OP_87_STA_DP_IND_L", ST, Ab, DP_IND_L, SAVE_A, IsolateAndExecuteSafely_2)

%addop($88, "OP_88_DEY", DE, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($89, "OP_89_BIT_IMM", BI, Tb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($8A, "OP_8A_TXA", TX, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($8B, "OP_8B_PHB", PH, B_, IMP, NOTHIN, this)
	JSR PushToStack_DATA_BANK
	JMP NEXT_OP_1

%addop($8C, "OP_8C_STY_ABS", ST, Yw, ABS, SAVE_Y, IsolateAndExecuteSafely_3)

%addop($8D, "OP_8D_STA_ABS", ST, Aw, ABS, SAVE_A, IsolateAndExecuteSafely_3)

%addop($8E, "OP_8E_STX_ABS", ST, Xw, ABS, SAVE_X, IsolateAndExecuteSafely_3)

%addop($8F, "OP_8F_STA_LONG", ST, Al, LONG, SAVE_A, IsolateAndExecuteSafely_4)

%addop($90, "OP_90_BCC", BC, C_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.C
	EOR.b #$80
	JMP DoBranching

%addop($91, "OP_91_STA_DP_IND_Y", ST, Ab, DP_IND_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($92, "OP_92_STA_DP_IND", ST, Ab, DP_IND, SAVE_A, IsolateAndExecuteSafely_2)

%addop($93, "OP_93_STA_SR_IND_Y", ST, A_, SR_IND_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($94, "OP_94_STY_DP_X", ST, Yb, DP_X, SAVE_Y, IsolateAndExecuteSafely_2)

%addop($95, "OP_95_STA_DP_X", ST, Ab, DP_X, SAVE_A, IsolateAndExecuteSafely_2)

%addop($96, "OP_96_STX_DP_Y", ST, Xb, DP_Y, SAVE_X, IsolateAndExecuteSafely_2)

%addop($97, "OP_97_STA_DP_IND_L_Y", ST, Ab, DP_IND_L_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($98, "OP_98_TYA", TY, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($99, "OP_99_STA_ABS_Y", ST, Aw, ABS_Y, SAVE_A, IsolateAndExecuteSafely_3)

%addop($9A, "OP_9A_TXS", TX, S_, IMP, NOTHIN, this)
	REP #$20
	LDA.b DP.REG_X
	STA.b DP.REG_SR
	JMP NEXT_OP_1

%addop($9B, "OP_9B_TXY", TX, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($9C, "OP_9C_STZ_ABS", ST, Zw, ABS, STZ_IT, IsolateAndExecuteSafely_3)

%addop($9D, "OP_9D_STA_ABS_X", ST, Aw, ABS_X, SAVE_A, IsolateAndExecuteSafely_3)

%addop($9E, "OP_9E_STZ_ABS_X", ST, Zw, ABS_X, STZ_IT, IsolateAndExecuteSafely_3)

%addop($9F, "OP_9F_STA_LONG_X", ST, Al, LONG_X, SAVE_A, IsolateAndExecuteSafely_4)

%addop($A0, "OP_A0_LDY_IMM", LD, Yb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($A1, "OP_A1_LDA_DP_X_IND", LD, Ab, DP_X_IND, READ_A, IsolateAndExecuteSafely_2)

%addop($A2, "OP_A2_LDX_IMM", LD, Xb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($A3, "OP_A3_LDA_SR", LD, A_, SR, READ_A, IsolateAndExecuteSafely_2)

%addop($A4, "OP_A4_LDY_DP", LD, Yb, DP, READ_Y, IsolateAndExecuteSafely_2)

%addop($A5, "OP_A5_LDA_DP", LD, Ab, DP, READ_A, IsolateAndExecuteSafely_2)

%addop($A6, "OP_A6_LDX_DP", LD, Xb, DP, READ_X, IsolateAndExecuteSafely_2)

%addop($A7, "OP_A7_LDA_DP_IND_L", LD, Ab, DP_IND_L, READ_A, IsolateAndExecuteSafely_2)

%addop($A8, "OP_A8_TAY", TA, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($A9, "OP_A9_LDA_IMM", LD, Ab, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($AA, "OP_AA_TAX", TA, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($AB, "OP_AB_PLB", PL, B_, IMP, NOTHIN, this)
	JSR PullFromStack_DATA_BANK
	JSR SetFlags_from_B
	JMP NEXT_OP_1

%addop($AC, "OP_AC_LDY_ABS", LD, Yw, ABS, READ_Y, IsolateAndExecuteSafely_3)

%addop($AD, "OP_AD_LDA_ABS", LD, Aw, ABS, READ_A, IsolateAndExecuteSafely_3)

%addop($AE, "OP_AE_LDX_ABS", LD, Xw, ABS, READ_X, IsolateAndExecuteSafely_3)

%addop($AF, "OP_AF_LDA_LONG", LD, Al, LONG, READ_A, IsolateAndExecuteSafely_4)

%addop($B0, "OP_B0_BCS", BC, S_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.C
	JMP DoBranching

%addop($B1, "OP_B1_LDA_DP_IND_Y", LD, Ab, DP_IND_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B2, "OP_B2_LDA_DP_IND", LD, Ab, DP_IND, READ_A, IsolateAndExecuteSafely_2)

%addop($B3, "OP_B3_LDA_SR_IND_Y", LD, A_, SR_IND_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B4, "OP_B4_LDY_DP_X", LD, Yb, DP_X, READ_Y, IsolateAndExecuteSafely_2)

%addop($B5, "OP_B5_LDA_DP_X", LD, Ab, DP_X, READ_A, IsolateAndExecuteSafely_2)

%addop($B6, "OP_B6_LDX_DP_Y", LD, Xb, DP_Y, READ_X, IsolateAndExecuteSafely_2)

%addop($B7, "OP_B7_LDA_DP_IND_L_Y", LD, Ab, DP_IND_L_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B8, "OP_B8_CLV", CL, V_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($B9, "OP_B9_LDA_ABS_Y", LD, Aw, ABS_Y, READ_A, IsolateAndExecuteSafely_3)

%addop($BA, "OP_BA_TSX", TS_, X_, IMP, NOTHIN, this)
	REP #$20
	LDA.b DP.REG_SR
	STA.b DP.REG_X
	JSR SetFlags_from_X
	JMP NEXT_OP_1

%addop($BB, "OP_BB_TYX", TY, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($BC, "OP_BC_LDY_ABS_X", LD, Yw, ABS_X, READ_Y, IsolateAndExecuteSafely_3)

%addop($BD, "OP_BD_LDA_ABS_X", LD, Aw, ABS_X, READ_A, IsolateAndExecuteSafely_3)

%addop($BE, "OP_BE_LDX_ABS_Y", LD, Xw, ABS_Y, READ_X, IsolateAndExecuteSafely_3)

%addop($BF, "OP_BF_LDA_LONG_X", LD, Al, LONG_X, READ_A, IsolateAndExecuteSafely_4)

%addop($C0, "OP_C0_CPY_IMM", CP, Yb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($C1, "OP_C1_CMP_DP_X_IND", CM, Pb, DP_X_IND, CMP_A, IsolateAndExecuteSafely_2)

%addop($C2, "OP_C2_REP", RE, P_, IMM, NOTHIN, IsolateAndExecute_2)

%addop($C3, "OP_C3_CMP_SR", CM, P_, SR, CMP_A, IsolateAndExecuteSafely_2)

%addop($C4, "OP_C4_CPY_DP", CP, Yb, DP, CPY_Y, IsolateAndExecuteSafely_2)

%addop($C5, "OP_C5_CMP_DP", CM, Pb, DP, CMP_A, IsolateAndExecuteSafely_2)

%addop($C6, "OP_C6_DEC_DP", DE, Cb, DP, DEC_IT, IsolateAndExecuteSafely_2)

%addop($C7, "OP_C7_CMP_DP_IND_L", CM, Pb, DP_IND_L, CMP_A, IsolateAndExecuteSafely_2)

%addop($C8, "OP_C8_INY", IN, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($C9, "OP_C9_CMP_IMM", CM, Pb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($CA, "OP_CA_DEX", DE, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($CB, "OP_CB_WAI", WA, I_, IMP, NOTHIN, NEXT_OP_1)

%addop($CC, "OP_CC_CPY_ABS", CP, Yw, ABS, CPY_Y, IsolateAndExecuteSafely_3)

%addop($CD, "OP_CD_CMP_ABS", CM, Pw, ABS, CMP_A, IsolateAndExecuteSafely_3)

%addop($CE, "OP_CE_DEC_ABS", DE, Cw, ABS, DEC_IT, IsolateAndExecuteSafely_3)

%addop($CF, "OP_CF_CMP_LONG", CM, Pl, LONG, CMP_A, IsolateAndExecuteSafely_4)

%addop($D0, "OP_D0_BNE", BN, E_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.Z
	EOR.b #$80
	JMP DoBranching

%addop($D1, "OP_D1_CMP_DP_IND_Y", CM, Pb, DP_IND_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D2, "OP_D2_CMP_DP_IND", CM, Pb, DP_IND, CMP_A, IsolateAndExecuteSafely_2)

%addop($D3, "OP_D3_CMP_SR_IND_Y", CM, P_, SR_IND_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D4, "OP_D4_PEI_DP_IND", PE, I_, DP_IND, PEI_IT, IsolateAndExecuteSafely_2)

%addop($D5, "OP_D5_CMP_DP_X", CM, Pb, DP_X, CMP_A, IsolateAndExecuteSafely_2)

%addop($D6, "OP_D6_DEC_DP_X", DE, Cb, DP_X, DEC_IT, IsolateAndExecuteSafely_2)

%addop($D7, "OP_D7_CMP_DP_IND_L_Y", CM, Pb, DP_IND_L_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D8, "OP_D8_CLD", CL, D_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($D9, "OP_D9_CMP_ABS_Y", CM, Pw, ABS_Y, CMP_A, IsolateAndExecuteSafely_3)

%addop($DA, "OP_DA_PHX", PH, X_, IMP, NOTHIN, this)
	JSR PushToStack_REG_X
	JMP NEXT_OP_1

%addop($DB, "OP_DB_STP", ST, P_, IMP, NOTHIN, this)
--	BRA --

%addop($DC, "OP_DC_JMP_ABS_IND", JM, Pw, ABS_IND, RELOC, IsolateAndExecuteSafely_0)

%addop($DD, "OP_DD_CMP_ABS_X", CM, Pw, ABS_X, CMP_A, IsolateAndExecuteSafely_3)

%addop($DE, "OP_DE_DEC_ABS_X", DE, Cw, ABS_X, DEC_IT, IsolateAndExecuteSafely_3)

%addop($DF, "OP_DF_CMP_LONG_X", CM, Pl, LONG_X, CMP_A, IsolateAndExecuteSafely_4)

%addop($E0, "OP_E0_CPX_IMM", CP, Xb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($E1, "OP_E1_SBC_DP_X_IND", SB, Cb, DP_X_IND, SBC_A, IsolateAndExecuteSafely_2)

%addop($E2, "OP_E2_SEP", SE, P_, IMM, NOTHIN, IsolateAndExecute_2)

%addop($E3, "OP_E3_SBC_SR", SB, C_, SR, SBC_A, IsolateAndExecuteSafely_2)

%addop($E4, "OP_E4_CPX_DP", CP, Xb, DP, CPX_X, IsolateAndExecuteSafely_2)

%addop($E5, "OP_E5_SBC_DP", SB, Cb, DP, SBC_A, IsolateAndExecuteSafely_2)

%addop($E6, "OP_E6_INC_DP", IN, Cb, DP, INC_IT, IsolateAndExecuteSafely_2)

%addop($E7, "OP_E7_SBC_DP_IND_L", SB, Cb, DP_IND_L, SBC_A, IsolateAndExecuteSafely_2)

%addop($E8, "OP_E8_INX", IN, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($E9, "OP_E9_SBC_IMM", SB, Cb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($EA, "OP_EA_NOP", NO, P_, IMP, NOTHIN, NEXT_OP_1)

%addop($EB, "OP_EB_XBA", XB, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($EC, "OP_EC_CPX_ABS", CP, Xw, ABS, CPX_X, IsolateAndExecuteSafely_3)

%addop($ED, "OP_ED_SBC_ABS", SB, Cw, ABS, SBC_A, IsolateAndExecuteSafely_3)

%addop($EE, "OP_EE_INC_ABS", IN, Cw, ABS, INC_IT, IsolateAndExecuteSafely_3)

%addop($EF, "OP_EF_SBC_LONG", SB, Cl, LONG, SBC_A, IsolateAndExecuteSafely_4)

%addop($F0, "OP_F0_BEQ", BE, Q_, REL, NOTHIN, HandleBranches)
	SEP #$30
	LDA.b DP.REG_P.Z
	JMP DoBranching

%addop($F1, "OP_F1_SBC_DP_IND_Y", SB, Cb, DP_IND_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F2, "OP_F2_SBC_DP_IND", SB, Cb, DP_IND, SBC_A, IsolateAndExecuteSafely_2)

%addop($F3, "OP_F3_SBC_SR_IND_Y", SB, C_, SR_IND_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F4, "OP_F4_PEA", PE, A_, JMP_ABS, NOTHIN, this)
	JSR PushToStack_address
	JMP NEXT_OP_3

%addop($F5, "OP_F5_SBC_DP_X", SB, Cb, DP_X, SBC_A, IsolateAndExecuteSafely_2)

%addop($F6, "OP_F6_INC_DP_X", IN, Cb, DP_X, INC_IT, IsolateAndExecuteSafely_2)

%addop($F7, "OP_F7_SBC_DP_IND_L_Y", SB, Cb, DP_IND_L_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F8, "OP_F8_SED", SE, D_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($F9, "OP_F9_SBC_ABS_Y", SB, Cw, ABS_Y, SBC_A, IsolateAndExecuteSafely_3)

%addop($FA, "OP_FA_PLX", PL, X_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_X
	JMP NEXT_OP_1

%addop($FB, "OP_FB_XCE", XC, E_, IMP, NOTHIN, NEXT_OP_1)

%addop($FC, "OP_FC_JSR_ABS_X_IND", JS, Rw, ABS_X_IND, RELOC, this)
	JSR PushToStack_RTS
	JMP RELOCATE_JUMP_ABS_X_IND

%addop($FD, "OP_FD_SBC_ABS_X", SB, Cw, ABS_X, SBC_A, IsolateAndExecuteSafely_3)

%addop($FE, "OP_FE_INC_ABS_X", IN, Cw, ABS_X, INC_IT, IsolateAndExecuteSafely_3)

%addop($FF, "OP_FF_SBC_LONG_X", SB, Cl, LONG_X, SBC_A, IsolateAndExecuteSafely_4)

;===============================================================================
; DATA
;===============================================================================
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

;===============================================================================
; HEADER
;===============================================================================
cleartable
org $00FFB0 ; ROM registration
db "AA"
db "DASM"
db $00, $00, $00, $00, $00, $00
db $00 ; flash size
db $00 ; expansion RAM size
db $00 ; special version
db $00 ; special chip

org $00FFC0 ; ROM specifications
db "Self-Di", "sassemb", "ler    "

db $31 ; rom map
db $00 ; rom type
db $07 ; rom size
db $00 ; sram size
db $01 ; ntsc
db $33 ; use $FFB0 for header
db $01 ; version
dw #$FFFF ; checksum
dw #$0000 ; inverse checksum

Vectors_Native:
NAT_VECTOR_UNU: dw $FFFF, $FFFF ; unused
NAT_VECTOR_COP: dw Vector_COP
NAT_VECTOR_BRK: dw Vector_BRK
NAT_VECTOR_ABR: dw Vector_Abort
NAT_VECTOR_NMI: dw Vector_NMI
NAT_VECTOR_RST: dw Vector_Reset
NAT_VECTOR_IRQ: dw Vector_IRQ

Vectors_Emulation:
EMU_VECTOR_UNU: dw $FFFF, $FFFF ; unused
EMU_VECTOR_COP: dw Vector_COP
EMU_VECTOR_UN2: dw $FFFF
EMU_VECTOR_ABR: dw Vector_Abort
EMU_VECTOR_NMI: dw Vector_NMI
EMU_VECTOR_RST: dw Vector_Reset
EMU_VECTOR_IRQ: dw Vector_IRQ ; IRQ/BRK
