;===============================================================================
; I hope you're ready.
; We're about to dive into the actual code that will disassemble itself.
;===============================================================================
; Here's our RESET ROUTINE. This is where we start whenever the system powers on.
; The SNES knows how to get here because the architecture it runs on will always
; look at the same exact spot ($00:FFFC) for a vector. That's the reset vector.
; It will take that vector and begin execution of code there.
; We've put our reset routine at $00:8000, but it can go anywhere in bank00.
; Understanding the mechanics of the hardware beyond this is not necessary for
; writing a reset routine. Just know that there's that location in ROM ($00:FFFC)
; that will be looked at for a vector on reset.
; After the reset routine, we will find our NMI routine. It will be found the same way
; except it will be located by looking for a vector at a separate address.
;
; The main purpose of the code here will be configuring our initial settings and memory.
; On actual hardware, memory will be nondeterministic from console to console.
; Hardware registers are determinitic, but consider them not to be,
; mostly for foolproofing.
Vector_Reset:
	; First we'll use SEI to disable interrupts.
	; This will set the I flag in the processor status register,
	; which was covered in defines.asm
	; This isn't necessary in accurate CPU emulation, but it's a good habit.
	;
	; You may also want to reuse the reset routine as a failsafe.
	; This is our first instruction, and with it comes from terminology:
	;   INSTRUCTION - a single operation performed by the CPU
	;   OPCODE - an 8-bit value of machine code identifying the instruction
	;   OPERAND - the arguments (if any) to the instruction
	;   MNEMONIC - the 3 letter name we type to identify an instruction
	;   ADDRESSING MODE - indicates what the instruction acts on
	;
	; For SEI:
	;   opcode:          78
	;   operand:         none
	;   mnemonic:        SEI
	;   addressing mode: implied
	SEI

	; REP is used to REset Processor flags
	; This is our first instruction with an operand
	; So let's look at it in full as well:
	;   opcode:          C2
	;   operand:         09
	;   mnemonic:        REP
	;   addressing mode: immmediate
	; Here, we're disabling decimal mode and the carry flag
	; Decimal mode is another unnecessary fix, but a good habit
	;     NVMXDIZC
	REP #%00001001

	; There's more terminology to cover as we move on regarding addressing modes
	;   DIRECT PAGE, DP - 8-bit (1 byte) operand used with the D register and in bank 00
	;   ABSOLUTE - 16-bit (2 byte) operand, forming an address with the Data Bank
	;   long - 24-bit (3 byte) operand, explicit and as-is
	;   IMMEDIATE - taken from the address following the opcode (pontification below)
	;   IMPLIED - functions without an operand
	;   INDIRECT - address is contained in the contents of the operand's address
	;   INDEXED - offset with X or Y
	;   RELATIVE - operand points to an offset relative to the program counter
	;   STACK PUSH - adds an item to stack and decrements the stack pointer
	;   STACK PULL - takes an item to stack and increments the stack pointer
	;   STACK RELATIVE - loads a value in the stack, offset from the stack pointer

	; XCE will exchange the carry and emulation flags
	; The carry flag being clear will become the emulation flag
	; and the emulation flag that was set will be our carry flag
	XCE

	; This is our first JUMP instruction
	; These and BRANCH instructions are fundamental for program flow
	; Rather than working on registers or memory, jumps and branches move
	; the program counter to a new location for execution.
	; In addition to jumps and branches, there are also CALLS and RETURNS.
	; These operate much the same way, except a call will push the current
	; program counter to stack before relocating.
	; A return will relocate itself by pulling the topmost items from the stack.
	;
	; Interrupts are always in bank00, which is slow
	; this JML will bring us to bank80, where fastrom is in effect
	; The .l after the mnemonic means to explicitly assemble 24-bits
	; This isn't necessary in the case of JML, but it's a good way
	; to introduce the .l suffix
	JML.l Reset_Fast

Reset_Fast:
	; Fast rom isn't actually enabled until bit0 of $420D is set.
	; Here we're taking it value and shifting it left.
	; And because it's a ROLL operation, we're also shifting in the carry.
	; Our carry flag is set from exchanging it with the emulation flag.
	; So at the end, bit 0 of $420D will be set, enabling fastrom.
	; This specific way of doing things is a bit more involved, because
	; only bit 0 of this address does anything. The reset are open bus.
	; Don't worry about that though, and let's move on.
	ROL.w $420D

	; This is our first STORE operation.
	; STZ for STore Zero will write 00 to the operand address.
	; This is the only store operation that does not use a register
	; The other store operations each write the contents of a register
	; rather than a specific value.
	;   STA - STore from Accumulator
	;   STX - STore from X index register
	;   STY - STore from Y index register
	;
	; Complementing the store instructions are the LOAD instructions:
	;   LDA - LoaD to Accumulator
	;   LDX - LoaD to X index register
	;   LDY - LoaD to Y index register
	; These will load the contents of the operand address into the
	; specified address.
	;
	; By setting $4200 to $00, we disable the NMI and IRQ interrupts.
	; This is another good practice and something we will want to do whenever
	; we want as much CPU time as possible.
	; The .w here tells the assembler to use 16-bit writes.
	; In the case of addresses, 16-bit is also called "absolute" addressing.
	; For almost every absolute addressing operation, data bank matters.
	; We're not worried about data bank right now, because we're definitely
	; in DB=$00; that's how emulation mode always starts.
	; Emulation mode also always begins with M and X set, so we know that
	; this STZ will only write 1 byte of $00 to $4200.
	STZ.w NMITIMEN

	; PEA is our first STACK PUSH operation.
	; PEA will push 16 bits to stack and PLD will pull 16 bits
	; PEA is always 16-bit, regardless of the M flag
	PEA.w $2100

	; PLD is our first first STACK PULL operation.
	; Our stack is a last-in, first-out or LIFO system
	; And our stack pointer points to the first empty slot
	; This sets our Direct Page to $2100, to save just a little on
	; what we're doing next.
	; Direct page is a special addressing mode used to greatly improve
	; the performance and size of code. Direct page addresses are all
	; addressed with a single byte.
	; The Direct Page register was explained in defines.asm
	PLD

	; We're loading X with $80 because that's our program bank
	; We could use PHK (which pushes our program bank)
	; But we're going to use the same value in X for other purposes
	; The .b is used to signal that we're only loading 8 bits
	; The # indicates that we are using IMMEDIATE ADDRESSING.
	; Now, it might be tempting to call this a constant, but that's incorrect.
	; When in ROM, it is technically constant, but that's only because ROM
	; is, well, read-only.
	; If we wanted, we could execute immediate addressing in RAM
	; and it could include self-modifying code.
	; The term is IMMEDIATE because the value used is found immediately after the opcode.
	; You will need to be mindful of your M and X flags when using immediate addressing.
	; And I recommend always being explicit with the size.
	LDX.b #$80

	; So let's instead push X and pull it back into our data bank.
	; Keep in mind that pushing items to stack does not modify the register.
	; So even though we "put X in the stack", X still holds the value $80.
	PHX
	PLB

	; Here, we're reusing $80 to disable the screen
	STX.b INIDISP

	; And we're also configuring VMAIN to increment vram on writes to $2119
	; and to increment it by 1 word each time.
	STX.b VMAIN

	; By writing $00 here, we tell the WRAM port to be in bank 7E.
	STZ.b WMADDH

	; We'll be using mode 0 with 8x8 tiles, so everything here is 0.
	STZ.b BGMODE

	; And we don't want mosaic, so kill that.
	STZ.b MOSAIC

	; We load $02 so that background 1 has its tile map at $0000 in VRAM
	; the only bit we have set tells the BG1 tilemap to be double height.
	LDA.b #$02
	STA.b BG1SC

	; This is our first INCREMENT/DECREMENT instruction.
	; DEC for DECrement will subtract 1 from the operand address or
	; implied register. In the case of an unqualified DEC or INC, the
	; implied register is A. So this DEC will decrement our accumulator.
	; DEC or INC can also take an operand address, which will add or subtract
	; 1 from the address's contents without using the accumulator.
	; For X and Y, the DEX, INX, DEY, and INY instructions exist.
	;
	; The next value we want is $01.
	; And this is an example of being a little extra clever in assembly
	; Rather than loading the value explicitly, let's just decrement
	; We're already at 2, so this will leave our accumulator with $01
	DEC

	; Now we're telling BG1 to look for character graphics at $2000 in VRAM
	STA.b BG12NBA

	; The same value is also used to enable BG1 and only BG1 on the main screen
	STA.b TM

	; We want everything on the subscreen disabled,
	; as well as the window through pipes.
	STZ.b TS
	STZ.b TMW
	STZ.b TSW

	; We want to reset BG1 to have no scroll.
	; Background scroll registers are examples of WRITE TWICE registers.
	; The first write we perform sets the low byte.
	; The second write sets the high byte.
	; In this case, we want every byte to be 0, so four STZ do fine.
	STZ.b BG1HOFS
	STZ.b BG1HOFS
	STZ.b BG1VOFS
	STZ.b BG1VOFS

	; These are more PPU registers we want nothing to do with
	STZ.b W12SEL
	STZ.b CGWSEL
	STZ.b SETINI

	; We're finally switching to some 16-bit stuff.
	; To avoid typing binary all the time, you will want to memorize a few values:
	;    REP #$1x - Clears X flag
	;    REP #$2x - Clears M flag
	;    REP #$3x - Clears M and X flag
	;    REP #$x1 - Clears carry
	; And these same values apply to SEP, which sets flags instead of resetting them.
	REP #$20

	; We want to clear all of memory next, so we'll set these ports to point to $0000
	STZ.b VMADDR ; Video RAM
	STZ.b WMADDL ; Work RAM

	; This label is where we'll pull the value $00 from in the upcoming DMAs
	; Remember that the SNES is little endian, so the machine code looks like this:
	; A9 00 43
ZeroLand:
	LDA.w #$4300

	; Now we want direct page to point to $4300, where DMA ports are located
	; The reason we didn't use PEA this time is because PEA always does 16-bits
	; But we wanted to remain in 8-bit accumulator for the time
	; This time around, we're already using a 16-bit accumulator
	; So it's more efficient and sane to use TCD
	; TCD is also an example of a mnemonic that refers to the accumulator
	; as C, rather than A. Other mnemonics that do so are: TDC, TCS, TSC
	; This is because unlike TYA and TXA, the bit mode of the target is not
	; relevant. These instructions will always transfer 16-bits, regardless.
	TCD

	; Immediate addressing can be used with labels too
	; But, in this case, we need to add 1
	; And ya, you can use math in operands as well.
	; We need +1 because ZeroLand is actually pointing to the opcode,
	; which is A9. We need the byte that follows, 00.
	; We'll use this address for DMA source on channels 0 and 1.
	LDA.w #ZeroLand+1

	; When working with DMA, your channel is the second lowest nibble
	; or the x in $43x2, to use source address as an example.
	; You'll notice that we're using .b to use direct page addressing
	; But I typed out the full address.
	; While STA.b $02 would work exactly the same, it would be less clear.
	; By writing the full 16-bits, I'm making it explicitly clear that
	; the intended write is to this address.
	; This redundant byte is ignored when assembling.
	STA.b $4302
	STA.b $4312

	; X still holds $80 from way back when.
	; We'll use it to set the source bank of our DMA data.
	STX.b $4304
	STX.b $4314

	; Here, we're setting 2 DMA properties at the same time.
	; The high byte will be written to $4311 for the PPU port.
	; In this case, it's $80 which corresponds to $2180, the WRAM data port.
	; The low byte ($08) will be written to $4310.
	; This tells it to use mode 0 (write once) as a fixed transfer.
	; The fixed transfer means we never increment the source address as we write.
	LDA.w #$8008
	STA.b $4310

	; This is the same idea for VRAM, except we're writing a different port: $2118.
	; We're also using a different mode. We want a fixed mode 1 transfer, which writes
	; 2 registers, once each. The 2 registers written will be $2118 then $2119 for each
	; piece of transfer. Even though we are writing 2 ports, we only use 1 byte because
	; this is a fixed transfer. There is no straight forward way to write a fixed transfer
	; for an arbitrary 16-bit value.
	; But we want every VRAM address to have $00, so that's fine for us.
	LDA.w #$1809
	STA.b $4300

	; We load X with $03 to set off our DMAs.
	; DMA 0 (flagged with bit 0) will run first.
	; channel:  76543210
	;     $03: %00000011
	; When DMA 0 finishes, DMA 1 will run.
	; We never set the size registers because they are currently $0000.
	; This actually corresponds to writing 65536 bytes, which is what we want.
	LDX.b #$03
	STX.w $420B

	; Now we want to clear bank 7F.
	; In addition to resetting the WRAM address to $0000
	; we set the WRAM bank to $03.
	; But not really.
	; Only the lowest bit of WMADDH matters, so we're really setting it to $01,
	; which points WMDATA to bank 7F.
	STX.w WMADDH
	STZ.w WMADDR

	; And here's another decrement, this time for X.
	; We go from $03 to $02. That's also why WRAM was done on DMA channel 1
	; So that we could do this clever little save when activating the channel.
	; Now, only channel 1 will run its DMA, because that's the only bit set:
	; channel:  76543210
	;     $02: %00000010
	DEX
	STX.w $420B

	; Now that we've cleared memory, let's load our graphics in.
	; I've put all graphics data at the bottom of this file.
	; You can look at it now or later.
	LDA.w #GFX
	STA.b $4302

	; We're writing to $2118 for VRAM on this channel again
	; But this time, we don't want a fixed transfer
	; so we need to disable bit 3, setting $4300 to $01
	LDA.w #$1801
	STA.b $4300

	; This instruction is a REGISTER TRANSFER instruction.
	; TAX for Transfer Accumulator to X register.
	; This will take the contents of one register and copy them to another.
	; In addition to TAX, we also have:
	;    TAY - Transfer Accumulator to Y register
	;    TXA - Transfer X register to Accumulator
	;    TYA - Transfer Y register to Accumulator
	;    TXY - Transfer X register to Y register
	;    TYX - Transfer Y register to X register
	;    TCD - Transfer Accumulator to Direct page
	;    TDC - Transfer Direct page to Accumulator
	;    TCS - Transfer Accumulator to Stack pointer
	;    TSC - Transfer Stack pointer to Accumulator
	;    TXS - Transfer X register to Stack pointer
	;    TSX - Transfer Stack pointer to X register
	;
	; This usage is another example of small and cute optimization
	; I will want to activate the channel by writing $01 to DMA enable
	; Instead of loading X explicitly, I'm giving the value of A to X now
	; As A happens to hold $01
	; The reason X gets $01 and not $1801 is because X is currently 8-bit
	; When a register transfer operation is performed, the size of the exchange
	; is determined by the target.
	TAX

	; We'll write 2kB, which holds the graphics for opcodes and such.
	LDA.w #$0800
	STA.b $4305

	; And we want to write that to $2000 in VRAM.
	; The register VMADDR is actually indexing words.
	; So to write to any address in VRAM, you will need to divide it by 2.
	LDA.w #$1000
	STA.w VMADDR

	; And now we want to enable the channel
	STX.w $420B

	; It just so happens that we want to write $1000 bytes next.
	; Since A currently has that value from setting the VRAM address,
	; we can reuse it here.
	; Being this optimal all the time isn't necessary, especially starting out,
	; but being able to manage values in your head and keep track of what you've
	; done throughout the workflow of a program is important.
	; It separates good code from bad code.
	STA.b $4305

	; We now want to write to $3000 in VRAM.
	; We've split it up this way so that writing HEX value tiles is simpler.
	; We'll see why it's simpler when the draw routines are covered later.
	LDA.w #$1800
	STA.w VMADDR

	; We don't need to define a new source address because all of our
	; graphics were stored together.
	; The previous DMA stopped where this one will start.
	; So we can just activate the channel
	STX.w $420B

	; Again, we're making use of the different register sizes to give Y $00.
	; We're using Y this time because we will reuse X to enable the DMA.
	; We need to set the CGRAM address with an 8 bit write.
	TAY
	STY.w CGADD

	; We'll be writing to $2122.
	; And this is an example of a write twice register
	; So we need to use mode 2, which will write the same register with 2 values.
	; Technically, we could have used mode 0, as we are only writing 1 register,
	; but using mode 2 for single write-twice registers is good practice.
	; It makes it more clear what the intended purpose is, and when using HDMA,
	; it will be required anyways.
	LDA.w #$2202
	STA.b $4300

	; We only need 64 bytes for the palettes.
	; And like with our graphics, our last DMA stopped where this one starts,
	; so we can skip setting it and just enable the DMA.
	LDA.w #$0040
	STA.b $4305
	STX.w $420B

	; I would like to point the stack to $1FFF
	; But I have another trick:
	; I also want direct page to point to $0000.
	; By pointing the stack to $1FFD, the PLD that follows will bring it to $1FFF.
	; Because memory was just cleaned, we know that a $0000 will be pulled.
	LDA.w #$1FFD
	TCS
	PLD

;===============================================================================

	; And that's pretty much it for initialization.
	; It's a lot to take in at once, but it's necessary to understand it.
	; Once you get a grasp on initialization, it becomes much easier to do.
Disassemble_Start:
	; As mentioned in defines.asm, we want a secondary stack but in bank 7F
	; So here's where we set that pointer's most significant byte.
	LDX.b #$7F
	STX.b DP.REG_SR_BANK

	; Here I've called 2 subroutines.
	; Each one will start in a different place
	; I've done this so that the ROM can also disassemble its own reset vector.
	; There's no good way to simulate an actual interrupt here,
	; and we probably wouldn't want to anyways.
	JSR RunVector_NMI
	JMP RunVector_RESET

;===============================================================================

	; This is our NMI routine.
	; It will trigger at the bottom of the screen every frame.
	; Assuming it's enabled.
Vector_NMI:
	; Just like with the reset routine, we want to move into fast rom.
	; "Reading" doesn't just apply to data. Opcodes have to be read to be
	; executed. And if we're in bank80, they will be read faster.
	JML .fast

