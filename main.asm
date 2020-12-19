lorom

arch 65816
math pri on

org $800000
incsrc "defines.asm"
incsrc "registers.asm"

org $808000
incbin "disassemble.asm":0-7fff
reset bytes

org $808000
incsrc "disassemble.asm"

incsrc "header.asm"

print "Size: ", bytes, " bytes"
