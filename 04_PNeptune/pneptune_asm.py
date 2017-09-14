#!/usr/bin/python
from sys import *
'''
Parallel Neptune processor assembler

all opcodes are 32 bits long

Encoding:

Registers:

R0..R3 128 bit ALU registers
A0..A3  32 bit address/general purpose registers

Opcodes on arithmetic registers binary/decimal
 31  28 27   24 23  20 19  16 15    8 7   0
+------+-------+------+------+-------+-----+
| 0000 | Opcode|  Rd  |  Rs  | start | end | Arithmetic opcodes ADD, SUB, RSUB, EQ, NEQ, LT, LE, GT, GE
+------+-------+------+------+-------+-----+

Opcodes on arithmetic registers transfer, comparison, logic, shift
 31  28 27   24 23  20 19  16 15    8 7   0
+------+-------+------+------+-------+-----+
| 0001 | Opcode|  Rd  |  Rs  | start | end | Arithmetic opcodes ADD, SUB, RSUB, EQ, NEQ, LT, LE, GT, GE
+------+-------+------+------+-------+-----+

Opcodes on Address registers
 31  28 27   24 23  20 19  16 15          0
+------+-------+------+------+-------------+
| 0010 | Opcode|  Rd  |  Rs  |    literal  | 
+------+-------+------+------+-------------+

Opcodes on P register
 31  28 27   24 23  20 19  16 15    8 7     0
+------+-------+------+------+-------+-------+
| 0011 | Opcode|  Rd  | 0000 | Start |  lit  | 
+------+-------+------+------+-------+-------+

Conditional relative jump
 31  28 27   24 23  20 19  16 15          0
+------+-------+---------------------------+
| 0100 |  CCCC |S ----- offset ------      | 
+------+-------+---------------------------+
Conditional absolute jump
 31  28 27   24 23  20 19  16 15          0
+------+-------+---------------------------+
| 0101 |  CCCC |     ----- abs ------      | 
+------+-------+---------------------------+
call
 31  28 27   24 23  20 19  16 15          0
+------+-------+---------------------------+
| 0110 |  CCCC |  ----- offset ------      | 
+------+-------+---------------------------+

Size field 

P is selected when start or end are 255
Left is the left most nibble
Right is the right most nibble

0000 0000 dddd ssss ..left.. .right..   ADD.B.SZ R1, R0                     T_TWO_OP
0000 0001 dddd cccc ..left.. .right..   ADD.B.SZ R1, CNT                    T_TWO_OP
0000 0100 dddd ssss ..left.. .right..   SUB.B.SZ R1, R0
0000 0101 dddd ssss ..left.. .right..   RSUB.B.SZ R1, R0
0000 0110 dddd ssss ..left.. .right..   NOT.B.SZ R1, R0
0000 1000 dddd ssss ..left.. .right..   ADD.D.SZ R1, R0                     T_TWO_OP
0000 1001 dddd ssss ..left.. .right..   ADD.D.SZ R1, CNT                    T_TWO_OP
0000 1100 dddd ssss ..left.. .right..   SUB.D.SZ R1, R0
0000 1101 dddd ssss ..left.. .right..   RSUB.D.SZ R1, R0
0000 1110 dddd ssss ..left.. .right..   NOT.D.SZ R1, R0
0001 0000 dddd ssss ..left.. .right..   EQ.D/B.SZ R1, R0
0001 0001 dddd ssss ..left.. .right..   NEQ.D/B.SZ R1, R0
0001 0010 dddd ssss ..left.. .right..   GT.D/B.SZ R1, R0
0001 0011 dddd ssss ..left.. .right..   GTEQ.D/B.SZ R1, R0
0001 0100 dddd ssss ..left.. .right..   LT.D/B.SZ R1, R0
0001 0101 dddd ssss ..left.. .right..   LTEQ.D/B.SZ R1, R0
0001 0110 dddd ssss ..left.. .right..   OR.D/B.SZ R1, R0
0001 0111 dddd ssss ..left.. .right..   XOR.D/B.SZ R1, R0
0001 1000 dddd ssss ..left.. .right..   AND.D/B.SZ R1, R0
0001 1001 dddd ssss ..left.. .right..   MOV.SZ R1, R0                         T_TWO_OP_S
0001 1010 dddd ssss ..left.. .right..   EX.SZ R1, R0                          T_TWO_OP_S
0001 1011 dddd 0000 ..left.. .right..   CLR.SZ Rd                             T_ONE_OP_S
0001 1100 dddd 0000 ..left.. .right..   SR.D/B.SZ                             T_ONE_OP
0001 1101 dddd 0000 ..left.. .right..   SL.D/B.SZ                             T_ONE_OP
0001 1110 dddd 0000 ..left.. .right..   CSR.D/B.SZ                            T_ONE_OP
0001 1111 dddd 0000 ..left.. .right..   CSL.D/B.SZ                            T_ONE_OP

0010 0000 dddd ssss LLLLLLLL LLLLLLLL   Add Ad, As, Lit
0010 0001 dddd ssss LLLLLLLL LLLLLLLL   Sub Ad, As, Lit
0010 0010 dddd ssss LLLLLLLL LLLLLLLL   EQ  Ad, As
0010 0011 dddd ssss LLLLLLLL LLLLLLLL   NEQ Ad, As
0010 0100 dddd ssss LLLLLLLL LLLLLLLL   LT  Ad, As
0010 0101 dddd ssss LLLLLLLL LLLLLLLL   GT  Ad, As
0010 0110 dddd ssss LLLLLLLL LLLLLLLL   AND Ad, As
0010 0111 dddd ssss LLLLLLLL LLLLLLLL   OR  Ad, As
0010 1000 dddd ssss LLLLLLLL LLLLLLLL   XOR Ad, As
0010 1001 dddd ssss LLLLLLLL LLLLLLLL   NOT Ad, As

0010 1000 dddd ssss LLLLLLLL LLLLLLLL   XOR Ad, As
0010 1001 dddd ssss LLLLLLLL LLLLLLLL   NOT Ad, As
0010 1000 dddd ssss LLLLLLLL LLLLLLLL   XOR Ad, As
0010 1001 dddd ssss LLLLLLLL LLLLLLLL   NOT Ad, As


0011 0000 dddd 0000 ..Start. 0000 nnnn LDN.P Rd, n                            T_LDN     load n into d at P post increment



1100 00sr rrrr rrrr  JMP unconditional up +/- 1024 words    T_REL
1100 01sr rrrr rrrr  JMP if true up to +/- 1024 words       T_REL
1100 10sr rrrr rrrr  CALL +/- 1024 words                    T_REL
1100 11sr rrrr rrrr  CALL if true up to +/- 1024 words      T_REL

1101 dddd ssss 0SSS  LOAD.SZ Rd, @Rs                        T_TWO_OP_S
1101 dddd ssss 1SSS  STORE.SZ @Rd, Rs                       T_TWO_OP_S

1110 0000 0000 aaaa aaaa aaaa aaaa aaaa long absolute jump  T_ABS 
1110 0000 0001 aaaa aaaa aaaa aaaa aaaa long absolute call  T_ABS 

1110 dddd 0010 aaaa aaaa aaaa aaaa aaaa load absolute       T_LS_ABS 
1110 dddd 0011 aaaa aaaa aaaa aaaa aaaa store absolute      T_LS_ABS 

1110 dddd 0100 aaaa aaaa aaaa aaaa aaaa load up to 5 nibbles 

1110 0000 ssss aaaa aaaa aaaa aaaa aaaa load absolute (abs << 4)
1110 0001 ssss aaaa aaaa aaaa aaaa aaaa store absolute (abs << 4)

1110 0010 ssss rrrr oooo oooo oooo oooo load absolute (abs << 4)
1110 0011 ssss rrrr oooo oooo oooo oooo store absolute (abs << 4)

Registers:

0: constant zero (to easily compare)
1: constant 1 for the least significant digit (to use as add.d.w a, 1)
2: A
3: B
4: C
5: D
6, 7, 8: r6, r7, r8
9: constant 9
F: constant F
'''
T_ONE_OP   = 1
T_TWO_OP   = 2
T_TWO_CNT  = 3
T_ONE_OP_S = 4 # without decimal/binary 
T_TWO_OP_S = 5 # without decimal/binary
T_REL      = 6
T_ABS      = 7
T_LS_ABS   = 8
T_LDN      = 9
T_LDB      = 10
T_LDW      = 11
T_NONE     = 12
T_ONE_LIT  = 13

