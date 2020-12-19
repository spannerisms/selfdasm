GetVectorSet:
	SEP #$30
	JSR Sync_REG_P
	LDA.b DP.REG_P.E
	AND.b #$80
	LSR
	LSR
	LSR
	TAX
	RTS

DidAReturn:
	SEP #$20
	LDA.b DP.SUBROUTINE_LEVEL
	BEQ ++
	DEC.b DP.SUBROUTINE_LEVEL

++	RTS

DidACall:
	SEP #$20
	INC.b DP.SUBROUTINE_LEVEL
	RTS

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
	BRA .push_1

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
	JSR Sync_REG_P

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
	JSR Sync_REG_P
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
	JSR Sync_REG_P
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
	JSR Sync_REG_P
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
	STA.b DP.TESTB
	JSR Collect_REG_P
	LDA.b DP.TESTB
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
	STA.b DP.TESTB
	JSR Collect_REG_P
	LDX.b DP.TESTB

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

;===============================================================================
Get_Immediate:
	PHY
	PHA
	PHP

	REP #$30
	LDY.w #1

	LDA.b [DP.ROM_READ], Y
	STA.b DP.TEST

	PLP
	PLA
	PLY
	RTS

Get_A:
	PHP
	REP #$20
	PHA

	LDA.b DP.REG_A
	STA.b DP.TEST

	PLA
	PLP
	RTS

Save_A:
	PHA
	PHP

	JSR Collect_REG_P
	LDA.b DP.TEST
	STA.b DP.REG_A

	PLP
	PLA
	RTS

Get_X:
	PHP
	REP #$20
	PHA

	LDA.b DP.REG_X
	STA.b DP.TEST

	PLA
	PLP
	RTS

Save_X:
	PHX
	PHP

	JSR Collect_REG_P
	LDX.b DP.TEST
	STX.b DP.REG_X

	PLP
	PLX
	RTS

Get_Y:
	PHP
	REP #$20
	PHA

	LDA.b DP.REG_Y
	STA.b DP.TEST

	PLA
	PLP
	RTS

Save_Y:
	PHY
	PHP

	JSR Collect_REG_P
	LDY.b DP.TEST
	STY.b DP.REG_Y

	PLP
	PLY
	RTS

LOAD_A:
	REP #$20
	LDA.b DP.REG_A
	JMP Collect_REG_P

