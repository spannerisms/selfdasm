:: This is a batch file
:: Batch files, to keep it simple, can be used to run basic Windows commands

:: This line create an empty file called "selfdasm.sfc"
type nul >selfdasm.sfc

:: This tells Windows to run a program named "asar.exe"
:: The text following it are the parameters passed
:: --fixchecksum=on tells asar to automatically calculate the checksum for the header
:: "main.asm" is the assembly code we want to assembly
:: "selfdasm.sfc" is the file we want to assemble to
:: asar.exe can either be in the same folder as the code we are running
:: or you can research how to add PATH variables to call it from anywhere
asar --fix-checksum=on "main.asm" "selfdasm.sfc"

:: This will pause the command prompt after everything is done
:: This allows us to see anything we may have printed during assembly
:: If this were removed, the prompt would close after it finished.
pause

:: To run a batch file, double-click it from File Explorer
:: Once you build this file, you'll be done.
:: And you can watch the ROM we reviewed disassemble itself.