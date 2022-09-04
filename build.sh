../beebasm/beebasm -i 6502timing.asm -D cpu=0 -D target=0 -do 6502timing.ssd -boot 6502tim -title 6502Timing
../beebasm/beebasm -i 6502timing.asm -D cpu=1 -D target=0 -do 65C12timing.ssd -boot 6502tim -title 65C12Timing
../beebasm/beebasm -i 6502timing.asm -D cpu=0 -D target=1 -do 6502timing1M.ssd -boot 6502tim -title 6502Tim1MH
../beebasm/beebasm -i 6502timing.asm -D cpu=1 -D target=1 -do 65C12timing1M.ssd -boot 6502tim -title 65C12Tim1MH
../beebasm/beebasm -i 6502timing.asm -D cpu=2 -D target=0 -do 65C02timing.ssd -boot 6502tim -title 65C02Timing
../beebasm/beebasm -i 6502timing.asm -D cpu=2 -D target=1 -do 65C02timing1M.ssd -boot 6502tim -title 65C02Tim1MH
../beebasm/beebasm -i 6502timing.asm -D cpu=0 -D target=2
../beebasm/beebasm -i 6502timing.asm -D cpu=0 -D target=0
mv 6502tim 6502timing.6502
../beebasm/beebasm -i 6502timing.asm -D cpu=1 -D target=0
mv 6502tim 65C12timing.6502
../beebasm/beebasm -i 6502timing.asm -D cpu=2 -D target=0
mv 6502tim 65C02timing.6502