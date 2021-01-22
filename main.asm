;===============================================================================
; Homebrewing on the SNES is honestly quite a task.
; Assembly, the language, is not hard. Not by any means.
; But homebrewing has quite a steep learning curve.
; And it's a big step up from hacking in general.
;
; You will need to understand a lot of hardware on the SNES.
; You will need to manage memory.
; You will need to create everything from scratch.
;
; The goal of this tutorial is to create a small program and improve basic
; assembly and SNES concepts to a higher level along the way.
;
; This program is a very simple concept:
; Create a ROM that reads its own byte code and disassembles it.
; While the concept is simple, we'll need to take certain precautions
; to avoid messing with the program's memory as it runs the disassembly.
; To accomplish this, we will be using 1 bank of WRAM (bank 7E) for operation,
; and we will "emulate" a second segment for the code being disassembled in 7F.
;
; Before we begin, I strongly recommend watching this series:
; <https://www.youtube.com/playlist?list=PLHQ0utQyFw5KCcj1ljIhExH_lvGwfn6GV>
; SNES Features by Retro Game Mechanics Explained
; This is a great series for learning the basics.
; It's so useful, that I am going to proceed through this tutorial assuming
; that you have already watched it
;
; In addition to that series, I will also assume general programming knowledge.
; You will need to be familiar with concepts such as
;   hexadecimal
;   bitwise math
;   integer overflow
;   flags
;
; I would like to make it clear that this should not be your first stop
; in learning assembly. I am going to assume you are competent enough to
; read and understand other resources if you need something such as an
; instruction explained in more detail.
; This program will not hold back on using more advanced techniques,
; and while they will be explained, it will be up to you to understand the
; basic concepts underlying them.
;
; One thing you should notice is that all this tutorial text is on a line
; beginning with a semicolon. Semicolons denote comments.
; Anything from the semicolon to the end of the line is ignored for assembly.
;===============================================================================

; The first thing we want to do is define the mapping mode
; We'll be using lorom for 2 reasons:
;  It's the simplest and easiest to understand.
;  This ROM will be small. It will fit entirely in bank00
lorom

; Next we want to specify our architecture.
; 65816 is the instruction set used by the main CPU of the SNES
arch 65816

; Unfortunately, asar likes to be backwards compatible with xkas
; the assembler it obsoleted
; By default, asar does math operations from left to right, always
; this line tells it to take order of operations into account
math pri on

; org statements tell us to assemble at a specific address.
; This address is known as the "Program Counter".
; This phrase will mean both the code or data currently being written by asar
; and the code being executed by the CPU.
; In this case, the org is putting us at $80:0000 in ROM
; That's Bank 80, address $0000
; This address is actually RAM, but a weird quirk in asar requires
; that struct definitions (which we will see in the next file) be after some org.
; I like to have that org at $80:0000 because it prevents me from writing code
; in the file on accident. Writing code to WRAM like that will throw an error.
org $800000

; incsrc tells asar to load the file named and assemble it as code.
; It will look relative to where it's working.
; In this case, it will look in the same folder as this file for "defines.asm".
; Go ahead and open that file and we'll go through it
incsrc "defines.asm"

;===============================================================================
; WELCOME BACK
;===============================================================================
; Clear table tells asar to use regular ASCII encoding for strings
; Yup! asar can encode strings as data
; and we will find this to be incredibly useful later on
cleartable

; Here's a proper org statement
; We'll be writing code starting at $80:8000
org $808000
; This statement resets the counter for how many bytes have been written to ROM.
; We'll use this at the end to see how much code and data we've written
reset bytes

; Before we look at the main program code, open up "header.asm" and continue there.
incsrc "disassemble.asm"
incsrc "header.asm"

; This is a print statement
; We can use this to help debug compilation
; We'll just use this one to print the size of our rom's code and data
; the bytes keyword will print the number of bytes asar has counted itself
; writing since the last time we reset it
print "Size: ", bytes, " bytes"

; Since our rom is 128k and lorom, it will have 4 banks of 32kB each
; Some emulators are picky about the size, so we're going to write a
; dummy byte to the very last location in ROM.
; If we didn't do this, our new code would
org $83FFFF
db 0
