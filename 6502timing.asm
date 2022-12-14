;
; Program to test 6502 instruction timings
; By Dominic Plunkett (C) 08/2022
;
; This program is targeted at the BBC micro, but can be changed to other platforms
; it assumes that there is some forum of character output routine @ &FFE3
; it requires a 6522 via clocked at 1MHz assumed to be @ &FE60
; it requires some ram in Zero page and some RAM across a page boundary &0900 used here
; the code is assembled @ &2000 for acorn targets


; Pass in cpu = 0 for 6502 : cpu =1 for 65C12 ; cpu = 2 for 65C02
; target = 0 for no 1MHz stretching target=1 for 1MHZ clock stretching
; target = 2 for C64

; vectors
; $2000 entry
; $2010 printchar entry A char to print . Must preserve X Y
; $2020 setup ( e.g. timer )
; $2030 timer start ; entry A time to preset the timer ( may need to add a constant)
; $2040 timer stop ; return timer value in X
; $2050 End of test ; entry A number of failures
; $2060

;Zero page address
zpx         = &70
zp          = &71
indirFE     = &72 ; indirect address of page boundary -2
indirFF     = &74 ; indirect address of page boundary -1
stringptr   = &76
ptr2        = &78
indirtemp   = &76
indirtemp2  = &78
passfailzp  = &7A

IF target = 0 ; normal memory space
   branchaddress = &8FF ;page boundary needs space before and afterwards for branch tests
   addrFE   = &08FE ; address -2 of page boundary
   addrFF   = addrFE+1 ; address -1 of page boundary
   Tadjust  = 0; clock stretch cycle adjust
   BCadjust = 0; number of extra bytes in the time macro
   timerbase  = &FE60 ; base address of 6522 via
   passfailreg = &FCD0 ; address that is written to to signify pass or number of failures
      ;setup via
ENDIF

IF target = 1 ; test page cross in 1MHz space

   branchaddress = &8FF ;page boundary needs space before and afterwards for branch tests
   addrFE   = &FCFE ; address -2 of page boundary
   addrFF   = addrFE+1 ; address -1 of page boundary
   Tadjust  = 1; clock stretch cycle adjust
   BCadjust = 0; number of extra bytes in the time macro
   timerbase  = &FE60 ; base address of 6522 via
   passfailreg = &FCD0 ; address that is written to to signify pass or number of failures
      ;setup via
ENDIF

IF target = 2 ; C64

   branchaddress = &8FFF ;page boundary needs space before and afterwards for branch tests
   addrFE   = &8CFE ; address -2 of page boundary
   addrFF   = addrFE+1 ; address -1 of page boundary
   Tadjust  = 0; clock stretch cycle adjust
   BCadjust = 0; number of extra bytes in the time macro
   c64osasci = &FFD2 ; os print byte ( needs to preserve X and Y)
   timerbase  = &DD00 ; base address of timer
   passfailreg = $DFFF ; address that is written to to signify pass or number of failures

   prgorg = &2000-15
   ORG &7FF; code origin
.start
   EQUB LO(prgstart),HI(prgstart)
   .prgstart
   EQUB LO(prgend),HI(prgend) ; pointer to next line
   EQUB LO(0010),HI(0010) ; line number
   EQUB &9E," 2064",0 ; "SYS 8192",0


   .prgend
   EQUB 0,0 ; end of program
   EQUB 0,0
   ;ORG &0810
 ;  ORG &2000

   JMP starttest

.osasci
   cmp #64
   bcc  printcharok
   eor #32
.printcharok
   jmp c64osasci

.setup
   LDA #&7F : STA timerbase+&D ; turn off interrupts
   LDA #$E  ; Select other font
   JSR c64osasci

   RTS

.starttimer
   SEC
   SBC #3
   STA timerbase+4
   STA timerbase+5
.waitforrasterloop
   LDA $D012               ; hardcoded raster counter . we need to sync to the beginning of the frame
   AND #&e4
   BNE waitforrasterloop
   LDA #&11
   STA timerbase+&E
   RTS

.stoptimer              ; stop timer vector
   LDX timerbase+4
   RTS

.endoftests             ; end tests vector
   RTS
ENDIF

; end of target definitions

IF ((target = 0) OR (target =1))
; setup vectors
   origin = &2000
   ORG origin         ; code origin
.start
   JMP starttest

   ORG origin+&10
.osasci                 ; put char vector
   JMP $FFE3            ; os print byte ( needs to preserve X and Y)

   ORG origin+&20
.setup                   ; setup timer vector
   LDA #&7F : STA timerbase+&E ; turn off interrupts
   LDA #&00 : STA timerbase+&B ; setup timer 1
   RTS

   ORG origin+&30
.starttimer             ; start timer vector
   LSR A                ; Beeb timer is 1MHz
   STA timerbase+4
   STA timerbase+5     ; doesn't matter what the high byte is to trigger the timer
   RTS

   ORG origin+&40
.stoptimer              ; stop timer vector
   LDA timerbase+4
   ASL A                ; compensate for beeb timer being 1MHz
   TAX
   RTS

   ORG origin+&50
.endoftests             ; end tests vector
   STA passfailreg
   RTS

   ORG origin+&60

ENDIF

IF ((target = 1) AND (cpu = 0))
   Ta2 = 1 ; BBC B with 1MHz clock stretch
ELSE
   Ta2 = 0
ENDIF

imm      = &FF ; immediate constant

dresult  = 254 ; byte to signify print timing error
dterm    = 255 ; string termination byte

MACRO RESET
   LDX #1
   LDY #1
   SEI
ENDMACRO

; timer macros NB the length of TIME is important

timeoffset = 8 ; sta /lda time offset

MACRO TIME time
   LDA #(time+timeoffset)*2
   JSR starttimer
ENDMACRO

MACRO STOP
   JSR stoptimer ; LDX timerbase+4
ENDMACRO

MACRO CHECK
   JSR check
ENDMACRO

MACRO BLOCKCOPY address,start, end
   LDA #LO(address-BCadjust)
   LDX #HI(address-BCadjust)
   LDY #end-start
   JSR blockcopy
ENDMACRO

MACRO UNDOC1BYTE byte
   EQUB byte
   EQUB byte
ENDMACRO

MACRO UNDOC2BYTE byte,address
   EQUB byte,address
   EQUB byte,address
ENDMACRO

MACRO UNDOC3BYTE byte,address
   EQUB byte,LO(address),HI(address)
   EQUB byte,LO(address),HI(address)
ENDMACRO