.fast
	; It's good practice to save everything when handling interrupts.
	; We don't need to worry about P because that's already on the stack
	; as part of how the hardware handles the interrupt.
	; We just want to push every register in full.
	; We reset M and X to 16-bit so that their full values will be pushed.
	REP #$30
	PHA
	PHY
	PHX
	PHB
	PHD

	; We'll want to operate with direct page at $0000
	LDA.w #$0000
	TCD

	; We want some 8-bit functionality
	; So we'll set the M and X flags now.
	; I won't be noting bit mode changes anymore as it would get tedious.
	; But this is a special occasion: our first SEP!
	SEP #$30

	; This register needs to be read every time NMI occurs
	; to acknowledge the interrupt.
	; It doesn't matter how it gets read, just that it does.
	; The AND will perform this just fine.
	; We'll use long addressing so that our data bank doesn't matter.
	; AND performs a bitwise AND with the accumulator and memory.
	; The result is then given to the accumulator and processor flags are set.
	; Bitwise operations can only be performed with the accumulator.
	; The following bitwise operations exist:
	;   AND - AND (&)
	;   ORA - OR (|), the extra A is for Accumulator
	;   EOR - Exclusive OR (^), often written XOR in modern discussion
	AND.l RDNMI

	; Now we want to check our drawing flag.
	; The only thing we plan to do during NMI is draw.
	; So if we're not drawing, we can just leave.
	; BIT works essentially the same as AND, but with a couple differences:
	; Only the processor status register is changed. The result is not placed in A.
	; Except in immediate addressing, bit 6 (or bit 14 when M=0)
	; of the target value is put in V. Even if the result would be a 0.
	; The same is true for bit 7 (or bit 15 when M=0) and the negative flag.
	; For example:
	;    A=29  addr=C3
	;    AND.w addr      00101001  |  29
	;                  & 11000011  |  C3
	;                  = 00000001  |  01
	;    A would still contain $29 after this, as the result is discarded
	;    The N flag would be set, as the operand had bit 7 set
	;    The V flag would be set, as the operand had bit 6 set
	;    The Z flag would be reset, as the result ($01) was not zero
	;
	; Thus BIT can be used to easily test 2 flags, in the highest order bits.
	; In this case, we only need bit 7.
	; If bit 7 is clear, the result will be flagged as positive,
	; and we know we shouldn't do any drawing.
	BIT.b DP.DO_DRAW
	BPL .skip

	; If we're actually drawing, we should move our data bank to $80
	; it can be anywhere really for what we're about to do,
	; but it might as well match our program bank
	; Especially since we will want to reuse the value
	LDA.b #$80
	PHA
	PLB

	; It's a good habit to disable the screen explicitly during NMI.
	; Even though we're already in vertical blank, fblank allows graphics,
	; to be worked with if NMI somehow extends past the vblank period.
	STA.w INIDISP

	; We're only drawing once, so let's acknowledge that flag and clear it.
	STZ.b DP.DO_DRAW

	; Our draw routine should be able to handle arbitrary VRAM addresses.
	; We won't worry about verifying anything about where to write.
	; Let's just go with the assumption that whatever sets the address
	; has set it correctly.
	; For a small and self contained program like this, that assumption is fine.
	; But you will need to be able to manage assumptions like this on your own
	; when dealing with anything more complex.
	REP #$20
	LDA.b DP.VRAM_LOC
	STA.w VMADDR

	; Ee want to copy the buffer 2 bytes at a time into VRAM.
	; While this could be done with DMA, setting up small transfers can be tedious.
	; We aren't desperate for time efficiency here, so we'll do it manually.
	LDX.b #00

	; This label here is a RELATIVE LABEL.
	; anything following this "--" that references a "--" will use this one.
	; until a new "--" label is defined.
	; For this loop, the BCC -- will branch back here when the condition is met
	; Relative labels can also be made in the positive direction using "+"
	; Any number of "+" or "-" can be strung together to form a relative label.
	;
	; Inside of this, our first loop, we have our first instance of INDEXED ADDRESSING.
	; The ,X means that the address is whatever the operand is plus the value of X
	; You can think of it as LDA addr+X, but keep in mind that mnemonic won't work here
	; Example:
	;   LDA.w $1200,X
	; That will load the value from the address $1200 if X=00
	; But if X=34, it will load the value in address $1234
--	LDA.b DP.DRAW_BUFFER,X
	STA.w VMDATA

	; Since we're working with 16-bit data, we need to increment X twice each iteration
	INX
	INX

	; We only want to write 32 characters at a time, which is the same as 64 bytes.
	; Since we started at X=00, once it reaches 64, we've written 64 bytes.
	; BNE could be used here, but it's always good practice to use BCC in cases like this
	; BCC will essentially behave as a "less than".
	; Both branch instructions cost the same number of cycles, but BCC gives you a
	; failsafe in certain situations.
	; In some cases, BNE is better.
	; For our loop, either is perfectly fine, as we define the starting condition,
	; and that starting condition will never be different.
	CPX.b #64
	BCC --

	; We'll use X to set the screen brightness to maximum and disable force blank,
	; Because X is already in 8-bit mode.
	LDX.b #$0F
	STX.w INIDISP

	; Here's where we would have ended up if the draw flag was unset.
	; This is an example of a SUBLABEL.
	; sublabels allow you to create a nested structure to your code,
	; But they also allow you to reuse simple label names.
	; Asar will see this label as "Vector_NMI_fast".
	; We can also access it as such.
	; Unfortunately, we cannot access it as "Vector_NMI.fast".
	; We can reuse ".skip" in the scope of other labels, but
	; we cannot reuse ".skip" in the scope of "Vector_NMI".
.skip
	; When preserving anything in stack,
	; remember to pull in the opposite order you pushed.
	REP #$30
	PLD
	PLB
	PLX
	PLY
	PLA

	; Every interrupt handler should end with RTI
	; We won't be using any other interrupt, so we can point them all here
	; and have everything share the RTI for the NMI vector
	; Also, since we just covered sublabels, these labels are going to be scopeless
	; prefixing a label with # will prevent it from creating a new scope
	; so while these are top level labels, we couldn't put a ".skip" after them
	; As we would still be within "Vector_NMI"
#Vector_COP:
#Vector_IRQ:
#Vector_Unused:
#Vector_Abort:
#Vector_BRK:
	RTI

;===============================================================================

	; This subroutine will set up our interrupts and "emulate" handling them.
RunVector:
.RESET
	REP #$20
	LDA.w #EMU_VECTOR_RST

	; We want to read from bank00, so we need to set DP.ROM_READ+2
	; but we're in 16 bit A.
	; To set the bank, we can clear the high byte (DP.ROM_READ+1).
	; The high byte will bet set to 00 as well as the bank, but we will be writing
	; the high byte to the proper value afterwards, when writing the low byte.
	STZ.b DP.ROM_READ+1
	STA.b DP.ROM_READ+0

	; This is our first example if INDIRECT ADDRESSING.
	; There are 2 types of indirect addressing modes:
	;    (absolute) reading locally
	;    [long] reading anywhere
	;
	; For our LDA.b [DP.ROM_READ], an indirect long
	; an address will be formed from the 3 bytes located at:
	;        BANK            HIGH            LOW
	;   DP.ROM_READ+2   DP.ROM_READ+1   DP.ROM_READ+0
	;
	; Data will be then be read as if that address were specified as the location to read.
	;
	; The address ultimately read from is called the EFFECTIVE ADDRESS.
	; For some addressing modes, this is the same as the operand.
	; For example:
	;    LDA.w $1234
	; The operand here is $1234, but it is also the effective address
	;
	; But here:
	;    LDA.w $1234,X
	; The operand is $1234, but that's not necessarily the same as the effective address
	; If X=5, then the effective address would be $1234+5, or $1239
	;
	; For ABSOLUTE INDIRECT ADDRESSING, only the operand and the operand+1
	; are used to form the address. The bank will be the same as the data bank.
	;
	; In addition to indirect address, there is also INDIRECT INDEXED.
	; This comes in 2 flavors:
	;    pre-indexed: (addr,X) - always done with X
	;   post-indexed: (addr),Y - always done with Y
	;
	; PRE-INDEXED will add the value of X to the operand before reading for an address.
	; Pre-indexing with absolute is only available with the JMP and JSR operations,
	; and these are the only absolute instructions that use program bank instead of data bank.
	;
	; Consider this:
	;    LDA.b ($80,X)
	;    If X=$40, then the CPU will look at the memory in $C0 and $C1 to form an address
	;    Let's say $C0=34 and $C1=12, that means they point to $1234
	;    The memory at $1234 will be loaded into the accumulator.
	;    It doesn't matter if A is 8- or 16-bit
	;    The parentheses () indicated an absolute address would be looked at.
	;
	; POST-INDEXED will read the address from memory first and then add in Y.
	; Consider this:
	;    LDA.b [$80],Y
	;    Let's say $80=56, $81=90, $82=20
	;    The CPU will begin by forming the address $209056
	;    Then it will add in Y
	;    If Y=58, then the address we end up reading from is $20:90AE
	;
	; Back to our project: we're not using any sort of indexing here
	; We just want to read an exact location we've already defined
	; Since both the vector and routine for interrupts must be in bank00,
	; we don't need to bother with writing the bank again.
	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ

	; On a proper reset, all of these registers will be 00.
	STZ.b DP.REG_A
	STZ.b DP.REG_X
	STZ.b DP.REG_Y
	STZ.b DP.REG_D
	STZ.b DP.REG_DB

	; The stack will always be this on a proper reset.
	LDA.w #$01FF
	STA.b DP.REG_SR

	; Remember that the value of A is not disturbed when changing bit modes.
	; So A=FF
	; We'll reuse that value to set the emulation flag
	; even though we only care about bit7 for our processor flag addresses.
	SEP #$30
	STA.b DP.REG_P.E

	; M and X are always set when the system resets.
	; Unfortunately, there's no worthwhile way to reuse the SEP we just did.
	LDA.b #$30
	STA.b DP.REG_P

	; When we eventually get to the reset vector, we'll want to continue forever.
	; This infinite loop will cover that.
--	JSR Disassemble_Next
	BRA --

	; This segment of the subroutine is where we've coded our NMI handler
	; "emulation". It's similar to the above, but it won't run forever.
	; We'll have it exit when an RTI instruction is disassembled.
.NMI
	; When NMI occurs, the value of any register should be considered
	; non-deterministic.
	; We will just ignore them.
	SEP #$30

	; This masks out bit3 of the emulated processor, the D flag
	; which is automatically disabled when NMI triggers.
	; We also need to enable the I flag.
	LDA.b DP.REG_P
	AND.b #$F7
	ORA.b #$04

	; We'll save our REG_P in X
	TAX

	; Here we're loading the location of NMI then branching ahead
	; to a routine that handles arbitrary interrupts.
	; We've only got one hardware interrupt planned for now,
	; but see if you can modify this code to handle an IRQ routine.
	;
	; You'll need to:
	;   Write a non-empty IRQ routine
	;   Write a subroutine to prepare the program for IRQ disassembly
	;   Call that subroutine inside the main branch of code
	REP #$20
	LDA.w #NAT_VECTOR_NMI
	BRA DisassembleInterrupt

	; This code takes care of BRK and COP, the software interrupts.
	; We won't be using these opcodes,
	; but what good is a disassembler that only disassembles code it has?
	; It should be able to disassemble any code put into it!
PrepSoftwareInterrupt:
	REP #$20

	; BRK and COP are odd
	; They are technically 1 byte opcodes
	; but the processor treats them as 2 bytes when executing the interrupt.
	; We need to compensate for that and adjust for the functionality
	; shared between our RTI and RTL stack pushes.
	DEC.b DP.ROM_READ
	DEC.b DP.ROM_READ

	; This subroutine will handle all stack operations as we disassemble.
	; It will be covered shortly.
	JSR PushToStack_INTERRUPT

	; In addition to disabling the D flag, software interrupts also
	; automatically set the I flag.
	SEP #$30
	LDA.b DP.REG_P
	AND.b #$F7
	ORA.b #$04
	STA.b DP.REG_P

	; This subroutine will handle REG_P flag changes.
	; More on it later.
	JSR Sync_REG_P

	; Which set of vectors an interrupt comes from is determined by
	; whether or not we are in emulation mode.
	; This code will test the emulation flag and return with X as an
	; offset into the interrupt vector table.
GetVectorSet:
	SEP #$30

	; Remember: only bit 7 matters in these flags we created.
	LDA.b DP.REG_P.E
	AND.b #$80

	; LSR is basically a divide by 2.
	; We want to divide either
	;   128 by 8 to get 16
	;       or
	;     0 by 8 to get 0
	; and that will give us the offset from the native vectors
	; of where our vector lies.
	LSR
	LSR
	LSR
	TAX
	REP #$20
	RTS

;===============================================================================

	; Here's where we will disassemble every interrupt except the reset.
	; While there is no such thing as a function parameter, per se,
	; we can still use registers or memory as parameters in assembly
	; by setting them up before routines and having the routines expect
	; certain memory or registers to be set up in such a way.
	; For this subroutine, we expect the following parameters:
	;    A - 16-bit address of vector location
	;    X - 8-bit processor status value
DisassembleInterrupt:
	REP #$20
	STZ.b DP.ROM_READ+1
	STA.b DP.ROM_READ+0

	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ

	STX.b DP.REG_P

	LDA.w #$01FF
	STA.b DP.REG_SR

	; this routine begins similarly to the reset disassembler.
	; The main difference is this one won't run forever.
	; we're jumping ahead to the start label because we don't want to
	; disassemble our terminating instruction, RTI, if it happens to come first.
	BRA .start

	; By putting this label here, we can avoid some extra logic.
	; If we put it later, we would need an additional BRA for the loop.
	; While that would be the same amount of code, it's slightly more time efficient
	; to loop with BNE or BEQ, so that a failed condition exits the loop.
	; It may be a small save, but being able to come up with such a program flow
	; is essential to becoming a competent assembly programmer.
.next
	; Another subroutine we'll cover in a moment.
	; This will both disassemble code and draw it.
	JSR Disassemble_Next

.start
	SEP #$30
	LDA.b [DP.ROM_READ]

	; $40 is the opcode for an RTI.
	; If we read that, our next instruction to disassemble is an RTI.
	; All interrupts besides the reset interrupt need to end eventually,
	; and they all should end with an RTI.
	CMP.b #$40
	BNE .next

	; A good common efficiency practice is noticing that
	; if you have something like this:
	;    JSR subroutine
	;    RTS
	; the RTS can be replaced by simply jumping to the subroutine.
	; The RTS that normally exits the subroutine will double as a means
	; of exiting the routine that called it.
	; This can also be done with JSL/RTL pairs using JML.
	; But you can't mix and match JSL/RTS or JSR/RTL.
	;
	; This subroutine will only draw code, not disassemble it.
	JMP OnlyDrawOpcode

;===============================================================================

	; Here's the main juice of our program
	; This will draw an opcode and then "emulate" the execution of it.
Disassemble_Next:
	; We'll begin by making sure the individual flags in REG_P.% match
	; the main REG_P variable.
	JSR Sync_REG_P
	JSR DrawOpCode

	; We need to be 16-bit for this because there are 256 opcodes
	; And we need to have the opcode * 2 to locate the routine.
	; The maximum value we can expect is thus 512, which requires 9 bits.
	REP #$30
	LDA.b [DP.ROM_READ]

	; We can't have the operand or next instruction be part of our ID
	; so we need to mask out the top byte
	AND.w #$00FF

	; ASL for Arithmetic Shift Left is a bitwise shift operation.
	; Like DEC and INC, unqualified it operates on the accumulator.
	; The other shift operations are:
	;    LSR - Logical Shift Right
	;    ROL - ROll Left
	;    ROR - ROll Right
	; Each of these is also implied accumulator when unqualified, but
	; able to take on an operand address.
	;
	; ASL is essentially multiply by 2.
	ASL
	TAX

	; This is another example of skipping a JSR.
	; When the opcode's routine finishes and does its RTS,
	; it will exit back to wherever Disassemble_Next was called from.
	; The opcode emulation routines will be covered in detail later.
	JMP.w (OpCodeRun,X)

;===============================================================================
	; This is what we'll use to emulate stack operations.
	; A lot is being done here to save space.
	; It's good to understand what can share code and when.
	; Many of the subroutines here will call others in the PushToStack
	; family to make use of their functionality.
PushToStack:
	; JSL is what will cause this stack push to occur.
.JSL
	; We start by pushing the program bank, which is just the bank
	; byte of our current program counter in DP.ROM_READ
	JSR .PROGRAM_BANK

	; Then we push the program counter
	; We will need to point this to the last byte of the operand
	; because RTL and RTS increment the address they pull from stack.
	; For this, we want to do +3
	; We'll take care of that in part by doing +1 here,.
	; Then we'll branch ahead to partway through the next bit of code
	; which operates similarly but increments by +2.
	REP #$20
	LDA.b DP.ROM_READ
	INC

	; And this ++ label operates similarly to the -- described before
	; except + means it will look ahead, rather than behind.
	BRA ++

	; Like .JSL, we need to point the address ahead by 2.
.JSR
	REP #$20
	LDA.b DP.ROM_READ
++	INC
	INC

	; We want to push 2 bytes.
	; We'll see how that's done, when we get there.
	BRA .push_2

	; This stack push will occur after any interrupt, except for reset.
	; First the 24-address is saved. We do this by using the functionality of .JSL.
	; Then the status register.
	; And we're doing that by BLEEDING into the .REG_P to push the status register.
	; Often times, you will have subroutines shared by multiple other routines,
	; but one routine may use that subroutine fairly often.
	; If the last thing needed is calling that subroutine, it may make more sense
	; to remove the subroutine call, and put the routine's code before the subroutine.
	; Once the routine finishes the main segment of its code, it will just continue,
	; or "bleed" into the desired subroutine.
.INTERRUPT
	JSR .JSL

	; The following 4 register pushes are very simple.
	; Based on what was described above, you should be able to understand them.
.REG_P
	SEP #$20
	LDA.b DP.REG_P
	BRA .push_1

	; Called by PHD
.REG_D
	REP #$20
	LDA.b DP.REG_D
	BRA .push_2

	; Called by PHK
.PROGRAM_BANK
	SEP #$20
	LDA.b DP.ROM_READ.b
	BRA .push_1

	; Called by PHB
.DATA_BANK
	SEP #$20
	LDA.b DP.REG_DB
	BRA .push_1

	; These registers all require some extra trickery to account for bit mode.
	; Here we'll be loading the value first, then using a shared bit of code
	; that will determine if we push 1 or 2 bytes.
.REG_X
	REP #$20
	LDA.b DP.REG_X
	BRA .test_i

.REG_Y
	REP #$20
	LDA.b DP.REG_Y
	BRA .test_i

.REG_A
	REP #$20
	LDA.b DP.REG_A

	; This .test_i segment will test bit 7 of the appropriate processor flag
	; to determine how many bytes to push.
	; How? by setting M only for REG_A, we will test bit 7 of DP.REG_P.M
	; But by skipping the M=8 for .REG_X and .REG_Y
	; we will test bit 15 of DP.REG_P.M
	; which is the same as bit 7 of DP.REG_P.X.
	SEP #$20

