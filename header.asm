;===============================================================================
; This is our header.
; There are multiple header types, but we will be using the latest version.
; The header is critical to having any program run on the SNES
;===============================================================================
; Some data always goes here, at least for this header type
; So we'll be pointing the program counter there.
org $00FFB0

; The first 2 bytes are the publisher code
; For homebrew, that doesn't even matter.
; We'll set it to HB for Home Brew.
db "HB"

; These next 4 bytes are the game code.
; Again, not really important.
; We'll use DASM because asm is a common abbreviation for assembly.
; And the D will mean "Dis", for Disassembly.
db "DASM"

; These should always be $00
db $00, $00, $00, $00, $00, $00

; This is used for expansion chips on the cartridge.
; We won't be using those, so they're all $00.
db $00 ; flash size
db $00 ; expansion RAM size
db $00 ; special version
db $00 ; special chip

; The data here is standard across all header types,
; which is why I've included another org statement.
org $00FFC0

; a 21 byte string of the ROM name is expected here.
; This doesn't actually do anything, but we should name it anyways.
db "Self-Disassembler    "

; This is our ROM mapping mode. We're using lorom and fastrom
db $31

; This is our ROM type. $00 means we only have a ROM.
; No memory or battery.
db $00

; This is the size of our ROM in kilobytes
; Where kB = 2^x
; In our case, that's 2^7, or 128k
db $07

; This is the size of SRAM in kiloBITS, (not bytes)
; We have no onboard memory, so that's $00
db $00

; This is the region of our ROM.
; Since this ROM was written in the United States, we'll set it to $01.
db $01

; This is used to indicate which header version we're using.
; We're setting it to $33 for the latest specs.
db $33

; This is our ROM's version. This is 1.0, so we'll leave it at $00
db $00

; This is the checksum used to validate the ROM data.
; When added together, they should equal $FFFF
; asar will handle the calculation if we tell it to.
; Which we will.
dw #$FFFF ; checksum
dw #$0000 ; inverse checksum

; These are our interrupt vectors.
; Whenever an interrupt occurs, these are looked at to determine
; where in bank00 to begin executing code for the interrupt handler.
; There are 2 sets, native and emulation mode.
; The only emulation mode vector that needs to be here is the RESET.
; The CPU always starts in emulation mode, so it always uses that vector.
; The rest will be the same as our native mode vectors, just in case.
; In addition to that, we'll add labels so that they can be accessed by
; the disassembly code.
; Even though the location never changes, avoid using magic numbers.
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
EMU_VECTOR_IRQ: dw Vector_IRQ

;===============================================================================
; Now that we've looked at the header, let's dive into the actual code.
; continue reading at "disassemble.asm"
;===============================================================================