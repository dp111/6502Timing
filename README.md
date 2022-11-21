# 6502Timing
This program test almost all the timing for 6502 instructions including the undocumented instructions. If the program detects an error the instruction is printed out with the timing error detected. The code is design to run on a BBC micro computer with a 1MHz 6522 via. The code is reasonably easy to port to other systems providing there is some form of character output for errors and a timer to time instructions. The code uses macros to simplify the code.

The following instructions aren't yet checked ; BRK and of course the HALT instructions

# Building

To build you need beebasm https://github.com/stardot/beebasm

My build line is ( it assumes beebasm directory is in the directory above)

./build.sh

This creates SSDs that can be shift breaked to start the test.
| SSD | Machine |
| ------- | ----- |
|6502timing.ssd    |BBC 6502 instruction timing test suite|
|6502timing1M.ssd  |BBC 6502 instruction timing test suite with absolute address at &FCFE to provoke cycle stretching|
|65C12timing.ssd   |BBC Master 65C12 instruction timing test suite|
|65C12timing1M.ssd |BBC Master 65C12 instruction timing test suite with absolute address at &FCFE to provoke cycle stretching|
|65C02timing.ssd   |BBC upgraded to 65C02 instruction timing test suite|
|65C02timing1M.ssd |BBC upgraded to 65C02 instruction timing test suite with absolute address at &FCFE to provoke cycle stretching|

At the end of the test $FCD0 is written to with the number of failures. Emulators can trap writes to this address and work out if the tests have passed or not. 

# Vectors Build ( .6502)

These versions are the same as the acorn version except they aren't built within an SSD file. The vector versions have a fixed set of vectors that external functions are vectored through. This enables easy patching of the vectors to add custom timer functions for instance. If your code functions are small ( <17bytes) then you can place your code directly at the vector otherwise you will need to JMP to your function.

| Vector | Function |
| ------- | ----- |
| &2000 | Code Entry point |
| &2010 | Display character in A , must preserve X and Y |
| &2020 | Initialise timer and screen etc |
| &2030 | Start timer with the value in A ( depend on the system you may need to add or subtract a constant to take into account timer zero errors). Must preserve X and Y |
| &2040 | Read timer into X |
| &2050 | end of tests A contains the number of failed tests. |

# C64 version ( 6502tim.prg)

This is a special build for C64 machines.