.test_i
	BIT.b DP.REG_P.M

	; We want to be in M=8bit either way after this
	SEP #$20
	; The N flag holds the status of the flag we were testing.
	; But SEP and REP only modify the bits specified in the operand.
	; So N will be what it was before the SEP #$20.
	BMI .push_1

	; for 16-bit pushes, we want to push the high byte before the low byte.
.push_2
	; This SEP may seem redundant, but remember that there are other
	; stack operations that will need to enter this segment of code.
	; Rather than have them all do SEP #$20 before entering,
	; it makes more sense to do it inside this segment of code,
	; because this is common to the routine itself.
	SEP #$20

	; XBA swaps the high byte and low byte of A.
	; The mnemonic means eXchange B and A.
	; You may see the accumulator referred to as A,
	; but it may also be referred to as C for the full 16 bits,
	; B for the high byte, and A for the low byte.
	; Regardless of bitmode, the high byte of the accumulator (B)
	; can be accessed with this instruction.
	XBA

	; This will write to wherever our emulated stack pointer is pointing,
	; but in bank7F. Keep in mind, we're just "emulating" this.
	; The stack on the actual processor is always and only in bank00.
	STA.b [DP.REG_SR]

	; We want to decrement the stack pointer in 16-bit mode.
	; There are ways to handle 16-bit operations while in 8-bit mode,
	; but it is often simpler to swap for a moment to handle the task.
	REP #$20
	DEC.b DP.REG_SR

	; We need to put our low byte back in the lower byte of the accumulator.
	; We also forgo another SEP #$20, as we will be bleeding into one.
	XBA

.push_1
	SEP #$20
	STA.b [DP.REG_SR]

	REP #$20
	DEC.b DP.REG_SR

	RTS

;===============================================================================

	; This is the opposite of a stack push, obviously.
	; Every one of these subroutines will begin with a "pull",
	; and this pull will be saved in A for later manipulation.
PullFromStack:
	; What we'll be doing with .pull_1 and .pull_2 is
	; exiting with different bit modes for the accumulator.
	; The assumption is that if we asked for 2 bytes from the stack,
	; we're probably about to work with 2 bytes.
	; Ditto for 1 byte.
.pull_1
	; We need to increment the stack register before reading,
	; because it points to the first empty slot.
	REP #$20
	INC.b DP.REG_SR

	SEP #$20
	LDA.b [DP.REG_SR]

	RTS

.pull_2
	; We only increment once because we want to load the low byte,
	; which is situated on top of the stack, followed by the high byte
	; which is situated just after.
	REP #$20
	INC.b DP.REG_SR
	LDA.b [DP.REG_SR]

	; And since we pulled 2 bytes, we need an extra increment of the stack.
	INC.b DP.REG_SR
	RTS

	; As described, we know we'll be in 8-bit accumulator because that's
	; how we coded the .pull_1 subroutine to work.
.REG_P
	JSR .pull_1
	STA.b DP.REG_P
	RTS

	; The first thing RTI does is pull the processor from stack.
	; Then it pulls a 24-bit address and saves it to the program counter.
	; We handle that part by bleeding into the RTL subroutine.
.RTI
	JSR .REG_P

	; The program bank is pulled last, so we will need to pull the address first.
	; and we have that code written in the .RTS segment
.RTL
	JSR .RTS
	JSR .pull_1
	STA.b DP.ROM_READ.b
	RTS

	; RTS will pull 2 bytes.
	; But the address it pulls is 1 byte before the location it will lead to
	; We need to account for that by incrementing the address before saving
	; it to our program counter at DP.ROM_READ.
.RTS
	JSR .pull_2
	INC
	STA.b DP.ROM_READ
	RTS

	; These stack operations also set processor flags.
	; To set these flags, we'll use a routine covered later.
.DATA_BANK
	JSR .pull_1
	STA.b DP.REG_DB
	BRA SetFlags_from_PreloadedValue

.REG_D
	JSR .pull_2
	STA.b DP.REG_D
	BRA SetFlags_from_PreloadedValue

	; For REG_A, REG_X, and REG_Y
	; we'll use a couple parameters to share functionality in our testing:
	; We'll load X with the offset in our register data.
	;     The contents of REG_A are at DP.REG_A+0
	;     The contents of REG_X are at DP.REG_A+2
	;     The contents of REG_Y are at DP.REG_A+4
	; And we'll read the relevant flag to save to run the actual test.
.REG_A
	SEP #$30
	LDX.b #0
	LDA.b DP.REG_P.M
	BRA .testAXY

.REG_X
	SEP #$30
	LDX.b #2
	LDA.b DP.REG_P.X
	BRA .testAXY

.REG_Y
	SEP #$30
	LDX.b #4
	LDA.b DP.REG_P.X

	; This is where we're testing the N flag for the bit mode we loaded,
	; and where our write will happen to save the value we loaded to
	; the correct register address based on X.
.testAXY
	; Here, we're using SUBSUBLABELS.
	; These only exist within the scope of the sublabel.
	; So its full name is PullFromStack_testAXY_do2
	; and it can be accessed as such.
	BPL ..do2

	JSR .pull_1
	BRA ..save

..do2
	JSR .pull_2

..save
	STA.b DP.REG_A, X
	BRA SetFlags_from_PreloadedValue

;===============================================================================

	; The purpose of this routine is to set flags in the processor as if we had
	; just performed a load, pull, or transfer operation.
SetFlags:
	; X has a unique circumstance with the TSX command.
	; For TSC, all 16 bits matter for the processor, but for TSX,
	; we need to take the bitmode of REG_P.X into account
.from_X
	; We'll begin by matching our processor to REG_P
	SEP #$20
	LDA.b DP.REG_P
	PHA
	PLP

	; Then we'll use that bitmode to load the proper size of REG_X
	; Once we've done that, we can handle it like every other flag setting.
	LDX.b DP.REG_X

	; All other entry points we need for this routine will already have
	; the N and Z flags set from a previous operation.
	; So we'll use those flags in our actual processor as is to set
	; the N and Z flags in the "emulated" processor status register.
.from_PreloadedValue
	; We'll start by saving the P flag twice.
	; We do this so that we can remember the N and Z flags later.
	; We enter 8-bit accumulator now because we'll need to stay there
	; for further tests. If we happen to enter this with 16-bit A,
	; we don't want the upcoming PLP for the N and Z tests to bring us
	; back to 8-bit accumulator.
	SEP #$20
	PHP
	PHP

	; Now we'll collect the emulated P and mask out the N and Z flags.
	LDA.b DP.REG_P
	AND.b #$7D

	; We'll pull P once to get the N flag.
	PLP

	; If the N flag is reset, we'll have a positive number,
	; and there's nothing further we need to do.
	BPL ++

	; Otherwise, add in the bit for N.
	ORA.b #$80

	; Now do the same for the Z flag.
	; It's a bit counterintuitive at first glance,
	; but in this case, if Z=1 then the value is 0.
++	PLP
	BNE ++

	; Add in the bit for Z
	ORA.b #$02

	; And now we should save our recalculated REG_P.
++	STA.b DP.REG_P
	RTS

;===============================================================================

	; This subroutine will be used to update the individual flags of REG_P
	; to match the full REG_P address we have saved.
	; The bits will be handled one at a time and placed in bit 7 of the
	; corresponding flag address.
Sync_REG_P:
	SEP #$30
	LDX.b #8
	LDA.b DP.REG_P

	; This loop will shift the lowest bit out of A, which holds REG_P,
	; one at a time and put those bits in the corresponding flag's address.
	; This is one of the reasons we only care about bit7 in these addresses.
	; It simplifies this routine, because we only need to ROR the bit (roll right).
	; The other reason is that BIT and LDA make testing bit 7 incredibly easy,
	; since it will be placed into the N flag of the processor status register.
.next
	; This LSR will shift the next flag into the carry.
	; The ROR will shift the carry to bit 7 of the address.
	; We're using REG_P as the base of our indexed write because we loaded X with 8,
	; and we're also using it as a counter.
	; It would also be valid to have done LDX.b #7 and ROR.b DP.REG_P+1,X
	; but that would be slightly less clear what we're doing.
	; Instead, we can give X the actual value of our counter for clarity.
	; DP.REG_P will never be manipulated erroneously, because
	; our looping condition is BNE.
	; It will test for X being nonzero.
	; When X reaches 00, it will stop.
	LSR
	ROR.b DP.REG_P,X
	DEX
	BNE .next

	; When index registers are in 8-bit mode, they always have a high byte of 00.
	; We'll be taking aggressive caution to make sure this is handled properly.
	BIT.b DP.REG_P.X
	BPL .index_fine

	STZ.b DP.REG_X+1
	STZ.b DP.REG_Y+1

.index_fine
	RTS

;===============================================================================

	; We only ever enter this from one place,
	; and it's a place that avoids disassembly.
	; So just to be safe, let's make sure our flags are set properly.
OnlyDrawOpcode:
	JSR Sync_REG_P

	; This is our main draw routine.
	; We want to draw each line of code to screen so that it looks somewhat like:
	;    808123: JSL $808456  A:0000 X:0000 Y:0000 P:00 S:01FF D:0000 B:00
	;
	; We don't have that much room, so we'll need to condense our characters.
	; We'll have each hexadecimal value represented by a single character,
	; consisting of 2 digits.
	; Our mnemonics will also be created from 2 letter tiles.
DrawOpCode:
	; The first thing we'll do is call the bulk of the draw code
	; This code won't actually draw anything.
	; What it will do is set up a buffer and write address
	; which will be used later, during NMI, to draw to the screen.
	JSR .dodraw

	; Once the buffer is set up, we'll flag the draw functionality of NMI
	; and enable NMI so it can actually trigger.
	SEP #$20
	LDA.b #$80
	STA.b DP.DO_DRAW
	STA.w NMITIMEN

	; We can't actually control when NMI occurs, but we can wait for it.
	; The simplest wai to do so is with the WAI opcode.
	; This is good for us, as only NMI can occur, but WAI isn't specifically
	; just for NMI.
	; It won't be appropriate in cases where IRQ is possible.
	WAI

	; Our screen draw will occur only during the first NMI
	; These next 3 are just to slow the program down a little
	; So that we can read it as it draws more easily
	; If you were to remove these 3 WAI
	; then one line would be disassembled every frame
	; If you were to add some WAI, then there would be that many more frames
	; between each draw.
	WAI
	WAI
	WAI

	; Now that we're done with drawing, let's disable NMI again.
	; This will give us the maximum amount of CPU time to work with.
	; In reality, we don't need to do this here, as our program is so simple.
	; But it's good to know of this technique in general.
	STZ.w NMITIMEN

	RTS

.dodraw
	; We'll begin by grabbing the opcode and multiplying it by 2.
	; This will be used to index some data tables later.
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	STA.b DP.SCRATCH

	; We want to start on the second row of the tile map each time
	; and we initialied the address to $0000.
	; As each row is 32 tiles and 1 tile is 2 bytes, we +$0040 each time.
	; But remember that $2116 indexes words, so we need to cut that number in half
	; Rather than writing $0020, I've put $0040, the address we want, and >>1
	; which shifts the value right once.
	; This way, it is unambiguous where I want to be writing.
	LDA.b DP.VRAM_LOC

	; I've skipped a CLC for this ADC because I can guarantee the carry is clear.
	; We masked out the high byte of our opcode, so 0 was shifted into the carry
	; when we multiplied it by 2 using ASL.
	ADC.w #$0040>>1

	; If we reach $06C0 in VRAM, we want to reset the screen.
	; Just like with the previous instruction, I've made my intentions here clear
	; by writing the actual VRAM address, and shifting it in the source code.
	CMP.w #$06C0>>1
	BCC .write_addr

	; This is the code we'll use to reset the screen
	; A will hold the vertical scroll of our background.
	; It will start at 1 and increment by 3 every frame until it overflows to 0.
	; When it hits 0, we'll blank the tilemap in VRAM and start anew.
	SEP #$30
	LDA.b #$01

	; RDNMI flags NMI triggers in bit 7.
	; These occur even if NMI is disabled.
	; We'll use this fact to wait for vertical blank to mess with the screen.
	; When we perform this read, the bit will also be cleared.
	; $4212 can also be used to wait for vblank,
	; but it would require us to wait for vblank to end as well as begin.
	; Since this flag clears itself on read, it's the one to use.
--	LDX.w RDNMI
	BPL --

	; We don't need a whole separate NMI subroutine for this simple code.
	; And because what we're doing is so fast and simple, we'll skip force blank
	; PPU registers can be modified during vertical blanking,
	; and this will be done quickly enough we know it will always work.
	INC
	INC
	INC
	STA.w BG1VOFS

	; In all cases we want the top byte to be $00
	STZ.w BG1VOFS

	; Stop when we overflow to 0.
	; We do this after writing background scroll because we will want
	; it to be reset to 0 when the scroll is done anyway.
	BEQ .clear

	; Remember that these are relative label
	; Relative labels are also reusable
	BRA --

.clear
	; For our DMA, we can't be sure we'll complete it quickly enough
	; So we'll need to enable FORCE BLANK for it.
	; Force blank, or FBlank allows us to write to PPU registers.
	; As the name implies, the screen will not be visible while fblank is
	; active.
	; We are using a black background that is currently scrolled to a blank
	; portion of the tilemap, so the FBlank will not be noticeable.
	; In other situations, long fblank periods can be hidden by fading the
	; screen to black by lowering the screen's brightness over the course of
	; several frames, enabling force blank at a brightness of 0, and turning
	; the brightness back up gradually when finished.
	LDX.b #$80
	STX.w INIDISP

	; Here's a DMA similar to the one covered in the reset routine.
	; We'll be clearing VRAM again, but a smaller block of memory this time.
	REP #$20
	LDA.w #ZeroLand+1
	STA.w $4302

	; X already holds $80 from enabling f-blank
	; So all we need to do is set up our fixed DMA to empty the tilemap
	STX.w $4304

	STZ.w VMADDR

	LDA.w #$1809
	STA.w $4300

	; For 8x8 tiles, a 32x32 tilemap quadrant is 2kB, or $0800 bytes.
	LDA.w #$0800
	STA.w $4305

	LDX.b #$01
	STX.w $420B

	; We'll be resetting our VRAM location now.
	; Since the row increment has already happened,
	; we'll actually want to start at this address
	; Rather then the row before it, as we had done for initialization.
	LDA.w #$0040>>1

	; We used 8-bit index registers for our scrolling routine.
	; We'll need to swap them back to 16-bit now.
	REP #$10

	; This is our entry point for when we don't reset the screen.
	; Scroll or no scroll, we will have our desired VRAM address in A.
.write_addr
	STA.b DP.VRAM_LOC

	; We'll prepare the line by completely emptying the draw buffer.
	LDX.w #64

	; we're using -2 so that we can stop at 0
	; Our final write will be when X=2
--	STZ.b DP.DRAW_BUFFER-2,X
	DEX
	DEX
	BNE --

	; We'll be using Y to write the current program counter.
	LDY.w #2

	; What we'll be doing here is writing the 3 bytes of the address
	; but in big endian order.
	; Y will decrement while X increments.
	; This way, the bank byte is written first
	; followed by the high byte of the address
	; and lastly the low byte of the address.
	; We mask out the top byte, as we are reading in 16-bit but only
	; want an 8-bit value.
	; We also add in $35 to the high byte, using ORA.
	; This will give us a tile starting at character $100
	;    priority 1
	;    palette  4
	;         vhpccctt
	;  $35 = %00110101
	; will be part of our tile definition
	;
	;     v - vertical flip
	;     h - horizontal flip
	;     p - priority
	;     c - palette (0-7)
	;     t - top 2 bits of tile ID or NAME
	; This is also why we put our hex graphics a bit later in VRAM.
	; We won't require additional math because whatever hex value we want
	; will match the tile named $1xx.
	; For example: the hex digits AF will be tile $1AF.
	;
	; Notice that we have to use addr,Y for this loop.
	; The dp,Y addressing mode is not available for LDA.
	; How unfortunate.
