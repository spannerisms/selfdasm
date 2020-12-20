lorom

arch 65816
math pri on

org $800000
incsrc "defines.asm"

org $808000

db "THIS ROM CONTAINS ITS OWN SOURCE CODE IN ASCII! CHECK SNES $81:8000 (pc: $8000)"

reset bytes
incsrc "disassemble.asm"

print "Size: ", bytes, " bytes"

check bankcross off
org $818000

db "main.asm:       " : incbin "main.asm"

fillbyte $20 : fill 128

db "defines.asm:     " : incbin "defines.asm"

fillbyte $20 : fill 128

db "disassemble.asm: " : incbin "disassemble.asm"

org $83FFFF
db 0
