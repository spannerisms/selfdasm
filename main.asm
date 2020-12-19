lorom

arch 65816
math pri on

org $800000
incsrc "defines.asm"
incsrc "registers.asm"

org $808000
incbin "disassemble.asm":0-7fff

org $808000
incsrc "setup.asm"
incsrc "general.asm"
incsrc "disassemble.asm"

incsrc "header.asm"