--	LDA.w DP.ROM_READ,Y
	AND.w #$00FF
	ORA.w #$3500

	; We know that X=00 from the termination of the previous loop
	; The first character is drawn to tile 1 on screen, instead of tile 0
	; We're starting here, because it's good practice
	; to avoid the edge of the screen for SNES games.
	; Many people still use CRTs when playing on console,
	; and those television may cut off screen margins.
	STA.b DP.DRAW_BUFFER.ADDR,X
	INX
	INX

	; We're using BPL here because Y is being used as an offset.
	; We will want to read DP.ROM_READ+0 when Y=00.
	; So we use BPL so that the loop terminates after 00, when Y
	; overflows to a negative $FFFF.
	DEY
	BPL --

	; Next we will draw a colon to the buffer.
	; It will be tile name $01.
	; We will give it maximum priority and palette 0:
	;           vhpccctt tttttttt
	;  $2001 = %00100000 00000001
	LDA.w #$2001
	STA.b DP.DRAW_BUFFER.COLON

	; This is loading the value we saved earlier,
	; The opcode shifted once to create an index.
	LDY.b DP.SCRATCH

	; The OpCode data tables will be explained more later,
	; but the first 2 bytes in it are the tile ids of the instruction.
	; All mnemonics are 3 letters, but we will include a 4th letter
	; (in lowercase) for the addressing mode.
	; Our mnemonics here will be created from 2 tiles of 1 or 2 letters each,
	; and we'll be giving them palette 2 and priority 1.
	;         vhpccctt
	;  $28 = %00101000
	; The constituent graphics characters can be viewed in a debug emulator's
	; VRAM viewer, or the opcodesgfx.png file.
	LDA.w OpCodeDraw+0,Y
	AND.w #$00FF
	ORA.w #$2800
	STA.b DP.DRAW_BUFFER.INSTRUCTION+0

	; There's not much reason to do this with a loop.
	; The ROM address could also have been unfurled, but what's done is done.
	LDA.w OpCodeDraw+1,Y
	AND.w #$00FF
	ORA.w #$2800
	STA.b DP.DRAW_BUFFER.INSTRUCTION+2

	; Now we need to draw the operand of the instruction.
	; This holds a value identifying the instruction's addressing mode
	; We don't need need to deal with that right now, but we do want to
	; get it ready, as we are about to mess with the Y register.
	; Since Y currently holds the instruction's index, we should grab this now.
	; We won't be using X in this next bit, so we'll save it in X
	; And we'll use X later to continue the instruction's drawing
	REP #$30
	LDA.w OpCodeFunc+0,Y
	AND.w #$00FF
	TAX

	; For later, we will be loading tile properties into the high byte of A
	; This will be elaborated on momentarily, but for now, notice we want
	; a high priority, palette 7 tile with an ID of $01xx:
	;         vhpccctt
	;  $3D = %00111101
	LDA.w #$3D00

	; Now it's time for each register.
	; We want to disassemble not just the instructions, but we would also
	; like to include the overall status of the "CPU" we're "emulating".
	; We'll go over just the accumulator, as each will be done the same way

	; We'll be drawing 1 byte at a time.
	; Being in 8-bit accumulator will allow us to manage that more efficiently.
	SEP #$20

	; We'll begin by drawing the "A with a colon" graphic.
	; A_COL for "A with COLon" is a bastardized definition we created
	; as a label in the defines.asm file.
	; We're using the pipe (|) for a logical OR to
	; include the priority bit and palette
	;         vhpccctt
	;  $20 = %00100000
	LDY.w #$2000|A_COL

	; We've also created labels for each register's allotment in the buffer
	; so that we can reference them with less ambiguity.
	STY.b DP.DRAW_BUFFER.A+0

	; To draw the 16-bit value in REG_A, we begin with our low byte
	; loaded in 8-bit accumulator, then we transfer that to Y.
	; Remember: the target register determines the size of the transfer.
	; Even though A is 8 bit, the B register (high byte of A), still holds $3D
	; Y will have a high byte of $3D and a low byte of whatever we loaded
	LDA.b DP.REG_A+0
	TAY
	STY.b DP.DRAW_BUFFER.A+4

	; We'll do this again for the high byte.
	; The high byte is written to an earlier address,
	; because we want to display our values in big endian.
	LDA.b DP.REG_A+1
	TAY
	STY.b DP.DRAW_BUFFER.A+2

	; Draw X: and value of REG_X
	LDY.w #$2000|X_COL
	STY.b DP.DRAW_BUFFER.X+0
	LDA.b DP.REG_X+0
	TAY
	STY.b DP.DRAW_BUFFER.X+4
	LDA.b DP.REG_X+1
	TAY
	STY.b DP.DRAW_BUFFER.X+2

	; Draw Y: and value of REG_Y
	LDY.w #$2000|Y_COL
	STY.b DP.DRAW_BUFFER.Y+0
	LDA.b DP.REG_Y+0
	TAY
	STY.b DP.DRAW_BUFFER.Y+4
	LDA.b DP.REG_Y+1
	TAY
	STY.b DP.DRAW_BUFFER.Y+2

	; Draw P: and value of REG_P
	; This one is only 8, so we only have 1 read to perform.
	LDY.w #$2000|P_COL
	STY.b DP.DRAW_BUFFER.P+0
	LDA.b DP.REG_P
	TAY
	STY.b DP.DRAW_BUFFER.P+2

	; Draw S: and value of REG_S
	LDY.w #$2000|S_COL
	STY.b DP.DRAW_BUFFER.S+0
	LDA.b DP.REG_SR+0
	TAY
	STY.b DP.DRAW_BUFFER.S+4
	LDA.b DP.REG_SR+1
	TAY
	STY.b DP.DRAW_BUFFER.S+2

	; Draw D: and value of REG_D
	LDY.w #$2000|D_COL
	STY.b DP.DRAW_BUFFER.D+0
	LDA.b DP.REG_D+0
	TAY
	STY.b DP.DRAW_BUFFER.D+4
	LDA.b DP.REG_D+1
	TAY
	STY.b DP.DRAW_BUFFER.D+2

	; Draw B: and value of REG_B
	; This register is only 8 bits.
	LDY.w #$2000|B_COL
	STY.b DP.DRAW_BUFFER.B+0
	LDA.b DP.REG_DB+0
	TAY
	STY.b DP.DRAW_BUFFER.B+2

	; Now that we've finished the register draw, we can handle the operand.
	; We did it in this order to prevent an extra subroutine call.
	; Now we'll grab the addressing mode's vector from a table
	; and push it to stack.
	; Doing so will allow us to use RTS to pull that value back out of the stack
	; and continue execution there.
	; It would be much more convenient to use an instruction like JMP (addr,X)
	; But we're in a bit of a common conundrum
	; We want to use X as our index into the draw buffer
	; Using this trick, which was actually common on the 6502, is our best bet
	; It would be tedious and inelegant to reload X at the start of each subroutines
	; It also wouldn't work, as many of them rely on each other to handle work.
	; We can't use Y for our draw buffer because we'd like to continue using
	; the dp,X addressing mode. There is no dp,Y addressing mode for the accumulator.
	; We also plan to use Y as a parameter within these routines.
	REP #$30
	LDA.w DrawAddressingMode,X

	PHA
	LDX.w #00

	RTS

	; Take note that each entry in this table has -1.
	;There's an automatic increment of the address pulled off
	; the stack when RTS is executed.
	; It's best to take that into account in the table, instead of
	; having an extra DEC to handle it.
DrawAddressingMode:
	dw .Draw_IMP-1

	dw .Draw_DP-1
	dw .Draw_DP_X-1
	dw .Draw_DP_Y-1
	dw .Draw_DP_IND-1

	dw .Draw_DP_X_IND-1
	dw .Draw_DP_IND_Y-1
	dw .Draw_DP_IND_L-1
	dw .Draw_DP_IND_L_Y-1

	dw .Draw_ABS-1
	dw .Draw_ABS_X-1
	dw .Draw_ABS_Y-1
	dw .Draw_ABS_IND-1

	dw .Draw_ABS_X_IND-1
	dw .Draw_ABS_IND_L-1
	dw .Draw_LONG-1
	dw .Draw_LONG_X-1

	dw .Draw_IMM-1
	dw .Draw_IMM_A-1
	dw .Draw_IMM_X-1

	dw .Draw_SR-1
	dw .Draw_SR_IND-1
	dw .Draw_SR_IND_Y-1
	dw .Draw_A_REG-1

	dw .Draw_REL-1
	dw .Draw_REL_L-1
	dw .Draw_JMP_ABS-1
	dw .Draw_JMP_LONG-1

	dw .Draw_BLK-1

	; Each of these will be used for all byte draws, including the first.
	; It expects a parameter of Y holding the number of bytes to write.
	; Before the address it will first include $ and other symbols to indicate
	; the addressing mode as required.
	; Each of these will also set up tile properties ORA'd in
	; for every byte character in the operand.

	; P for Parenthesis
	; This will draw ($ before the byte
	; The text will be orange
.Draw_FirstAddrByte_P
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_P
	BRA .Draw_FirstAddrByte_Arb

	; B for Bracket
	; This will draw [$ before the byte
	; The text will be orange
.Draw_FirstAddrByte_B
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_B
	BRA .Draw_FirstAddrByte_Arb

	; V for vectors, in other words, operands that point to code
	; We want to keep these addresses in white text
	; but this otherwise just draws $ before the byte
.Draw_FirstAddrByte_V
	LDA.w #$3500
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_R
	BRA .Draw_FirstAddrByte_Arb

	; IL for Immediate Lite
	; This will just draw the byte in yellow text
	; but it will only draw a $ before the byte
.Draw_FirstAddrByte_IL
	LDA.w #$2500
	BRA .Draw_FirstAddrByte_Icont

	; I for Immediate
	; This will use yellow text, but it will draw
	; both # and $ before the byte
.Draw_FirstAddrByte_I
	LDA.w #IMD
	JSR .Draw_Any

	LDA.w #$2500

.Draw_FirstAddrByte_Icont
	STA.b DP.DRAW_COLOR
	LDA.w #DOL_I
	BRA .Draw_FirstAddrByte_Arb

	; This will draw a $ before the byte
	; The text will be orange
.Draw_FirstAddrByte
	LDA.w #$3100
	STA.b DP.DRAW_COLOR
	LDA.w #DOL

	; This is our arbitrary entry point for every symbol that precedes operands.
..Arb
	STA.b DP.DRAW_BUFFER.OPERAND,X
	INX
	INX

	; As this draws, it will decrement the ROM pointer offset to read
	; the bytes backwards so that values can be written in big endian.
.Draw_AddrByte
	LDA.b [DP.ROM_READ],Y
	AND.w #$00FF
	ORA.b DP.DRAW_COLOR

	STA.b DP.DRAW_BUFFER.OPERAND,X
	INX
	INX

	DEY
	BNE .Draw_AddrByte

	; IMP for IMPlied
	; Implied addressing doesn't require any operand
	; It should exit immediately
	; It can share the RTS used by the above subroutine.
.Draw_IMP
	RTS

	; DOLlar
	; Draws $
.Draw_DOL
	LDA.w #DOL_R

	; This will draw any character we want.
	; Many routines that follow will branch here to draw some character.
.Draw_Any
	STA.b DP.DRAW_BUFFER.OPERAND,X
	INX
	INX
	RTS

	; This is for implied instructions that operate on the accumulator.
	; Explicitly putting A as the operand is valid, so we can display it
	; in our disassembly as a nicety.
.Draw_A_REG
	LDA.w #A_IMP
	BRA .Draw_Any

	; This is for our direct page addressing mode.
	; It will draw a single byte, prefixed by $.
.Draw_DP
	LDY.w #1
	BRA .Draw_FirstAddrByte

	; This is for our direct page X-indexed addressing mode.
	; It will use .Draw_DP to first draw the address.
	; Then it will draw a ,X.
	; We'll put the COM_X label here to save space by sharing the code.
	; Knowing where to put code that can be bleed into is an important skill.
.Draw_DP_X
	JSR .Draw_DP

	; COMma X
	; Draws ,X
.Draw_COM_X
	LDA.w #COM_X
	BRA .Draw_Any

	; This is the same as above, but for dp,Y.
	; We'll also put the COM_Y draw label here, as we did with COM_X.
.Draw_DP_Y
	JSR .Draw_DP

	; COMma Y
	; Draws ,Y
.Draw_COM_Y
	LDA.w #COM_Y
	BRA .Draw_Any

	; This will draw our indirect direct page addressing mode
	; so it will draw ($dp).
	; The opening parenthesis will be part of combined tile that
	; has both ( and $.
	; The closing parenthesis will be drawn on its own.
	; And we'll let anything else draw a closing parenthesis by
	; sharing this label.
.Draw_DP_IND
	LDY.w #1
	JSR .Draw_FirstAddrByte_P

	; Closing PaReNthesis
	; Draws )
.Draw_C_PRN
	LDA.w #C_PRN
	BRA .Draw_Any

	; We'll draw ($dp like above, but this is a preindex address
	; We'll need to draw a ,X before drawing the closing parenthesis
.Draw_DP_X_IND
	LDY.w #1
	JSR .Draw_FirstAddrByte_P

	; We'll add a label here that can be reused by (addr,X)
.Draw_COM_X_C_PRN
	JSR .Draw_COM_X
	BRA .Draw_C_PRN

	; This one is a bit more intricate than the previous ones.
	; We'll use .Draw_DP_IND to draw a ($dp),
	; but then we'll decrement X twice to rewrite the last character.
	; This would be like copying "($dp)" with CTRL-C,
	; pressing CTRL-V to paste it, and pressing backspace to delete the ")".
.Draw_DP_IND_Y
	JSR .Draw_DP_IND
	DEX
	DEX

	; Parenthesis COMma Y
	; Draws ),Y
.Draw_P_COM_Y
	LDA.w #P_COM_Y
	BRA .Draw_Any

	; This will draw [$dp]
	; Similar to DP_IND, but using square brackets to indicate
	; that the indirect address is 24-bit.
.Draw_DP_IND_L
	LDY.w #1
	JSR .Draw_FirstAddrByte_B

	; Closing BracKeT
	; Draws ]
.Draw_C_BKT
	LDA.w #C_BKT
	BRA .Draw_Any

	; The indexed version of the above, [$dp],Y
.Draw_DP_IND_L_Y
	JSR .Draw_DP_IND_L
	DEX
	DEX

	; Bracket COMma Y
	; Draws ],Y
	; This is the only addressing mode that uses the ],Y character
	; So we don't need to create a label, as there's nothing to share it with.
	LDA.w #B_COM_Y
	BRA .Draw_Any

	; This is for our absolute addressing mode.
	; We'll want to draw 2 bytes, so we load Y with that value.
.Draw_ABS
	LDY.w #2
	BRA .Draw_FirstAddrByte

	; Just like with dp,X,
	; we'll use the absolute addressing mode draw routine
	; and then append the ,X to it.
	; This time, we'll reuse the COM_X draw label shared by dp,X.
.Draw_ABS_X
	JSR .Draw_ABS
	BRA .Draw_COM_X

	; Same as above, but for addr,Y.
.Draw_ABS_Y
	JSR .Draw_ABS
	BRA .Draw_COM_Y

	; These rest will be the same as direct page,
	; but drawing 2 bytes instead of 1.
.Draw_ABS_IND
	LDY.w #2
	JSR .Draw_FirstAddrByte_P
	BRA .Draw_C_PRN

.Draw_ABS_X_IND
	LDY.w #2
	JSR .Draw_FirstAddrByte_P
	BRA .Draw_COM_X_C_PRN

.Draw_ABS_IND_L
	LDY.w #2
	JSR .Draw_FirstAddrByte_B
	BRA .Draw_C_BKT

	; Now we're coding the 24-bit addressing modes.
	; There are fewer of these than the others
	; We have to start using JMP instead of BRA here because
	; The distance between here and the code we're using is too far
	; Branches are relative, and can only jump backwards 127 bytes.
	; If you try branching to a label that is out of bounds,
	; the assembler will throw an error, and it won't compile.
	; Take note of when BRA is used and when JMP is used from here on.
.Draw_LONG
	LDY.w #3
	JMP .Draw_FirstAddrByte

.Draw_LONG_X
	JSR .Draw_LONG
	BRA .Draw_COM_X

	; These are for our immediate addressing modes
	; This one specifically fill be called by instructions that are always
	; 1 byte operands, such as BRK
.Draw_IMM
	LDY.w #1
	JMP .Draw_FirstAddrByte_I

	; For REG_A, REG_X, and REG_Y, we need to test the bit mode we're in.
	; We're using -1 on REG_P.M because we are currently in 16-bit accumulator.
	; This will test the address before it, putting REG_P.M's 7th bit
	; as the 15th bit of the address we test.
	; If it's 0, we'll draw 2 bytes.
	; If it's 1, we'll draw 1 byte.
.Draw_IMM_A
	BIT.b DP.REG_P.M-1
	BMI .Draw_IMM_1byte

.Draw_IMM_2byte
	LDY.w #2
	BRA .Draw_IMM_adjust

.Draw_IMM_1byte
	LDY.w #1

	; Here, we also want to change the addressing mode drawn.
	; By default, we'll be drawing Ab, Xb, Yb, etc.
	; But if Y=2, we want to change that lowercase b to a w.
	; I've set up the character layout to make this easy.
	; All we have to do is use the character 1 row down.
	; So we want add 16 to the character name.
	; Because the carry will be set of Y=2, we can make use of it.
	; That ADC.w #15 behaves like a +16.
	; We get +15 from the operand and +1 from the carry.
	; If Y is 1, then we don't need to change anything.
.Draw_IMM_adjust
	LDA.b DP.DRAW_BUFFER.INSTRUCTION+2
	CPY.w #2
	BCC ..not_w

	ADC.w #15
	STA.b DP.DRAW_BUFFER.INSTRUCTION+2

..not_w
	JMP .Draw_FirstAddrByte_I

	; IMM_X handles both the X and Y immediate operations.
	; This is the same as what we did for A.
	; The only difference is that we can't bleed into the 2 byte code.
	; We'll have to branch to it
.Draw_IMM_X
	BIT.b DP.REG_P.X-1
	BMI .Draw_IMM_1byte
	BRA .Draw_IMM_2byte

	; Stack relative operations have an operand that is neither
	; address nor immediate; rather, the operand is an index.
	; It's more similar to an immediate, so we'll use the same color.
	; We have a separate routine called "immediate lite" for drawing
	; operands with the color of an immediate value
	; but without the pound sign (#).
	; After we draw that, we also need to include the ,S
	; And we'll create a label so other routines can draw ,S with the same code.
.Draw_SR
	LDY.w #1
	JSR .Draw_FirstAddrByte_IL

	; COMma S
	; Draws ,S
.Draw_COM_S
	LDA.w #COM_S
	JMP .Draw_Any

	; This will draw our indirect stack relative operations.
	; Draws (i,S)
.Draw_SR_IND
	LDY.w #1
	JSR .Draw_FirstAddrByte_P
	JSR .Draw_COM_S
	JMP .Draw_C_PRN

	; This will draw indirect stack relative Y-indexed operations.
	; It will use the above to draw (i,S) then backspace to delete the ),
	; like we saw above with other Y-indexed draw routines.
	; Draws (i,S),Y
.Draw_SR_IND_Y
	JSR .Draw_SR_IND
	DEX
	DEX
	JMP .Draw_P_COM_Y

	; Relative addresses are for branch routines.
	; But when disassembling, it's much more useful to see
	; where the branch actually leads, rather than the offset it uses.
	; We'll do that by adding in the offset before printing a value.
.Draw_REL
	; First, we'll want to load the operand.
	; What we actually load is the offset operand in the high byte
	; and the opcode in the low byte.
	; This will make it easy to test if the value is negative
	; After we mask out the opcode, we'll test the sign of the value.
	; If the sign is negative, we want to do what's called sign extension.
	; We'll be using an 8-bit value that needs to be treated as 16 bits.
	; Sign extension simply copies the sign bit into all bits above it.
	; For positive numbers, that's 0.
	; If our number is positive, the AND has already taken care of that.
	; For negative numbers, that's 1.
	; If our number is negative, we'll want to ORA in $FF (%11111111).
	; And remember that right now, our number is flipped,
	; so we'll be extending the sign into the low byte.
	; Under most normal circumstances, sign extension of negative numbers
	; will be done with ORA #$FF00, rather than #$00FF.
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	BPL ..pos

	ORA.w #$00FF

	; After the sign is taken care of, we'll put the bytes in the correct order.
..pos
	XBA

	; This label will be shared by both 16-bit and 8-bit branch operations.
