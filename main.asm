lorom

arch 65816

math pri on

org $800000

incsrc "defines.asm"

cleartable

org $808000

reset bytes

incsrc "disassemble.asm"
incsrc "header.asm"

print "Size: ", bytes, " bytes"

org $83FFFF
db 0