macro MVN(src, dest) ; why asar
	MVN <dest>, <src>
endmacro

macro MVP(src, dest)
	MVP <dest>, <src>
endmacro

function hexto555(h) = ((((h&$FF)/8)<<10)|(((h>>8&$FF)/8)<<5)|(((h>>16&$FF)/8)<<0))

macro col4(h1,h2,h3,h4)
	dw hexto555(<h1>)
	dw hexto555(<h2>)
	dw hexto555(<h3>)
	dw hexto555(<h4>)
endmacro

struct DP $000000
	.SCRATCH: skip 10

	.TEST: skip 2 ; for doing operations on consistently
	.TESTB: skip 2 ; for doing operations on consistently

	.VECTOR_X: skip 2

	.VRAM_LOC: skip 2
	.DO_DRAW: skip 2
	.DRAW_READ: skip 2
	.DRAW_COLOR: skip 2

	.ROM_READ:
	.ROM_READ.l: skip 1
	.ROM_READ.h: skip 1
	.ROM_READ.b: skip 1

	.ROM_READ_LE:
	.ROM_READ_LE.l: skip 1
	.ROM_READ_LE.h: skip 1
	.ROM_READ_LE.b: skip 1

	.REG_P: skip 1
	.REG_P.N: skip 1
	.REG_P.V: skip 1
	.REG_P.M: skip 1
	.REG_P.X: skip 1
	.REG_P.D: skip 1
	.REG_P.I: skip 1
	.REG_P.Z: skip 1
	.REG_P.C: skip 1
	.REG_P.E: skip 1
	.REG_P.B: skip 1

	.REG_A: skip 2
	.REG_X: skip 2
	.REG_Y: skip 2
	.REG_D: skip 2

	.LOCAL_READ: skip 2
	.REG_DB: skip 1

	.REG_SR: skip 2
	.REG_SR_BANK: skip 1 ; always $7F

	.SUBROUTINE_LEVEL: skip 2
	.EXECUTE: skip 8

	.DRAW_BUFFER: skip 22
	.DRAW_BUFFER.A: skip 6
	.DRAW_BUFFER.X: skip 6
	.DRAW_BUFFER.Y: skip 6
	.DRAW_BUFFER.P: skip 4
	.DRAW_BUFFER.S: skip 6
	.DRAW_BUFFER.D: skip 6
	.DRAW_BUFFER.B: skip 4
	skip 20

endstruct

; characters
COL   = $3001 ; :
DOL   = $3002 ;  $
DOL_P = $3003 ; ($
DOL_B = $3004 ; [$
C_PRN = $3006 ; )
C_BKT = $3007 ; ]

IMD   = $2405 ;  #
DOL_I = $2402 ;  $

DOL_R = $3402 ;  $

COM     = $2C08 ; ,
COM_X   = $2C09 ; ,X
COM_Y   = $2C0A ; ,Y
COM_S   = $2C0B ; ,S
P_COM_Y = $2C0C ; ),Y
B_COM_Y = $2C0D ; ],Y
A_IMP   = $2C0E

A_ = $10
B_ = $11
C_ = $12
D_ = $13
E_ = $14
I_ = $15
K_ = $16
L_ = $17
M_ = $18
N_ = $19
P_ = $1A
Q_ = $1B
R_ = $1C
S_ = $1D
T_ = $1E
V_ = $1F
X_ = $2C
Y_ = $2D

CA = $6D
LA = $6E
RA = $6F

Ab = $20
Bb = $21
Cb = $22
Db = $23
Lb = $24
Pb = $25
Tb = $26
Rb = $27
Xb = $28
Yb = $29
Zb = $2A

Aw = $30
Bw = $31
Cw = $32
Dw = $33
Lw = $34
Pw = $35
Tw = $36
Rw = $37
Xw = $38
Yw = $39
Zw = $3A

Al = $2B
Cl = $3B
Dl = $3C
Ll = $3D
Pl = $3E
Rl = $3F

AD = $40
AN = $41
AS = $42
BC = $43
BE = $44
BI = $45
BM = $46
BN = $47
BP = $48
BR = $49
BV = $4A
CL = $4B
CM = $4C
CO = $4D
CP = $4E
DE = $4F
EO = $50
IN = $51
JM = $52
JS = $53
LD = $54
LS = $55
MV = $56
NO = $57
OR = $58
PE = $59
PH = $5A
PL = $5B
RE = $5C
RO = $5D
RT = $5E
SB = $5F
SE = $60
ST = $61
TA = $62
TC = $63
TD = $64
TR = $65
TS_ = $66
TX = $67
TY = $68
WA = $69
WD = $6A
XB = $6B
XC = $6C

A_COL = $70
X_COL = $71
Y_COL = $72
P_COL = $73
S_COL = $74
D_COL = $75
B_COL = $76

STR = $80

; addressing modes
DP         = $00 ; dp
DP_X       = $01 ; dp,X
DP_Y       = $02 ; dp,Y
DP_IND     = $03 ; (dp)

DP_X_IND   = $04 ; (dp,X)
DP_IND_Y   = $05 ; (dp),Y
DP_IND_L   = $06 ; [dp]
DP_IND_L_Y = $07 ; [dp],Y

ABS        = $08 ; addr
ABS_X      = $09 ; addr,X
ABS_Y      = $0A ; addr,Y
ABS_IND    = $0B ; (addr)

ABS_X_IND  = $0C ; (addr,X)
ABS_IND_L  = $0D ; [addr]
LONG       = $0E ; long
LONG_X     = $0F ; long,X

IMM        = $10 ; #i
IMM_L      = $11 ; i
IMM_A      = $12 ; #i based on M
IMM_X      = $13 ; #i based on X

SR         = $14 ; i,SR
SR_IND     = $15 ; (i,SR)
SR_IND_Y   = $16 ; (i,SR),Y

A_REG      = $17 ; A
REL        = $18 ; .branch +127/-128
REL_L      = $19 ; .branch +32767/-32768
JMP_ABS    = $1A ; jump/call absolute
JMP_LONG   = $1B ; jump/call long

BLK        = $1C ; SRC,DEST


IMP        = $7F ; implied

; opcode type
NOTHIN = $00

SAVE_A = $01
READ_A = $02
AND_A  = $03
EOR_A  = $04
ORA_A  = $05
ADC_A  = $06
SBC_A  = $07
CMP_A  = $09
BIT_A  = $09
TRB_A  = $0A
TSB_A  = $0B
SAVE_X = $0C
READ_X = $0D
CPX_X  = $0E
SAVE_Y = $0F
READ_Y = $10
CPY_Y  = $11
INC_IT = $12
DEC_IT = $13
STZ_IT = $14
ASL_IT = $15
LSR_IT = $16
ROL_IT = $17
ROR_IT = $18
PEI_IT = $19
RELOC  = $1A
RELOCL = $1B