.Draw_RELATIVE
	; Now that we have our offset, we can add it to the current program counter
	; of our disassembly's "emulation".
	; We're using SEC here so that our ADC gets an extra +1
	; This is slightly more efficient than clearing the carry and also using INC.
	; It needs to be +1 because the operand points to an address relative to the
	; the next instruction.
	SEC
	ADC.b DP.ROM_READ

	; And we will actually need to increment it one more timer after
	; to fully take this into acccount.
	INC

	; Before we can draw the address, we'll need to draw the $
	; So let's save the value we just calculated in scratch space.
	STA.b DP.SCRATCH
	JSR .Draw_DOL

	; We can't use the routines we used previously for drawing operands,
	; because they all assumed the operand was after the opcode.
	; We're using a calculated value, so we have to do this manually.

	; We'll draw the high byte first.
	; To do so, we'll load 1 byte ahead of where we saved our address.
	LDA.b DP.SCRATCH+1
	AND.w #$00FF
	ORA.w #$3500
	JSR .Draw_Any

	; Now we'll draw the low byte.
	LDA.b DP.SCRATCH+0
	AND.w #$00FF
	ORA.w #$3500
	JMP .Draw_Any

	; RELative Long
	; Unlike the previous routine, we don't need to perform
	; Any real trickery to sign extend negative numbers
	; However, we will need to do an extra increment
	; To account for the operand size
.Draw_REL_L
	LDY.w #1
	LDA.b [DP.ROM_READ],Y
	INC
	BRA .Draw_RELATIVE

	; This is for JMP and JML instructions.
	; They'll be drawn the same, but for different operand sizes
	; Both will use the Vector draw entry.
.Draw_JMP_ABS
	LDY.w #2
	JMP .Draw_FirstAddrByte_V

.Draw_JMP_LONG
	LDY.w #3
	JMP .Draw_FirstAddrByte_V

	; This is for block moves, MVN and MVP.
	; The operands here are actually used to indicate the banks
	; of the source and destination in the move.
	; They too will need a manual draw routine, even though the operands
	; follow the opcode.
.Draw_BLK
	; We'll first draw the $ for the source address.
	JSR .Draw_DOL

	; Now we'll draw the source address byte.
	LDY.w #2

	LDA.b [DP.ROM_READ],Y
	AND.w #$00FF
	ORA.w #$3500
	JSR .Draw_Any

	; This is another character only ever used in one place.
	; We'll load it and call .Draw_Any instead of calling
	; an existing subroutine.
	LDA.w #COM
	JSR .Draw_Any

	; Even though we had to draw our source bank manually
	; we can draw the destination bank with our vector draw entry,
	; because block moves swap the order of the mnemonic in the machine code.
	; All we need to do is decrement Y to set it to 1 first.
	DEY
	JMP .Draw_FirstAddrByte_V

;===============================================================================
;    Our draw routines are complete!
;    Now we can start looking at the code used to disassemble the rom
;===============================================================================

	; These routines will advance our "emulated" program counter to the next
	; instruction.

	; This one will advance 1 or 2, depending on the status of the X flag
	; It will be using a similar trick used before to test either M or X
	; depending on the bit mode, which is determined by the entry point
	; For the X flag test, we want the accumulator in 16-bit
NEXT_OP_X:
	REP #$20
	BRA .test

	; This will test the accumulator's bit mode in the "emulated" system.
	; # was used to prevent a new scope so that a simple label name
	; ".test" could be used.
#NEXT_OP_M:
	SEP #$20

.test
	BIT.b DP.REG_P.M
	BMI NEXT_OP_1
	BRA NEXT_OP_2

	; Each of this will increment the program counter by the amount
	; specified in the title
	; They'll bleed into each other for simplicity
	; However, there still needs to be a REP #$20 before each increment
	; because we're not exactly sure which one is being used
	; or what the status of the processor is when we get here
NEXT_OP_4:
	REP #$20
	INC.b DP.ROM_READ

NEXT_OP_3:
	REP #$20
	INC.b DP.ROM_READ

NEXT_OP_2:
	REP #$20
	INC.b DP.ROM_READ

NEXT_OP_1:
	REP #$20
	INC.b DP.ROM_READ

	RTS

;===============================================================================

	; This will handle relative offsets, the same as the draw routine.
	; This time, we'll take the address we calculate and give it to
	; the program counter.
DoBranchingLong:
	REP #$30
	LDY.w #1
	LDA.b [DP.ROM_READ],Y

	; For Long branching, we'll set the carry for the +1 that takes
	; the operand size into account.
	SEC
	BRA BranchDo

DoBranching:
	; Long branches only exist in one form: BRL
	; BRL always takes the branch.
	; But other branches may be conditional.
	; We'll assume that this routine is called first by testing a flag
	; that will be trackes with the N flag.
	BPL NEXT_OP_2

	; Take note of the 1 in this REP.
	; That will clear the carry, which is what we're using to take
	; operand size of the branch into account.
	; REP #$x1 and SEP #$x1 are something to always have on your mind.
	; They make it easy to optimize code just a little extra by
	; avoiding extraneous CLC or SEC operations.
	REP #$31

	; This is the same trick we saw for the relative draw routines.
	; This time, however, the operands of the AND are in the reverse.
	; This doesn't affect the result, but it showcases another way to do things.
	LDA.w #$FF00
	AND.b [DP.ROM_READ]
	BPL .pos

	ORA.w #$00FF

.pos
	XBA

	; Here is where we add the offset and program counter together.
	; We will always want +2 to occur,
	; but whether we do an extra +1 for BRL will be handled by the carry.
BranchDo:
	ADC.b DP.ROM_READ
	INC
	INC
	STA.b DP.ROM_READ
	RTS

;===============================================================================
	; This routine will handle the "emulation" of many of the smaller and
	; simpler instruction
	; The 4 entry points determine the size of the instruction and its operand
	; Included here is a little trick to make the entry points bit-mode agnostic
	; If X is 8-bit, then it will just load the value specified and then run a NOP
	; or "No OPeration"
	; If X is 16-bit the NOP will actually be treated as the high byte of the operand
	; and we will load, for example, #$EA04
	; This is fine, though, because immediately after we will be putting X into 8-bit
	; and that EA will disappear.
IsolateAndExecute_4:
	LDX.b #4
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_3:
	LDX.b #3
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_2:
	LDX.b #2
	NOP
	BRA IsolateAndExecute

IsolateAndExecute_1:
	LDX.b #1
	NOP
	BRA IsolateAndExecute

	; For immediate addressing, we'll need to test the respective flag
	; to determine if the instruction has a 1- or 2-byte operand.
	; We'll grab each flag individually and then shift it left to put the flag
	; into the carry.
	; Then we'll load X with 2, and if the carry is clear, meaning the flag is reset,
	; we'll increment X to 3 for a 16-bit immediate.
IsolateAndExecute_AccumulatorImmediate:
	SEP #$30
	LDA.b DP.REG_P.M
	BRA ++

IsolateAndExecute_IndexImmediate:
	SEP #$30
	LDA.b DP.REG_P.X

++	LDX.b #2
	ASL
	BCS .1byte

	INX

.1byte


IsolateAndExecute:
	SEP #$30

	; This will put 6B, the opcode for RTL immediately after the instruction
	; that we are about to copy over.
	LDA.b #$6B
	STA.b DP.EXECUTE,X

	; We need to copy the bytes in order, so we'll start with Y=0
	LDY.b #$00

	; For each iteration, we will read Y bytes past our "emulated" program counter
	; and store the value to WRAM.
	; Each iteration, X is decremented.
	; The loop terminates when X=0, indicating every byte has been copied
.next_copy
	LDA.b [DP.ROM_READ],Y
	STA.w DP.EXECUTE,Y
	INY
	DEX
	BNE .next_copy

	; At this point, Y holds the same value X did when we entered.
	; We'll use this to advance our program counter.
	REP #$21
	TYA
	ADC.b DP.ROM_READ
	STA.b DP.ROM_READ

;===============================================================================
	; This routine will execute the isolated code we've written to WRAM,
	; and it will do so in the exact same state as the "emulated" system.
	; This is why it's not really "emulation", because many of our instructions
	; will actually be performed directly by the CPU.
	; Much of this routine is juggling the stack to set up and recover registers.
ExecuteIsolatedCode:
	SEP #$10
	REP #$20

	; We'll begin by saving our direct page and data banks.
	PHD
	PHB

	; Now we'll push REG_P to stack so we can pull it in our actual P.
	LDX.b DP.REG_P
	PHX

	; Because all 16 bits of A are taken into account, we'll want to
	; load REG_A while still in 16-bit mode.
	LDA.b DP.REG_A

	; After that, we'll want to get our processor for loading REG_X and REG_Y
	; but we also need to save it again.
	PLP
	PHP

	; Loading REG_X and REG_Y will affect the N and Z flags,
	; and we can't have that impact our "emulated" system.
	LDX.b DP.REG_X
	LDY.b DP.REG_Y

	; This will push the 16-bits in REG_D to stack.
	PEI.b (DP.REG_D)

	; PLD also affects the N and Z flags.
	PLD

	; Now that everything that affects the processor status is finished,
	; we can pull back the REG_P and execute our isolated code in WRAM.
	PLP

	JSL.l DP.EXECUTE

	; We want to push A (whatever size it may be)
	; and the processor twice, to preserve its status.
	PHA
	PHP
	PHP

	; We'll set A to 8-bit so that we can pull REG_P once for saving.
	; All these writes will be long, because we aren't sure what
	; the exact state of the data bank and direct page registers
	; are after setting them up to match the "emulated" CPU.
	SEP #$20
	PLA
	STA.l DP.REG_P

	; Our second P pull will recover the bit mode for REG_A.
	; Then we can pull REG_A without causing a problem with the size of stack.
	PLP
	PLA


	; This REP #$2C will put us in 16-bit A for writing the full accumulator,
	; but it will also reset the I and D flags that may have been set in the
	; isolated code we executed:
	;       NVMXDIZC
	;   $2C 00101100
	REP #$2C
	STA.l DP.REG_A

	; Since our X flag still matches that of the emulated system, we can
	; just transfer X and Y to A.
	; The high byte of the accumulator will take $00 if X is 8-bit.
	TXA
	STA.l DP.REG_X

	TYA
	STA.l DP.REG_Y

	; And finally, we'll save direct page.
	TDC
	STA.l DP.REG_D

	; And now we recover the registers we had to save earlier.
	PLB
	PLD

	SEP #$30
	RTS

;===============================================================================
IsolateAndExecuteSafely_1:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_1

IsolateAndExecuteSafely_2:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_2

IsolateAndExecuteSafely_3:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_3

IsolateAndExecuteSafely_4:
	JSR IsolateAndExecuteSafely
	JMP NEXT_OP_4

	; Like the above routine, this will isolate code to "emulate" it.
	; but it will take additional precautions to safeguard memory
	; by creating the effective address of the operation.
IsolateAndExecuteSafely:
IsolateAndExecuteSafely_0:
	JSR GetEffectiveAddress
	JSR PrepareEffectiveRead

	; Once our effective address is created, we will want to
	; match our data bank to that of the effective address.
	; We will preserve our current data bank before doing so.
	PHB

	SEP #$10
	LDX.b DP.SCRATCH+2
	PHX
	PLB

	JSR ExecuteIsolatedCode

	PLB
	RTS

;===============================================================================
	; This here is a critical routine to properly disassembling our code.
	; What this routine will do is take an addressing mode and an operand
	; and turn it into a 24-bit address to handle later.
GetEffectiveAddress:
	; First, we'll get the opcode and turn it into an index.
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	TAX

	; And we'll use that index to get the addressing mode.
	LDA.w OpCodeFunc+0,X
	AND.w #$00FF
	TAX

	; Unlike with the draw routine, we don't need to preserve X here.
	; We can make use of JMP (addr,X) to handle the vector table.
	JMP (.addressing_modes,X)

	; Take note that since we aren't using the 6502 PHA : RTS trick,
	; we don't need -1 on the labels here.
.addressing_modes
	dw .handle_IMP
	dw .handle_DP
	dw .handle_DP_X
	dw .handle_DP_Y
	dw .handle_DP_IND
	dw .handle_DP_X_IND
	dw .handle_DP_IND_Y
	dw .handle_DP_IND_L
	dw .handle_DP_IND_L_Y
	dw .handle_ABS
	dw .handle_ABS_X
	dw .handle_ABS_Y
	dw .handle_ABS_IND
	dw .handle_ABS_X_IND
	dw .handle_ABS_IND_L
	dw .handle_LONG
	dw .handle_LONG_X
	dw .handle_IMM
	dw .handle_IMM_A
	dw .handle_IMM_X
	dw .handle_SR
	dw .handle_SR_IND
	dw .handle_SR_IND_Y
	dw .handle_A_REG
	dw .handle_REL
	dw .handle_REL_L
	dw .handle_JMP_ABS
	dw .handle_JMP_LONG
	dw .handle_BLK

	; DP addresss are always in bank 00,
	; but they also need to have the direct page register added to them.
.get_DP
.handle_DP
	; Clear the carry too!
	REP #$31

	; We'll read the opcode to put the operand in the high byte
	; so that we can avoid setting Y.
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	XBA
	ADC.b DP.REG_D
	STZ.b DP.SCRATCH+1
	STA.b DP.SCRATCH+0

	; This CLC will be here so that other routines can make use of it.
	CLC

	; All of these operations are irrelevant.
	; They should exit immediately.
	; These labels mostly exist only to fill the table.
.handle_IMP
.handle_IMM
.handle_IMM_A
.handle_IMM_X
.handle_A_REG
.handle_REL
.handle_REL_L
.handle_JMP_ABS
.handle_JMP_LONG
.handle_BLK
	RTS

	; We'll use the normal DP routine first to get the base address.
	; And remember, we put a CLC in that routine because we knew
	; that we would be needing the CLC for dp,X and dp,Y.
.handle_DP_X
	JSR .get_DP

	; We'll put a label here so that other routines can share this code
	; to add in X for indexed addressing.
.handle_X
	ADC.b DP.REG_X
	STA.b DP.SCRATCH+0
	RTS

.handle_DP_Y
	JSR .get_DP

	; Like above for X.
.handle_Y
	ADC.b DP.REG_Y
	STA.b DP.SCRATCH+0
	RTS

	; Here, we need to get the DP address first,
	; but then we need to read from it to find our final effective address.
.handle_DP_IND
	JSR .get_DP

.handle_DP_IND_ARB
	SEP #$30
	; Our emulated direct page will be in bank 7F,
	; so before we read, we need to fix that.
	LDA.b #$7F
	STA.b DP.SCRATCH+2

	; And because it's a 16-bit effective address
	; our data bank will matter, so we should load that now to use later.
	LDX.b DP.REG_DB

	; Here's where we'll clear the carry for anything that
	; relies on this routine for an indirect address.
	REP #$21

	; This is some extra code we'll use when we do [dp].
	; We'll load the effective address+2 to get the bank
	; and save it in Y for later.
	LDY.b #2
	LDA.b [DP.SCRATCH],Y
	TAY

	; For the main purpose of this routine, we only need the effective address
	; so we load and save that.
	; Then we put X (which held the "emulated" data bank) as the bank of
	; our effective address.
	LDA.b [DP.SCRATCH]
	STA.b DP.SCRATCH+0
	STX.b DP.SCRATCH+2

	RTS

	; Since (dp,X) is pre-indexed, we need to handle that indexing first.
	; Then we can use the indexed dp address to find the effective address
	; by jumping to the ARBitrary entry point.
.handle_DP_X_IND
	JSR .handle_DP_X
	BRA .handle_DP_IND_ARB

	; (dp),Y is post indexed, so we want to use the normal dp indirect first.
	; Then we can add in Y, using the shared code we made a label for above.
.handle_DP_IND_Y
	JSR .handle_DP_IND
	BRA .handle_Y

	; Remember that before writing our address in .handle_DP_IND
	; we loaded the 3rd byte into Y.
	; This is where we swap the bank of the effective address
	; to be from the location read.
.handle_DP_IND_L
	JSR .handle_DP_IND
	STY.b DP.SCRATCH+2
	RTS

	; Now we'll get a 24 bit address and add Y in afterwards.
.handle_DP_IND_L_Y
	JSR .handle_DP_IND_L
	BRA .handle_Y

	; This will perform many of the same functions as .get_DP
	; but for 16-bit absolute addresses.
	; It will use the current data bank instead of bank 00.
.get_ABS
.handle_ABS
	REP #$21
	SEP #$10

	LDY.b #1
	LDA.b [DP.ROM_READ],Y
	STA.b DP.SCRATCH+0

	LDY.b DP.REG_DB
	STY.b DP.SCRATCH+2

	RTS

	; Like for dp,X we just want abs and then with X added in.
	; Again, using shared code we made a label for above.
.handle_ABS_X
	JSR .get_ABS
	BRA .handle_X

	; Ditto for Y.
.handle_ABS_Y
	JSR .get_ABS
	BRA .handle_Y

	; Like direct page, the stack is always in bank00.
	; We'll save that for the effective bank's address.
	; SR points directly to the first open slot in stack,
	; and the operand (i) in i,S is simply an offset added to SR.
.handle_SR
	SEP #$10
	LDY.b #$00
	STY.b DP.SCRATCH+2

.do_SR
	; Like with DP, we can avoid setting Y by reading the operand
	; into the high byte and swapping it afterwards.
	REP #$21

	; However, we'll do the courtesy of setting the index registers
	; to 8-bit mode.
	SEP #$10
	LDA.b [DP.ROM_READ]
	AND.w #$FF00
	XBA
	ADC.b DP.REG_SR
	STA.b DP.SCRATCH+0

	RTS

	; This will handle (i,S)
	; Tt will need to load the data bank as a paremeter for a routine
	; that will covered in a moment.
.handle_SR_IND
	JSR .do_SR
	LDY.b DP.REG_DB
	BRA .handle_ABS_IND_ARB

	; We put the CLC here this time
	; because this is the only function that needs the carry clear
	; after relying on .handle_SR_IND or .do_SR.
.handle_SR_IND_Y
	JSR .handle_SR_IND
	CLC
	BRA .handle_Y

	; This will handle (addr).
	; And remember that that routine has preloaded Y with our data bank.
.handle_ABS_IND
	JSR .get_ABS

.handle_ABS_IND_ARB
	; Here's where we do some manipulation to make sure we read the correct address.
	; We'll start by avoiding anything that's $0000-$1FFF, because that area is our
	; actual WRAM
	CMP.w #$2000
	BCS ..rom_bank

	; Anything in that range should instead switch to bank7F.
	LDY.b #$7F

..rom_bank
	; We'll be swapping data banks for this read.
	; So we want to save our current data bank before giving Y to DB.
	PHB
	PHY
	PLB

	; To read from whatever bank we want, we'll actually use another
	; technique that can be done with indexed addressing
	; Instead of X behaving as an offset, it will be our base address
	; and the operand will act as our offset
	; In this case, we're using LDA.w $0000,X
	; and you can think of that as "The address X plus $0000"
	REP #$10
	TAX