.starttest
   JSR setup
   JSR printstring

   IF cpu = 0
      EQUS "6502 instruction timing checker"
      cpucmos = 0
      CPU 0
   ENDIF

   IF cpu = 1
      EQUS "65C12 instruction timing checker"
      cpucmos = 1
      CPU 1
   ENDIF

   IF cpu = 2
      EQUS "65C02 instruction timing checker"
      cpucmos = 1
      CPU 1
   ENDIF

   IF target = 1
      EQUB " (1MHz)"
   ENDIF

   EQUB 13,13

   EQUS "Version : 0.23",13
   EQUS "Build Date : ",TIME$,13,13
   EQUS "Only errors are printed",13
   EQUS "Note : X = 1 and Y = 1",13
   EQUS " 01 means 1 Clock Cycle too quick",13
   EQUS " FF means 1 Clock Cycle too long",13
   EQUS "    etc",13,13,dterm

   TIME 0 :STOP:CHECK:EQUS"Warning Timer Zero Error",dresult

   JSR printstring:
   EQUS "Checking documented instructions...",13,14,dterm

   ; setup indirect pointers
   LDA #addrFE  MOD 256:STA indirFE
   LDA #addrFE  DIV 256:STA indirFE+1
   LDA #addrFF  MOD 256:STA indirFF
   LDA #addrFF  DIV 256:STA indirFF+1

   LDA #0 : sta passfailzp

   RESET

   TIME 2 :ADC #imm :ADC #imm:STOP:CHECK:EQUS"ADC #imm",dresult
   TIME 3 :ADC zp:ADC zp:STOP:CHECK:EQUS"ADC zp",dresult
   TIME 4 :ADC zpx,X:ADC zpx,X:STOP:CHECK:EQUS"ADC zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :ADC (indirFE):ADC (indirFE):STOP:CHECK:EQUS"ADC (indirFE)",dresult
   ENDIF

   TIME 4+(2*Tadjust) :ADC addrFF:ADC addrFF:STOP:CHECK:EQUS"ADC addrFF",dresult
   TIME 4+(2*Tadjust) :ADC addrFE,X:ADC addrFE,X:STOP:CHECK:EQUS"ADC addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :ADC addrFF,X:ADC addrFF,X:STOP:CHECK:EQUS"ADC addrFF,X",dresult
   TIME 4+(2*Tadjust) :ADC addrFE,Y:ADC addrFE,Y:STOP:CHECK:EQUS"ADC addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :ADC addrFF,Y:ADC addrFF,Y:STOP:CHECK:EQUS"ADC addrFF,Y",dresult
   TIME 6+(2*Tadjust) :ADC (indirFE+1,X):ADC (indirFE+1,X) : STOP:CHECK:EQUS"ADC (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :ADC (indirFE),Y:ADC (indirFE),Y:STOP:CHECK:EQUS"ADC (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :ADC (indirFF),Y:ADC (indirFF),Y:STOP:CHECK:EQUS"ADC (indirFF),Y",dresult

   TIME 2+1 +cpucmos:SED:ADC #imm :ADC #imm:STOP:CHECK:EQUS"SED ADC #imm",dresult
   TIME 3+1 +cpucmos:SED:ADC zp:ADC zp:STOP:CHECK:EQUS"SED ADC zp",dresult
   TIME 4+1 +cpucmos:SED:ADC zpx,X:ADC zpx,X:STOP:CHECK:EQUS"SED ADC zpx,X",dresult
   IF cpucmos
      TIME 5+1+(1*Tadjust) +cpucmos:SED:ADC (indirFE):ADC (indirFE):STOP:CHECK:EQUS"SED ADC (indirFE)",dresult
   ENDIF
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:ADC addrFF:ADC addrFF:STOP:CHECK:EQUS"SED ADC addrFF",dresult
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:ADC addrFE,X:ADC addrFE,X:STOP:CHECK:EQUS"SED ADC addrFE,X",dresult
   TIME 5+1+(1*Tadjust)+(2*Ta2) +cpucmos:SED:ADC addrFF,X:ADC addrFF,X:STOP:CHECK:EQUS"SED ADC addrFF,X",dresult
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:ADC addrFE,Y:ADC addrFE,Y:STOP:CHECK:EQUS"SED ADC addrFE,Y",dresult
   TIME 5+1+(1*Tadjust)+(2*Ta2) +cpucmos:SED:ADC addrFF,Y:ADC addrFF,Y:STOP:CHECK:EQUS"SED ADC addrFF,Y",dresult
   TIME 6+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:ADC (indirFE+1,X):ADC (indirFE+1,X):STOP:CHECK:EQUS"SED ADC (indirFE+1,X)",dresult
   TIME 5+1+(1*Tadjust) +cpucmos:SED:ADC (indirFE),Y:ADC (indirFE),Y:STOP:CHECK:EQUS"SED ADC (indirFE),Y",dresult
   TIME 6+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:ADC (indirFF),Y:ADC (indirFF),Y:STOP:CHECK:EQUS"SED ADC (indirFF),Y",dresult


   TIME 2 :AND #imm:AND #imm:STOP:CHECK:EQUS"AND #imm",dresult
   TIME 3 :AND zp:AND zp:STOP:CHECK:EQUS"AND zp",dresult
   TIME 4 :AND zpx,X:AND zpx,X:STOP:CHECK:EQUS"AND zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :AND (indirFE):AND (indirFE):STOP:CHECK:EQUS"AND (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :AND addrFF:AND addrFF:STOP:CHECK:EQUS"AND addrFF",dresult
   TIME 4+(2*Tadjust) :AND addrFE,X:AND addrFE,X:STOP:CHECK:EQUS"AND addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :AND addrFF,X:AND addrFF,X:STOP:CHECK:EQUS"AND addrFF,X",dresult
   TIME 4+(2*Tadjust) :AND addrFE,Y:AND addrFE,Y:STOP:CHECK:EQUS"AND addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :AND addrFF,Y:AND addrFF,Y:STOP:CHECK:EQUS"AND addrFF,Y",dresult
   TIME 6+(2*Tadjust) :AND (indirFE+1,X):AND (indirFE+1,X):STOP:CHECK:EQUS"AND (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :AND (indirFE),Y:AND (indirFE),Y:STOP:CHECK:EQUS"AND (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :AND (indirFF),Y:AND (indirFF),Y:STOP:CHECK:EQUS"AND (indirFF),Y",dresult

   TIME 2 :ASL A:ASL A:STOP:CHECK:EQUS"ASL A",dresult
   TIME 5 :ASL zp:ASL zp:STOP:CHECK:EQUS"ASL zp",dresult
   TIME 6 :ASL zpx,X:ASL zpx,X:STOP:CHECK:EQUS"ASL zpx,X",dresult
   TIME 6+(4*Tadjust) :ASL addrFE:ASL addrFE :STOP:CHECK:EQUS"ASL addrFE",dresult
   TIME 7+(4*Tadjust)+(1*Ta2)-cpucmos :ASL addrFE,X:ASL addrFE,X:STOP:CHECK:EQUS"ASL addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :ASL addrFF,X:ASL addrFF,X:STOP:CHECK:EQUS"ASL addrFF,X",dresult

   TIME 2+1 :SEC:BCC*+2:BCC*+2:STOP:CHECK:EQUS"BCC not taken",dresult
   TIME 3+1 :CLC:BCC*+2:BCC*+2:STOP:CHECK:EQUS"BCC taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 7+1 :CLC:BCC*+4:.b BCC*+6:BCC *+2:BCC b:STOP:RTS:.be : CHECK: EQUS"BCC page cross",dresult}

   TIME 2+1 :CLC:BCS*+2:BCS*+2:STOP:CHECK:EQUS"BCS not taken",dresult
   TIME 3+1 :SEC:BCS*+2:BCS*+2:STOP:CHECK:EQUS"BCS taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 7+1 :SEC:BCS*+4:.b BCS*+6:BCS *+2:BCS b:STOP:RTS:.be : CHECK: EQUS"BCS page cross",dresult}

   TIME 2+1 :LDA#1:BEQ*+2:BEQ*+2:STOP:CHECK:EQUS"BEQ not taken",dresult
   TIME 3+1 :LDA#0:BEQ*+2:BEQ*+2:STOP:CHECK:EQUS"BEQ taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 7+1 :LDA#0:BEQ*+4:.b BEQ*+6:BEQ *+2:BEQ b:STOP:RTS:.be : CHECK: EQUS"BEQ page cross",dresult}

   IF cpucmos
      TIME 2 :BIT #imm:BIT #imm:STOP:CHECK:EQUS"BIT #imm",dresult
      TIME 4 :BIT zpx,X:BIT zpx,X:STOP:CHECK:EQUS"BIT zpx,X",dresult
      TIME 4+(2*Tadjust) :BIT addrFE,X:BIT addrFE,X:STOP:CHECK:EQUS"BIT addrFE,X",dresult
      TIME 5+(1*Tadjust)+(2*Ta2) :BIT addrFF,X:BIT addrFF,X:STOP:CHECK:EQUS"BIT addrFF,X",dresult
   ENDIF

   TIME 3 :BIT zp:BIT zp:STOP:CHECK:EQUS"BIT zp",dresult
   TIME 4+(2*Tadjust) :BIT addrFF:BIT addrFF:STOP:CHECK:EQUS"BIT addrFF",dresult

   IF cpu=2
      ; BBR instructions
      LDA #&FF : STA zp
      TIME 10 :EQUB &0f,zp,0:EQUB &0f,zp,0:EQUB &0f,zp,0:EQUB &0f,zp,0:STOP:CHECK: EQUS"BBR0 not taken",dresult
      TIME 10 :EQUB &1f,zp,0:EQUB &1f,zp,0:EQUB &1f,zp,0:EQUB &1f,zp,0:STOP:CHECK: EQUS"BBR1 not taken",dresult
      TIME 10 :EQUB &2f,zp,0:EQUB &2f,zp,0:EQUB &2f,zp,0:EQUB &2f,zp,0:STOP:CHECK: EQUS"BBR2 not taken",dresult
      TIME 10 :EQUB &3f,zp,0:EQUB &3f,zp,0:EQUB &3f,zp,0:EQUB &3f,zp,0:STOP:CHECK: EQUS"BBR3 not taken",dresult
      TIME 10 :EQUB &4f,zp,0:EQUB &4f,zp,0:EQUB &4f,zp,0:EQUB &4f,zp,0:STOP:CHECK: EQUS"BBR4 not taken",dresult
      TIME 10 :EQUB &5f,zp,0:EQUB &5f,zp,0:EQUB &5f,zp,0:EQUB &5f,zp,0:STOP:CHECK: EQUS"BBR5 not taken",dresult
      TIME 10 :EQUB &6f,zp,0:EQUB &6f,zp,0:EQUB &6f,zp,0:EQUB &6f,zp,0:STOP:CHECK: EQUS"BBR6 not taken",dresult
      TIME 10 :EQUB &7f,zp,0:EQUB &7f,zp,0:EQUB &7f,zp,0:EQUB &7f,zp,0:STOP:CHECK: EQUS"BBR7 not taken",dresult
      LDA #0 : STA zp
      TIME 10 :EQUB &8f,zp,0:EQUB &8f,zp,0:EQUB &8f,zp,0:EQUB &8f,zp,0:STOP:CHECK: EQUS"BBS0 not taken",dresult
      TIME 10 :EQUB &9f,zp,0:EQUB &9f,zp,0:EQUB &9f,zp,0:EQUB &9f,zp,0:STOP:CHECK: EQUS"BBS1 not taken",dresult
      TIME 10 :EQUB &Af,zp,0:EQUB &Af,zp,0:EQUB &Af,zp,0:EQUB &Af,zp,0:STOP:CHECK: EQUS"BBS2 not taken",dresult
      TIME 10 :EQUB &Bf,zp,0:EQUB &Bf,zp,0:EQUB &Bf,zp,0:EQUB &Bf,zp,0:STOP:CHECK: EQUS"BBS3 not taken",dresult
      TIME 10 :EQUB &Cf,zp,0:EQUB &Cf,zp,0:EQUB &Cf,zp,0:EQUB &Cf,zp,0:STOP:CHECK: EQUS"BBS4 not taken",dresult
      TIME 10 :EQUB &Df,zp,0:EQUB &Df,zp,0:EQUB &Df,zp,0:EQUB &Df,zp,0:STOP:CHECK: EQUS"BBS5 not taken",dresult
      TIME 10 :EQUB &Ef,zp,0:EQUB &Ef,zp,0:EQUB &Ef,zp,0:EQUB &Ef,zp,0:STOP:CHECK: EQUS"BBS6 not taken",dresult
      TIME 10 :EQUB &Ff,zp,0:EQUB &Ff,zp,0:EQUB &Ff,zp,0:EQUB &Ff,zp,0:STOP:CHECK: EQUS"BBS7 not taken",dresult

      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &0f,zp,3:EQUB &0f,zp,6:EQUB &0f,zp,0:EQUB &0f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR0 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &1f,zp,3:EQUB &1f,zp,6:EQUB &1f,zp,0:EQUB &1f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR1 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &2f,zp,3:EQUB &2f,zp,6:EQUB &2f,zp,0:EQUB &2f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR2 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &3f,zp,3:EQUB &3f,zp,6:EQUB &3f,zp,0:EQUB &3f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR3 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &4f,zp,3:EQUB &4f,zp,6:EQUB &4f,zp,0:EQUB &4f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR4 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &5f,zp,3:EQUB &5f,zp,6:EQUB &5f,zp,0:EQUB &5f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR5 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &6f,zp,3:EQUB &6f,zp,6:EQUB &6f,zp,0:EQUB &6f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR6 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &7f,zp,3:EQUB &7f,zp,6:EQUB &7f,zp,0:EQUB &7f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBR7 page cross",dresult}
      LDA #&FF : STA zp
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &8f,zp,3:EQUB &8f,zp,6:EQUB &8f,zp,0:EQUB &8f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS0 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &9f,zp,3:EQUB &9f,zp,6:EQUB &9f,zp,0:EQUB &9f,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS1 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Af,zp,3:EQUB &Af,zp,6:EQUB &Af,zp,0:EQUB &Af,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS2 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Bf,zp,3:EQUB &Bf,zp,6:EQUB &Bf,zp,0:EQUB &Bf,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS3 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Cf,zp,3:EQUB &Cf,zp,6:EQUB &Cf,zp,0:EQUB &Cf,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS4 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Df,zp,3:EQUB &Df,zp,6:EQUB &Df,zp,0:EQUB &Df,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS5 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Ef,zp,3:EQUB &Ef,zp,6:EQUB &Ef,zp,0:EQUB &Ef,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS6 page cross",dresult}
      {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 13 :EQUB &Ff,zp,3:EQUB &Ff,zp,6:EQUB &Ff,zp,0:EQUB &Ff,zp,&FF-8 :STOP:RTS:.be :CHECK:EQUS"BBS7 page cross",dresult}
   ENDIF

   TIME 2+1 :LDA#1:BMI*+2:BMI*+2:STOP:CHECK:EQUS"BMI not taken",dresult
   TIME 3+1 :LDA#128::BMI*+2:BMI*+2:STOP:CHECK:EQUS"BMI taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 8 :LDA#128:BMI*+4:.b BMI*+6:BMI *+2:BMI b:STOP:RTS:.be : CHECK: EQUS"BMI page cross",dresult}

   TIME 2+1 :LDA#0:BNE*+2:BNE*+2:STOP:CHECK:EQUS"BNE not taken",dresult
   TIME 3+1 :LDA#1:BNE*+2:BNE*+2:STOP:CHECK:EQUS"BNE taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 8 :LDA#1:BNE*+4:.b BNE*+6:BNE *+2:BNE b:STOP:RTS:.be : CHECK: EQUS"BNE page cross",dresult}

   TIME 2+1 :LDA#128:BPL*+2:BPL*+2:STOP:CHECK:EQUS"BPL not taken",dresult
   TIME 3+1 :LDA#0:BPL*+2:BPL*+2:STOP:CHECK:EQUS"BPL taken",dresult
   {BLOCKCOPY branchaddress-12, bs,be : .bs TIME 8 :LDA#0:BPL*+4:.b BPL*+6:BPL *+2:BPL b:STOP:RTS:.be : CHECK: EQUS"BPL page cross",dresult}

   IF cpucmos
      TIME 3 :BRA*+2:BRA*+2:STOP:CHECK:EQUS"BRA taken",dresult
      {BLOCKCOPY branchaddress-10, bs,be : .bs TIME 7 :BRA*+4:.b BRA*+6:BRA *+2:BRA b:STOP:RTS:.be : CHECK: EQUS"BRA page cross",dresult}
   ENDIF

   ; EQUS &2C,LO(indirFF),HI(indirFF) is BIT 00zp which is a 4 cycle instruction NB bit zp is 3 cycles
   TIME 2+2 :EQUS &2C,LO(indirFF),HI(indirFF):BVC*+2:BVC*+2:STOP:CHECK:EQUS"BVC not taken",dresult
   TIME 3+1 :CLV:BVC*+2:BVC*+2:STOP:CHECK:EQUS"BVC taken",dresult
   {BLOCKCOPY branchaddress-11, bs,be : .bs TIME 7+1 :CLV:BVC*+4:.b BVC*+6:BVC *+2:BVC b:STOP:RTS:.be : CHECK: EQUS"BVC page cross",dresult}

   TIME 2+1 :CLV:BVS*+2:BVS*+2:STOP:CHECK:EQUS"BVS not taken",dresult
   TIME 3+2 :EQUS &2C,LO(indirFF),HI(indirFF):BVS*+2:BVS*+2:STOP:CHECK:EQUS"BVS taken",dresult
   {BLOCKCOPY branchaddress-13, bs,be : .bs TIME 7+2:EQUS &2C,LO(indirFF),HI(indirFF):BVS*+4:.b BVS*+6:BVS *+2:BVS b:STOP:RTS:.be : CHECK: EQUS"BVS page cross",dresult}
   RESET
   TIME 2 :CLC:CLC:STOP:CHECK:EQUS"CLC",dresult
   TIME 2 :CLD:CLD:STOP:CHECK:EQUS"CLD",dresult

   TIME 2 :CLV:CLV:STOP:CHECK:EQUS"CLV",dresult

   TIME 2 :CMP #imm:CMP #imm:STOP:CHECK:EQUS"CMP #imm",dresult
   TIME 3 :CMP zp:CMP zp:STOP:CHECK:EQUS"CMP zp",dresult
   TIME 4 :CMP zpx,X:CMP zpx,X:STOP:CHECK:EQUS"CMP zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :CMP (indirFE):CMP (indirFE):STOP:CHECK:EQUS"CMP (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :CMP addrFF:CMP addrFF :STOP:CHECK:EQUS"CMP addrFF",dresult
   TIME 4+(2*Tadjust) :CMP addrFE,X:CMP addrFE,X:STOP:CHECK:EQUS"CMP addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :CMP addrFF,X:CMP addrFF,X:STOP:CHECK:EQUS"CMP addrFF,X",dresult
   TIME 4+(2*Tadjust) :CMP addrFE,Y:CMP addrFE,Y:STOP:CHECK:EQUS"CMP addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :CMP addrFF,Y:CMP addrFF,Y:STOP:CHECK:EQUS"CMP addrFF,Y",dresult
   TIME 6+(2*Tadjust) :CMP (indirFE+1,X):CMP (indirFE+1,X):STOP:CHECK:EQUS"CMP (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :CMP (indirFE),Y:CMP (indirFE),Y:STOP:CHECK:EQUS"CMP (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :CMP (indirFF),Y:CMP (indirFF),Y:STOP:CHECK:EQUS"CMP (indirFF),Y",dresult

   TIME 2 :CPX #imm:CPX #imm:STOP:CHECK:EQUS"CPX #imm",dresult
   TIME 3 :CPX zp:CPX zp:STOP:CHECK:EQUS"CPX zp",dresult
   TIME 4+(2*Tadjust) :CPX addrFF :CPX addrFF :STOP:CHECK:EQUS"CPX addrFF",dresult
   TIME 2 :CPY #imm:CPY #imm:STOP:CHECK:EQUS"CPY #imm",dresult
   TIME 3 :CPY zp:CPY zp:STOP:CHECK:EQUS"CPY zp",dresult
   TIME 4+(2*Tadjust) :CPY addrFF :CPY addrFF :STOP:CHECK:EQUS"CPY addrFF",dresult

   IF cpucmos
      TIME 2 :DEC A:DEC A:STOP:CHECK:EQUS"DEC A",dresult
   ENDIF

   TIME 5 :DEC zp:DEC zp:STOP:CHECK:EQUS"DEC zp",dresult
   TIME 6 :DEC zpx,X:DEC zpx,X:STOP:CHECK:EQUS"DEC zpx,X",dresult
   TIME 6+(4*Tadjust) :DEC addrFE:DEC addrFE :STOP:CHECK:EQUS"DEC addrFE",dresult
   TIME 7+(5*Tadjust) :DEC addrFE,X:DEC addrFE,X:STOP:CHECK:EQUS"DEC addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :DEC addrFF,X:DEC addrFF,X:STOP:CHECK:EQUS"DEC addrFF,X",dresult

   TIME 2 :DEX:DEX:STOP:CHECK:EQUS"DEX",dresult
   TIME 2 :DEY:DEY:STOP:CHECK:EQUS"DEY",dresult

   TIME 2 :EOR #imm:EOR #imm:STOP:CHECK:EQUS"EOR #imm",dresult
   TIME 3 :EOR zp:EOR zp:STOP:CHECK:EQUS"EOR zp",dresult
   TIME 4 :EOR zpx,X:EOR zpx,X:STOP:CHECK:EQUS"EOR zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :EOR (indirFE):EOR (indirFE):STOP:CHECK:EQUS"EOR (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :EOR addrFF:EOR addrFF :STOP:CHECK:EQUS"EOR addrFF",dresult
   TIME 4+(2*Tadjust) :EOR addrFE,X:EOR addrFE,X:STOP:CHECK:EQUS"EOR addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :EOR addrFF,X:EOR addrFF,X:STOP:CHECK:EQUS"EOR addrFF,X",dresult
   TIME 4+(2*Tadjust) :EOR addrFE,Y:EOR addrFE,Y:STOP:CHECK:EQUS"EOR addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :EOR addrFF,Y:EOR addrFF,Y:STOP:CHECK:EQUS"EOR addrFF,Y",dresult
   TIME 6+(2*Tadjust) :EOR (indirFE+1,X):EOR (indirFE+1,X):STOP:CHECK:EQUS"EOR (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :EOR (indirFE),Y:EOR (indirFE),Y:STOP:CHECK:EQUS"EOR (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :EOR (indirFF),Y:EOR (indirFF),Y:STOP:CHECK:EQUS"EOR (indirFF),Y",dresult

   IF cpucmos
      TIME 2 :INC A:INC A:STOP:CHECK:EQUS"INC A",dresult
   ENDIF

   TIME 5 :INC zp:INC zp:STOP:CHECK:EQUS"INC zp",dresult
   TIME 6 :INC zpx,X:INC zpx,X:STOP:CHECK:EQUS"INC zpx,X",dresult
   TIME 6+(4*Tadjust) :INC addrFE :INC addrFE :STOP:CHECK:EQUS"INC addrFE",dresult
   TIME 7+(5*Tadjust) :INC addrFE,X:INC addrFE,X:STOP:CHECK:EQUS"INC addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :INC addrFF,X:INC addrFF,X:STOP:CHECK:EQUS"INC addrFF,X",dresult

   TIME 2 :INX:INX:STOP:CHECK:EQUS"INX",dresult
   TIME 2 :INY:INY:STOP:CHECK:EQUS"INY",dresult

   TIME 3 :JMP *+3:JMP *+3:STOP:CHECK:EQUS"JMP &0000",dresult

   {LDA #jmp1 MOD256:STA indirtemp:LDA #jmp1 DIV256:STA indirtemp+1:LDA #jmp2 MOD256:STA indirtemp2:LDA #jmp2 DIV256:STA indirtemp2+1:
   TIME 5+cpucmos :JMP (indirtemp):.jmp1 JMP(indirtemp2):.jmp2 STOP:CHECK:EQUS"JMP (&0000)",dresult}
   IF cpucmos
      {LDA #jmp1 MOD256:STA indirtemp:LDA #jmp1 DIV256:STA indirtemp+1:LDA #jmp2 MOD256:STA indirtemp2:LDA #jmp2 DIV256:STA indirtemp2+1:
      TIME 6 :JMP (indirtemp-1,X):.jmp1 JMP(indirtemp2-1,X):.jmp2 STOP:CHECK:EQUS"JMP (&0000,X)",dresult}
   ENDIF

   TIME 6 :JSR *+3:JSR *+3:STOP:PLA:PLA:PLA:PLA:TXA:CHECK:EQUS"JSR &0000",dresult

   TIME 2 :LDA #imm:LDA #imm:STOP:CHECK:EQUS"LDA #imm",dresult
   TIME 3 :LDA zp:LDA zp:STOP:CHECK:EQUS"LDA zp",dresult
   TIME 4 :LDA zpx,X:LDA zpx,X:STOP:CHECK:EQUS"LDA zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :LDA (indirFE):LDA (indirFE):STOP:CHECK:EQUS"LDA (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :LDA addrFF :LDA addrFF :STOP:CHECK:EQUS"LDA addrFF",dresult
   TIME 4+(2*Tadjust) :LDA addrFE,X:LDA addrFE,X:STOP:CHECK:EQUS"LDA addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :LDA addrFF,X:LDA addrFF,X:STOP:CHECK:EQUS"LDA addrFF,X",dresult
   TIME 4+(2*Tadjust) :LDA addrFE,Y:LDA addrFE,Y:STOP:CHECK:EQUS"LDA addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :LDA addrFF,Y:LDA addrFF,Y:STOP:CHECK:EQUS"LDA addrFF,Y",dresult
   TIME 6+(2*Tadjust) :LDA (indirFE+1,X):LDA (indirFE+1,X):STOP:CHECK:EQUS"LDA (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :LDA (indirFE),Y:LDA (indirFE),Y:STOP:CHECK:EQUS"LDA (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :LDA (indirFF),Y:LDA (indirFF),Y:STOP:CHECK:EQUS"LDA (indirFF),Y",dresult

   TIME 2 :LDX #imm:LDX #imm:STOP:CHECK:EQUS"LDX #imm",dresult
   TIME 3 :LDX zp:LDX zp:STOP:CHECK:EQUS"LDX zp",dresult
   TIME 4 :LDX zp,Y:LDX zp,Y:STOP:CHECK:EQUS"LDX zp,Y",dresult
   TIME 4+(2*Tadjust) :LDX addrFF:LDX addrFF:STOP:CHECK:EQUS"LDX addrFF",dresult
   TIME 4+(2*Tadjust) :LDX addrFE,Y:LDX addrFE,Y:STOP:CHECK:EQUS"LDX addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :LDX addrFF,Y:LDX addrFF,Y:STOP:CHECK:EQUS"LDX addrFF,Y",dresult

   TIME 2 :LDY #imm:LDY #imm:STOP:CHECK:EQUS"LDY #imm",dresult
   TIME 3 :LDY zp:LDY zp:STOP:CHECK:EQUS"LDY zp",dresult
   TIME 4 :LDY zpx,X:LDY zpx,X:STOP:CHECK:EQUS"LDY zpx,X",dresult
   TIME 4+(2*Tadjust) :LDY addrFF :LDY addrFF :STOP:CHECK:EQUS"LDY addrFF",dresult
   TIME 4+(2*Tadjust) :LDY addrFE,X:LDY addrFE ,X:STOP:CHECK:EQUS"LDY addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :LDY addrFF,X:LDY addrFF ,X:STOP:CHECK:EQUS"LDY addrFF,X",dresult

   TIME 2 :LSR A:LSR A:STOP:CHECK:EQUS"LSR A",dresult
   TIME 5 :LSR zp:LSR zp:STOP:CHECK:EQUS"LSR zp",dresult
   TIME 6 :LSR zpx,X:LSR zpx,X:STOP:CHECK:EQUS"LSR zpx,X",dresult
   TIME 6+(4*Tadjust) :LSR addrFE:LSR addrFE:STOP:CHECK:EQUS"LSR addrFE",dresult
   TIME 7+(4*Tadjust)+(1*Ta2)-cpucmos :LSR addrFE,X:LSR addrFE,X:STOP:CHECK:EQUS"LSR addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :LSR addrFF,X:LSR addrFF,X:STOP:CHECK:EQUS"LSR addrFF,X",dresult

   TIME 2 :NOP:NOP:STOP:CHECK:EQUS"NOP",dresult

   TIME 2 :ORA #imm:ORA #imm:STOP:CHECK:EQUS"ORA #imm",dresult
   TIME 3 :ORA zp:ORA zp:STOP:CHECK:EQUS"ORA zp",dresult
   TIME 4 :ORA zpx,X:ORA zpx,X:STOP:CHECK:EQUS"ORA zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :ORA (indirFE):ORA (indirFE):STOP:CHECK:EQUS"ORA (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :ORA addrFF:ORA addrFF :STOP:CHECK:EQUS"ORA addrFF",dresult
   TIME 4+(2*Tadjust) :ORA addrFE,X:ORA addrFE,X:STOP:CHECK:EQUS"ORA addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :ORA addrFF,X:ORA addrFF,X:STOP:CHECK:EQUS"ORA addrFF,X",dresult
   TIME 4+(2*Tadjust) :ORA addrFE,Y:ORA addrFE,Y:STOP:CHECK:EQUS"ORA addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :ORA addrFF,Y:ORA addrFF,Y:STOP:CHECK:EQUS"ORA addrFF,Y",dresult
   TIME 6+(2*Tadjust) :ORA (indirFE+1,X):ORA (indirFE+1,X):STOP:CHECK:EQUS"ORA (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :ORA (indirFE),Y:ORA (indirFE),Y:STOP:CHECK:EQUS"ORA (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :ORA (indirFF),Y:ORA (indirFF),Y:STOP:CHECK:EQUS"ORA (indirFF),Y",dresult

   TIME 3 :PHA:PHA:STOP:PLA:PLA:TXA:CHECK:EQUS"PHA",dresult
   TIME 3 :PHP:PHP:STOP:PLP:PLP:TXA:CHECK:EQUS"PHP",dresult
   PHA:PHA:TIME 4 :PLA:PLA:STOP:CHECK:EQUS"PLA",dresult
   PHP:PHP:TIME 4 :PLP:PLP:STOP:CHECK:EQUS"PLP",dresult

   IF cpucmos
      TIME 3 :PHX:PHX:STOP:PLA:PLA:TXA:CHECK:EQUS"PHX",dresult
      TIME 3 :PHY:PHY:STOP:PLA:PLA:TXA:CHECK:EQUS"PHY",dresult
      PHX:PHX:TIME 4 :PLX:PLX:STOP:CHECK:EQUS"PLX",dresult
      PHY:PHY:TIME 4 :PLY:PLY:STOP:CHECK:EQUS"PLY",dresult
   ENDIF

   IF cpu = 2
      ; 65C02 instructions
      TIME 5 : UNDOC2BYTE &07,zp:STOP:CHECK:EQUS"RMB0",dresult
      TIME 5 : UNDOC2BYTE &17,zp:STOP:CHECK:EQUS"RMB1",dresult
      TIME 5 : UNDOC2BYTE &27,zp:STOP:CHECK:EQUS"RMB2",dresult
      TIME 5 : UNDOC2BYTE &37,zp:STOP:CHECK:EQUS"RMB3",dresult
      TIME 5 : UNDOC2BYTE &47,zp:STOP:CHECK:EQUS"RMB4",dresult
      TIME 5 : UNDOC2BYTE &57,zp:STOP:CHECK:EQUS"RMB5",dresult
      TIME 5 : UNDOC2BYTE &67,zp:STOP:CHECK:EQUS"RMB6",dresult
      TIME 5 : UNDOC2BYTE &77,zp:STOP:CHECK:EQUS"RMB7",dresult

      TIME 5 : UNDOC2BYTE &87,zp:STOP:CHECK:EQUS"SMB0",dresult
      TIME 5 : UNDOC2BYTE &97,zp:STOP:CHECK:EQUS"SMB1",dresult
      TIME 5 : UNDOC2BYTE &A7,zp:STOP:CHECK:EQUS"SMB2",dresult
      TIME 5 : UNDOC2BYTE &B7,zp:STOP:CHECK:EQUS"SMB3",dresult
      TIME 5 : UNDOC2BYTE &C7,zp:STOP:CHECK:EQUS"SMB4",dresult
      TIME 5 : UNDOC2BYTE &D7,zp:STOP:CHECK:EQUS"SMB5",dresult
      TIME 5 : UNDOC2BYTE &E7,zp:STOP:CHECK:EQUS"SMB6",dresult
      TIME 5 : UNDOC2BYTE &F7,zp:STOP:CHECK:EQUS"SMB7",dresult
   ENDIF

   TIME 2 :ROL A:ROL A:STOP:CHECK:EQUS"ROL A",dresult
   TIME 5 :ROL zp:ROL zp:STOP:CHECK:EQUS"ROL zp",dresult
   TIME 6 :ROL zpx,X:ROL zpx,X:STOP:CHECK:EQUS"ROL zpx,X",dresult
   TIME 6+(4*Tadjust) :ROL addrFE:ROL addrFE:STOP:CHECK:EQUS"ROL addrFE",dresult
   TIME 7+(4*Tadjust)+(1*Ta2)-cpucmos :ROL addrFE,X:ROL addrFE,X:STOP:CHECK:EQUS"ROL addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :ROL addrFF,X:ROL addrFF,X:STOP:CHECK:EQUS"ROL addrFF,X",dresult

   TIME 2 :ROR A:ROR A:STOP:CHECK:EQUS"ROR A",dresult
   TIME 5 :ROR zp:ROR zp:STOP:CHECK:EQUS"ROR zp",dresult
   TIME 6 :ROR zpx,X:ROR zpx,X:STOP:CHECK:EQUS"ROR zpx,X",dresult
   TIME 6+(4*Tadjust) :ROR addrFE:ROR addrFE:STOP:CHECK:EQUS"ROR addrFE",dresult
   TIME 7+(4*Tadjust)+(1*Ta2)-cpucmos :ROR addrFE,X:ROR addrFE,X:STOP:CHECK:EQUS"ROR addrFE,X",dresult
   TIME 7+(3*Tadjust)+(2*Ta2) :ROR addrFF,X:ROR addrFF,X:STOP:CHECK:EQUS"ROR addrFF,X",dresult

   {LDA #a DIV256: PHA:LDA#a MOD256:PHA :PHP:LDA #b DIV256: PHA:LDA#b MOD256:PHA:PHP
   TIME 6: RTI:.b RTI:.a STOP:CHECK:EQUS"RTI",dresult}
   {LDA #a DIV256: PHA:LDA#a MOD256:PHA:LDA #b DIV256: PHA:LDA#b MOD256:PHA
   TIME 6: .b RTS:.a RTS:STOP:CHECK:EQUS"RTS",dresult}

   TIME 2 :SBC #imm:SBC #imm:STOP:CHECK:EQUS"SBC #imm",dresult
   TIME 3 :SBC zp:SBC zp:STOP:CHECK:EQUS"SBC zp",dresult
   TIME 4 :SBC zpx,X:SBC zpx,X:STOP:CHECK:EQUS"SBC zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :SBC (indirFE):SBC (indirFE):STOP:CHECK:EQUS"SBC (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :SBC addrFF :SBC addrFF :STOP:CHECK:EQUS"SBC addrFF",dresult
   TIME 4+(2*Tadjust) :SBC addrFE,X:SBC addrFE,X:STOP:CHECK:EQUS"SBC addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :SBC addrFF,X:SBC addrFF,X:STOP:CHECK:EQUS"SBC addrFF,X",dresult
   TIME 4+(2*Tadjust) :SBC addrFE,Y:SBC addrFE,Y:STOP:CHECK:EQUS"SBC addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :SBC addrFF,Y:SBC addrFF,Y:STOP:CHECK:EQUS"SBC addrFF,Y",dresult
   TIME 6+(2*Tadjust) :SBC (indirFE+1,X):SBC (indirFE+1,X):STOP:CHECK:EQUS"SBC (indirFE+1,X)",dresult
   TIME 5+(1*Tadjust) :SBC (indirFE),Y:SBC (indirFE),Y:STOP:CHECK:EQUS"SBC (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :SBC (indirFF),Y:SBC (indirFF),Y:STOP:CHECK:EQUS"SBC (indirFF),Y",dresult

   TIME 2+1 +cpucmos:SED:SBC #imm:SBC #imm:STOP:CHECK:EQUS"SED SBC #imm",dresult
   TIME 3+1 +cpucmos:SED:SBC zp:SBC zp:STOP:CHECK:EQUS"SED SBC zp",dresult
   TIME 4+1 +cpucmos:SED:SBC zpx,X:SBC zpx,X:STOP:CHECK:EQUS"SED SBC zpx,X",dresult
   IF cpucmos
      TIME 5+1+(1*Tadjust) +cpucmos:SED:SBC (indirFE):SBC (indirFE):STOP:CHECK:EQUS"SED SBC (indirFE)",dresult
   ENDIF
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:SBC addrFF :SBC addrFF :STOP:CHECK:EQUS"SED SBC addrFF",dresult
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:SBC addrFE,X:SBC addrFE,X:STOP:CHECK:EQUS"SED SBC addrFE,X",dresult
   TIME 5+1+(1*Tadjust)+(2*Ta2) +cpucmos:SED:SBC addrFF,X:SBC addrFF,X:STOP:CHECK:EQUS"SED SBC addrFF,X",dresult
   TIME 4+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:SBC addrFE,Y:SBC addrFE,Y:STOP:CHECK:EQUS"SED SBC addrFE,Y",dresult
   TIME 5+1+(1*Tadjust)+(2*Ta2) +cpucmos:SED:SBC addrFF,Y:SBC addrFF,Y:STOP:CHECK:EQUS"SED SBC addrFF,Y",dresult
   TIME 6+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:SBC (indirFE+1,X):SBC (indirFE+1,X):STOP:CHECK:EQUS"SED SBC (indirFE+1,X)",dresult
   TIME 5+1+(1*Tadjust) +cpucmos:SED:SBC (indirFE),Y:SBC (indirFE),Y:STOP:CHECK:EQUS"SED SBC (indirFE),Y",dresult
   TIME 6+1+(1*Tadjust)+(1*Ta2) +cpucmos:SED:SBC (indirFF),Y:SBC (indirFF),Y:STOP:CHECK:EQUS"SED SBC (indirFF),Y",dresult

   TIME 2 :SEC:SEC:STOP:CHECK:EQUS"SEC",dresult
   TIME 2 :SED:SED:STOP:CLD:CHECK:EQUS"SED",dresult
   TIME 2 :SEI:SEI:STOP:CHECK:EQUS"SEI",dresult
   TIME 3 :STA zp:STA zp:STOP:CHECK:EQUS"STA zp",dresult
   TIME 4 :STA zpx,X:STA zpx,X:STOP:CHECK:EQUS"STA zpx,X",dresult
   IF cpucmos
      TIME 5+(1*Tadjust) :STA (indirFE):STA (indirFE):STOP:CHECK:EQUS"STA (indirFE)",dresult
   ENDIF
   TIME 4+(2*Tadjust) :STA addrFE:STA addrFE:STOP:CHECK:EQUS"STA addrFE",dresult
   TIME 5+(3*Tadjust) :STA addrFE,X:STA addrFE,X:STOP:CHECK:EQUS"STA addrFE,X",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :STA addrFF,X:STA addrFF,X:STOP:CHECK:EQUS"STA addrFF,X",dresult
   TIME 5+(3*Tadjust) :STA addrFE,Y:STA addrFE,Y:STOP:CHECK:EQUS"STA addrFE,Y",dresult
   TIME 5+(1*Tadjust)+(2*Ta2) :STA addrFF,Y:STA addrFF,Y:STOP:CHECK:EQUS"STA addrFF,Y",dresult
   TIME 6+(2*Tadjust) :STA (indirFE+1,X):STA (indirFE+1,X):STOP:CHECK:EQUS"STA (indirFE+1,X)",dresult
   TIME 6+(2*Tadjust) :STA (indirFE),Y:STA (indirFE),Y:STOP:CHECK:EQUS"STA (indirFE),Y",dresult
   TIME 6+(2*Tadjust) :STA (indirFF),Y:STA (indirFF),Y:STOP:CHECK:EQUS"STA (indirFF),Y",dresult
   TIME 3 :STX zp:STX zp:STOP:CHECK:EQUS"STX zp",dresult
   TIME 4 :STX zpx,Y:STX zpx,Y:STOP:CHECK:EQUS"STX zpx,Y",dresult
   TIME 4+(2*Tadjust) :STX addrFE:STX addrFE :STOP:CHECK:EQUS"STX addrFE",dresult
   TIME 3 :STY zp:STY zp:STOP:CHECK:EQUS"STY zp",dresult
   TIME 4 :STY zpx,X:STY zpx,X:STOP:CHECK:EQUS"STY zpx,X",dresult
   TIME 4+(2*Tadjust) :STY addrFE:STY addrFE :STOP:CHECK:EQUS"STY addrFE",dresult

   IF (cpucmos AND (target = 1))
      TIME 5+(3*Tadjust) :EQUB&03:STA addrFE,X:EQUB&03:STA addrFE,X:STOP:CHECK:EQUS"NOP1: STA addrFE,X",dresult
      TIME 4+(0*Tadjust) :LDA &FE34 :LDA &FE34 :STOP:CHECK:EQUS"LDA &FE34 (no stretch)",dresult
   ENDIF

   IF cpucmos

      TIME 3 :STZ zp:STZ zp:STOP:CHECK:EQUS"STZ zp",dresult
      TIME 4 :STZ zpx,X:STZ zpx,X:STOP:CHECK:EQUS"STZ zpx,X",dresult
      TIME 4+(2*Tadjust) :STZ addrFE:STZ addrFE :STOP:CHECK:EQUS"STZ addrFE",dresult
      TIME 5+(3*Tadjust) :STZ addrFE,X:STZ addrFE,X :STOP:CHECK:EQUS"STZ addrFE,X",dresult
      TIME 5+(1*Tadjust) :STZ addrFF,X:STZ addrFF,X :STOP:CHECK:EQUS"STZ addrFF,X",dresult
   ENDIF

   TIME 2 :TAX:TAX:STOP:CHECK:EQUS"TAX",dresult
   TIME 2 :TAY:TAY:STOP:CHECK:EQUS"TAY",dresult

   IF cpucmos
      TIME 5 : TRB zp:TRB zp:STOP:CHECK:EQUS"TRB zp",dresult
      TIME 6+(4*Tadjust) : TRB addrFF:TRB addrFF:STOP:CHECK:EQUS"TRB addrFF",dresult
      TIME 5 : TSB zp:TSB zp:STOP:CHECK:EQUS"TSB zp",dresult
      TIME 6+(4*Tadjust) : TSB addrFF:TSB addrFF:STOP:CHECK:EQUS"TSB addrFF",dresult
   ENDIF

   TIME 2 :TSX:TSX:STOP:CHECK:EQUS"TSX",dresult
   TIME 2 :TXA:TXA:STOP:CHECK:EQUS"TXA",dresult
   TSX:TIME 2 :TXS:TXS:STOP:CHECK:EQUS"TXS",dresult
   TIME 2 :TYA:TYA:STOP:CHECK:EQUS"TYA",dresult
   JSR printstring:EQUS"Testing CLI ( warning may fail )",13,dterm
   CLI:TIME 2 :CLI:CLI:STOP:CHECK:EQUS"CLI",dresult

   IF cpu = 0
      JSR printstring:EQUS"Done!",13,"Checking undocumented instructions...",13,dterm

      TIME 2 :EQUB &4B,imm:EQUB &4B,imm:STOP:CHECK:EQUS"&4B ALR ( ASR) #imm",dresult
      TIME 2 :EQUB &0B,imm:EQUB &0B,imm:STOP:CHECK:EQUS"&0B ANC ( ANC) #imm",dresult
      TIME 2 :EQUB &2B,imm:EQUB &2B,imm:STOP:CHECK:EQUS"&0B ANC ( ANC 2) #imm",dresult
      TIME 2 :EQUB &8B,imm:EQUB &8B,imm:STOP:CHECK:EQUS"&8B ANE ( XAA) #imm",dresult
      TIME 2 :EQUB &6B,imm:EQUB &6B,imm:STOP:CHECK:EQUS"&6B ARR #imm",dresult
      TIME 5 :EQUB&C7,zp:EQUB&C7,zp:STOP:CHECK:EQUS"&C7 DCP (DCM) zp",dresult
      TIME 6 :EQUB&D7,zpx:EQUB&D7,zpx:STOP:CHECK:EQUS"&D7 DCP (DCM) zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &CF,addrFF :STOP:CHECK:EQUS"&CF DCP (DCM) addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &DF,addrFE :STOP:CHECK:EQUS"&DF DCP (DCM) addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &DF,addrFF :STOP:CHECK:EQUS"&DF DCP (DCM) addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &DB,addrFE :STOP:CHECK:EQUS"&DB DCP (DCM) addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &DB,addrFF :STOP:CHECK:EQUS"&DB DCP (DCM) addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&C3,indirFE+1:EQUB&C3,indirFE+1:STOP:CHECK:EQUS"&C3 DCP (DCM) (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&D3,indirFE:EQUB&D3,indirFE:STOP:CHECK:EQUS"&D3 DCP (DCM) (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&D3,indirFF:EQUB&D3,indirFF:STOP:CHECK:EQUS"&D3 DCP (DCM) (indirFF),Y",dresult
      TIME 5 :EQUB&E7,zp:EQUB&E7,zp:STOP:CHECK:EQUS"&E7 ISC (ISB,INS) zp",dresult
      TIME 6 :EQUB&F7,zpx:EQUB&F7,zpx:STOP:CHECK:EQUS"&F7 ISC (ISB,INS) zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &EF,addrFF:STOP:CHECK:EQUS"&EF ISC (ISB,INS) addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &FF,addrFE:STOP:CHECK:EQUS"&FF ISC (ISB,INS) addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &FF,addrFF:STOP:CHECK:EQUS"&FF ISC (ISB,INS) addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &FB,addrFE:STOP:CHECK:EQUS"&FB ISC (ISB,INS) addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &FB,addrFF:STOP:CHECK:EQUS"&FB ISC (ISB,INS) addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&E3,indirFE+1:EQUB&E3,indirFE+1:STOP:CHECK:EQUS"&E3 ISC (ISB,INS) (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&F3,indirFE:EQUB&F3,indirFE:STOP:CHECK:EQUS"&F3 ISC (ISB,INS) (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&F3,indirFF:EQUB&F3,indirFF:STOP:CHECK:EQUS"&F3 ISC (ISB,INS) (indirFF),Y",dresult
      TSX:STX zpx:TIME 4+4+(2*Ta2) :UNDOC3BYTE &BB,addrFE:LDX zpx:LDX zpx:TXS:STOP:CHECK:EQUS"&BB LAS (LAR) addrFE,Y",dresult
      TSX:STX zpx:TIME 5+4+(3*Ta2) :UNDOC3BYTE &BB,addrFF:LDX zpx:LDX zpx:TXS:STOP:CHECK:EQUS"&BB LAS (LAR) addrFF,Y",dresult
      TIME 3 :EQUB&A7,zp:EQUB&A7,zp:STOP:CHECK:EQUS"&A7 LAX zp",dresult
      TIME 4 :EQUB&B7,zpx:EQUB&B7,zpx:STOP:CHECK:EQUS"&B7 LAX zpx",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &AF,addrFF:STOP:CHECK:EQUS"&AF LAX addrFF",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &BF,addrFE:STOP:CHECK:EQUS"&BF LAX addrFE,Y",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &BF,addrFF:STOP:CHECK:EQUS"&BF LAX addrFF,Y",dresult
      TIME 6+(2*Ta2)+1 :EQUB&A3,indirFE+1:LDX #1:EQUB&A3,indirFE+1:STOP:CHECK:EQUS"&A3 LAX (indirFE+1,X)",dresult
      TIME 5+(1*Ta2) :EQUB&B3,indirFE:EQUB&B3,indirFE:STOP:CHECK:EQUS"&B3 LAX (indirFE),Y",dresult
      TIME 6+(2*Ta2) :EQUB&B3,indirFF:EQUB&B3,indirFF:STOP:CHECK:EQUS"&B3 LAX (indirFF),Y",dresult
      TIME 2 :EQUB&AB,imm:EQUB&AB,imm:STOP:CHECK:EQUS"&AB LXA #imm",dresult
      TIME 5 :EQUB&27,zp:EQUB&27,zp:STOP:CHECK:EQUS"&27 RLA zp",dresult
      TIME 6 :EQUB&37,zpx:EQUB&37,zpx:STOP:CHECK:EQUS"&37 RLA zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &2F,addrFF:STOP:CHECK:EQUS"&2F RLA addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &3F,addrFE:STOP:CHECK:EQUS"&3F RLA addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &3F,addrFF:STOP:CHECK:EQUS"&3F RLA addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &3B,addrFE:STOP:CHECK:EQUS"&3B RLA addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &3B,addrFF:STOP:CHECK:EQUS"&3B RLA addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&23,indirFE+1:EQUB&23,indirFE+1:STOP:CHECK:EQUS"&23 RLA (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&33,indirFE:EQUB&33,indirFE:STOP:CHECK:EQUS"&33 RLA (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&33,indirFF:EQUB&33,indirFF:STOP:CHECK:EQUS"&33 RLA (indirFF),Y",dresult
      TIME 5 :EQUB&67,zp:EQUB&67,zp:STOP:CHECK:EQUS"&67 RRA zp",dresult
      TIME 6 :EQUB&77,zpx:EQUB&77,zpx:STOP:CHECK:EQUS"&77 RRA zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &6F,addrFF:STOP:CHECK:EQUS"&6F RRA addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &7F,addrFE:STOP:CHECK:EQUS"&7F RRA addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &7F,addrFF:STOP:CHECK:EQUS"&7F RRA addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &7B,addrFE:STOP:CHECK:EQUS"&7B RRA addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &7B,addrFF:STOP:CHECK:EQUS"&7B RRA addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&63,indirFE+1:EQUB&63,indirFE+1:STOP:CHECK:EQUS"&63 RRA (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&73,indirFE:EQUB&73,indirFE:STOP:CHECK:EQUS"&73 RRA (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&73,indirFF:EQUB&73,indirFF:STOP:CHECK:EQUS"&73 RRA (indirFF),Y",dresult
      TIME 3 :EQUB&87,zp:EQUB&87,zp:STOP:CHECK:EQUS"&87 SAX (AAX) zp",dresult
      TIME 4 :EQUB&97,zpx:EQUB&97,zpx:STOP:CHECK:EQUS"&97 SAX (AAX) zpx",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &8F,addrFF:STOP:CHECK:EQUS"&8F SAX addrFF",dresult
      TIME 6+(2*Ta2) :EQUB&83,indirFE+1:EQUB&83,indirFE+1:STOP:CHECK:EQUS"&83 SAX (AAX) (indirFE+1,X)",dresult
      TIME 2 :EQUB&CB,imm:EQUB&CB,imm:STOP:CHECK:EQUS"&CB SBX #imm",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &9F,addrFE:STOP:CHECK:EQUS"&9F SHA (AHX, AXA) addrFE,Y",dresult
      TIME 5+(1*Ta2) :UNDOC3BYTE &9F,addrFF:STOP:CHECK:EQUS"&9F SHA (AHX, AXA) addrFF,Y",dresult
      TIME 6+(2*Ta2) :EQUB&93,indirFE:EQUB&93,indirFE:STOP:CHECK:EQUS"&93 SHA (AHX, AXA) (indirFE),Y",dresult
      TIME 6+(1*Ta2) :EQUB&93,indirFF:EQUB&93,indirFF:STOP:CHECK:EQUS"&93 SHA (AHX, AXA) (indirFF),Y",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &9E,addrFE:STOP:CHECK:EQUS"&9E SHX (A11, SXA, XAS) addrFE,Y",dresult
      LDX #8:TIME 5+1+(1*Ta2) :LDA #0:UNDOC3BYTE &9E,addrFF:STOP:CHECK:EQUS"&9E SHX (A11, SXA, XAS) addrFF,Y",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &9C,addrFE:STOP:CHECK:EQUS"&9C SHY (A11, SYA, SAY) addrFE,X",dresult
      LDY #8:TIME 5+1+(1*Ta2) :LDA #0:UNDOC3BYTE &9C,addrFF:STOP:CHECK:EQUS"&9C SHY (A11, SYA, SAY) addrFF,X",dresult
      TIME 5 :EQUB&07,zp:EQUB07,zp:STOP:CHECK:EQUS"&07 SLO (ASO) zp",dresult

      TIME 6 :EQUB&17,zpx:EQUB&17,zpx:STOP:CHECK:EQUS"&17 SLO (ASO) zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &0F,addrFF:STOP:CHECK:EQUS"&0F SLO (ASO) addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &1F,addrFE:STOP:CHECK:EQUS"&1F SLO (ASO) addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &1F,addrFF:STOP:CHECK:EQUS"&1F SLO (ASO) addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &1B,addrFE:STOP:CHECK:EQUS"&1B SLO (ASO) addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &1B,addrFF:STOP:CHECK:EQUS"&1B SLO (ASO) addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&03,indirFE+1:EQUB&03,indirFE+1:STOP:CHECK:EQUS"&03 SLO (ASO) (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&13,indirFE:EQUB&13,indirFE:STOP:CHECK:EQUS"&13 SLO (ASO) (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&13,indirFF:EQUB&13,indirFF:STOP:CHECK:EQUS"&13 SLO (ASO) (indirFF),Y",dresult
      TIME 5 :EQUB&47,zp:EQUB&47,zp:STOP:CHECK:EQUS"&47 SRE (LSE) zp",dresult
      TIME 6 :EQUB&57,zpx:EQUB&57,zpx:STOP:CHECK:EQUS"&57 SRE (LSE) zpx",dresult
      TIME 6+(4*Ta2) :UNDOC3BYTE &4F,addrFF:STOP:CHECK:EQUS"&4F SRE (LSE) addrFF",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &5F,addrFE:STOP:CHECK:EQUS"&5F SRE (LSE) addrFE,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &5F,addrFF:STOP:CHECK:EQUS"&5F SRE (LSE) addrFF,X",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &5B,addrFE:STOP:CHECK:EQUS"&5B SRE (LSE) addrFE,Y",dresult
      TIME 7+(5*Ta2) :UNDOC3BYTE &5B,addrFF:STOP:CHECK:EQUS"&5B SRE (LSE) addrFF,Y",dresult
      TIME 8+(4*Ta2) :EQUB&43,indirFE+1:EQUB&43,indirFE+1:STOP:CHECK:EQUS"&43 SRE (LSE) (indirFE+1,X)",dresult
      TIME 8+(4*Ta2) :EQUB&53,indirFE:EQUB&53,indirFE:STOP:CHECK:EQUS"&53 SRE (LSE) (indirFE),Y",dresult
      TIME 8+(4*Ta2) :EQUB&53,indirFF:EQUB&53,indirFF:STOP:CHECK:EQUS"&53 SRE (LSE) (indirFF),Y",dresult
      TSX:STX zpx:TIME 5+4+(3*Ta2) :UNDOC3BYTE &9B,addrFE:LDX zpx:LDX zpx:TXS:STOP:CHECK:EQUS"&9B TAS (XAS,SHS) addrFE,Y",dresult
      ; the following doesn't correctly test page boundary crossing . We probably should define where in memory this actually accesses
      TSX:STX zpx:TIME 5+3+4+(1*Ta2) :LDA #0:TAX:TXS:UNDOC3BYTE &9B,addrFF:LDX zpx:LDX zpx:TXS:STOP:CHECK:EQUS"&9B TAS (XAS,SHS) addrFF,Y",dresult
      TIME 2 :EQUB&EB,imm:EQUB&EB,imm:STOP:CHECK:EQUS"&EB USBC (SBC) #imm",dresult
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
      TIME 3 :EQUB&04,zp:EQUB&04,zp:STOP:CHECK:EQUS"&04 NOP zp",dresult
      TIME 3 :EQUB&44,zp:EQUB&44,zp:STOP:CHECK:EQUS"&44 NOP zp",dresult
      TIME 3 :EQUB&64,zp:EQUB&64,zp:STOP:CHECK:EQUS"&64 NOP zp",dresult
      TIME 4 :EQUB&14,zpx:EQUB&14,zpx:STOP:CHECK:EQUS"&14 NOP zpx,X",dresult
      TIME 4 :EQUB&34,zpx:EQUB&34,zpx:STOP:CHECK:EQUS"&34 NOP zpx,X",dresult
      TIME 4 :EQUB&54,zpx:EQUB&54,zpx:STOP:CHECK:EQUS"&54 NOP zpx,X",dresult
      TIME 4 :EQUB&74,zpx:EQUB&74,zpx:STOP:CHECK:EQUS"&74 NOP zpx,X",dresult
      TIME 4 :EQUB&D4,zpx:EQUB&D4,zpx:STOP:CHECK:EQUS"&D4 NOP zpx,X",dresult
      TIME 4 :EQUB&F4,zpx:EQUB&F4,zpx:STOP:CHECK:EQUS"&F4 NOP zpx,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &0C,addrFF:STOP:CHECK:EQUS"&0C NOP addrFF",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &1C,addrFE:STOP:CHECK:EQUS"&1C NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &1C,addrFF:STOP:CHECK:EQUS"&1C NOP addrFF,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &3C,addrFE:STOP:CHECK:EQUS"&3C NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &3C,addrFF:STOP:CHECK:EQUS"&3C NOP addrFF,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &5C,addrFE:STOP:CHECK:EQUS"&5C NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &5C,addrFF:STOP:CHECK:EQUS"&5C NOP addrFF,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &7C,addrFE:STOP:CHECK:EQUS"&7C NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &7C,addrFF:STOP:CHECK:EQUS"&7C NOP addrFF,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &DC,addrFE:STOP:CHECK:EQUS"&DC NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &DC,addrFF:STOP:CHECK:EQUS"&DC NOP addrFF,X",dresult
      TIME 4+(2*Ta2) :UNDOC3BYTE &FC,addrFE:STOP:CHECK:EQUS"&FC NOP addrFE,X",dresult
      TIME 5+(3*Ta2) :UNDOC3BYTE &FC,addrFF:STOP:CHECK:EQUS"&FC NOP addrFF,X",dresult
   ; untested BRK
   ELSE
      JSR printstring:EQUS"Done!",13,"Checking NOP instructions...",13,dterm
      TIME 1 :UNDOC1BYTE &03:STOP:CHECK:EQUS"&03 NOP",dresult
      TIME 1 :UNDOC1BYTE &0B:STOP:CHECK:EQUS"&0B NOP",dresult
      TIME 1 :UNDOC1BYTE &13:STOP:CHECK:EQUS"&13 NOP",dresult
      TIME 1 :UNDOC1BYTE &1B:STOP:CHECK:EQUS"&1B NOP",dresult
      TIME 1 :UNDOC1BYTE &23:STOP:CHECK:EQUS"&23 NOP",dresult
      TIME 1 :UNDOC1BYTE &2B:STOP:CHECK:EQUS"&2B NOP",dresult
      TIME 1 :UNDOC1BYTE &33:STOP:CHECK:EQUS"&33 NOP",dresult
      TIME 1 :UNDOC1BYTE &3B:STOP:CHECK:EQUS"&3B NOP",dresult
      TIME 1 :UNDOC1BYTE &43:STOP:CHECK:EQUS"&43 NOP",dresult
      TIME 1 :UNDOC1BYTE &4B:STOP:CHECK:EQUS"&4B NOP",dresult
      TIME 1 :UNDOC1BYTE &53:STOP:CHECK:EQUS"&53 NOP",dresult
      TIME 1 :UNDOC1BYTE &5B:STOP:CHECK:EQUS"&5B NOP",dresult
      TIME 1 :UNDOC1BYTE &63:STOP:CHECK:EQUS"&63 NOP",dresult
      TIME 1 :UNDOC1BYTE &6B:STOP:CHECK:EQUS"&6B NOP",dresult
      TIME 1 :UNDOC1BYTE &73:STOP:CHECK:EQUS"&73 NOP",dresult
      TIME 1 :UNDOC1BYTE &7B:STOP:CHECK:EQUS"&7B NOP",dresult
      TIME 1 :UNDOC1BYTE &83:STOP:CHECK:EQUS"&83 NOP",dresult
      TIME 1 :UNDOC1BYTE &8B:STOP:CHECK:EQUS"&8B NOP",dresult
      TIME 1 :UNDOC1BYTE &93:STOP:CHECK:EQUS"&93 NOP",dresult
      TIME 1 :UNDOC1BYTE &9B:STOP:CHECK:EQUS"&9B NOP",dresult
      TIME 1 :UNDOC1BYTE &A3:STOP:CHECK:EQUS"&A3 NOP",dresult
      TIME 1 :UNDOC1BYTE &AB:STOP:CHECK:EQUS"&AB NOP",dresult
      TIME 1 :UNDOC1BYTE &B3:STOP:CHECK:EQUS"&B3 NOP",dresult
      TIME 1 :UNDOC1BYTE &BB:STOP:CHECK:EQUS"&BB NOP",dresult
      TIME 1 :UNDOC1BYTE &C3:STOP:CHECK:EQUS"&C3 NOP",dresult
      TIME 1 :UNDOC1BYTE &CB:STOP:CHECK:EQUS"&CB NOP",dresult
      TIME 1 :UNDOC1BYTE &D3:STOP:CHECK:EQUS"&D3 NOP",dresult
      TIME 1 :UNDOC1BYTE &DB:STOP:CHECK:EQUS"&DB NOP",dresult
      TIME 1 :UNDOC1BYTE &E3:STOP:CHECK:EQUS"&E3 NOP",dresult
      TIME 1 :UNDOC1BYTE &EB:STOP:CHECK:EQUS"&EB NOP",dresult
      TIME 1 :UNDOC1BYTE &F3:STOP:CHECK:EQUS"&F3 NOP",dresult
      TIME 1 :UNDOC1BYTE &FB:STOP:CHECK:EQUS"&FB NOP",dresult

      IF cpu = 1
         ; 65C02 these are BBS BBR instructions
         TIME 1 :UNDOC1BYTE &0F:STOP:CHECK:EQUS"&0F NOP",dresult
         TIME 1 :UNDOC1BYTE &1F:STOP:CHECK:EQUS"&1F NOP",dresult
         TIME 1 :UNDOC1BYTE &2F:STOP:CHECK:EQUS"&2F NOP",dresult
         TIME 1 :UNDOC1BYTE &3F:STOP:CHECK:EQUS"&3F NOP",dresult
         TIME 1 :UNDOC1BYTE &4F:STOP:CHECK:EQUS"&4F NOP",dresult
         TIME 1 :UNDOC1BYTE &5F:STOP:CHECK:EQUS"&5F NOP",dresult
         TIME 1 :UNDOC1BYTE &6F:STOP:CHECK:EQUS"&6F NOP",dresult
         TIME 1 :UNDOC1BYTE &7F:STOP:CHECK:EQUS"&7F NOP",dresult
         TIME 1 :UNDOC1BYTE &8F:STOP:CHECK:EQUS"&8F NOP",dresult
         TIME 1 :UNDOC1BYTE &9F:STOP:CHECK:EQUS"&9F NOP",dresult
         TIME 1 :UNDOC1BYTE &AF:STOP:CHECK:EQUS"&AF NOP",dresult
         TIME 1 :UNDOC1BYTE &BF:STOP:CHECK:EQUS"&BF NOP",dresult
         TIME 1 :UNDOC1BYTE &CF:STOP:CHECK:EQUS"&CF NOP",dresult
         TIME 1 :UNDOC1BYTE &DF:STOP:CHECK:EQUS"&DF NOP",dresult
         TIME 1 :UNDOC1BYTE &EF:STOP:CHECK:EQUS"&EF NOP",dresult
         TIME 1 :UNDOC1BYTE &FF:STOP:CHECK:EQUS"&FF NOP",dresult
         ; 65C02 RMB SMB
         TIME 1 :UNDOC1BYTE &07:STOP:CHECK:EQUS"&07 NOP",dresult
         TIME 1 :UNDOC1BYTE &17:STOP:CHECK:EQUS"&17 NOP",dresult
         TIME 1 :UNDOC1BYTE &27:STOP:CHECK:EQUS"&27 NOP",dresult
         TIME 1 :UNDOC1BYTE &37:STOP:CHECK:EQUS"&37 NOP",dresult
         TIME 1 :UNDOC1BYTE &47:STOP:CHECK:EQUS"&47 NOP",dresult
         TIME 1 :UNDOC1BYTE &57:STOP:CHECK:EQUS"&57 NOP",dresult
         TIME 1 :UNDOC1BYTE &67:STOP:CHECK:EQUS"&67 NOP",dresult
         TIME 1 :UNDOC1BYTE &77:STOP:CHECK:EQUS"&77 NOP",dresult
         TIME 1 :UNDOC1BYTE &87:STOP:CHECK:EQUS"&87 NOP",dresult
         TIME 1 :UNDOC1BYTE &97:STOP:CHECK:EQUS"&97 NOP",dresult
         TIME 1 :UNDOC1BYTE &A7:STOP:CHECK:EQUS"&A7 NOP",dresult
         TIME 1 :UNDOC1BYTE &B7:STOP:CHECK:EQUS"&B7 NOP",dresult
         TIME 1 :UNDOC1BYTE &C7:STOP:CHECK:EQUS"&C7 NOP",dresult
         TIME 1 :UNDOC1BYTE &D7:STOP:CHECK:EQUS"&D7 NOP",dresult
         TIME 1 :UNDOC1BYTE &E7:STOP:CHECK:EQUS"&E7 NOP",dresult
         TIME 1 :UNDOC1BYTE &F7:STOP:CHECK:EQUS"&F7 NOP",dresult
      ENDIF

      TIME 2 :UNDOC2BYTE &02,imm:STOP:CHECK:EQUS"&02 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &22,imm:STOP:CHECK:EQUS"&22 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &42,imm:STOP:CHECK:EQUS"&42 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &62,imm:STOP:CHECK:EQUS"&62 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &82,imm:STOP:CHECK:EQUS"&82 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &C2,imm:STOP:CHECK:EQUS"&C2 NOP #imm",dresult
      TIME 2 :UNDOC2BYTE &E2,imm:STOP:CHECK:EQUS"&E2 NOP #imm",dresult
      TIME 3 :UNDOC2BYTE &44,zp:STOP:CHECK:EQUS"&44 NOP zp",dresult
      TIME 4 :UNDOC2BYTE &54,zpx:STOP:CHECK:EQUS"&54 NOP zpx",dresult
      TIME 4 :UNDOC2BYTE &D4,zpx:STOP:CHECK:EQUS"&D4 NOP zpx",dresult
      TIME 4 :UNDOC2BYTE &F4,zpx:STOP:CHECK:EQUS"&F4 NOP zpx",dresult
      TIME 8 :UNDOC3BYTE &5C,addrFF:STOP:CHECK:EQUS"&5C NOP addrFF",dresult
      TIME 4+(2*Tadjust) :UNDOC3BYTE &DC,addrFF:STOP:CHECK:EQUS"&DC NOP addrFF",dresult
      TIME 4+(2*Tadjust) :UNDOC3BYTE &FC,addrFF:STOP:CHECK:EQUS"&FC NOP addrFF",dresult

   ENDIF

   JSR printstring:EQUS"Done!",13,13,"Number of failures : 0x",dterm
   LDA passfailzp : JSR PrHex
   LDA #13: JSR osasci

   LDA passfailzp
   JMP endoftests


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

.blockcopyloop
   LDA (stringptr),Y
   DEY
   STA (ptr2),Y
   CPY #0
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
   CLD
   BNE testfailed

.correct
{
   ; skip string
   PLA
   STA stringptr
   PLA
   STA stringptr+1
   LDY #0
.PrTextLp
   INY
   LDA (stringptr),Y
   CMP #dresult
   BCC PrTextLp

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

.testfailed
   INC passfailzp

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
   JSR osasci
   INY
   BNE PrTextLp

.PrDict
   CMP   #dterm
   BEQ PrTextEnd

; print timing error, format column first
   TYA
   PHA
.prcolumn
   LDA #32
   JSR osasci
   INY
   CPY #37
   BMI prcolumn

   TXA
   CLC
   BPL shiftscale
   SEC
.shiftscale
   ROR A

   JSR PrHex
   LDA #13
   JSR osasci

   PLA
   TAY

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

.PrHex
  PHA:LSR A:LSR A:LSR A:LSR A
  JSR PyNybble :PLA
.PyNybble
  AND #15:CMP #10:BCC PrDigit
  ADC #6
.PrDigit
  ADC #'0':JMP osasci

   .end

IF target = 2
   SAVE "6502tim.prg",start,end
ELSE
   SAVE"6502tim", start, end
ENDIF