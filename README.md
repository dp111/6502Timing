# 6502Timing
This program test almost all the timing for 6502 instructions including the undocumented instructions. If the program detects an error the instruction is printed out with the timing error detected. The code is design to run on a BBC micro computer with a 1MHz 6522 via. The code is reasonably easy to port to other systems providing there is some form of character output for errors and a timer to time instructions. The code uses macros to simplify the code.   

# Building

To build you need beebasm https://github.com/stardot/beebasm

My build line is 

../beebasm/beebasm -i 6502timing.asm -do 6502timing.ssd -boot 6502tim -v

This creates an SSD that can be shift breaked to start the test.