OP_NAME     = 0
OP_DECHEX   = 1
OP_BASE     = 2
OP_TYPE     = 3
OP_EXTRA    = 4

opcode_tbl = [ 
    [ 'ADD',  'H', 0x00000000, T_TWO_OP,    1 ], 
    [ 'ADD',  'H', 0x01000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero
    [ 'SUB',  'H', 0x04000000, T_TWO_OP,    1 ], 
    [ 'SUB',  'H', 0x05000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero
    [ 'RSUB', 'H', 0x06000000, T_TWO_OP,    1 ], 
    [ 'RSUB', 'H', 0x07000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero 
    [ 'ADD',  'D', 0x08000000, T_TWO_OP,    1 ], 
    [ 'ADD',  'D', 0x09000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero
    [ 'SUB',  'D', 0x0C000000, T_TWO_OP,    1 ], 
    [ 'SUB',  'D', 0x0D000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero
    [ 'NOT',  'D', 0x0E090000, T_ONE_OP,    1 ], # reversed sub eq to C=9-C 
    [ 'RSUB', 'D', 0x0E000000, T_TWO_OP,    1 ], 
    [ 'RSUB', 'D', 0x0F000000, T_TWO_CNT,   1 ], # use a constant for the LSD and then zero
    [ 'EQ',    '', 0x10000000, T_TWO_OP_S,  1 ], 
    [ 'NEQ',   '', 0x11000000, T_TWO_OP_S,  1 ], 
    [ 'GT',    '', 0x12000000, T_TWO_OP_S,  1 ], 
    [ 'GTEQ',  '', 0x13000000, T_TWO_OP_S,  1 ], 
    [ 'LT',    '', 0x14000000, T_TWO_OP_S,  1 ], 
    [ 'LTEQ',  '', 0x15000000, T_TWO_OP_S,  1 ], 
    [ 'OR',    '', 0x16000000, T_TWO_OP_S,  1 ], 
    [ 'XOR',   '', 0x17000000, T_TWO_OP_S,  1 ], 
    [ 'AND',   '', 0x18000000, T_TWO_OP_S,  1 ], 
    [ 'MOV',   '', 0x19000000, T_TWO_OP_S,  1 ], 
    [ 'EX',    '', 0x1A000000, T_TWO_OP_S,  1 ], 
    [ 'SR',   'D', 0x1C000000, T_ONE_OP,    1 ], 
    [ 'SL',   'D', 0x1D000000, T_ONE_OP,    1 ], 
    [ 'SR',   'H', 0x1E000000, T_ONE_OP,    1 ], 
    [ 'SL',   'H', 0x1F000000, T_ONE_OP,    1 ], 

    [ 'LOADP', '', 0x20000000, T_ONE_LIT,   1 ], 
    [ 'EQP',   '', 0x21000000, T_ONE_LIT,   1 ], 
    [ 'NEQP',  '', 0x22000000, T_ONE_LIT,   1 ], 
    [ 'INCP',  '', 0x23000000, T_NONE,      1 ], 
    [ 'DECP',  '', 0x24000000, T_NONE,      1 ], 
    [ 'LDN',   '', 0x30000000, T_LDN,       1 ], # load nibbles @P
#    [ 'LDB',   '', 0x30000000, T_LDB, 1 ], # load byte @P    
    [ 'RET',   '', 0x40000000, T_NONE,      1 ], 
    [ 'STOP',  '', 0x41000000, T_NONE,      1 ], 
    [ 'JMP',   '', 0x50000000, T_ABS,       1 ], 
    [ 'CALL',  '', 0x51000000, T_ABS,       1 ], 
    [ 'JC',    '', 0x52000000, T_ABS,       1 ], 
    [ 'JNC',   '', 0x53000000, T_ABS,       1 ], 
    [ 'JT',    '', 0x54000000, T_ABS,       1 ], 
    [ 'JNT',   '', 0x55000000, T_ABS,       1 ], 
 #   [ 'CT',    '', 0xCC000000, T_REL,       1 ],     
    
#    [ 'LOAD',  '', 0xD0000000, T_TWO_OP_S, 1 ], # load Rd from Rs with size
#    [ 'STO',   '', 0xD0080000, T_TWO_OP_S, 1 ], # Store Rd to Rs with size
#    [ 'JMP',   '', 0xE0000000, T_ABS, 2 ], # jump absolute
#    [ 'CALL',  '', 0xE0100000, T_ABS, 2 ], # call absolute
#    [ 'LOAD',  '', 0xE0200000, T_LS_ABS, 2 ], 
#    [ 'STO',   '', 0xE0300000, T_LS_ABS, 2 ],     
#    [ 'LDW',   '', 0xE0400000, T_LDW, 2 ] 
    [ '', '', 0, 255, 1 ]
    ]

symbolTable = dict()

def lookupOpcode(opcodeName, dechex):
    for op in opcode_tbl:
        if opcodeName == op[OP_NAME]:
            if (op[OP_DECHEX] == dechex) or (dechex == ''):
                print 'Found op: ', op
                return op
    return None

def lookupSymbol(symName):
    if symName in symbolTable:
        return symbolTable[symName]
    return None

def addSymbol(symName, value):
    if symName not in symbolTable:
        symbolTable[symName] = value
        return True
    return False    


#
# label: op.d.w r0,r1
#
#
def tokenizeLine(line):
    label = ''
    opcode = ['', '', 'Z'] # opcode name, type, size
    arg1 = ''
    arg2 = ''
    
    # sym: op r0,r2
    # sym:op r0,r1 ; comment
    # op
       
    if ':' in line:
        s = line.split(':')
        label = s[0]
        line = s[1]
        
    parts = line.split()  # at least one space between the opcode and the first argument
    if len(parts) < 1:
        return [label, opcode, arg1, arg2]

    if len(parts) - 1 == 1:
        if ',' in parts[1]:
            args = parts[1].split(',')
            arg1 = args[0]
            arg2 = args[1]
        else:
            arg1 = parts[1]
    elif len(parts) - 1 == 2:
        arg1 = parts[1].rstrip(',')
        arg2 = parts[2].lstrip(',')
    
    br_opcode = parts[0].upper().split('.')
    if len(br_opcode) == 1:
        opcode[0] = br_opcode[0]
    elif len(br_opcode) == 2:
        opcode[0] = br_opcode[0]
        if br_opcode[1] != 'D' and br_opcode[1] != 'H':
            if len(br_opcode) > 2:
                return [label, opcode, arg1, arg2] # unknown type
            else:
                opcode[2] = br_opcode[1] # transfer size
        else:
            opcode[1] = br_opcode[1]
    elif len(br_opcode) == 3:
        opcode[0] = br_opcode[0]
        if br_opcode[1] != 'D' and br_opcode[1] != 'B':
            return [label, opcode, arg1, arg2] # unknown type
        opcode[1] = br_opcode[1] # transfer type
        opcode[2] = br_opcode[2] # transfer size
    else:
        return [label, opcode, arg1, arg2]
    return [label, opcode, arg1, arg2]

# get register number
def getReg(reg):
    if len(reg) > 0:
        if reg[0] == 'R' or reg[0] =='r':
            #reg[0] = '0'
            return int(reg[1:len(reg)], 10)
        elif reg == 'A' or reg == 'a':
            return 2
        elif reg == 'B' or reg == 'b':
            return 3
        elif reg == 'C' or reg == 'c':
            return 4
        elif reg == 'D' or reg == 'd':
            return 5
        elif reg == '0':    # register 0 is always read as zero
            return 0
    
    return None
# returns a number or None  
def getSymbolOrLiteral(reg):
    reg = reg.lstrip('#') # '#' is only to indicate that the argument is a number
    sym = lookupSymbol(reg)
    if sym == None:
        try:
            val = int(reg)
            return val
        except ValueError:
            return None
    else:
        return sym # address of the symbol
# returns the shifted destination register
def setDST(dst):
    return dst << 20
# return the shifted source register
def setSRC(src):
    return src << 16

def assembleLine(line, lineNum, pc, ignore_missing_sym):
    original_line = line
    # remove comments
    without_comments = line.split(';')
    without_comments = without_comments[0].strip()
    
    tokens = tokenizeLine(without_comments)
    print '* Tokens: ', tokens
    if (len(tokens[0]) > 0) and ignore_missing_sym: # use this flag to create symbols on first pass only
        if not addSymbol(tokens[0], pc):
            print 'Duplicated symbol {0:s} at line {1:d}'.format(label, lineNum)
            return None
    
    if len(tokens[1][0]) > 0:
        op = lookupOpcode(tokens[1][0], tokens[1][1])
    else:
        return None, False

    if op == None:
        print 'Unknown opcode {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
        return None, True

    f_left = 0
    f_right = 0        
    
    if tokens[1][2] == 'P':
        f_left = 255
        f_right = 255
    elif tokens[1][2] == 'WP':
        f_left = 255
        f_right = 0
    elif tokens[1][2] == 'XS':
        f_left = 2
        f_right = 2
    elif tokens[1][2] == 'X':
        f_left = 2
        f_right = 0
    elif tokens[1][2] == 'S':
        f_left = 31
        f_right = 31
    elif tokens[1][2] == 'M':
        f_left = 31
        f_right = 3
    elif tokens[1][2] == 'B':
        f_left = 1
        f_right = 0
    elif tokens[1][2] == 'W':
        f_left = 31
        f_right = 0
    elif tokens[1][2] == 'A':
        f_left = 4
        f_right = 0
    elif tokens[1][2] != 'Z':
        # ignore no size
        print 'Unknown size {0:s} for {1:s} at line {2:d}'.format(tokens[1][2], tokens[1][0], lineNum)
        return None, True
    
    # assemble
    dst = getReg(tokens[2])
    dst_sym = getSymbolOrLiteral(tokens[2])
    src = getReg(tokens[3])
    src_sym = getSymbolOrLiteral(tokens[3])
    if ignore_missing_sym == True:
        dst_sym = 0
        src_sym = 0    
    
    print '* Dst & src :', dst, src
    if op[OP_TYPE] == T_TWO_OP: # two arguments with size and type
        if src == None:
            if src_sym != None:
                # return the CONSTANT version
                return [ op[OP_BASE] + 0x01000000 + setDST(dst) + setSRC(src_sym) + (f_left << 8) + f_right ], False
            print 'Two register arguments expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
            
        if dst == None or (src == None and src_sym == None):
            print 'Two register arguments expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] + setDST(dst) + setSRC(src) + (f_left << 8) + f_right ], False

    elif op[OP_TYPE] == T_TWO_OP_S: # two arguments with size and without type
        if dst == None or src == None:
            print 'Two register arguments expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] + setDST(dst) + setSRC(src) + (f_left << 8) + f_right ], False
    elif op[OP_TYPE] == T_ONE_OP: # One argument with size and type
        if dst == None or src != None:
            print 'One register argument expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] + setDST(dst) + (f_left << 8) + f_right ], False
    elif op[OP_TYPE] == T_ONE_OP_S: # One argument with size and type
        if dst != None or src != None:
            print 'One register argument expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] + setDST(dst) + (f_left << 8) + f_right ], False
    elif op[OP_TYPE] == T_LDN: # One register + literal argument
        if dst == None or src_sym == None:
            print 'One register argument plus one literal expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        numnibs = 0x01000000
        if src_sym > 0xFFFFF:
            print 'Constant {0:x} exceeds range for {1:s}'.format(tokens[1][0], src_sym)
        elif src_sym > 0XFFFF:
            numnibs = 0x05000000
        elif src_sym > 0XFFF:
            numnibs = 0x04000000
        elif src_sym > 0XFF:
            numnibs = 0x03000000
        elif src_sym > 0XF:
            numnibs = 0x02000000
        return [ op[OP_BASE] + numnibs + setDST(dst) + (src_sym & 0xFFFFF) ], False
    elif op[OP_TYPE] == T_LDB: # One register + literal argument
        if dst == None or src_sym == None:
            print 'One register argument plus one literal expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] + setDST(dst) + (src_sym & 255) ], False
    elif op[OP_TYPE] == T_NONE: # No arguments
        if dst != None and src_sym != None:
            print 'No arguments expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [ op[OP_BASE] ], False
        
    elif op[OP_TYPE] == T_ABS: # Absolute
        if dst_sym == None:
            print 'One absolute argument expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True

        return [op[OP_BASE] + (dst_sym & 65535) ], False
    elif op[OP_TYPE] == T_LS_ABS: # Absolute
        if dst == None or src_sym == None:
            print 'One absolute argument expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [op[OP_BASE] + setDST(dst) + (dst_sym & 65535) ], False
    elif op[OP_TYPE] == T_ONE_LIT: # Register P opcodes load and compare
        if dst_sym == None:
            print 'One literal argument expected for {0:s} at line {1:d}'.format(tokens[1][0], lineNum)
            return None, True
        
        return [op[OP_BASE] + (dst_sym & 31) ], False
# first pass, creates and checks symbols and opcodes
# returns True if successes
def firstPass(fileName):
    f = open(fileName, 'rt')
    
    pc = 0
    lineNum = 1
    for line in f:
        op, flag = assembleLine(line, lineNum, pc, True)
        
        if flag:
            print 'Cancelled due to error'
            return False
        if op != None:
            pc += len(op)
        lineNum += 1
    f.close()
# first pass, creates and checks symbols and opcodes
# returns True if successes
def secondPass(fileName):
    f = open(fileName, 'rt')
    fileNamewoExt = fileName.rsplit('.')
    fileNamewoExt = fileNamewoExt[0]
    lst = open(fileNamewoExt + '.lst', 'wt')
    bin = open(fileNamewoExt + '.bin', 'wt')
    
    pc = 0
    lineNum = 1
    for line in f:
        op, flag = assembleLine(line, lineNum, pc, False)
        
        if flag:
            print 'Cancelled due to error'
            return False
        if op != None:
            for j in range(len(op)):
                s = '{0:6d}  {1:06X} {2:08X}  '.format(lineNum, pc, op[j])
                if j == 0:
                    lst.write(s + line)
                else:
                    lst.write(s + '\r\n')
                bin.write('{0:08x}\r\n'.format(op[j]))
            pc += len(op)
        else:
            s = '{0:6d}            {1:s}'.format(lineNum, line)
            lst.write(s)
        lineNum += 1
    f.close()
    lst.close()
    bin.close()
print 'Two pass Neptune assembler'

firstPass(argv[1])
secondPass(argv[1])

#op, flag = assembleLine('aa: add.d.w r0, r1', 0, 0)

#print op

