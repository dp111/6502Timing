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




