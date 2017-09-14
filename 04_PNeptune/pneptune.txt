Parallel Neptune Core - An extended Saturn processor
----------------------------------------------------

Programming model

16 128 bit Alu registers, equivalent to A..D
5 bits P register
256 Level Hardware stack
Carry and comparion flags are separated and have their own branches on true/false
Per opcode decimal/hex flag for ALU registers

The assembly syntax has been changed and the encoding of opcodes too. It doesn't
make at this point much sense to cram all opcodes issome tiny encoding like 
the Saturn. Need for more than 16 nibbles means that compatibility with the
saturn even at the assembly level is problematic. 

Contrary to the Saturn, all register combintions are possible.

Register fields
                      | <------ A ------> |
                              | <-- X --> |
                              | XS|  
      WS-1              4   3   2   1   0  
      +---+--- ... ---+---+---+---+---+---+   
      | S |           | S | E | E | E | E |  
      +---+--- ... ---+---+---+---+---+---+

      +---+--- ... ---+---+---+---+---+---+
      | 0 |    WS - 2 digits significand  |
      +---+--- ... ---+---+---+---+---+---+
      
Encoding

Opcodes on arithmetic registers hex/decimal

Arithmetic opcodes ADD, SUB, RSUB, EQ, NEQ, LT, LE, GT, GE

 31  28 27   24 23  20 19  16 15    8 7   0
+------+-------+------+------+-------+-----+
| 000x | Opcode|  Rd  |  Rs  | start | end | 
+------+-------+------+------+-------+-----+

Opcodes on P register
 31  28 27   24 23  20 19  16 15    8 7     0
+------+-------+------+------+-------+-------+
| 0010 | Opcode|  Rd  | 0000 | Start |  lit  | 
+------+-------+------+------+-------+-------+

Load immediate to ALU register up to 5 nibbles @P
 31  28 27   24 23  20 19  16 15    8 7     0
+------+-------+------+------+-------+-------+
| 0011 |   n   |  Rd  |       literal        | 
+------+-------+------+------+-------+-------+

Conditional/Unconditional jumps
 31  28 27   24 23  20 19  16 15          0
+------+-------+---------------------------+
| 0100 |  CCCC |    ---- address ------    | 
+------+-------+---------------------------+

Opcodes on Address registers
 31  28 27   24 23  20 19  16 15          0
+------+-------+------+------+-------------+
| 1000 | Opcode|  Rd  |  Rs  |    literal  | 
+------+-------+------+------+-------------+


Field  |  End (MSD) | Start (LSD)
-------+------------+------------
   S   |      31    |     31
   W   |      31    |      0
   M   |      30    |      3
   XS  |       2    |      2
   B   |       1    |      0
   X   |       2    |      0
   WP  |       p    |      0
   P   |       P    |      P

The register P can take values from 31 to 0.


   
ADD.H/D.f  dst, src   dst = dst+src
-----------------------------------

Add decimal/hex with field

Adds two numbers together. The field specifies the length of the operation.
Decimal adjust is done automatically and the carry flag is set/cleared 
depending on the result of the last digit. The source argument can be a 
register or a constant. The given constant will be used for the rightmost 
digit and the rest will be zeros. Used for A=A+1.

A=A+1 W     add.d.w     a,#1
A=A+C WP    add.d.wp    a,c
B=B+C X     add.h.x     b,c     in hexmode

SUB.H/D.f   dst, src   dst = dst+src
------------------------------------

Subtract decimal/hex with field

Subtracts two numbers together. The field specifies the length of the operation.
Decimal adjust is done automatically and the carry flag is set/cleared 
depending on the result of the last digit. The source argument can be a 
register or a constant. The given constant will be used for the rightmost 
digit and the rest will be zeros. Used for A=A-1.

A=A-1 W     sub.d.w     a,#1
A=A-C WP    sub.d.wp    a,c
B=B-C X     sub.h.x     b,c     in hexmode

RSUB.H/D.f   dst, src   dst = dst+src
------------------------------------

Reversed subtract decimal/hex with field