.handle_ABS_IND_ARB_getaddr
	LDA.w $0000,X
	STA.b DP.SCRATCH+0

	; We'll go back to 8-bit index registers now.
	; Y still holds our emulated data bank.
	SEP #$10
	PLB

	RTS

	; The only instructions that can use this addressing mode are
	; JMP (addr,X) and JSR (addr,X)
	; and those use the program bank not data bank.
	; Before we handle the indirect address, we'll give Y and the scratch
	; the program bank from our pointer to handle this behavior.
.handle_ABS_X_IND
	JSR .handle_ABS_X

	LDY.b DP.ROM_READ.b
	STY.b DP.SCRATCH+2
	BRA .handle_ABS_IND_ARB

	; This is similar to the above, but we need to use 3 bytes instead of 2.
	; That means we also have to take care of our data bank.
.handle_ABS_IND_L
	JSR .get_ABS
	CMP.w #$2000
	BCS ..rom_bank

	LDY.b #$7F

..rom_bank
	PHB
	PHY
	PLB

	; Again, you can see the operand being used as the parameter.
	; In this case, we're doing "The address X + $0001" to find the high byte.
	REP #$10
	TAX
	LDA.w $0001,X

	STA.b DP.SCRATCH+1
	BRA .handle_ABS_IND_ARB_getaddr

	; This will handle 24-bit addressing.
	; Because every byte is explicitly in the operand,
	; this addressing mode is much simpler than the others.
.handle_LONG
	REP #$21
	SEP #$10
	LDY.b #2
	LDA.b [DP.ROM_READ],Y
	STA.b DP.SCRATCH+1

	DEY
	LDA.b [DP.ROM_READ],Y
	STA.b DP.SCRATCH+0

	RTS

	; And this is our final addressing mode!
.handle_LONG_X
	JSR .handle_LONG
	JMP .handle_X

;===============================================================================

	; This here is another critical routine.
	; What this routine will do is take the effective address calculated in the
	; routine above and turn it into an address we can use safely.
	; We will want to avoid writing to the area of memory we are working with,
	; so we'll use this routine to turn anything that needs to be safeguarded
	; into an address in bank7F or open bus.
PrepareEffectiveRead:
	; We'll begin by getting an offset again based on our opcode
	REP #$30
	LDA.b [DP.ROM_READ]
	AND.w #$00FF
	ASL
	TAX

	; We're not read to use that offset yet though

	; First, we need to check the bank of the effective address.
	LDA.b DP.SCRATCH+2
	AND.w #$00FF

	; We'll test for banks $00-$3F, which contain a WRAM mirror.
	CMP.w #$0040 : BCC .mirroredbank

	; Here, I've used a colon (:) to separate instructions on the same line.
	; This isn't something I personally do often, but this is an instance
	; of where doing so helps readability more than it hinders.
	; How you use multiple instructions per line is preference, but I believe
	; they lead to less readable code more often than not.
	; Try to divvy your code up into logical ideas with empty lines
	; before you turn everything into multi-op lines.

	; Anything in bank 7E is WRAM, so we'll want to move it to bank 7F.
	; Anything less than 7E that has reached this point ($40-$7D) will
	; have no wram mirror.
	; The order of these compares is important, as we want to filter out
	; banks $00-$3F before we test for $40-$7D.
	CMP.w #$007E : BEQ .wram : BCC .nomirror

	; Now, we'll test for banks $C0-$FF, banks with no WRAM mirror.
	CMP.w #$00C0 : BCS .nomirror

	; Anything in bank7F can actually interfere with our disassembly
	; We'll need to treat them separately to see how we should handle
	; it from here.
	; Anything that got this far and isn't $7F will be $80-$BF
	; all of which have WRAM mirrors, so they'll bleed into the
	; mirrored banks branch if the condition fails.
	CMP.w #$007F : BEQ .registercontinue

.mirroredbank
	; Now we want to test the address we're using against certain values
	; to see where in the bank it lies.
	LDA.b DP.SCRATCH

	; For mirrored banks, we'll need to see what exactly we're looking at
	; Anything from $0000-$1FFF is a mirror of bank7E.
	; Anything from $2000-$7FFF is a register or openbus.
	; Those and ROM addresses at $8000-$FFFF will be handled in the
	; not a WRAM mirror branch.
	; And we'll want to swap the effective address to 7F if it's WRAM.
	CMP.w #$2000 : BCS .notwrammirror

.wram
	SEP #$20
	LDA.b #$7F
	STA.b DP.SCRATCH+2
	REP #$20
	BRA .not_register

.nomirror
	LDA.b DP.SCRATCH
	; For banks without a WRAM mirror, anything that's not ROM is open bus.
	CMP.w #$8000 : BCS .romspace
	BRA .openbus

.notwrammirror
	; First we'll test for ROM addresses.
	CMP.w #$8000 : BCS .romspace

	; Now we'll look for addresses from $2000 to $20FF.
	; We can use BCC here because we've already filtered out $0000-$1FFF.
	CMP.w #$2100 : BCC .openbus

	; this will find anything from $2100-$21FF for registers.
	CMP.w #$2200 : BCC .registercontinue

	; Anything from $2200-$4015 is open bus.
	; Only $4016 and $4017 are registers.
	CMP.w #$4016 : BCC .openbus
	CMP.w #$4017 : BEQ .registercontinue

	; $4018-$41FF are open bus.
	CMP.w #$4200 : BCC .openbus

	; $4210 is a special, hardcoded case.
	; Earlier we saw that it was read and tested for bit 7.
	; We need to force the "emulated" system to always get a negative read
	; otherwise, it would end up in an infinite loop.
	CMP.w #$4210 : BEQ .forcenegativeread

	; Anything from $4200-$421F is a register.
	CMP.w #$4220 : BCC .registercontinue

	; Anything $4221-$42FF is open bus.
	CMP.w #$4300 : BCC .openbus

	; And of what's remaining, this will treat $4380-$7FFF as open bus.
	; $4300-$437F will fail this condition and continue into the register branch.
	CMP.w #$4380 : BCS .openbus

	; For registers, we'll need to include some extra logic.
	; It's fine if most registers are read, ut any writes could be fatal.
	; This byte in our opcode data table is a broader take
	; on the addressing mode that tells us the nature of the operation.
.registercontinue
	LDA.w OpCodeFunc+1,X
	AND.w #$00FF

	; The IDs for operation type have been ordered so that testing them is simple
	; Anything >= PEI or <SAVE_A can be left alone
	CMP.w #PEI_IT : BCS .not_register
	CMP.w #SAVE_A : BCC .not_register
	BRA .register

	; We made one of our unused vectors $FFFF.
	; That's where we can read from when we need a negative value.
.forcenegativeread
	LDA.w #EMU_VECTOR_UNU>>0
	STA.b DP.SCRATCH+0

	LDA.w #EMU_VECTOR_UNU>>8
	BRA .write_the_bank

	; For open bus and register writes, we'll use $66:6666.
	; This effectively causes nothing to happen, as this address
	; does not point to anything.
	; Nothing at all.
.openbus
.register
	LDA.w #$6666
	STA.b DP.SCRATCH+0

.write_the_bank
	STA.b DP.SCRATCH+1

.romspace
.not_register
	; Now to prepare WRAM with some code we can execute in isolation.
	; First, we'll take our address and save it to EXECUTE+1
	; where the operand will be.
	LDA.b DP.SCRATCH
	STA.b DP.EXECUTE+1

	; Now we'll write $6B6B to the end of the execution buffer.
	; $6B is the opcode for RTL.
	; We'll be using a JSL to execute this code and want to return from it when done.
	LDA.w #$6B6B
	STA.b DP.EXECUTE+3

	; For anything below PEI, we will be writing out new code to execute (see below).
	LDA.w OpCodeFunc+1,X
	AND.w #$00FF
	CMP.w #PEI_IT
	BCC .set_opcode

	; But for PEI, JSR (addr,X), and JMP (addr,x), we need to handle them directly.
	; We only want our vector table to have 3 entries, so we'll need to bring the
	; ID we have down to 0, by subtracting the first member's value.
	SBC.w #PEI_IT
	ASL
	TAX
	JMP (.exec_op,X)

.exec_op
	dw EXEC_PEI_IT
	dw EXEC_RELOC
	dw EXEC_RELOCL

	; PEI (dp) reads 16 bits from the direct page address and pushes them to stack.
	; 16 bits will be pushed regardless of the accumulator's bit mode.
	; We'll handle this by just reading our effective address, which was handled
	; as a (dp) in the previous routine.
#EXEC_PEI_IT:
	LDA.b DP.SCRATCH
	JSR PushToStack_push_2
	BRA .set_nothing

	; RELOCate Long should use the actual effective address and all 24bits
	; So we'll have it rewrite our "emulated" program counter's high byte
	; which will also cover the bank byte.
#EXEC_RELOCL:
	LDA.b DP.SCRATCH+1
	STA.b DP.ROM_READ+1

	; For local relocations, we only need to change the address.
#EXEC_RELOC:
	LDA.b DP.SCRATCH
	STA.b DP.ROM_READ

	; This will have our special functions use RTL as the first opcode
	; causing the written code to exit immediately.
.set_nothing
	LDA.w #0

	; For all other operations, we want a specific opcode
	; that will handle the operand as an absolute address.
	; The bank or data bank is taken care of in another routine.
.set_opcode
	SEP #$30
	TAX
	LDA.w .ops,X
	STA.b DP.EXECUTE
	RTS

.ops
	db $6B ; NOTHIN
	db $AD ; READ_A
	db $2D ; AND_A
	db $4D ; EOR_A
	db $0D ; ORA_A
	db $6D ; ADC_A
	db $ED ; SBC_A
	db $CD ; CMP_A
	db $2C ; BIT_A
	db $AE ; READ_X
	db $EC ; CPX_X
	db $AC ; READ_Y
	db $CC ; CPY_Y
	db $8D ; SAVE_A
	db $8E ; SAVE_X
	db $8C ; SAVE_Y
	db $EE ; INC_IT
	db $CE ; DEC_IT
	db $9C ; STZ_IT
	db $0E ; ASL_IT
	db $4E ; LSR_IT
	db $2E ; ROL_IT
	db $6E ; ROR_IT
	db $1C ; TRB_A
	db $0C ; TSB_A

;===============================================================================

	; We have now finished the bulk of the code.
	; We've completed our draw routines and we've written a handler for most
	; operations to be handled arbitrarily.
	; Now what we will need to do is set up data.
	; Without this data, our program won't actually know how to handle the opcodes
	; as it reads them.

	; Here's what I think is the best use of macros:
	; We'll begin by initializing some tables for our opcode data

	; This table will hold 16-bit vectors for the instruction's handler routine.
	; FILLWORD tells asar to use a specific 16-bit filler value.
	; FILL tells asar to fill that many bytes bytes.
	; We're using a filler value of $0000 for 512 bytes.
	; We've written 256*2 to make it clear that we have 256 entries of 2 bytes each
OpCodeRun:
	fillword $0000 : fill 256*2

	; This table will hold the characters used to draw the mnemonic.
OpCodeDraw:
	fillbyte $0000 : fill 256*2	

	; This table will hold the addressing mode and function type.
OpCodeFunc:
	fillbyte $0000 : fill 256*2

	; Here's another bastardized define.
	; We'll use "this" (literally) to mean that the handler routine is actually
	; right after the macro definition.
this = 0

	; This macro is what we'll use to define every opcode.
	;
	; Here's how it works:
	; PUSHPC saves the current program counter write address
	; the org statements then take us to the entry's location in the data tables
	; PULLPC recovers the program counter, which was changed by the orgs
	; This basic technique allows us to keep data together in source code
	; but segregated in rom
	;
	; For our sanity, let's also document each parameter:
	;   op    - Instruction opcode ($00-$FF)
	;   name  - Instruction name (used to create labels)
	;   char1 - Character 1 for instruction draw
	;   char2 - Character 2 for instruction draw
	;   addm  - Addressing mode ID
	;   addt  - Addressing mode function type
	;   hand  - Disassembly handler
	;
	; This is also where we'll be using many of the "variables" we created
	; in defines.asm.
macro addop(op, name, char1, char2, addm, addt, hand)
	pushpc

	; This select statement will compare the routine we input to "this".
	; If we wrote "this", then it will automatically use the label created
	; inside the macro with the same name as "name".
	org OpCodeRun+<op>*2
		dw select(equal(<hand>,this), <name>, <hand>)

	org OpCodeDraw+<op>*2
		db <char1>, <char2>

	; addm is multiplied by 2 because it will always be used to
	; index a table of 16-bit words.
	org OpCodeFunc+<op>*2
		db <addm>*2, <addt>

	pullpc

	; This will create a label matching the name we passed.
	; It was done after pullpc, so it will be at the same address
	; the program counter was at before the org statements.
<name>:
endmacro

	; Luckily, our first instruction is something we need to handle manually!
	; That  allows us to review the "this" functionality we just saw.
	; We can't see it, but there is indeed a label named "OP_00_BRK".
	; You can imagine it as being just below this macro call.
	; The first entry in our OpCodeRun table will be dw "OP_00_BRK".
	; All of this is handled by the macro.
%addop($00, "OP_00_BRK", BR, K_, IMM, NOTHIN, this)
	; This routine was covered at the very beginning.
	; We use this to set up registers and the stack.
	JSR PrepSoftwareInterrupt

	; Next, we want to set the program bank to 00
	; by zeroing the high and bank bytes together.
	STZ.b DP.ROM_READ+1

	; Here, we'll load the value of the native mode vector
	; this will cover half the cases
	LDA.l NAT_VECTOR_BRK

	; BRK is an interesting case, because, in emulation mode
	; it actually shares the same vector as IRQ.
	; We'll use the offset we programmed into PrepSoftwareInterrupt
	; to test for native or emulation mode.
	; if X=0, then we're in nativemode, and can use NAT_VECTOR_BRK
	; that we've already loaded.
	CPX.b #0
	BEQ .native_mode

	; For emulation mode, we'll want to set the X flag of REG_P.
	; In emulation mode, this is actually the B flag, used to distinguish
	; a BRK interrupt from an IRQ interrupt.
	; After we do that, we'll load the emulation IRQ vector for our program counter.
.emu_mode
	LDA.w #$0010
	TSB.b DP.REG_P

	LDA.l EMU_VECTOR_IRQ

.native_mode
	STA.b DP.ROM_READ+0
	RTS

	; Many instructions will be pointing to IsolateAndExecute routines.
	; In this case, we need to take memory safety precautions,
	; and our operand is 1 byte in size (so the instruction is 2 bytes total).
	; Thus, we want IsolateAndExecuteSafely_2
%addop($01, "OP_01_ORA_DP_X_IND", OR, Ab, DP_X_IND, ORA_A, IsolateAndExecuteSafely_2)

	; COP is another software interrupt, but this time, we can use the offset
	; calculated for us by PrepSoftwareInterrupt.
	; If we're in native mode, X will be 0, and we'll load NAT_VECTOR_COP.
	; If we're in emulation mode, X will be 16, and we'll load NAT_VECTOR_COP+16
	; which is the same as loading EMU_VECTOR_COP
%addop($02, "OP_02_COP", CO, P_, IMM, NOTHIN, this)
	JSR PrepSoftwareInterrupt

	STZ.b DP.ROM_READ+1
	LDA.l NAT_VECTOR_COP,X

	STA.b DP.ROM_READ+0
	RTS

%addop($03, "OP_03_ORA_SR", OR, A_, SR, ORA_A, IsolateAndExecuteSafely_2)

%addop($04, "OP_04_TSB_DP", TS_, Bb, DP, TSB_A, IsolateAndExecuteSafely_2)

%addop($05, "OP_05_ORA_DP", OR, Ab, DP, ORA_A, IsolateAndExecuteSafely_2)

%addop($06, "OP_06_ASL_DP", AS, Lb, DP, ASL_IT, IsolateAndExecuteSafely_2)

%addop($07, "OP_07_ORA_DP_IND", OR, Ab, DP_IND, ORA_A, IsolateAndExecuteSafely_2)

	; For stack operations, we can't execute them in isolation.
	; We'll use the built in stack operations and then continue with the NEXT_OP
	; routines we made, that advance the program counter.
	; For stack operations, we also don't want any operand drawn, as there is none
	; so we mark them with IMP for IMPlied.
%addop($08, "OP_08_PHP", PH, P_, IMP, NOTHIN, this)
	JSR PushToStack_REG_P
	JMP NEXT_OP_1

	; Immediate mode instructions don't need any safety precautions.
	; We can use the IsolateAndExecute routines without safeguarding
	; to  copy the instruction directly and execute it.
