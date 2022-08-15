;
; Program to test 6502 instruction timings
; By Dominic Plunkett (C) 08/2022
;
; This program is targeted at the BBC micro, but can be changed to other platforms
; it assumes that there is some forum of character output routine @ &FFE3
; it requires a 6522 via clocked at 1MHz assumed to be @ &FE60
; it requires some ram in Zero page and some RAM across a page boundary &0900 used here
; the code is assembled @ &2000

osasci = &FFE3 ; os print byte
viabase	= &FE60 ; base address of 6522 via

;page boundary needs frew space before and afterwards for branch tests
addrFE  = &08FE ; address -2 of page boundary
addrFF  = &08FF ; address -1 of page boundary

;Zero page address
zpx = &70
zp = &71
indirFE = &72 ; indirect address of page boundary -2
indirFF = &74 ; indirect address of page boundary -1
stringptr = &76 
ptr2 = &78
indirtemp = &76
indirtemp2 = &78

imm = &FF ; immediate constant

timeoffset = 64

dresult = 128 ; byte to signify print timing error	

	
MACRO RESET
	LDX #1
	LDY #1
	SEI
ENDMACRO	

MACRO TIME time
	LDA #time+timeoffset
	STA viabase+4
	LDA #0 
	STA viabase+5
ENDMACRO

MACRO STOP
	LDA viabase+4
ENDMACRO

MACRO CHECK
	JSR check
ENDMACRO


MACRO BLOCKCOPY address,start, end
	LDA	#(address) MOD256
	LDX #(address) DIV256
	LDY #end-start
	JSR blockcopy
ENDMACRO
	
