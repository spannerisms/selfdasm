pushtable
cleartable
; Internal ROM header
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
db $02 ; rom type, rom, ram, sram
db $05 ; rom size
db $00 ; sram size
db $01 ; ntsc
db $33 ; use $FFB0 for header
db $01 ; version
dw #$FFFF ; checksum
dw #$0000 ; inverse checksum

; native mode
Vectors:
NAT_VECTOR_UNU: dw $FFFF, $FFFF ; unused
NAT_VECTOR_COP: dw Vector_COP
NAT_VECTOR_BRK: dw Vector_BRK
NAT_VECTOR_ABR: dw Vector_Abort
NAT_VECTOR_NMI: dw Vector_NMI
NAT_VECTOR_RST: dw Vector_Reset
NAT_VECTOR_IRQ: dw Vector_IRQ ; IRQ

; emulation mode
EMU_VECTOR_UNU: dw $FFFF, $FFFF ; unused
EMU_VECTOR_COP: dw Vector_COP
EMU_VECTOR_BRK: dw Vector_Unused
EMU_VECTOR_ABR: dw Vector_Abort
EMU_VECTOR_NMI: dw Vector_NMI
EMU_VECTOR_RST: dw Vector_Reset
EMU_VECTOR_IRQ: dw Vector_IRQ ; IRQ/BRK
pulltable