%addop($09, "OP_09_ORA_IMM", OR, Ab, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

	; ASL is an implied addressing mode, but we put A_REG to tell it to draw
	; the A for accumulator explicitly as the operand.
%addop($0A, "OP_0A_ASL_A", AS, L_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($0B, "OP_0B_PHD", PH, D_, IMP, NOTHIN, this)
	JSR PushToStack_REG_D
	JMP NEXT_OP_1

%addop($0C, "OP_0C_TSB_ADDR", TS_, Bw, ABS, TSB_A, IsolateAndExecuteSafely_3)

%addop($0D, "OP_0D_ORA_ADDR", OR, Aw, ABS, ORA_A, IsolateAndExecuteSafely_3)

%addop($0E, "OP_0E_ASL_ADDR", AS, Lw, ABS, ASL_IT, IsolateAndExecuteSafely_3)

%addop($0F, "OP_0F_ORA_LONG", OR, Al, LONG, ORA_A, IsolateAndExecuteSafely_4)

	; For branch instructions, we'll want to first test the relevant flag.
	; We only set up our DoBranching routine to handle one half of the flags.
	; In this case, BPL should branch when N=0.
	; Gor DoBranching to successfully branch, we'll need to flip it using EOR.
	; Now, if the "emulated" N flag is reset, our processor status will have
	; N set, and allow branching, and vice versa for it being set.
	;
	; We also know that all these routines will enter with M and X reset
	; So we'll read the flag minus 1 to get the desired bit.
	; That way we can stay in 16-bit mode and save a couple instructions.
%addop($10, "OP_10_BPL", BP, L_, REL, NOTHIN, this)
	LDA.b DP.REG_P.N-1
	EOR.w #$8000
	JMP DoBranching

%addop($11, "OP_11_ORA_DP_IND_Y", OR, Ab, DP_IND_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($12, "OP_12_ORA_DP_IND", OR, Ab, DP_IND, ORA_A, IsolateAndExecuteSafely_2)

%addop($13, "OP_13_ORA_SR_IND_Y", OR, A_, SR_IND_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($14, "OP_14_TRB_DP", TR, Bb, DP, TRB_A, IsolateAndExecuteSafely_2)

%addop($15, "OP_15_ORA_DP_X", OR, Ab, DP_X, ORA_A, IsolateAndExecuteSafely_2)

%addop($16, "OP_16_ASL_DP_X", AS, Lb, DP_X, ASL_IT, IsolateAndExecuteSafely_2)

%addop($17, "OP_17_ORA_DP_IND_L_Y", OR, Ab, DP_IND_L_Y, ORA_A, IsolateAndExecuteSafely_2)

%addop($18, "OP_18_CLC", CL, C_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($19, "OP_19_ORA_ABS_Y", OR, Aw, ABS_Y, ORA_A, IsolateAndExecuteSafely_3)

%addop($1A, "OP_1A_INC", IN, C_, A_REG, NOTHIN, IsolateAndExecute_1)

	; TCS, which gives the accumulator to the stack pointer is very simple.
	; It also has no effect on the processor status,
	; but because we're handling the stack separately from everything else
	; We'll want to handle this transfer manually.
%addop($1B, "OP_1B_TCS", TC, S_, IMP, NOTHIN, this)
	LDA.b DP.REG_A
	STA.b DP.REG_SR
	JMP NEXT_OP_1

%addop($1C, "OP_1C_TRB_ABS", TR, Bw, ABS, TRB_A, IsolateAndExecuteSafely_3)

%addop($1D, "OP_1D_ORA_ABS_X", OR, Aw, ABS_X, ORA_A, IsolateAndExecuteSafely_3)

%addop($1E, "OP_1E_ASL_ABS_X", AS, Lw, ABS_X, ASL_IT, IsolateAndExecuteSafely_3)

%addop($1F, "OP_1F_ORA_LONG_X", OR, Al, LONG_X, ORA_A, IsolateAndExecuteSafely_4)

	; JSR will need to push the current program counter to "emulated" stack
	; before we move the program counter.
%addop($20, "OP_20_JSR", JS, R_, JMP_ABS, NOTHIN, this)
	JSR PushToStack_JSR

	; Rather than mess with Y, we'll save a single byte and increment our
	; program counter to get the operand
	; After all, we'll be changing it momentarily.
	REP #$30

	; We'll also allow JMP to share this code by creating a label.
	; We'll put the REP #$30 before the label because, as mentioned above,
	; we know all these routines will be entered with both M and X in 16-bit mode.
	; JMP will enter here directly, so we can guarantee it will be in that state.
#HandleJMP:
	INC.b DP.ROM_READ
	LDA.b [DP.ROM_READ]
	STA.b DP.ROM_READ

	RTS

%addop($21, "OP_21_AND_DP_X_IND", AN, Db, DP_X_IND, AND_A, IsolateAndExecuteSafely_2)

	; This is similar to JSR, but we have some more memory precautions
	; that we need to take care of manually
%addop($22, "OP_22_JSL", JS, L_, JMP_LONG, NOTHIN, this)
	JSR PushToStack_JSL

	REP #$20

	; Like JMP is with JSR, JML is the same as JSL, but without a stack push.
	; We'll put a label here so that JML can share the code
#HandleJML:
	SEP #$10
	; First, we'll get the bank byte of the operand and give it to X
	LDY.b #3
	LDA.b [DP.ROM_READ],Y
	TAX

	; But because we know we might execute something in bank $7E,
	; we need to change it to 7F so we don't accidentally execute the wrong code.
	; This way, the "emulated" system will be able to do isolation exactly
	; as we are, without any interference.
	CPX.b #$7E
	BNE ++

	LDX.b #$7F

	; Once our bank is settled, we can copy the address over.
++	LDY.b #1
	LDA.b [DP.ROM_READ],Y

	; And save both.
	STA.b DP.ROM_READ
	STX.b DP.ROM_READ.b

	RTS

%addop($23, "OP_23_AND_SR", AN, D_, SR, AND_A, IsolateAndExecuteSafely_2)

%addop($24, "OP_24_BIT_DP", BI, Tb, DP, BIT_A, IsolateAndExecuteSafely_2)

%addop($25, "OP_25_AND_DP", AN, Db, DP, AND_A, IsolateAndExecuteSafely_2)

%addop($26, "OP_26_ROL_DP", RO, Lb, DP, ROL_IT, IsolateAndExecuteSafely_2)

%addop($27, "OP_27_AND_DP_IND_L", AN, Db, DP_IND_L, AND_A, IsolateAndExecuteSafely_2)

%addop($28, "OP_28_PLP", PL, P_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_P
	JMP NEXT_OP_1

%addop($29, "OP_29_AND_IMM", AN, Db, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($2A, "OP_2A_ROL", RO, L_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($2B, "OP_2B_PLD", PL, D_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_D
	JMP NEXT_OP_1

%addop($2C, "OP_2C_BIT_ABS", BI, Tw, ABS, BIT_A, IsolateAndExecuteSafely_3)

%addop($2D, "OP_2D_AND_ABS", AN, Dw, ABS, AND_A, IsolateAndExecuteSafely_3)

%addop($2E, "OP_2E_ROL_ABS", RO, Lw, ABS, ROL_IT, IsolateAndExecuteSafely_3)

%addop($2F, "OP_2F_AND_LONG", AN, Dl, LONG, AND_A, IsolateAndExecuteSafely_4)

	; This instruction is the opposite of BPL.
	; Which, as you may remember, we had to flip the bit for.
	; Because this is the opposite, we can leave the bit as is.
%addop($30, "OP_30_BMI", BM, I_, REL, NOTHIN, this)
	LDA.b DP.REG_P.N-1
	JMP DoBranching

%addop($31, "OP_31_AND_DP_IND_Y", AN, Db, DP_IND_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($32, "OP_32_AND_DP_IND", AN, Db, DP_IND, AND_A, IsolateAndExecuteSafely_2)

%addop($33, "OP_33_AND_SR_IND_Y", AN, D_, SR_IND_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($34, "OP_34_BIT_DP_X", BI, Tb, DP_X, BIT_A, IsolateAndExecuteSafely_2)

%addop($35, "OP_35_AND_DP_X", AN, Db, DP_X, AND_A, IsolateAndExecuteSafely_2)

%addop($36, "OP_36_ROL_DP_X", RO, Lb, DP_X, ROL_IT, IsolateAndExecuteSafely_2)

%addop($37, "OP_37_AND_DP_IND_L_Y", AN, Db, DP_IND_L_Y, AND_A, IsolateAndExecuteSafely_2)

%addop($38, "OP_38_SEC", SE, C_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($39, "OP_39_AND_ABS_Y", AN, Dw, ABS_Y, AND_A, IsolateAndExecuteSafely_3)

%addop($3A, "OP_3A_DEC", DE, C_, A_REG, NOTHIN, IsolateAndExecute_1)

	; The opposite of TCS.
	; Regardless of bit mode, all 16-bytes of the stack pointer are given to A.
	; This will affect the N and Z flags, with all 16-bits matterinf,
	; even when A is in 8 bit mode.
%addop($3B, "OP_3B_TSC", TS_, C_, IMP, NOTHIN, this)
	LDA.b DP.REG_SR
	STA.b DP.REG_A
	JSR SetFlags_from_PreloadedValue
	JMP NEXT_OP_1

%addop($3C, "OP_3C_BIT_ABS_X", BI, Tw, ABS_X, BIT_A, IsolateAndExecuteSafely_3)

%addop($3D, "OP_3D_AND_ABS_X", AN, Dw, ABS_X, AND_A, IsolateAndExecuteSafely_3)

%addop($3E, "OP_3E_ROL_ABS_X", RO, Lw, ABS_X, ROL_IT, IsolateAndExecuteSafely_3)

%addop($3F, "OP_3F_AND_LONG_X", AN, Dl, LONG_X, AND_A, IsolateAndExecuteSafely_4)

	; Here we're using the stack pull routine directly in our macro.
	; There's nothing further to do once we've pulled the processor and address back.
	; And because the program counter will be set by this RTI
	; there's no use for the NEXT_OP routines.
%addop($40, "OP_40_RTI", RT, I_, IMP, NOTHIN, PullFromStack_RTI)

%addop($41, "OP_41_EOR_DP_X_IND", EO, Rb, DP_X_IND, EOR_A, IsolateAndExecuteSafely_2)

	; WDM is a reserved byte for future expansion (that never happened).
	; It behaves as a No OPeration, but it's 2 bytes long.
	; You can use WDM in your code as a break point
	; as some debugging emulators allow a "Break on WDM".
	; This makes it very easy to find code without knowing its address.
	; You can just type WDM wherever you need to watch and then re-assemble.
	; Once finished, you can remove the WDM.
%addop($42, "OP_42_WDM", WD, M_, IMM, NOTHIN, NEXT_OP_2)

%addop($43, "OP_43_EOR_SR", EO, R_, SR, EOR_A, IsolateAndExecuteSafely_2)

	; Block moves are difficult to handle.
	; So we won't.
	; We'll just skip over them.
	; And that's fine, because we don't have any block moves in our code.
%addop($44, "OP_44_MVP_BLK", MV, P_, BLK, NOTHIN, NEXT_OP_3)

%addop($45, "OP_45_EOR_DP", EO, Rb, DP, EOR_A, IsolateAndExecuteSafely_2)

%addop($46, "OP_46_LSR_DP", LS, Rb, DP, LSR_IT, IsolateAndExecuteSafely_2)

%addop($47, "OP_47_EOR_DP_IND_L", EO, Rb, DP_IND_L, EOR_A, IsolateAndExecuteSafely_2)

%addop($48, "OP_48_PHA", PH, A_, IMP, NOTHIN, this)
	JSR PushToStack_REG_A
	JMP NEXT_OP_1

%addop($49, "OP_49_EOR_IMM", EO, Rb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($4A, "OP_4A_LSR", LS, R_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($4B, "OP_4B_PHK", PH, K_, IMP, NOTHIN, this)
	JSR PushToStack_PROGRAM_BANK
	JMP NEXT_OP_1

	; Similar to JSR, but there's nothing to push to stack before changing our pc.
	; We'll share the code we wrote for JSR earlier.
%addop($4C, "OP_4C_JMP", JM, P_, JMP_ABS, NOTHIN, HandleJMP)

%addop($4D, "OP_4D_EOR_ABS", EO, Rw, ABS, EOR_A, IsolateAndExecuteSafely_3)

%addop($4E, "OP_4E_LSR_ABS", LS, Rw, ABS, LSR_IT, IsolateAndExecuteSafely_3)

%addop($4F, "OP_4F_EOR_LONG", EO, Rl, LONG, EOR_A, IsolateAndExecuteSafely_4)

	; This tests for the overflow flag being clear.
	; Like with BPL, we need to flip the flag after reading it
	; before we continue at DoBranching.
%addop($50, "OP_50_BVC", BV, C_, REL, NOTHIN, this)
	LDA.b DP.REG_P.V-1
	EOR.w #$8000
	JMP DoBranching

%addop($51, "OP_51_EOR_DP_IND_Y", EO, Rb, DP_IND_Y, EOR_A, IsolateAndExecuteSafely_2)

%addop($52, "OP_52_EOR_DP_IND", EO, Rb, DP_IND, EOR_A, IsolateAndExecuteSafely_2)

%addop($53, "OP_53_EOR_SR_IND_Y", EO, R_, SR_IND_Y, EOR_A, IsolateAndExecuteSafely_2)

	; The other block move.
	; Also ignored.
%addop($54, "OP_54_MVN_BLK", MV, N_, BLK, NOTHIN, NEXT_OP_3)

%addop($55, "OP_55_EOR_DP_X", EO, Rb, DP_X, EOR_A, IsolateAndExecuteSafely_2)

%addop($56, "OP_56_LSR_DP_X", LS, Rb, DP_X, LSR_IT, IsolateAndExecuteSafely_2)

%addop($57, "OP_57_EOR_DP_IND_L_Y", EO, Rb, DP_IND_L_Y, EOR_A, IsolateAndExecuteSafely_2)

%addop($58, "OP_58_CLI", CL, I_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($59, "OP_59_EOR_ABS_Y", EO, Rw, ABS_Y, EOR_A, IsolateAndExecuteSafely_3)

%addop($5A, "OP_5A_PHY", PH, Y_, IMP, NOTHIN, this)
	JSR PushToStack_REG_Y
	JMP NEXT_OP_1

	; Unlike TCS, we're handling the D register in our isolated code
	; so we don't need to handle it with a custom routine.
%addop($5B, "OP_5B_TCD", TC, D_, IMP, NOTHIN, IsolateAndExecute_1)

	; Here's where we make use of that HandleJML label created.
	; It will run the same code as JSL, but skip the address push to stack.
%addop($5C, "OP_5C_JML", JM, L_, JMP_LONG, NOTHIN, HandleJML)

%addop($5D, "OP_5D_EOR_ABS_X", EO, Rw, ABS_X, EOR_A, IsolateAndExecuteSafely_3)

%addop($5E, "OP_5E_LSR_ABS_X", LS, Rw, ABS_X, LSR_IT, IsolateAndExecuteSafely_3)

%addop($5F, "OP_5F_EOR_LONG_X", EO, Rl, LONG_X, EOR_A, IsolateAndExecuteSafely_4)

	; Like RTI, we can go directly to the stack pull routine with RTS.
%addop($60, "OP_60_RTS", RT, S_, IMP, NOTHIN, PullFromStack_RTS)

%addop($61, "OP_61_ADC_DP_X_IND", AD, Cb, DP_X_IND, ADC_A, IsolateAndExecuteSafely_2)

	; PER is an interesting, but fairly useless instruction for the SNES.
	; It effectively pushes an offset to stack that can be used as a branch.
	; This was useful for relocatable code on operating systems, but with how
	; the SNES tends to be programmed, it's often an inferior way of doing things.
%addop($62, "OP_62_PER_REL_L", PE, R_, REL_L, NOTHIN, this)
	CLC
	LDY.w #1
	LDA.b [DP.ROM_READ],Y
	INC
	INC
	INC
	ADC.b DP.ROM_READ
	JSR PushToStack_push_2
	JMP NEXT_OP_3

%addop($63, "OP_63_ADC_SR", AD, C_, SR, ADC_A, IsolateAndExecuteSafely_2)

%addop($64, "OP_64_STZ_DP", ST, Zb, DP, STZ_IT, IsolateAndExecuteSafely_2)

%addop($65, "OP_65_ADC_DP", AD, Cb, DP, ADC_A, IsolateAndExecuteSafely_2)

%addop($66, "OP_66_ROR_DP", RO, Rb, DP, ROR_IT, IsolateAndExecuteSafely_2)

%addop($67, "OP_67_ADC_DP_IND_L", AD, Cb, DP_IND_L, ADC_A, IsolateAndExecuteSafely_2)

%addop($68, "OP_68_PLA", PL, A_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_A
	JMP NEXT_OP_1

%addop($69, "OP_69_ADC_IMM", AD, Cb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($6A, "OP_6A_ROR", RO, R_, A_REG, NOTHIN, IsolateAndExecute_1)

%addop($6B, "OP_6B_RTL", RT, L_, IMP, NOTHIN, PullFromStack_RTL)

%addop($6C, "OP_6C_JMP_ABS_IND", JM, Pw, ABS_IND, RELOC, IsolateAndExecuteSafely_0)

%addop($6D, "OP_6D_ADC_ABS", AD, Cw, ABS, ADC_A, IsolateAndExecuteSafely_3)

%addop($6E, "OP_6E_ROR_ABS", RO, Rw, ABS, ROR_IT, IsolateAndExecuteSafely_3)

%addop($6F, "OP_6F_ADC_LONG", AD, Cl, LONG, ADC_A, IsolateAndExecuteSafely_4)

%addop($70, "OP_70_BVS", BV, S_, REL, NOTHIN, this)
	LDA.b DP.REG_P.V-1
	JMP DoBranching

%addop($71, "OP_71_ADC_DP_IND_Y", AD, Cb, DP_IND_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($72, "OP_72_ADC_DP_IND", AD, Cb, DP_IND, ADC_A, IsolateAndExecuteSafely_2)

%addop($73, "OP_73_ADC_SR_IND_Y", AD, C_, SR_IND_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($74, "OP_74_STZ_DP_X", ST, Zb, DP_X, STZ_IT, IsolateAndExecuteSafely_2)

%addop($75, "OP_75_ADC_DP_X", AD, Cb, DP_X, ADC_A, IsolateAndExecuteSafely_2)

%addop($76, "OP_76_ROR_DP_X", RO, Rb, DP_X, ROR_IT, IsolateAndExecuteSafely_2)

%addop($77, "OP_77_ADC_DP_IND_L_Y", AD, Cb, DP_IND_L_Y, ADC_A, IsolateAndExecuteSafely_2)

%addop($78, "OP_78_SEI", SE, I_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($79, "OP_79_ADC_ABS_Y", AD, Cw, ABS_Y, ADC_A, IsolateAndExecuteSafely_3)

%addop($7A, "OP_7A_PLY", PL, Y_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_Y
	JMP NEXT_OP_1

%addop($7B, "OP_7B_TDC", TD, C_, IMP, NOTHIN, IsolateAndExecute_1)

	; Remember, JMP (addr,X) uses program bank.
	; But also remember that we took care of that quirk in GetEffectiveAddress.
%addop($7C, "OP_7C_JMP_ABS_X_IND", JM, Pw, ABS_X_IND, RELOC, IsolateAndExecuteSafely_0)

%addop($7D, "OP_7D_ADC_ABS_X", AD, Cw, ABS_X, ADC_A, IsolateAndExecuteSafely_3)

%addop($7E, "OP_7E_ROR_ABS_X", RO, Rw, ABS_X, ROR_IT, IsolateAndExecuteSafely_3)

%addop($7F, "OP_7F_ADC_LONG_X", AD, Cl, LONG_X, ADC_A, IsolateAndExecuteSafely_4)

	; We could have created a label that skips any testing for this,
	; but this is a good opportunity to show again that we can use SEP or REP
	; for any flag, not just the M and X flags.
	; In this case, we're setting the N flag to force DoBranching to continue.
%addop($80, "OP_80_BRA", BR, A_, REL, NOTHIN, this)
	SEP #$80
	JMP DoBranching

%addop($81, "OP_81_STA_DP_X_IND", ST, Ab, DP_X_IND, SAVE_A, IsolateAndExecuteSafely_2)

	; Unlike BRA, we'll just use an existing label here.
	; Mostly because there is only one long branching instruction,
	; so we never included a test there to begin with.
%addop($82, "OP_82_BRL", BR, L_, REL_L, NOTHIN, DoBranchingLong)

%addop($83, "OP_83_STA_SR", ST, A_, SR, SAVE_A, IsolateAndExecuteSafely_2)

%addop($84, "OP_84_STY_DP", ST, Yb, DP, SAVE_Y, IsolateAndExecuteSafely_2)

%addop($85, "OP_85_STA_DP", ST, Ab, DP, SAVE_A, IsolateAndExecuteSafely_2)

%addop($86, "OP_86_STX_DP", ST, Xb, DP, SAVE_X, IsolateAndExecuteSafely_2)

%addop($87, "OP_87_STA_DP_IND_L", ST, Ab, DP_IND_L, SAVE_A, IsolateAndExecuteSafely_2)

%addop($88, "OP_88_DEY", DE, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($89, "OP_89_BIT_IMM", BI, Tb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($8A, "OP_8A_TXA", TX, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($8B, "OP_8B_PHB", PH, B_, IMP, NOTHIN, this)
	JSR PushToStack_DATA_BANK
	JMP NEXT_OP_1

%addop($8C, "OP_8C_STY_ABS", ST, Yw, ABS, SAVE_Y, IsolateAndExecuteSafely_3)

%addop($8D, "OP_8D_STA_ABS", ST, Aw, ABS, SAVE_A, IsolateAndExecuteSafely_3)

%addop($8E, "OP_8E_STX_ABS", ST, Xw, ABS, SAVE_X, IsolateAndExecuteSafely_3)

%addop($8F, "OP_8F_STA_LONG", ST, Al, LONG, SAVE_A, IsolateAndExecuteSafely_4)

%addop($90, "OP_90_BCC", BC, C_, REL, NOTHIN, this)
	LDA.b DP.REG_P.C-1
	EOR.w #$8000
	JMP DoBranching

%addop($91, "OP_91_STA_DP_IND_Y", ST, Ab, DP_IND_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($92, "OP_92_STA_DP_IND", ST, Ab, DP_IND, SAVE_A, IsolateAndExecuteSafely_2)

%addop($93, "OP_93_STA_SR_IND_Y", ST, A_, SR_IND_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($94, "OP_94_STY_DP_X", ST, Yb, DP_X, SAVE_Y, IsolateAndExecuteSafely_2)

%addop($95, "OP_95_STA_DP_X", ST, Ab, DP_X, SAVE_A, IsolateAndExecuteSafely_2)

%addop($96, "OP_96_STX_DP_Y", ST, Xb, DP_Y, SAVE_X, IsolateAndExecuteSafely_2)

%addop($97, "OP_97_STA_DP_IND_L_Y", ST, Ab, DP_IND_L_Y, SAVE_A, IsolateAndExecuteSafely_2)

%addop($98, "OP_98_TYA", TY, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($99, "OP_99_STA_ABS_Y", ST, Aw, ABS_Y, SAVE_A, IsolateAndExecuteSafely_3)

%addop($9A, "OP_9A_TXS", TX, S_, IMP, NOTHIN, this)
	LDA.b DP.REG_X
	STA.b DP.REG_SR
	JMP NEXT_OP_1

%addop($9B, "OP_9B_TXY", TX, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($9C, "OP_9C_STZ_ABS", ST, Zw, ABS, STZ_IT, IsolateAndExecuteSafely_3)

%addop($9D, "OP_9D_STA_ABS_X", ST, Aw, ABS_X, SAVE_A, IsolateAndExecuteSafely_3)

%addop($9E, "OP_9E_STZ_ABS_X", ST, Zw, ABS_X, STZ_IT, IsolateAndExecuteSafely_3)

%addop($9F, "OP_9F_STA_LONG_X", ST, Al, LONG_X, SAVE_A, IsolateAndExecuteSafely_4)

	; There's not much to say about many of these instructions!
	; See if you can justify the use of the IsolateAndExecute routines yourself.
%addop($A0, "OP_A0_LDY_IMM", LD, Yb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($A1, "OP_A1_LDA_DP_X_IND", LD, Ab, DP_X_IND, READ_A, IsolateAndExecuteSafely_2)

%addop($A2, "OP_A2_LDX_IMM", LD, Xb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($A3, "OP_A3_LDA_SR", LD, A_, SR, READ_A, IsolateAndExecuteSafely_2)

%addop($A4, "OP_A4_LDY_DP", LD, Yb, DP, READ_Y, IsolateAndExecuteSafely_2)

%addop($A5, "OP_A5_LDA_DP", LD, Ab, DP, READ_A, IsolateAndExecuteSafely_2)

%addop($A6, "OP_A6_LDX_DP", LD, Xb, DP, READ_X, IsolateAndExecuteSafely_2)

%addop($A7, "OP_A7_LDA_DP_IND_L", LD, Ab, DP_IND_L, READ_A, IsolateAndExecuteSafely_2)

%addop($A8, "OP_A8_TAY", TA, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($A9, "OP_A9_LDA_IMM", LD, Ab, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($AA, "OP_AA_TAX", TA, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($AB, "OP_AB_PLB", PL, B_, IMP, NOTHIN, this)
	JSR PullFromStack_DATA_BANK
	JMP NEXT_OP_1

%addop($AC, "OP_AC_LDY_ABS", LD, Yw, ABS, READ_Y, IsolateAndExecuteSafely_3)

%addop($AD, "OP_AD_LDA_ABS", LD, Aw, ABS, READ_A, IsolateAndExecuteSafely_3)

%addop($AE, "OP_AE_LDX_ABS", LD, Xw, ABS, READ_X, IsolateAndExecuteSafely_3)

%addop($AF, "OP_AF_LDA_LONG", LD, Al, LONG, READ_A, IsolateAndExecuteSafely_4)

%addop($B0, "OP_B0_BCS", BC, S_, REL, NOTHIN, this)
	LDA.b DP.REG_P.C-1
	JMP DoBranching

%addop($B1, "OP_B1_LDA_DP_IND_Y", LD, Ab, DP_IND_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B2, "OP_B2_LDA_DP_IND", LD, Ab, DP_IND, READ_A, IsolateAndExecuteSafely_2)

%addop($B3, "OP_B3_LDA_SR_IND_Y", LD, A_, SR_IND_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B4, "OP_B4_LDY_DP_X", LD, Yb, DP_X, READ_Y, IsolateAndExecuteSafely_2)

%addop($B5, "OP_B5_LDA_DP_X", LD, Ab, DP_X, READ_A, IsolateAndExecuteSafely_2)

%addop($B6, "OP_B6_LDX_DP_Y", LD, Xb, DP_Y, READ_X, IsolateAndExecuteSafely_2)

%addop($B7, "OP_B7_LDA_DP_IND_L_Y", LD, Ab, DP_IND_L_Y, READ_A, IsolateAndExecuteSafely_2)

%addop($B8, "OP_B8_CLV", CL, V_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($B9, "OP_B9_LDA_ABS_Y", LD, Aw, ABS_Y, READ_A, IsolateAndExecuteSafely_3)

	; This is our unique flag setting situation.
	; We're saving all 16 bits of SR to X, but routines executed later
	; will handle the clearing of the high byte if X is in 8-bit mode.
%addop($BA, "OP_BA_TSX", TS_, X_, IMP, NOTHIN, this)
	LDA.b DP.REG_SR
	STA.b DP.REG_X
	JSR SetFlags_from_X
	JMP NEXT_OP_1

%addop($BB, "OP_BB_TYX", TY, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($BC, "OP_BC_LDY_ABS_X", LD, Yw, ABS_X, READ_Y, IsolateAndExecuteSafely_3)

%addop($BD, "OP_BD_LDA_ABS_X", LD, Aw, ABS_X, READ_A, IsolateAndExecuteSafely_3)

%addop($BE, "OP_BE_LDX_ABS_Y", LD, Xw, ABS_Y, READ_X, IsolateAndExecuteSafely_3)

%addop($BF, "OP_BF_LDA_LONG_X", LD, Al, LONG_X, READ_A, IsolateAndExecuteSafely_4)

%addop($C0, "OP_C0_CPY_IMM", CP, Yb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($C1, "OP_C1_CMP_DP_X_IND", CM, Pb, DP_X_IND, CMP_A, IsolateAndExecuteSafely_2)

%addop($C2, "OP_C2_REP", RE, P_, IMM, NOTHIN, IsolateAndExecute_2)

%addop($C3, "OP_C3_CMP_SR", CM, P_, SR, CMP_A, IsolateAndExecuteSafely_2)

%addop($C4, "OP_C4_CPY_DP", CP, Yb, DP, CPY_Y, IsolateAndExecuteSafely_2)

%addop($C5, "OP_C5_CMP_DP", CM, Pb, DP, CMP_A, IsolateAndExecuteSafely_2)

%addop($C6, "OP_C6_DEC_DP", DE, Cb, DP, DEC_IT, IsolateAndExecuteSafely_2)

%addop($C7, "OP_C7_CMP_DP_IND_L", CM, Pb, DP_IND_L, CMP_A, IsolateAndExecuteSafely_2)

%addop($C8, "OP_C8_INY", IN, Y_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($C9, "OP_C9_CMP_IMM", CM, Pb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($CA, "OP_CA_DEX", DE, X_, IMP, NOTHIN, IsolateAndExecute_1)

	; We won't be "emulating" interrupts, so we'll do nothing for WAI.
%addop($CB, "OP_CB_WAI", WA, I_, IMP, NOTHIN, NEXT_OP_1)

%addop($CC, "OP_CC_CPY_ABS", CP, Yw, ABS, CPY_Y, IsolateAndExecuteSafely_3)

%addop($CD, "OP_CD_CMP_ABS", CM, Pw, ABS, CMP_A, IsolateAndExecuteSafely_3)

%addop($CE, "OP_CE_DEC_ABS", DE, Cw, ABS, DEC_IT, IsolateAndExecuteSafely_3)

%addop($CF, "OP_CF_CMP_LONG", CM, Pl, LONG, CMP_A, IsolateAndExecuteSafely_4)

%addop($D0, "OP_D0_BNE", BN, E_, REL, NOTHIN, this)
	LDA.b DP.REG_P.Z-1
	EOR.w #$8000
	JMP DoBranching

%addop($D1, "OP_D1_CMP_DP_IND_Y", CM, Pb, DP_IND_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D2, "OP_D2_CMP_DP_IND", CM, Pb, DP_IND, CMP_A, IsolateAndExecuteSafely_2)

%addop($D3, "OP_D3_CMP_SR_IND_Y", CM, P_, SR_IND_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D4, "OP_D4_PEI_DP_IND", PE, I_, DP_IND, PEI_IT, IsolateAndExecuteSafely_2)

%addop($D5, "OP_D5_CMP_DP_X", CM, Pb, DP_X, CMP_A, IsolateAndExecuteSafely_2)

%addop($D6, "OP_D6_DEC_DP_X", DE, Cb, DP_X, DEC_IT, IsolateAndExecuteSafely_2)

%addop($D7, "OP_D7_CMP_DP_IND_L_Y", CM, Pb, DP_IND_L_Y, CMP_A, IsolateAndExecuteSafely_2)

%addop($D8, "OP_D8_CLD", CL, D_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($D9, "OP_D9_CMP_ABS_Y", CM, Pw, ABS_Y, CMP_A, IsolateAndExecuteSafely_3)

%addop($DA, "OP_DA_PHX", PH, X_, IMP, NOTHIN, this)
	JSR PushToStack_REG_X
	JMP NEXT_OP_1

	; STP stops the processor completely.
	; And we can emulate that! Why not?
	; If you stick a STP somewhere in code that gets disassembled before
	; the program runs into it, we'll create an infinite loop.
%addop($DB, "OP_DB_STP", ST, P_, IMP, NOTHIN, this)
--	BRA --

%addop($DC, "OP_DC_JMP_ABS_IND", JM, Pw, ABS_IND, RELOC, IsolateAndExecuteSafely_0)

%addop($DD, "OP_DD_CMP_ABS_X", CM, Pw, ABS_X, CMP_A, IsolateAndExecuteSafely_3)

%addop($DE, "OP_DE_DEC_ABS_X", DE, Cw, ABS_X, DEC_IT, IsolateAndExecuteSafely_3)

%addop($DF, "OP_DF_CMP_LONG_X", CM, Pl, LONG_X, CMP_A, IsolateAndExecuteSafely_4)

%addop($E0, "OP_E0_CPX_IMM", CP, Xb, IMM_X, NOTHIN, IsolateAndExecute_IndexImmediate)

%addop($E1, "OP_E1_SBC_DP_X_IND", SB, Cb, DP_X_IND, SBC_A, IsolateAndExecuteSafely_2)

%addop($E2, "OP_E2_SEP", SE, P_, IMM, NOTHIN, IsolateAndExecute_2)

%addop($E3, "OP_E3_SBC_SR", SB, C_, SR, SBC_A, IsolateAndExecuteSafely_2)

%addop($E4, "OP_E4_CPX_DP", CP, Xb, DP, CPX_X, IsolateAndExecuteSafely_2)

%addop($E5, "OP_E5_SBC_DP", SB, Cb, DP, SBC_A, IsolateAndExecuteSafely_2)

%addop($E6, "OP_E6_INC_DP", IN, Cb, DP, INC_IT, IsolateAndExecuteSafely_2)

%addop($E7, "OP_E7_SBC_DP_IND_L", SB, Cb, DP_IND_L, SBC_A, IsolateAndExecuteSafely_2)

%addop($E8, "OP_E8_INX", IN, X_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($E9, "OP_E9_SBC_IMM", SB, Cb, IMM_A, NOTHIN, IsolateAndExecute_AccumulatorImmediate)

%addop($EA, "OP_EA_NOP", NO, P_, IMP, NOTHIN, NEXT_OP_1)

%addop($EB, "OP_EB_XBA", XB, A_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($EC, "OP_EC_CPX_ABS", CP, Xw, ABS, CPX_X, IsolateAndExecuteSafely_3)

%addop($ED, "OP_ED_SBC_ABS", SB, Cw, ABS, SBC_A, IsolateAndExecuteSafely_3)

%addop($EE, "OP_EE_INC_ABS", IN, Cw, ABS, INC_IT, IsolateAndExecuteSafely_3)

%addop($EF, "OP_EF_SBC_LONG", SB, Cl, LONG, SBC_A, IsolateAndExecuteSafely_4)

%addop($F0, "OP_F0_BEQ", BE, Q_, REL, NOTHIN, this)
	LDA.b DP.REG_P.Z-1
	JMP DoBranching

%addop($F1, "OP_F1_SBC_DP_IND_Y", SB, Cb, DP_IND_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F2, "OP_F2_SBC_DP_IND", SB, Cb, DP_IND, SBC_A, IsolateAndExecuteSafely_2)

%addop($F3, "OP_F3_SBC_SR_IND_Y", SB, C_, SR_IND_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F4, "OP_F4_PEA", PE, A_, JMP_ABS, NOTHIN, this)
	LDY.w #1
	LDA.b [DP.ROM_READ],Y

	JSR PushToStack_push_2
	JMP NEXT_OP_3

%addop($F5, "OP_F5_SBC_DP_X", SB, Cb, DP_X, SBC_A, IsolateAndExecuteSafely_2)

%addop($F6, "OP_F6_INC_DP_X", IN, Cb, DP_X, INC_IT, IsolateAndExecuteSafely_2)

%addop($F7, "OP_F7_SBC_DP_IND_L_Y", SB, Cb, DP_IND_L_Y, SBC_A, IsolateAndExecuteSafely_2)

%addop($F8, "OP_F8_SED", SE, D_, IMP, NOTHIN, IsolateAndExecute_1)

%addop($F9, "OP_F9_SBC_ABS_Y", SB, Cw, ABS_Y, SBC_A, IsolateAndExecuteSafely_3)

%addop($FA, "OP_FA_PLX", PL, X_, IMP, NOTHIN, this)
	JSR PullFromStack_REG_X
	JMP NEXT_OP_1

%addop($FB, "OP_FB_XCE", XC, E_, IMP, NOTHIN, this)
	SEP #$20
	; Save our "emulated" carry to our actual carry flag.
	ASL.b DP.REG_P.C

	; Now load our emulation flag and save it to our carry flag.
	LDA.b DP.REG_P.E
	STA.b DP.REG_P.C

	; Shift the carry flag we had before into our emulation flag.
	ROR.b DP.REG_P.E
	JMP NEXT_OP_1

	; IsolateAndExecuteSafely_0 handles everything except the stack push.
	; We'll have to do that ourselves first.
%addop($FC, "OP_FC_JSR_ABS_X_IND", JS, Rw, ABS_X_IND, RELOC, this)
	JSR PushToStack_JSR
	JMP IsolateAndExecuteSafely_0

%addop($FD, "OP_FD_SBC_ABS_X", SB, Cw, ABS_X, SBC_A, IsolateAndExecuteSafely_3)

%addop($FE, "OP_FE_INC_ABS_X", IN, Cw, ABS_X, INC_IT, IsolateAndExecuteSafely_3)

%addop($FF, "OP_FF_SBC_LONG_X", SB, Cl, LONG_X, SBC_A, IsolateAndExecuteSafely_4)

;===============================================================================
; Here's where all our graphics and colors are stored
;===============================================================================
; Graphics are not something you want to do manually.
; You'll want some tool.
; I've included a very simple tool called "singlesheet.jar" with this tutorial.
; I've also included the source images I used to create these graphics.
; For 2bpp images, the format will look like the .png files included.
; There will be a 64*128 space up top, holding 8 rows of 16 tiles
; with a tile size of 16x16.
; Below that is the palettes definition area,
; used to know how to index the image for 2bpp graphics.
; Each set of 4 colors is one of the 8 possible 2bpp palettes you'll use
; You can draw on the top image using the image editor of your choice.
; And you can adjust the palettes as well; just be sure that the colors match.
; The program will the first index that matches, reading from left to right.
; So you may come across problems using the same color in different slots.
; For instances like that, just make that color different in one of the slots,
; because these colors aren't actually going into the SNES.
; They're only used to build an indexed image the SNES can understand
; to create palettes, you can use the macros we went over in defines.asm
; as I've done below.
GFX:
incbin "opcodesgfx.2bpp"
incbin "hexgfx1.2bpp"
incbin "hexgfx2.2bpp"

Palettes:
%col4($000000, $F8F8F8, $F80000, $000000)
%col4($000000, $F8F8F8, $F8E800, $000000)
%col4($000000, $00FFE8, $1098F8, $C000C8)
%col4($000000, $F8F8F8, $1098F8, $00FFE8)

%col4($000000, $F8F8F8, $F85000, $000000)
%col4($000000, $F8F8F8, $F8F8F8, $00FFE8)
%col4($000000, $F8F8F8, $1098F8, $000000)
%col4($000000, $F8F8F8, $0058D8, $000000)

; If you got here by reading through to the bottom, continue on
; by going back to main.asm
; Otherwise, continue where you left off.
