;===============================================================================
; Hey! You made it!
;===============================================================================
; The first thing defined in this file is a function.
; functions in asar convert parameters to a number output.
; This jumbled mess is what I use in all my assembly to create colors.
; On the SNES, colors are 5 bit red, green, and blue values in a 16-bit number.
; Oh ya, 16-bit numbers. Let's get some basic terminology situated now:
;   BYTE - 8 bits
;   WORD - 16 bits
;   LONG - 32 bits
; I'll be covering terminology as it comes up. And will put terms in ALL CAPS.
; All this function does is take a color defined in standard HEX format (#RRGGBB)
; and turns it into a value the SNES can work with
; We can't really make use of white space, so functions can be messy.
;
; As an example, if we wanted to define the color HEX #E86040, we would write
;   hexto555($E86040)
; and it would output
;   $219D
;
; The dollar sign ($) is what we use to denote that a number is base-16
; In other languages, you may see the prefix 0x instead.
; And in older assembly source codes or references, you may see the suffix H
; So all of these are the same:
;   $1234
;  0x1234
;    1234H
; And all of them are equal to 4660 decimal.
; To write a decimal number, you simply omit the prefix.
;
; Binary numbers can be written with the prefix %
; I won't be using many binary numbers in this tutorial, but I will at least once
; just to give you an example.
function hexto555(h) = ((((h&$FF)/8)<<10)|(((h>>8&$FF)/8)<<5)|(((h>>16&$FF)/8)<<0))

; Next up are MACROS.
; Macros are very powerful, but, with great power, comes great responsibility.
; My stance is that macros are perhaps the most useful tool for data organization.
; And while they can be used for code structure, I strongly recommend you avoid that.
; The more explicit your code is, the easier it is to understand.
; While it may be verbose at times, that's just how things are with assembly.
;
; In macro definitions, unlike functions, each argument must be referenced with
; angle brackets (< >) surrounding the argument name
; this macro is named col4, for "4 colors".
; it uses the function we just looked at to write out 4 colors at once.
;
; To use this macro, we put it on its own line and prefix the name with a %.
; like so:
;    %col4($000000, $F8F8F8, $F80000, $0000F8)
; and this will automatically be turned into the following on assembly:
;    dw hexto555($000000)
;    dw hexto555($F8F8F8)
;    dw hexto555($F80000)
;    dw hexto555($0000F8)
;
; And those values correspond to a pure black, white, red, and blue.
; "dw" means "define word", and it is used to write a 16-bit number directly to ROM.
; There's a define for each length:
;    db - define byte
;    dw - define word
;    dl - define long
;    dd - define double (32 bits, but we won't be using this)
macro col4(h1,h2,h3,h4)
	dw hexto555(<h1>)
	dw hexto555(<h2>)
	dw hexto555(<h3>)
	dw hexto555(<h4>)
endmacro

; Next, we'll be defining a STRUCT.
; Structs are, in my opinion, one of the most useful features asar provides.
; They allow you to essentially create variables by designating memory.
; Memory can also be designated with defines (more on those in a moment)
; But that requires you to constantly manage each address individually.
; This can be a massive pain, especially when refactoring.
; Instead, we can define a struct like this:
;   struct NAME ADDRESS
; and then create labels inside it.
; Those labels will be followed by a "skip", which essentially defines
; the size of the variable.
; skip can also be used when hacking to avoid overwriting code.
; All it does is jump the program counter ahead by that many bytes.
;
; This struct will be named DP (for Direct Page) and located at $0000 in bank00.
; More on direct page later.
; Each "variable" here will be explained as we get to them, but here's a brief overview:
struct DP $7E0000
	; This will be general scratch space for performing calculations and such
	; We should consider it very volatile and only store temporary values here.
	.SCRATCH: skip 4

	; This address will flag draw updates for our draw routine
	.DO_DRAW: skip 1

	; And when we do draw things, this will tell us where
	.VRAM_LOC: skip 2

	; And this will be used for the color of the text
	.DRAW_COLOR: skip 2

	; This will hold the address in ROM we're currently disassembling
	; Note that the first label has no skip statement
	; This means it points to the same location as .ROM_READ.l
	; I've done this to split the address into 3 bytes
	; allowing us to address them individually more explicitly
	; The low byte is first because the SNES is a little endian processor
	; this means that bytes are written backwards, from low to high
	; So if we are currently disassembling the address $80:8123
	; It will actually appear like this in memory:
	;   .ROM_READ.l = $23
	;   .ROM_READ.h = $81
	;   .ROM_READ.b = $80
	.ROM_READ:
	.ROM_READ.l: skip 1
	.ROM_READ.h: skip 1
	.ROM_READ.b: skip 1

	; Here's where we'll store the PROCESSOR STATUS REGISTER (P)
	; We'll also store each flag inside of P individually, for easy testing.
	; Let's go over each flag now:
	; The P flag is layed out like this:
	; bit:   76543210   ?
	; flag:  NVMXDIZC   E
	; when a flag is "set" that means the bit is flipped to a 1
	; when a flag is "reset", it will be flipped to a 0
	; When we use the individually referenced flags, we'll only consider bit7
	.REG_P: skip 1

	; The N FLAG is used to flag "NEGATIVE" results
	; Values are neither signed nor unsigned.
	; Or rather, which they are is up to you and how you use them.
	; But this flag facilitates signed arithmetic.
	; When a value is loaded, the highest bit is sent to the N flag
	; For 8-bit numbers, that's bit 7, and for 16-bit numbers, bit 15
	; The negative flag also flags a < b when comparing a to b
	.REG_P.N: skip 1

	; The V FLAG is used to flag OVERFLOW in signed arithmetic
	; This is different and distinct from integer overflow
	; Essentially, this means that the result went negative or positive
	; when it wasn't supposed to.
	; For example, if we add the 8-bit numbers $01 and $7F we get $80
	; For signed arithmetic, this means 1 + 127 = -128
	; That's not correct!
	; In this case, the V flag will be set, to indicate the error.
	; However, if we do this:
	;    $01 - $06 = $FB
	; that's equivalent to 1 - 6 = -5
	; While this equation results in an integer overflow, the result is correct.
	; The V flag will be reset.
	.REG_P.V: skip 1

	; The M FLAG decides the size of our ACCUMULATOR
	; When M is set, almost all operations using the accumulator will be done in 8-bit
	; When M is reset, these operations will be 16-bit.
	; There are exceptions, and I will cover them later.
	.REG_P.M: skip 1

	; The X FLAG decides to size of our INDEX REGISTERS, X and Y
	; Like M, when set, these will be 8 bit. When reset, they will be 16-bit.
	; Unlike M, however, setting the index registers to 8-bit will also
	; set their top byte to $00.
	; With the accumulator, the top byte is preserved, but mostly ignored.
	.REG_P.X: skip 1

	; The D FLAG indicates we should use BINARY CODED DECIMAL or BCD.
	; When BCD is enabled, each byte is split into 2 digits from 0-9.
	; For example, $1234 will denote the decimal value 1234.
	; It won't be actually be equal to that decimal value, but that is what
	; it will be meant to represent.
	; This tutorial will not be using BCD.
	.REG_P.D: skip 1

	; The I FLAG tells the CPU to ignore most interrupts.
	; The only exception to this is NMI, the Non-Maskable one (it's in the name).
	; When set, any hardware interrupt is ignored.
	.REG_P.I: skip 1

	; The Z FLAG indicates a result of ZERO (0).
	; When a value is loaded or manipulated and the result is exactly 0
	; then the Z flag will be set.
	; For any other value, the Z flag will be reset.
	; When comparing numbers, the Z flag indicates the numbers are equal.
	.REG_P.Z: skip 1

	; The C FLAG indicates the status of the CARRY.
	; The carry serves multiple purposes.
	; For arithmetic, this is the carry or borrow in addition or subtraction.
	; It essentially flags integer overflow, but can be used to extend arithmetic
	; to numbers larger than 16-bit.
	; For example, say we have this:
	;   $80 + $95 = $115
	; If we're using 8-bit arithmetic, the accumulator would hold $15.
	; Where's the highest digit?
	; It's been moved to the carry flag.
	; We can then use the carry flag on another digit to extend the number to 16-bits.
	; We can use more addresses or we can get the carry flag itself by adding A and $00.
	; Any addition performed when the carry flag is set will have +1 added to it.
	; So the full equation is really:
	;   addend + addend + carry = sum
	;
	; For subtraction, think of it as the opposite. We "borrow" whatever is in the carry.
	; so we have:
	;   minuend - subtrahend - carry = difference
	;
	; But the carry serves another purpose:
	; When shifting numbers bitwise, the carry flag will hold "bit 8".
	; It's not really bit 8 of the number, but it can be treated as such.
	; For example, if we shift the value $81 to the right, it becomes $40
	; and the carry flag will be set, because the lowest bit was set.
	; We shifted bit 0 out and gave it to C.
	; The carry can also be shifted in, when using rolls instead of shifts.
	;
	; Being clever with and mindful of the carry flag is important.
	.REG_P.C: skip 1

	; The E FLAG is used to tell the processor to run in 6502 EMULATION MODE.
	; This flag is actually hidden.
	; And it gives the carry flag a third purpose.
	; The E flag can only be accessed by swapping it with the carry.
	; Understanding emulation mode is not important, as you will always disable it.
	.REG_P.E: skip 1

	; This is another unimportant flag only listed for completeness.
	; The B flag is used to indicate that an interrupt was requested through software.
	; This only occurs in emulation mode, so we'll leave it at that.
	.REG_P.B: skip 1

	; Here's where we'll hold each register
	; This is our ACCUMULATOR, A.
	; The accumulator is our most robust register for
	; loading, storing, and manipulating values.
	.REG_A: skip 2

	; This is our X INDEX REGISTER.
	; Our index registers can load and store values much the same was as
	; the accumulator, but they have fewer ways of doing so. They also cannot
	; be used to perform arithmetic or bitwise functions.
	; The functionality they have that the accumulator lacks is being used as
	; an offset for an operand address to read values more dynamically.
	.REG_X: skip 2

	; This is our Y INDEX REGISTER.
	.REG_Y: skip 2

	; This is our DIRECT PAGE ADDRESS.
	; Direct page is an addressing mode that tells you where in bank00
	; 8-bit addresses are read from.
	; While it's called direct *page*, it actually can be defined anywhere.
	; Examples:
	;    $21 reads $00:0021 when D=$0000
	;    $21 reads $00:4321 when D=$4300
	;    $21 reads $00:4342 when D=$4321
	; If the low byte of D is not $00
	; any direct page addressing will take an extra cycle
	; It's best to avoid this when possible
	.REG_D: skip 2

	; DB is our DATA BANK. It is distinct from the PROGRAM BANK.
	; While the program bank tells us where to handle code
	; The data bank tells us where to handle data.
	; Examples:
	;    STA.w $4000 writes to $00:4000 when DB=$00
	;    STA.w $4000 writes to $7E:4000 when DB=$7E
	;    STA.w $4000 writes to $7F:4000 when DB=$7F
	; The only exceptions to this are these instructions:
	;    JSR (addr,X)
	;    JMP (addr,X)
	; Both of those instructions will use the program bank for reading.
	.REG_DB: skip 1

	; SR is our STACK REGISTER, or STACK POINTER.
	; This points to the first open spot in the stock.
	; The stack is always in bank00
	.REG_SR: skip 2
	; Except...
	; We want to "emulate" memory to prevent interference
	; So we will write $7F to this address at some point.
	; That way our emulated stack is in the disassembly's bank
	.REG_SR_BANK: skip 1

	; This is where we will write many instructions so that
	; we can, as the name implies, execute them as code
	.EXECUTE: skip 5

	; This will be our draw buffer (as it says)
	; It's 64 bytes total, so it can hold 32 tiles
	; It's been split into segments so that we can address each
	; part of the buffer 
	.DRAW_BUFFER:
	.DRAW_BUFFER.EMPTY_1: skip 2
	.DRAW_BUFFER.ADDR: skip 6
	.DRAW_BUFFER.COLON: skip 2
	.DRAW_BUFFER.INSTRUCTION: skip 4
	.DRAW_BUFFER.OPERAND: skip 8
	.DRAW_BUFFER.EMPTY_2: skip 2
	.DRAW_BUFFER.A: skip 6
	.DRAW_BUFFER.X: skip 6
	.DRAW_BUFFER.Y: skip 6
	.DRAW_BUFFER.P: skip 4
	.DRAW_BUFFER.S: skip 6
	.DRAW_BUFFER.D: skip 6
	.DRAW_BUFFER.B: skip 4
	.DRAW_BUFFER.EMPTY_3: skip 2

endstruct

; Labels can be defined with
;   NAME = ADDRESS
; Here we've done that for important hardware registers we'll be using
INIDISP = $002100
OAMDATA = $002104
BGMODE = $002105
MOSAIC = $002106
BG1SC = $002107
BG12NBA = $00210B
BG1HOFS = $00210D
BG1VOFS = $00210E
BG2HOFS = $00210F
BG2VOFS = $002110
VMAIN = $002115
VMADDR = $002116
VMDATA = $002118
CGADD = $002121
CGDATA = $002122
W12SEL = $002123
TM = $00212C
TS = $00212D
TMW = $00212E
TSW = $00212F
CGWSEL = $002130
CGADSUB = $002131
SETINI = $002133
WMDATA = $002180
WMADDR = $002181
WMADDL = $002181
WMADDM = $002182
WMADDH = $002183
NMITIMEN = $004200
RDNMI = $004210


; Labels can also be used as defines.
; This is a complete bastardization of their purpose, but it works.
; I often do this to cut down on my typing.
; For a proper define, you use:
;  !NAME = VALUE
; And value can be anything, including strings
; Using labels as defines as we are here can only accept numbers
; They also can't be changed
; Nor can they be used to assign other values
; Be wary of this, and try to stick to using defines.

; Here we'll just be listing a bunch of tilemap values for various phrases.
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

; These are used for identifying what type of addressing we're disassembling
IMP        = $00 ; implied
DP         = $01 ; dp
DP_X       = $02 ; dp,X
DP_Y       = $03 ; dp,Y
DP_IND     = $04 ; (dp)
DP_X_IND   = $05 ; (dp,X)
DP_IND_Y   = $06 ; (dp),Y
DP_IND_L   = $07 ; [dp]
DP_IND_L_Y = $08 ; [dp],Y
ABS        = $09 ; addr
ABS_X      = $0A ; addr,X
ABS_Y      = $0B ; addr,Y
ABS_IND    = $0C ; (addr)
ABS_X_IND  = $0D ; (addr,X)
ABS_IND_L  = $0E ; [addr]
LONG       = $0F ; long
LONG_X     = $10 ; long,X
IMM        = $11 ; #i
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


; And here we're defining various opcode types
NOTHIN = $00
READ_A = $01
AND_A  = $02
EOR_A  = $03
ORA_A  = $04
ADC_A  = $05
SBC_A  = $06
CMP_A  = $07
BIT_A  = $09
READ_X = $09
CPX_X  = $0A
READ_Y = $0B
CPY_Y  = $0C
SAVE_A = $0D
SAVE_X = $0E
SAVE_Y = $0F
INC_IT = $10
DEC_IT = $11
STZ_IT = $12
ASL_IT = $13
LSR_IT = $14
ROL_IT = $15
ROR_IT = $16
TRB_A  = $17
TSB_A  = $18
PEI_IT = $19
RELOC  = $1A
RELOCL = $1B

; Now that we've finished this file, head back to "main.asm"