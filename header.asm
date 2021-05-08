org $00FFB0
db "HB"
db "DASM"
db $00, $00, $00, $00, $00, $00
db $00
db $00
db $00
db $00

org $00FFC0
db "Self-Disassembler    "
db $31
db $00
db $07
db $00
db $01
db $33
db $00
dw #$FFFF
dw #$0000

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