ORG &2000         ; code origin
.start
	JSR printstring
	EQUS "6502 instruction timing checking", 13,"Only errors are printed",13,"01= 1 Cycle short, FF= 1 Cycle too long",13,0
	; setup indirect pointers
    LDA #addrFE  MOD 256:STA indirFE
    LDA #addrFE  DIV 256:STA indirFE+1
    LDA #addrFF  MOD 256:STA indirFF
    LDA #addrFF  DIV 256:STA indirFF+1	
	;setup via
	LDA #&7F : STA viabase+&E ; turn off interupts
	LDA #&00 : STA viabase+&B ; setup timer 1
	
	RESET
	
	TIME 2 :ADC #imm :ADC#imm:STOP:CHECK:EQUS "ADC #imm",dresult  
	TIME 3 :ADC zp:ADC zp:STOP:CHECK:EQUS"ADC zp",dresult
	TIME 4 :ADC zpx,X:ADC zpx,X:STOP:CHECK:EQUS"ADC zpx,X",dresult
	;TIME 5 :ADC (indirzp):ADC (indirzp):STOP:CHECK:EQUS"ADC (indirzp)",dresult 
	TIME 4 :ADC addrFF :ADC addrFF :STOP:CHECK:EQUS"ADC addrFF ",dresult 
	TIME 4 :ADC addrFE ,X:ADC addrFE ,X:STOP:CHECK:EQUS"ADC addrFE ,X",dresult 
	TIME 5 :ADC addrFF ,X:ADC addrFF ,X:STOP:CHECK:EQUS"ADC addrFF ,X",dresult 
	TIME 4 :ADC addrFE ,Y:ADC addrFE ,Y:STOP:CHECK:EQUS"ADC addrFE ,Y",dresult 
	TIME 5 :ADC addrFF ,Y:ADC addrFF ,Y:STOP:CHECK:EQUS"ADC addrFF ,Y",dresult 
	TIME 6 :ADC (indirFE,X):ADC (indirFE,X):STOP:CHECK:EQUS"ADC (indirFE,X)",dresult
	TIME 5 :ADC (indirFE),Y: ADC (indirFE),Y:STOP:CHECK:EQUS"ADC (indirFE),Y",dresult
	TIME 6 :ADC (indirFF),Y: ADC (indirFF),Y:STOP:CHECK:EQUS"ADC (indirFF),Y",dresult

	TIME 2 :AND #imm:AND #imm:STOP:CHECK:EQUS"AND #imm",dresult
	TIME 3 :AND zp:AND zp:STOP:CHECK:EQUS"AND zp",dresult
	TIME 4 :AND zpx,X:AND zpx,X:STOP:CHECK:EQUS"AND zpx,X",dresult
	;TIME 5 :AND (indirzp):AND (indirzp):STOP:CHECK:EQUS"AND (indirzp)",dresult 
	TIME 4 :AND addrFF :AND addrFF :STOP:CHECK:EQUS"AND addrFF ",dresult 
	TIME 4 :AND addrFE ,X:AND addrFE ,X:STOP:CHECK:EQUS"AND addrFE ,X",dresult 
	TIME 5 :AND addrFF ,X:AND addrFF ,X:STOP:CHECK:EQUS"AND addrFF ,X",dresult 
	TIME 4 :AND addrFE ,Y:AND addrFE ,Y:STOP:CHECK:EQUS"AND addrFE ,Y",dresult 
	TIME 5 :AND addrFF ,Y:AND addrFF ,Y:STOP:CHECK:EQUS"AND addrFF ,Y",dresult 
	TIME 6 :AND (indirFE,X):AND (indirFE,X):STOP:CHECK:EQUS"AND (indirFE,X)",dresult
	TIME 5 :AND (indirFE),Y: AND (&72),Y:STOP:CHECK:EQUS"AND (indirFE),Y",dresult
	TIME 6 :AND (indirFF),Y: AND (indirFF),Y:STOP:CHECK:EQUS"AND (indirFF),Y",dresult
	
	TIME 2 :ASL A:ASL A:STOP:CHECK:EQUS"ASL A",dresult
	TIME 5 :ASL zp:ASL zp:STOP:CHECK:EQUS"ASL zp",dresult
	TIME 6 :ASL zpx,X:ASL zpx,X:STOP:CHECK:EQUS"ASL zpx,X",dresult
	TIME 6 :ASL addrFE :ASL addrFE :STOP:CHECK:EQUS"ASL addrFE ",dresult
	TIME 7 :ASL addrFE ,X:ASL addrFE ,X:STOP:CHECK:EQUS"ASL addrFE ,X",dresult
	TIME 7 :ASL addrFF ,X:ASL addrFF ,X:STOP:CHECK:EQUS"ASL addrFF ,X",dresult
	
	SEC:TIME 2 :BCC*+2:BCC*+2:STOP:CHECK:EQUS"BCC not taken",dresult
	CLC:TIME 3 :BCC*+2:BCC*+2:STOP:CHECK:EQUS"BCC taken",dresult
	{BLOCKCOPY addrFF-13, bs,be : .bs CLC:TIME 7 :BCC*+4:.b BCC*+6:BCC *+2:BCC b:STOP:RTS:.be : CHECK: EQUS"BCC page cross",dresult:RESET}
	
	CLC:TIME 2 :BCS*+2:BCS*+2:STOP:CHECK:EQUS"BCS not taken",dresult
    SEC:TIME 3 :BCS*+2:BCS*+2:STOP:CHECK:EQUS"BCS taken",dresult
    {BLOCKCOPY addrFF-13, bs,be : .bs SEC:TIME 7 :BCS*+4:.b BCS*+6:BCS *+2:BCS b:STOP:RTS:.be : CHECK: EQUS"BCS page cross",dresult:RESET}
	
	TIME 4 :LDA#1:LDA#1:BEQ*+2:BEQ*+2:STOP:CHECK:EQUS"BEQ not taken",dresult
	TIME 5 :LDA#0:LDA#0:BEQ*+2:BEQ*+2:STOP:CHECK:EQUS"BEQ taken",dresult
	{BLOCKCOPY addrFF-16, bs,be : .bs TIME 9 :LDA#0:LDA#0:BEQ*+4:.b BEQ*+6:BEQ *+2:BEQ b:STOP:RTS:.be : CHECK: EQUS"BEQ page cross",dresult:RESET}
	
	TIME 3 :BIT &FF:BIT &FF:STOP:CHECK:EQUS"BIT &FF",dresult
	TIME 4 :BIT &FFFF:BIT &FFFF:STOP:CHECK:EQUS"BIT &FFFF",dresult
	
	TIME 4 :LDA#1:LDA#1:BMI*+2:BMI*+2:STOP:CHECK:EQUS"BMI not taken",dresult
	TIME 5 :LDA#128:LDA#128::BMI*+2:BMI*+2:STOP:CHECK:EQUS"BMI taken",dresult
	{BLOCKCOPY addrFF-16, bs,be : .bs TIME 9 :LDA#128:LDA#128:BMI*+4:.b BMI*+6:BMI *+2:BMI b:STOP:RTS:.be : CHECK: EQUS"BMI page cross",dresult:RESET}
	
	TIME 4 :LDA#0:LDA#0:BNE*+2:BNE*+2:STOP:CHECK:EQUS"BNE not taken",dresult
	TIME 5 :LDA#1:LDA#1:BNE*+2:BNE*+2:STOP:CHECK:EQUS"BNE taken",dresult
	{BLOCKCOPY addrFF-16, bs,be : .bs TIME 9 :LDA#1:LDA#1:BNE*+4:.b BNE*+6:BNE *+2:BNE b:STOP:RTS:.be : CHECK: EQUS"BNE page cross",dresult:RESET}
	
	TIME 4 :LDA#128:LDA#128:BPL*+2:BPL*+2:STOP:CHECK:EQUS"BPL not taken",dresult
	TIME 5 :LDA#0:LDA#0::BPL*+2:BPL*+2:STOP:CHECK:EQUS"BPL taken",dresult
	{BLOCKCOPY addrFF-16, bs,be : .bs TIME 9 :LDA#0:LDA#0:BPL*+4:.b BPL*+6:BPL *+2:BPL b:STOP:RTS:.be : CHECK: EQUS"BPL page cross",dresult:RESET}
	
	BIT indirFF:TIME 2 :BVC*+2:BVC*+2:STOP:CHECK:EQUS"BVC not taken",dresult
	CLV:TIME 3 :BVC*+2:BVC*+2:STOP:CHECK:EQUS"BVC taken",dresult
	{BLOCKCOPY addrFF-13, bs,be : .bs CLV:TIME 7 :BVC*+4:.b BVC*+6:BVC *+2:BVC b:STOP:RTS:.be : CHECK: EQUS"BVC page cross",dresult:RESET}
	
	CLV:TIME 2 :BVS*+2:BVS*+2:STOP:CHECK:EQUS"BVS not taken",dresult
	BIT indirFF:TIME 3 :BVS*+2:BVS*+2:STOP:CHECK:EQUS"BVS taken",dresult
	{BLOCKCOPY addrFF-14, bs,be : .bs BIT indirFF: TIME 7 :BVS*+4:.b BVS*+6:BVS *+2:BVS b:STOP:RTS:.be : CHECK: EQUS"BVS page cross",dresult:RESET}
	
	TIME 2 :CLC:CLC:STOP:CHECK:EQUS"CLC",dresult
	TIME 2 :CLD:CLD:STOP:CHECK:EQUS"CLD",dresult
	;TIME 2 :CLI:CLI:STOP:CHECK:EQUS"CLI",dresult
	TIME 2 :CLV:CLV:STOP:CHECK:EQUS"CLV",dresult
	
	TIME 2 :CMP #imm:CMP #imm:STOP:CHECK:EQUS"CMP #0xFF",dresult
	TIME 3 :CMP zp:CMP zp:STOP:CHECK:EQUS"CMP zp",dresult
	TIME 4 :CMP zpx,X:CMP zpx,X:STOP:CHECK:EQUS"CMP zpx,X",dresult
	;TIME 5 :CMP (indirzp):CMP (indirzp):STOP:CHECK:EQUS"CMP (indirzp)",dresult 
	TIME 4 :CMP addrFF :CMP addrFF :STOP:CHECK:EQUS"CMP addrFF ",dresult 
	TIME 4 :CMP addrFE ,X:CMP addrFE ,X:STOP:CHECK:EQUS"CMP addrFE ,X",dresult 
	TIME 5 :CMP addrFF ,X:CMP addrFF ,X:STOP:CHECK:EQUS"CMP addrFF ,X",dresult 
	TIME 4 :CMP addrFE ,Y:CMP addrFE ,Y:STOP:CHECK:EQUS"CMP addrFE ,Y",dresult 
	TIME 5 :CMP addrFF ,Y:CMP addrFF ,Y:STOP:CHECK:EQUS"CMP addrFF ,Y",dresult 
	TIME 6 :CMP (indirFE,X):CMP (indirFE,X):STOP:CHECK:EQUS"CMP (indirFE,X)",dresult
	TIME 5 :CMP (indirFE),Y: CMP (indirFE),Y:STOP:CHECK:EQUS"CMP (indirFE),Y",dresult
	TIME 6 :CMP (indirFF),Y: CMP (indirFF),Y:STOP:CHECK:EQUS"CMP (indirFF),Y",dresult
	
	TIME 2 :CPX #imm:CPX #imm:STOP:CHECK:EQUS"CPX #imm",dresult
	TIME 3 :CPX zp:CPX zp:STOP:CHECK:EQUS"CPX zp",dresult
	TIME 4 :CPX addrFF :CPX addrFF :STOP:CHECK:EQUS"CPX addrFF ",dresult
	TIME 2 :CPY #imm:CPY #imm:STOP:CHECK:EQUS"CPY #0xFF",dresult
	TIME 3 :CPY zp:CPY zp:STOP:CHECK:EQUS"CPY zp",dresult
	TIME 4 :CPY addrFF :CPY addrFF :STOP:CHECK:EQUS"CPY addrFF ",dresult
	
	TIME 5 :DEC zp:DEC zp:STOP:CHECK:EQUS"DEC zp",dresult
	TIME 6 :DEC zpx,X:DEC zpx,X:STOP:CHECK:EQUS"DEC zpx,X",dresult
	TIME 6 :DEC addrFE :DEC addrFE :STOP:CHECK:EQUS"DEC addrFE ",dresult
	TIME 7 :DEC addrFE ,X:DEC addrFE ,X:STOP:CHECK:EQUS"DEC addrFE ,X",dresult
	TIME 7 :DEC addrFF ,X:DEC addrFF ,X:STOP:CHECK:EQUS"DEC addrFF ,X",dresult
	
	TIME 2 :DEX:DEX:STOP:CHECK:EQUS"DEX",dresult
	TIME 2 :DEY:DEY:STOP:CHECK:EQUS"DEY",dresult
	
	TIME 2 :EOR #imm:EOR #imm:STOP:CHECK:EQUS"EOR #0xFF",dresult
	TIME 3 :EOR zp:EOR zp:STOP:CHECK:EQUS"EOR zp",dresult
	TIME 4 :EOR zpx,X:EOR zpx,X:STOP:CHECK:EQUS"EOR zpx,X",dresult
	;TIME 5 :EOR (indirzp):EOR (indirzp):STOP:CHECK:EQUS"EOR (indirzp)",dresult 
	TIME 4 :EOR addrFF :EOR addrFF :STOP:CHECK:EQUS"EOR addrFF ",dresult 
	TIME 4 :EOR addrFE ,X:EOR addrFE ,X:STOP:CHECK:EQUS"EOR addrFE ,X",dresult 
	TIME 5 :EOR addrFF ,X:EOR addrFF ,X:STOP:CHECK:EQUS"EOR addrFF ,X",dresult 
	TIME 4 :EOR addrFE ,Y:EOR addrFE ,Y:STOP:CHECK:EQUS"EOR addrFE ,Y",dresult 
	TIME 5 :EOR addrFF ,Y:EOR addrFF ,Y:STOP:CHECK:EQUS"EOR addrFF ,Y",dresult 
	TIME 6 :EOR (indirFE,X):EOR (indirFE,X):STOP:CHECK:EQUS"EOR (indirFE,X)",dresult
	TIME 5 :EOR (indirFE),Y: EOR (indirFE),Y:STOP:CHECK:EQUS"EOR (indirFE),Y",dresult
	TIME 6 :EOR (indirFF),Y: EOR (indirFF),Y:STOP:CHECK:EQUS"EOR (indirFF),Y",dresult
	
	TIME 5 :INC zp:INC zp:STOP:CHECK:EQUS"INC zp",dresult
	TIME 6 :INC zpx,X:INC zpx,X:STOP:CHECK:EQUS"INC zpx,X",dresult
	TIME 6 :INC addrFE :INC addrFE :STOP:CHECK:EQUS"INC addrFE ",dresult
	TIME 7 :INC addrFE ,X:INC addrFE ,X:STOP:CHECK:EQUS"INC addrFE ,X",dresult
	TIME 7 :INC addrFF ,X:INC addrFF ,X:STOP:CHECK:EQUS"INC addrFF ,X",dresult
	
	TIME 2 :INX:INX:STOP:CHECK:EQUS"INX",dresult
	TIME 2 :INY:INY:STOP:CHECK:EQUS"INY",dresult
	
	TIME 3 :JMP *+3:JMP *+3:STOP:CHECK:EQUS"JMP &0000",dresult
	
	{LDA #jmp1 MOD256:STA indirtemp:LDA #jmp1 DIV256:STA indirtemp+1:LDA #jmp2 MOD256:STA indirtemp2:LDA #jmp2 DIV256:STA indirtemp2+1:
	TIME 5 :JMP (indirtemp):.jmp1 JMP(indirtemp2):.jmp2 STOP:CHECK:EQUS"JMP (&0000)",dresult}
	TIME 6 :JSR *+3:JSR *+3:STOP:TAX:PLA:PLA:PLA:PLA:TXA:CHECK:EQUS"JSR &0000",dresult
	
	TIME 2 :LDA #imm:LDA #imm:STOP:CHECK:EQUS"LDA #imm",dresult
	TIME 3 :LDA zp:LDA zp:STOP:CHECK:EQUS"LDA zp",dresult
	TIME 4 :LDA zpx,X:LDA zpx,X:STOP:CHECK:EQUS"LDA zpx,X",dresult
	;TIME 5 :LDA (indirzp):LDA (indirzp):STOP:CHECK:EQUS"LDA (indirzp)",dresult 
	TIME 4 :LDA addrFF :LDA addrFF :STOP:CHECK:EQUS"LDA addrFF ",dresult 
	TIME 4 :LDA addrFE ,X:LDA addrFE ,X:STOP:CHECK:EQUS"LDA addrFE ,X",dresult 
	TIME 5 :LDA addrFF ,X:LDA addrFF ,X:STOP:CHECK:EQUS"LDA addrFF ,X",dresult
	TIME 4 :LDA addrFE ,Y:LDA addrFE ,Y:STOP:CHECK:EQUS"LDA addrFE ,Y",dresult 
	TIME 5 :LDA addrFF ,Y:LDA addrFF ,Y:STOP:CHECK:EQUS"LDA addrFF ,Y",dresult 
	TIME 6 :LDA (indirFF,X):LDA (indirFF,X):STOP:CHECK:EQUS"LDA (indirFF,X)",dresult
	TIME 5 :LDA (indirFE),Y: LDA (indirFE),Y:STOP:CHECK:EQUS"LDA (indirFE),Y",dresult
	TIME 6 :LDA (indirFF),Y: LDA (indirFF),Y:STOP:CHECK:EQUS"LDA (indirFF),Y",dresult
	TIME 2 :LDX #imm:LDX #imm:STOP:CHECK:EQUS"LDX #imm",dresult
	TIME 3 :LDX zp:LDX zp:STOP:CHECK:EQUS"LDX zp",dresult
	TIME 4 :LDX zp,Y:LDX zp,Y:STOP:CHECK:EQUS"LDX zp,Y",dresult
	;TIME 5 :LDX (indirzp):LDX (indirzp):STOP:CHECK:EQUS"LDX (indirzp)",dresult 
	TIME 4 :LDX addrFF :LDX addrFF :STOP:CHECK:EQUS"LDX addrFF ",dresult 
	TIME 4 :LDX addrFE ,Y:LDX addrFE ,Y:STOP:CHECK:EQUS"LDX addrFE ,Y",dresult 
	TIME 5 :LDX addrFF ,Y:LDX addrFF ,Y:STOP:CHECK:EQUS"LDX addrFF ,Y",dresult 
	TIME 2 :LDY #imm:LDY #imm:STOP:CHECK:EQUS"LDY #imm",dresult
	TIME 3 :LDY zp:LDY zp:STOP:CHECK:EQUS"LDY zp",dresult
	TIME 4 :LDY zpx,X:LDY zpx,X:STOP:CHECK:EQUS"LDY zpx,X",dresult
	;TIME 5 :LDY (indirzp):LDY (indirzp):STOP:CHECK:EQUS"LDY (indirzp)",dresult 
	TIME 4 :LDY addrFF :LDY addrFF :STOP:CHECK:EQUS"LDY addrFF ",dresult 
	TIME 4 :LDY addrFE ,X:LDY addrFE ,X:STOP:CHECK:EQUS"LDY addrFE ,X",dresult 
	TIME 5 :LDY addrFF ,X:LDY addrFF ,X:STOP:CHECK:EQUS"LDY addrFF ,X",dresult 
	TIME 2 :LSR A:LSR A:STOP:CHECK:EQUS"LSR A",dresult
	TIME 5 :LSR zp:LSR zp:STOP:CHECK:EQUS"LSR zp",dresult
	TIME 6 :LSR zpx,X:LSR zpx,X:STOP:CHECK:EQUS"LSR zpx,X",dresult
	TIME 6 :LSR addrFE :LSR addrFE :STOP:CHECK:EQUS"LSR addrFE ",dresult
	TIME 7 :LSR addrFE ,X:LSR addrFE ,X:STOP:CHECK:EQUS"LSR addrFE ,X",dresult
	TIME 7 :LSR addrFF ,X:LSR addrFF ,X:STOP:CHECK:EQUS"LSR addrFF ,X",dresult
	TIME 2 :NOP:NOP:STOP:CHECK:EQUS"NOP",dresult

	TIME 2 :ORA #imm:ORA #imm:STOP:CHECK:EQUS"ORA #imm",dresult
	TIME 3 :ORA zp:ORA zp:STOP:CHECK:EQUS"ORA zp",dresult
	TIME 4 :ORA zpx,X:ORA zpx,X:STOP:CHECK:EQUS"ORA zpx,X",dresult
	;TIME 5 :ORA (indirzp):ORA (indirzp):STOP:CHECK:EQUS"ORA (indirzp)",dresult 
	TIME 4 :ORA addrFF :ORA addrFF :STOP:CHECK:EQUS"ORA addrFF ",dresult 
	TIME 4 :ORA addrFE ,X:ORA addrFE ,X:STOP:CHECK:EQUS"ORA addrFE ,X",dresult 
	TIME 5 :ORA addrFF ,X:ORA addrFF ,X:STOP:CHECK:EQUS"ORA addrFF ,X",dresult 
	TIME 4 :ORA addrFE ,Y:ORA addrFE ,Y:STOP:CHECK:EQUS"ORA addrFE ,Y",dresult 
	TIME 5 :ORA addrFF ,Y:ORA addrFF ,Y:STOP:CHECK:EQUS"ORA addrFF ,Y",dresult 
	TIME 6 :ORA (indirFF,X):ORA (indirFF,X):STOP:CHECK:EQUS"ORA (indirFF,X)",dresult
	TIME 5 :ORA (indirFE),Y: ORA (indirFE),Y:STOP:CHECK:EQUS"ORA (indirFE),Y",dresult
	TIME 6 :ORA (indirFF),Y: ORA (indirFF),Y:STOP:CHECK:EQUS"ORA (indirFF),Y",dresult
	TIME 7 :PHA:PHA:PLA:PLA:STOP:CHECK:EQUS"PHA / PLA",dresult
	TIME 7 :PHP:PHP:PLP:PLP:STOP:CHECK:EQUS"PHP / PLP",dresult
	TIME 2 :ROL A:ROL A:STOP:CHECK:EQUS"ROL A",dresult
	TIME 5 :ROL zp:ROL zp:STOP:CHECK:EQUS"ROL zp",dresult
	TIME 6 :ROL zpx,X:ROL zpx,X:STOP:CHECK:EQUS"ROL zpx,X",dresult
	TIME 6 :ROL addrFE :ROL addrFE :STOP:CHECK:EQUS"ROL addrFE ",dresult
	TIME 7 :ROL addrFE ,X:ROL addrFE ,X:STOP:CHECK:EQUS"ROL addrFE ,X",dresult
	TIME 7 :ROL addrFF ,X:ROL addrFF ,X:STOP:CHECK:EQUS"ROL addrFF ,X",dresult
	TIME 2 :ROR A:ROR A:STOP:CHECK:EQUS"ROR A",dresult
	TIME 5 :ROR zp:ROR zp:STOP:CHECK:EQUS"ROR zp",dresult
	TIME 6 :ROR zpx,X:ROR zpx,X:STOP:CHECK:EQUS"ROR zpx,X",dresult
	TIME 6 :ROR addrFE :ROR addrFE :STOP:CHECK:EQUS"ROR addrFE ",dresult
	TIME 7 :ROR addrFE ,X:ROR addrFE ,X:STOP:CHECK:EQUS"ROR addrFE ,X",dresult
	TIME 7 :ROR addrFF ,X:ROR addrFF ,X:STOP:CHECK:EQUS"ROR addrFF ,X",dresult
	
	{LDA #a DIV256: PHA:LDA#a MOD256:PHA :PHP:LDA #b DIV256: PHA:LDA#b MOD256:PHA:PHP
	TIME 6: RTI:.b RTI:.a STOP:CHECK:EQUS"RTI",dresult}
	{LDA #a DIV256: PHA:LDA#a MOD256:PHA:LDA #b DIV256: PHA:LDA#b MOD256:PHA
	TIME 6: .b RTS:.a RTS:STOP:CHECK:EQUS"RTS",dresult}
	
	TIME 2 :SBC #imm:SBC #imm:STOP:CHECK:EQUS"SBC #imm",dresult
	TIME 3 :SBC zp:SBC zp:STOP:CHECK:EQUS"SBC zp",dresult
	TIME 4 :SBC zpx,X:SBC zpx,X:STOP:CHECK:EQUS"SBC zpx,X",dresult
	;TIME 5 :SBC (indirzp):SBC (indirzp):STOP:CHECK:EQUS"SBC (indirzp)",dresult 
	TIME 4 :SBC addrFF :SBC addrFF :STOP:CHECK:EQUS"SBC addrFF ",dresult 
	TIME 4 :SBC addrFE ,X:SBC addrFE ,X:STOP:CHECK:EQUS"SBC addrFE ,X",dresult 
	TIME 5 :SBC addrFF ,X:SBC addrFF ,X:STOP:CHECK:EQUS"SBC addrFF ,X",dresult 
	TIME 4 :SBC addrFE ,Y:SBC addrFE ,Y:STOP:CHECK:EQUS"SBC addrFE ,Y",dresult 
	TIME 5 :SBC addrFF ,Y:SBC addrFF ,Y:STOP:CHECK:EQUS"SBC addrFF ,Y",dresult 
	TIME 6 :SBC (indirFF,X):SBC (indirFF,X):STOP:CHECK:EQUS"SBC (indirFF,X)",dresult
	TIME 5 :SBC (indirFE),Y: SBC (indirFE),Y:STOP:CHECK:EQUS"SBC (indirFE),Y",dresult
	TIME 6 :SBC (indirFF),Y: SBC (indirFF),Y:STOP:CHECK:EQUS"SBC (indirFF),Y",dresult
	TIME 2 :SEC:SEC:STOP:CHECK:EQUS"SEC",dresult
	TIME 2 :SED:SED:STOP:CLD:CHECK:EQUS"SED",dresult
	TIME 2 :SEI:SEI:STOP:CHECK:EQUS"SEI",dresult
	TIME 3 :STA zp:STA zp:STOP:CHECK:EQUS"STA zp",dresult
	TIME 4 :STA zpx,X:STA zpx,X:STOP:CHECK:EQUS"STA zpx,X",dresult
	TIME 4 :STA addrFE :STA addrFE :STOP:CHECK:EQUS"STA addrFE ",dresult
	TIME 5 :STA addrFE ,X:STA addrFE ,X:STOP:CHECK:EQUS"STA addrFE ,X",dresult
	TIME 5 :STA addrFF ,X:STA addrFF ,X:STOP:CHECK:EQUS"STA addrFF ,X",dresult
	TIME 5 :STA addrFE ,Y:STA addrFE ,Y:STOP:CHECK:EQUS"STA addrFE ,Y",dresult
	TIME 5 :STA addrFF ,Y:STA addrFF ,Y:STOP:CHECK:EQUS"STA addrFF ,Y",dresult
	TIME 6 :STA (&72,X):STA (&72,X):STOP:CHECK:EQUS"STA (&72,X)",dresult
	TIME 6 :STA (indirFE),Y: STA (indirFE),Y:STOP:CHECK:EQUS"STA (indirFE),Y",dresult
	TIME 6 :STA (indirFF),Y: STA (indirFF),Y:STOP:CHECK:EQUS"STA (indirFF),Y",dresult
	TIME 3 :STX zp:STX zp:STOP:CHECK:EQUS"STX zp",dresult
	TIME 4 :STX zpx,Y:STX zpx,Y:STOP:CHECK:EQUS"STX zpx,Y",dresult
	TIME 4 :STX addrFE :STX addrFE :STOP:CHECK:EQUS"STX addrFE ",dresult
	TIME 3 :STY zp:STY zp:STOP:CHECK:EQUS"STY zp",dresult
	TIME 4 :STY zpx,X:STY zpx,X:STOP:CHECK:EQUS"STY zpx,X",dresult
	TIME 4 :STY addrFE :STY addrFE :STOP:CHECK:EQUS"STY addrFE ",dresult
	TIME 2 :TAX:TAX:STOP:CHECK:EQUS"TAX",dresult
	TIME 2 :TAY:TAY:STOP:CHECK:EQUS"TAY",dresult
	TIME 2 :TSX:TSX:STOP:CHECK:EQUS"TSX",dresult
	TIME 2 :TXA:TXA:STOP:CHECK:EQUS"TXA",dresult
	TIME 4 :TSX:TXS:TSX:TXS:STOP:CHECK:EQUS"TSX",dresult
	TIME 2 :TYA:TYA:STOP:CHECK:EQUS"TYA",dresult

	JSR printstring:EQUS "Now checking undocumented instructions",13,0
	
	TIME 2 :EQUB &4B,imm:EQUB &4B,imm:STOP:CHECK:EQUS"&4B ALR ( ASR) #imm",dresult
	TIME 2 :EQUB &0B,imm:EQUB &0B,imm:STOP:CHECK:EQUS"&0B ANC ( ANC) #imm",dresult
	TIME 2 :EQUB &2B,imm:EQUB &2B,imm:STOP:CHECK:EQUS"&0B ANC ( ANC 2) #imm",dresult
	TIME 2 :EQUB &8B,imm:EQUB &8B,imm:STOP:CHECK:EQUS"&8B ANE ( XAA) #imm",dresult
	TIME 2 :EQUB &6B,imm:EQUB &6B,imm:STOP:CHECK:EQUS"&6B ARR #imm",dresult
	TIME 5 :EQUB&C7,zp:EQUB&C7,zp:STOP:CHECK:EQUS"&C7 DCP (DCM) zp",dresult
	TIME 6 :EQUB&D7,zpx:EQUB&D7,zpx:STOP:CHECK:EQUS"&D7 DCP (DCM) zpx",dresult
	TIME 6 :EQUB&CF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&CF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&CF DCP (DCM) addrFE",dresult
	TIME 7 :EQUB&DF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&DF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&DF DCP (DCM) addrFE,X",dresult
	TIME 7 :EQUB&DF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&DF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&DF DCP (DCM) addrFF,X",dresult
	TIME 7 :EQUB&DB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&DB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&DB DCP (DCM) addrFE,Y",dresult
	TIME 7 :EQUB&DB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&DB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&DB DCP (DCM) addrFF,Y",dresult
	TIME 8 :EQUB&C3,indirFE:EQUB&C3,indirFE:STOP:CHECK:EQUS"&C3 DCP (DCM) (indirFE,X)",dresult
	TIME 8 :EQUB&D3,indirFE:EQUB&D3,indirFE:STOP:CHECK:EQUS"&D3 DCP (DCM) (indirFE),Y",dresult
	TIME 8 :EQUB&D3,indirFF:EQUB&D3,indirFF:STOP:CHECK:EQUS"&D3 DCP (DCM) (indirFF),Y",dresult
	TIME 5 :EQUB&E7,zp:EQUB&E7,zp:STOP:CHECK:EQUS"&E7 ISC (ISB,INS) zp",dresult
	TIME 6 :EQUB&F7,zpx:EQUB&F7,zpx:STOP:CHECK:EQUS"&F7 ISC (ISB,INS) zpx",dresult
	TIME 6 :EQUB&EF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&EF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&EF ISC (ISB,INS) addrFE",dresult
	TIME 7 :EQUB&FF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&FF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&FF ISC (ISB,INS) addrFE,X",dresult
	TIME 7 :EQUB&FF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&FF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&FF ISC (ISB,INS) addrFF,X",dresult
	TIME 7 :EQUB&FB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&FB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&FB ISC (ISB,INS) addrFE,Y",dresult
	TIME 7 :EQUB&FB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&FB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&FB ISC (ISB,INS) addrFF,Y",dresult
	TIME 8 :EQUB&E3,indirFE:EQUB&E3,indirFE:STOP:CHECK:EQUS"&E3 ISC (ISB,INS) (indirFE,X)",dresult
	TIME 8 :EQUB&F3,indirFE:EQUB&F3,indirFE:STOP:CHECK:EQUS"&F3 ISC (ISB,INS) (indirFE),Y",dresult
	TIME 8 :EQUB&F3,indirFF:EQUB&F3,indirFF:STOP:CHECK:EQUS"&F3 ISC (ISB,INS) (indirFF),Y",dresult
	TSX:STX zpx:LDX#1:TIME 4 :EQUB&BB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&BB:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:LDX zpx:TXS:CHECK:EQUS"&BB LAS (LAR) addrFE,Y",dresult
	TSX:STX zpx:LDX#1:TIME 5 :EQUB&BB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&BB:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:LDX zpx:TXS:CHECK:EQUS"&BB LAS (LAR) addrFF,Y",dresult
	TIME 3 :EQUB&A7,zp:EQUB&A7,zp:STOP:CHECK:EQUS"&A7 LAX zp",dresult
	TIME 4 :EQUB&B7,zpx:EQUB&B7,zpx:STOP:CHECK:EQUS"&B7 LAX zpx",dresult
	TIME 4 :EQUB&AF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&AF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&AF LAX addrFE",dresult
	TIME 4 :EQUB&BF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&BF:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&BF LAX addrFE,Y",dresult
	TIME 5 :EQUB&BF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&BF:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&BF LAX addrFF,Y",dresult
	TIME 7 :EQUB&A3,indirFE:EQUB&A3,indirFE:STOP:CHECK:EQUS"&A3 LAX (indirFE,X)",dresult
	TIME 5 :EQUB&B3,indirFE:EQUB&B3,indirFE:STOP:CHECK:EQUS"&B3 LAX (indirFE),Y",dresult
	TIME 6 :EQUB&B3,indirFF:EQUB&B3,indirFF:STOP:CHECK:EQUS"&B3 LAX (indirFF),Y",dresult
	TIME 2 :EQUB&AB,imm:EQUB&AB,imm:STOP:CHECK:EQUS"&AB LXA #imm",dresult
	TIME 5 :EQUB&27,zp:EQUB&27,zp:STOP:CHECK:EQUS"&27 RLA zp",dresult
	TIME 6 :EQUB&37,zpx:EQUB&37,zpx:STOP:CHECK:EQUS"&37 RLA zpx",dresult
	TIME 6 :EQUB&2F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&2F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&2F RLA addrFE",dresult
	TIME 7 :EQUB&3F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&3F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&3F RLA addrFE,X",dresult
	TIME 7 :EQUB&3F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&3F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&3F RLA addrFF,X",dresult
	TIME 7 :EQUB&3B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&3B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&3B RLA addrFE,Y",dresult
	TIME 7 :EQUB&3B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&3B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&3B RLA addrFF,Y",dresult
	TIME 8 :EQUB&23,indirFE:EQUB&23,indirFE:STOP:CHECK:EQUS"&23 RLA (indirFE,X)",dresult
	TIME 8 :EQUB&33,indirFE:EQUB&33,indirFE:STOP:CHECK:EQUS"&33 RLA (indirFE),Y",dresult
	TIME 8 :EQUB&33,indirFF:EQUB&33,indirFF:STOP:CHECK:EQUS"&33 RLA (indirFF),Y",dresult
	TIME 5 :EQUB&67,zp:EQUB&67,zp:STOP:CHECK:EQUS"&67 RRA zp",dresult
	TIME 6 :EQUB&77,zpx:EQUB&77,zpx:STOP:CHECK:EQUS"&77 RRA zpx",dresult
	TIME 6 :EQUB&6F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&6F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&6F RRA addrFE",dresult
	TIME 7 :EQUB&7F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&7F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&7F RRA addrFE,X",dresult
	TIME 7 :EQUB&7F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&7F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&7F RRA addrFF,X",dresult
	TIME 7 :EQUB&7B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&7B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&7B RRA addrFE,Y",dresult
	TIME 7 :EQUB&7B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&7B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&7B RRA addrFF,Y",dresult
	TIME 8 :EQUB&63,indirFE:EQUB&63,indirFE:STOP:CHECK:EQUS"&63 RRA (indirFE,X)",dresult
	TIME 8 :EQUB&73,indirFE:EQUB&73,indirFE:STOP:CHECK:EQUS"&73 RRA (indirFE),Y",dresult
	TIME 8 :EQUB&73,indirFF:EQUB&73,indirFF:STOP:CHECK:EQUS"&73 RRA (indirFF),Y",dresult
	TIME 3 :EQUB&87,zp:EQUB&87,zp:STOP:CHECK:EQUS"&87 SAX (AAX) zp",dresult
	TIME 4 :EQUB&97,zpx:EQUB&97,zpx:STOP:CHECK:EQUS"&97 SAX (AAX) zpx",dresult
	TIME 4 :EQUB&8F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&8F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&8F SAX addrFE",dresult
	TIME 6 :EQUB&83,indirFE:EQUB&83,indirFE:STOP:CHECK:EQUS"&83 SAX (AAX) (indirFE,X)",dresult
	TIME 2 :EQUB&CB,imm:EQUB&CB,imm:STOP:CHECK:EQUS"&CB SBX #imm",dresult
	TIME 5 :EQUB&9F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&9F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&9F SHA (AHX, AXA) addrFE,Y",dresult
	TIME 5 :EQUB&9F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&9F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&9F SHA (AHX, AXA) addrFF,Y",dresult
	TIME 6 :EQUB&93,indirFE:EQUB&93,indirFE:STOP:CHECK:EQUS"&93 SHA (AHX, AXA) (indirFE),Y",dresult
	TIME 6 :EQUB&93,indirFF:EQUB&93,indirFF:STOP:CHECK:EQUS"&93 SHA (AHX, AXA) (indirFF),Y",dresult
	TIME 5 :EQUB&9E:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&9E:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&9E SHX (A11, SXA, XAS) addrFE,Y",dresult
	TIME 5 :EQUB&9E:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&9E:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&9E SHX (A11, SXA, XAS) addrFF,Y",dresult
	TIME 5 :EQUB&9C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&9C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&9C SHY (A11, SYA, SAY) addrFE,X",dresult
	TIME 5 :EQUB&9C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&9C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&9C SHY (A11, SYA, SAY) addrFF,X",dresult
	TIME 5 :EQUB&07,zp:EQUB07,zp:STOP:CHECK:EQUS"&07 SLO (ASO) zp",dresult
	TIME 6 :EQUB&17,zpx:EQUB&17,zpx:STOP:CHECK:EQUS"&17 SLO (ASO) zpx",dresult
	TIME 6 :EQUB&0F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&0F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&0F SLO (ASO) addrFE",dresult
	TIME 7 :EQUB&1F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&1F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&1F SLO (ASO) addrFE,X",dresult
	TIME 7 :EQUB&1F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&1F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&1F SLO (ASO) addrFF,X",dresult
	TIME 7 :EQUB&1B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&1B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&1B SLO (ASO) addrFE,Y",dresult
	TIME 7 :EQUB&1B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&1B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&1B SLO (ASO) addrFF,Y",dresult
	TIME 8 :EQUB&03,indirFE:EQUB&03,indirFE:STOP:CHECK:EQUS"&03 SLO (ASO) (indirFE,X)",dresult
	TIME 8 :EQUB&13,indirFE:EQUB&13,indirFE:STOP:CHECK:EQUS"&13 SLO (ASO) (indirFE),Y",dresult
	TIME 8 :EQUB&13,indirFF:EQUB&13,indirFF:STOP:CHECK:EQUS"&13 SLO (ASO) (indirFF),Y",dresult
	TIME 5 :EQUB&47,zp:EQUB&47,zp:STOP:CHECK:EQUS"&47 SRE (LSE) zp",dresult
	TIME 6 :EQUB&57,zpx:EQUB&57,zpx:STOP:CHECK:EQUS"&57 SRE (LSE) zpx",dresult
	TIME 6 :EQUB&4F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&4F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&4F SRE (LSE) addrFE",dresult
	TIME 7 :EQUB&5F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&5F:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&5F SRE (LSE) addrFE,X",dresult
	TIME 7 :EQUB&5F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&5F:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&5F SRE (LSE) addrFF,X",dresult
	TIME 7 :EQUB&5B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&5B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&5B SRE (LSE) addrFE,Y",dresult
	TIME 7 :EQUB&5B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&5B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&5B SRE (LSE) addrFF,Y",dresult
	TIME 8 :EQUB&43,indirFE:EQUB&43,indirFE:STOP:CHECK:EQUS"&43 SRE (LSE) (indirFE,X)",dresult
	TIME 8 :EQUB&53,indirFE:EQUB&53,indirFE:STOP:CHECK:EQUS"&53 SRE (LSE) (indirFE),Y",dresult
	TIME 8 :EQUB&53,indirFF:EQUB&53,indirFF:STOP:CHECK:EQUS"&53 SRE (LSE) (indirFF),Y",dresult 
	TSX:STX zpx:TIME 5 :EQUB&9B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&9B:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:LDX zpx:TXS:CHECK:EQUS"&9B TAS (XAS,SHS) addrFE,Y",dresult
	; the following does't correctly test page boundary crossing . We probably shoudl define where in memory this actually accesses
	TSX:STX zpx:TIME 5 :EQUB&9B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&9B:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:LDX zpx:TXS:CHECK:EQUS"&9B TAS (XAS,SHS) addrFF,Y",dresult
	TIME 2 :EQUB&8B,imm:EQUB&8B,imm:STOP:CHECK:EQUS"&EB USBC (SBC) #imm",dresult
	TIME 2 :EQUB&1A:EQUB&1A:STOP:CHECK:EQUS"&1A NOP",dresult
	TIME 2 :EQUB&3A:EQUB&3A:STOP:CHECK:EQUS"&3A NOP",dresult
	TIME 2 :EQUB&5A:EQUB&5A:STOP:CHECK:EQUS"&5A NOP",dresult
	TIME 2 :EQUB&7A:EQUB&7A:STOP:CHECK:EQUS"&7A NOP",dresult
	TIME 2 :EQUB&DA:EQUB&DA:STOP:CHECK:EQUS"&DA NOP",dresult
	TIME 2 :EQUB&FA:EQUB&FA:STOP:CHECK:EQUS"&FA NOP",dresult
	TIME 2 :EQUB&80,imm:EQUB&80,imm:STOP:CHECK:EQUS"&80 NOP #imm",dresult
	TIME 2 :EQUB&82,imm:EQUB&82,imm:STOP:CHECK:EQUS"&82 NOP #imm",dresult
	TIME 2 :EQUB&89,imm:EQUB&89,imm:STOP:CHECK:EQUS"&89 NOP #imm",dresult
	TIME 2 :EQUB&C2,imm:EQUB&C2,imm:STOP:CHECK:EQUS"&C2 NOP #imm",dresult
	TIME 2 :EQUB&E2,imm:EQUB&E2,imm:STOP:CHECK:EQUS"&E2 NOP #imm",dresult
	TIME 3 :EQUB&04,imm:EQUB&04,imm:STOP:CHECK:EQUS"&04 NOP &00",dresult
	TIME 3 :EQUB&44,imm:EQUB&44,imm:STOP:CHECK:EQUS"&44 NOP &00",dresult
	TIME 3 :EQUB&64,imm:EQUB&64,imm:STOP:CHECK:EQUS"&64 NOP &00",dresult
	TIME 4 :EQUB&14,imm:EQUB&14,imm:STOP:CHECK:EQUS"&14 NOP &00,X",dresult
	TIME 4 :EQUB&34,imm:EQUB&34,imm:STOP:CHECK:EQUS"&34 NOP &00,X",dresult
	TIME 4 :EQUB&54,imm:EQUB&54,imm:STOP:CHECK:EQUS"&54 NOP &00,X",dresult
	TIME 4 :EQUB&74,imm:EQUB&74,imm:STOP:CHECK:EQUS"&74 NOP &00,X",dresult
	TIME 4 :EQUB&D4,imm:EQUB&D4,imm:STOP:CHECK:EQUS"&D4 NOP &00,X",dresult
	TIME 4 :EQUB&F4,imm:EQUB&F4,imm:STOP:CHECK:EQUS"&F4 NOP &00,X",dresult
	TIME 4 :EQUB&0C,imm:EQUB0:EQUB&0C,imm:EQUB0:STOP:CHECK:EQUS"&0C NOP &0000",dresult
	TIME 4 :EQUB&1C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&1C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&1C NOP addrFE,X",dresult
	TIME 5 :EQUB&1C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&1C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&1C NOP addrFF,X",dresult
	TIME 4 :EQUB&3C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&3C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&3C NOP addrFE,X",dresult
	TIME 5 :EQUB&3C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&3C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&3C NOP addrFF,X",dresult
	TIME 4 :EQUB&5C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&5C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&5C NOP addrFE,X",dresult
	TIME 5 :EQUB&5C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&5C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&5C NOP addrFF,X",dresult
	TIME 4 :EQUB&7C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&7C:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&7C NOP addrFE,X",dresult
	TIME 5 :EQUB&7C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&7C:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&7C NOP addrFF,X",dresult
	TIME 4 :EQUB&DC:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&DC:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&DC NOP addrFE,X",dresult
	TIME 5 :EQUB&DC:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&DC:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&DC NOP addrFF,X",dresult
	TIME 4 :EQUB&FC:EQUBaddrFE MOD256:EQUBaddrFE DIV256:EQUB&FC:EQUBaddrFE MOD256:EQUBaddrFE DIV256:STOP:CHECK:EQUS"&FC NOP addrFE,X",dresult
	TIME 5 :EQUB&FC:EQUBaddrFF MOD256:EQUBaddrFF DIV256:EQUB&FC:EQUBaddrFF MOD256:EQUBaddrFF DIV256:STOP:CHECK:EQUS"&FC NOP addrFF,X",dresult	

; untest brk CLI

	
	JSR printstring:EQUS "Done!",13,0
	RTS

.blockcopy 
	STA ptr2
	STX ptr2+1
	PLA
	STA stringptr
	PLA
	STA stringptr+1
	TYA
	PHA
	INY 
	INY
.blockcopyloop	
	DEY
	LDA (stringptr),Y
	DEY
	STA (ptr2),Y
	INY
	CPY #1
	BNE blockcopyloop
	PLA	
	CLC
	ADC stringptr:TAY
	LDA #0
	ADC stringptr+1
	PHA
	TYA
	PHA
	JMP (ptr2)


.check
	SEC
	SBC #timeoffset-2
	BEQ correct
	TAX
	JMP printstring
.correct
{
	; skip string
	PLA
	STA stringptr
	PLA
	STA stringptr+1
	LDY #1
	.PrTextLp
	LDA (stringptr),Y
	BEQ PrTextEnd
	CMP#128
	BEQ PrTextEnd
	INY
	BNE PrTextLp
.PrTextEnd
	CLC
	TYA
	ADC stringptr:TAY
	LDA #0
	ADC stringptr+1
	PHA
	TYA
	PHA
	RESET
	RTS
 }
	
.printstring
{
  ; Print inline text
  ; =================
  ; Corrupts A,Y
  PLA
  STA stringptr
  PLA
  STA stringptr+1
  LDY #1
.PrTextLp
  LDA (stringptr),Y
  BMI PrDict
  BEQ PrTextEnd
  JSR osasci
.prloopinc
  INY
  BNE PrTextLp
.PrTextEnd
  CLC
  TYA
  ADC stringptr:TAY
  LDA #0
  ADC stringptr+1
  PHA
  TYA
  PHA
  RESET
  RTS

.PrDict  

; print timing error, format column first
	TYA
	PHA
.prcolumn
	LDA #32
	JSR osasci
	INY
	CPY #35
	BMI prcolumn
	TXA
	JSR PrHex
	PLA
	TAY
	LDA #13
	JSR osasci
	JMP PrTextEnd
	
.PrHex
  PHA:LSR A:LSR A:LSR A:LSR A
  JSR PyNybble :PLA
.PyNybble
  AND #15:CMP #10:BCC PrDigit
  ADC #6
.PrDigit
  ADC #'0':JMP osasci

dresult = 128	
	


dImm = 129 : EQUS "#0xFF",0

dADC = 150

  
}	
	
	.end
	
	
SAVE "6502tim", start, end
	
	