Subtracts two numbers together. The field specifies the length of the operation.
Decimal adjust is done automatically and the carry flag is set/cleared 
depending on the result of the last digit. The source argument can be a 
register or a constant. The given constant will be used for the rightmost 
digit and the rest will be zeros. Used for A=-A (A=0-A).

A=B-A W     rsub.d.w    a,b
A=-A WP     rsub.d.wp   a,#9
B=C-B X     rsub.h.x    b,c     in hexmode

EQ.H/D.f    dst,src     ?A=B
NEQ.H/D.f   dst,src     ?A#B
GT.H/D.f    dst,src     ?A>B
GTEQ.H/D.f  dst,src     ?A>=B
LT.H/D.f    dst,src     ?A<B
LTEQ.H/D.f  dst,src     ?A<=B
-----------------------------

Comparison operands. They affect the comparison flag and not the carry.
They should be followed by a JT/JNT opcode.

OR.f        dst,src     A=A|A 
XOR.f        dst,src    A=A^A 
AND.f        dst,src    A=A&A
-----------------------------

Logical operations. Do not affect carry.
 
MOV.f       dst, src    A=B
-----------------------------

Transfers the contents of src to dst. Does not affect the carry.

EX.f        dst, src    AEXB
-----------------------------

Exchanges the contents between src to dst. Does not affect the carry.

SR.D/H.f    dst,src     ASR
---------------------------

Shift right one nibble. Trown nibble sets/clears the shift flag.
This flag can be tested with JS/JNS.  

SR.D/H.f    dst,src     ASR
---------------------------

Shift right one nibble (D) or one bit (H). Trown nibble/bit sets/clears 
the shift flag. This flag can be tested with JS/JNS.  

LOADP       #n          P=n
---------------------------

Loads P. Does not affect the carry.

EQP         #n          ?P=n
----------------------------

Sets/clears the comparison flag if P equals/doesn't equal the given number.

NEQP        #n          ?P#n
----------------------------

Clears/sets the comparison flag if P equals/doesn't equal the given number.

INCP                    P=P+1
-----------------------------

Increments P. Affects carry on overflow and sets P to 0.

DECP                    P=P-1
-----------------------------

Decrements P. Affects carry on underflow and sets P to 31.


LDN         dst,#n      LA(x) n/LC(x) n
---------------------------------------

Load up to 5 nibbles at P in dst. Dst can be any register.



RET                      RTN
----------------------------

Return from subrutine

STOP
----------------------------

Stops the simulator

JMP                     GOxx
----------------------------

Unconditional jump

CALL                    GOSUB
-----------------------------

Unconditional call


JC                      GOC
JNC                     GONC
JT
JNT
JS
JNS
----------------------------

Conditional jumps.
Carry set
Carry cleared
Condition true
Condition false
Shift not zero
Shift zero


Assembler
---------

To assemble a file:

python pneptune_asm.py <filename.pnasm>

Two output files are generated:

filename.bin contains the generated code starting at address 0 as a text
file with hexadecial encoding, it can be used by the simulator directly 
or read by synthesis/HDL simulator tools like synplyfy, icarus verilog.

filename.lst is a listing file with original assembly and address opcode

Simulation
----------

Invoque the simulator like:

python pneptune_sim.py <code.bin>

A list of executed opcodes and results are written to the console:

PNeptune Simulator v1.00
   39 words read
Reset
00000  2000001e        LOADP    #1e             P: 1e
00004  31300005        LDN      B,#5            B: 0500000000000000000000000000000
00008  19431f00        MOV.W    C,B             C: 0500000000000000000000000000000
0000c  08331f00        ADD.D.W  B,B             B: 1000000000000000000000000000000
00010  08331f00        ADD.D.W  B,B             B: 2000000000000000000000000000000
00014  08341f00        ADD.D.W  B,C             B: 2500000000000000000000000000000
00018  19420400        MOV.A    C,A             C: 0500000000000000000000000000000
0001c  08440400        ADD.D.A  C,C             C: 0500000000000000000000000000000
00020  19401f00        MOV.W    C,0             C: 0000000000000000000000000000000
00024  5300000b        JNC      0002c
