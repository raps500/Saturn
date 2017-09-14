#!/usr/bin/python
'''
PNeptune emulator
A follow up of the HP Saturn processor

HW-Stack up to 256 levels

16 128-bit registers ALU registers (all like A, B, C, D)
* register 0 is alwys 0 and cannot be modified
* register 9 is always 9 and cannot be modified, used for A=-A-1 when decimal
* register 15 is always F and cannot be modified
Per opcode binary or decimal computation (when it makes sense like add and sub)
4 32 bit Address/general purpose registers

'''
from sys import *
RA = [ ]     # 4 Address registers
RR = [ ] # 4 32 nibble registers
RPC = 0      # 20 bit program counter
RSTACK = []  # 256 level hw stack
RSTACKPTR = 0# stack pointer to the last used
RP = 0       # P register
CARRYF = 0   # carry flag in F register
CMPF = 1     # compare flag when true in F register
FIELDS = [ 'P ', 'WP', 'XS', 'X ', 'S ', 'M ', 'B ', 'W ' ]

DEBUG       = True
WORDSIZE    = 32
WORDSIZEM1  = WORDSIZE - 1
MAXALUREGS  = 16
MAXADDRREGS = 4
set_carry = True
# register names
RN = [ '0', 'R1', 'A', 'B', 'C', 'D', 'R6', 'R7', 'R8', '9', 'R10', 'R11', 'R12', 'R13', 'CNT', 'F' ]

def Neptune_Reset():
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    if DEBUG:
        print 'Reset'
    
    for i in range(MAXALUREGS):
        if i == 9:
            RR.append([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9])
        elif i == 15:
            RR.append([15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15])
        else:
            RR.append([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    for i in range(MAXADDRREGS):
        RA.append(0)
   
    RPC = 0
    RSTACK = []
    RSTACKPTR = 0
    RP = 0
    RF = [ False, False, False, False, False, False, False, False, False, False, False, False, False, False, False ]
    
#
# Add opcode, adds in binary or decimal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_AddB(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'ADD.H.{0:s}  {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end):
        r = RR[isrc][i] + RR[idst][i] + c
        if (r >= 16):
            c = 1
            r -= 16
        else:
            c = 0
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
        
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# Add opcode, adds in decimal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_AddD(isrc, idst, nib_start, nib_end, size):
    #global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'ADD.D.{0:s}  {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end+1):
        r = RR[isrc][i] + RR[idst][i] + c
        if (r >= 10):
            c = 1
            r -= 10
        else:
            c = 0
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# RSub opcode, reverse sub in binary or decimal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_RSubB(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'RSUB.H.{0:s} {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end+1):
        r = 16 + RR[isrc][i] - RR[idst][i] - c
        if (r < 16):
            c = 1
        else:
            c = 0
            r -= 16
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
        
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# RSub opcode, reverse sub in decimal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_RSubD(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'RSUB.D.{0:s} {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end+1):
        r = 10 + RR[isrc][i] - RR[idst][i] - c
        if (r < 10):
            c = 1
            #r -= 6
        else:
            c = 0
            r -= 10
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
        
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# Sub opcode, sub in binary from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_SubB(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'SUB.H.{0:s}  {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end+1):
        r = 16 + RR[idst][i] - RR[isrc][i] - c
        if (r < 16):
            c = 1
        else:
            c = 0
            r -= 16
        
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
        
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# Sub opcode, sub in decimal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
# set_carry: True if carry has to be set for overflows on the left most nibble
def Neptune_SubD(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'SUB.D.{0:s}  {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    c = 0
    r = 0
    for i in range(nib_start, nib_end+1):
        r = 10 + RR[idst][i] - RR[isrc][i] - c
        if (r < 10):
            c = 1
            #r -= 6
        else:
            c = 0
            r -= 10
        #print r, RR[idst][i], RR[isrc][i], c
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = r
        
    if set_carry:
        RF[CARRYF] = c == 1
    return deb_str
#
# Compare if equal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpEq(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'EQ.{0:s}     {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    eq = True # equal
    for i in range(nib_start, nib_end+1):
        if RR[idst][i] != RR[isrc][i]:
            eq = False
    RF[CMPF] = eq    
    return deb_str
#
# Compare if not equal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpNEq(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'NEQ.{0:s}    {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    eq = True # equal
    for i in range(nib_start, nib_end+1):
        if RR[idst][i] != RR[isrc][i]:
            eq = False
    RF[CMPF] = not eq   
    return deb_str
#
# Compare if greater than from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpGT(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'GT.{0:s}     {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    gt = True
    for i in range(nib_start, nib_end+1):
        gt = RR[idst][i] > RR[isrc][i]

    RF[CMPF] = gt
    return deb_str 
#
# Compare if greater than or equal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpGTEQ(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'GTEQ.{0:s}   {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    eq = True # equal
    gt = False
    for i in range(nib_start, nib_end+1):
        if RR[idst][i] != RR[isrc][i]:
            eq = False
        gt = RR[idst][i] > RR[isrc][i]
    RF[CMPF] = eq or gt
    return deb_str
#
# Compare if less than from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpLT(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'LT.{0:s}     {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    lt = True
    for i in range(nib_start, nib_end+1):
        gt = RR[idst][i] < RR[isrc][i]

    RF[CMPF] = lt
    return deb_str
#
# Compare if less than or equal from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_CmpLTEQ(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'LTEQ.{0:s}   {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    eq = True # equal
    gt = False
    for i in range(nib_start, nib_end+1):
        if RR[idst][i] != RR[isrc][i]:
            eq = False
        gt = RR[idst][i] > RR[isrc][i]
    RF[CMPF] = (not eq) or (not gt)
    return deb_str
#
# And from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_AND(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'AND.{0:s}    {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    for i in range(nib_start, nib_end+1):
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = RR[idst][i] & RR[isrc][i]
    return deb_str
#
# OR from right to left
# And from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_OR(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'OR.{0:s}     {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    for i in range(nib_start, nib_end+1):
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = RR[idst][i] & RR[isrc][i]
    return deb_str
# XOR from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_XOR(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'XOR.{0:s}    {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    for i in range(nib_start, nib_end+1):
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = RR[idst][i] ^ RR[isrc][i]
    return deb_str
# NOT from right to left
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_NOT(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'NOT.{0:s}    {1:s}'.format(size, RN[idst])
    for i in range(nib_start, nib_end+1):
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = 15 - RR[isrc][i]
    return deb_str
# Moves nibbles
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_MOV(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry, RN
    deb_str = 'MOV.{0:s}    {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    #print dumpReg(isrc)
    #print dumpReg(idst)
    for i in range(nib_start, nib_end+1):
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = RR[isrc][i]
    return deb_str    
# Exchanges nibbles
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_EX(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'EX.{0:s}     {1:s},{2:s}'.format(size, RN[idst], RN[isrc])
    for i in range(nib_start, nib_end+1):
        t = RR[isrc][i]
        if (isrc != 0) and (isrc != 9) and (isrc != 15):
            RR[isrc][i] = RR[idst][i]
        if (idst != 0) and (idst != 9) and (idst != 15):
            RR[idst][i] = t
    return deb_str        
# SRD shift right a whole nibble, zeroes are feeded from the right
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_SRD(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'SR.D.{0:s}   {1:s}'.format(size, RN[idst])
    if nib_start < nib_end:
        for i in range(nib_start + 1, nib_end + 1):
            if (idst != 0) and (idst != 9) and (idst != 15):
                RR[idst][i - 1] = RR[idst][i]
    if (idst != 0) and (idst != 9) and (idst != 15):
        RR[idst][nib_end] = 0
    return deb_str
# SLD shift right a whole nibble
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_SLD(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'SL.D.{0:s}   {1:s}'.format(size, RN[idst])

    if (idst != 0) and (idst != 9) and (idst != 15):
        if nib_start < nib_end:
            for i in range(nib_end, nib_start, -1):
                if (i + 1) < WORDSIZE:
                    RR[idst][i+1] = RR[idst][i]
        RR[idst][nib_start] = 0
    return deb_str
# Load 
# loads nib_end - nib_start nibbles atrting at a byte address
# from most sig byte to least sig byte: 
#
# MEM  +0  +1  +2
#      65  43  21
#
# REG Pos 5 4 3 2 1 0
#         6 5 4 3 2 1
#
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_LOAD(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'LOAD.{0:s}  {1:s},{2:s}'.format(size, RN[idst], RN[isrc])

    addr = (RR[isrc][3] << 12) + (RR[isrc][2] << 8) + (RR[isrc][1] << 4) + (RR[isrc][0])
    high = True
    for i in range(nib_start, nib_end + 1):
        if high:
            high = False
            RR[idst][i] = (MEM[addr] >> 4) & 15
        else:
            high = True
            RR[idst][i] = MEM[addr] & 15
            addr += 1
    return deb_str
# Store
# MEM  +0  +1  +2
#      65  43  21
#
# REG Pos 5 4 3 2 1 0
#         6 5 4 3 2 1
#
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_STO(isrc, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'STO.{0:s}   {1:s}, {2:s}'.format(size, RN[idst], RN[isrc])

    addr = (RR[isrc][3] << 12) + (RR[isrc][2] << 8) + (RR[isrc][1] << 4) + (RR[isrc][0])
    
    nend = nib_end 
    flag = True
    while flag:
        if nend == nib_start:
            MEM[addr] = RR[idst][nib_start] << 4
        else:
            MEM[addr] = (RR[idst][nend] << 4) + (RR[idst][nend-1] << 4)
        addr += 1
        nend -= 2
        if nend < nib_start:
            flag = False
    return deb_str
# Load 
# loads nib_end - nib_start nibbles atrting at a byte address
# from most sig byte to least sig byte: 
#
# MEM  +0  +1  +2
#      65  43  21
#
# REG Pos 5 4 3 2 1 0
#         6 5 4 3 2 1
#
# isrc     : first operand register
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_LOAD_ABS(addr, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'LOAD.{0:s}  {1:02d}, %04x'.format(size, RN[idst], addr)

    high = True
    for i in range(nib_end, nib_start, -1):
        if high:
            high = False
            RR[idst][i] = (MEM[addr] >> 4) & 15
        else:
            high = True
            RR[idst][i] = MEM[addr] & 15
            addr += 1
    return deb_str
# Store
# MEM  +0  +1  +2
#      65  43  21
#
# REG Pos 5 4 3 2 1 0
#         6 5 4 3 2 1
#
# addr     : byte address to store to
# idst     : send and destination register
# nib_start: right most (start) nibble
# nib_end  : left most (end) nibble
def Neptune_STO_ABS(addr, idst, nib_start, nib_end, size):
    global RR, RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    deb_str = 'STO.{0:s}   {1:02d}, {2:04x}'.format(size, RN[idst], addr)

    nend = nib_end 
    while flag:
        if nend == nib_start:
            MEM[addr] = RR[idst][nib_start] << 4
        else:
            MEM[addr] = (RR[idst][nend] << 4) + (RR[idst][nend-1] << 4)
        addr += 1
        nend -= 2
        if nend < nib_start:
            flag = False
    return deb_str
    
def dumpReg(isrc):
    global RR, RN
    s = '{0:s}: '.format(RN[isrc])
    for j in range(WORDSIZEM1, 0, -1):
        s = s + '{0:x}'.format(RR[isrc][j])
    return s
    
# executes a single step
# Updates all registers as needed
# word0 : least significant word
# word1 : most significant word
#
# Opcodes are 32 bit i.e. word long
# Loads of multiple nibbles are achieved via multiple opcodes
#
def Neptune_SingleStep(word):
    global RPC, RP, RF, RSTACK, RSTACKPTR, DEBUG, CARRYF, CMPF, set_carry
    
    dst         = (word >> 20) & 15
    src         = (word >> 16) & 15
    dec_bin     = ((word >> 27) & 1) == 1 
    nib_start   = (word >> 0) & 255
    nib_end     = (word >> 8) & 255
    sign        = (word & 0x0200) == 0x0200
    rel         = (word << 2) & 0x003FFFFF
    aabs        = (word << 2) & 0x003FFFFF
    
    op          = (word >> 24) & 15
    family      = (word >> 28) & 15
    jgroup      = (word >> 10) & 3
    err_flag    = False
    
        
    field = '[{0:2d}..{1:2d}]'.format(nib_end, nib_start)
    
    if nib_start == WORDSIZEM1 and nib_end == WORDSIZEM1:
        field = 'S'
    elif  nib_start == 0 and nib_end == WORDSIZEM1:
        field = 'W'
    elif  nib_start == 0 and nib_end == 255:
        field = 'WP'
        nib_end = RP
    elif  nib_start == 255 and nib_end == 255:
        field = 'P'
        nib_start = RP
        nib_end = RP
    elif  nib_start == 0 and nib_end == 2:
        field = 'X'
    elif  nib_start == 2 and nib_end == 2:
        field = 'XS'
    elif  nib_start == 0 and nib_end == 4:
        field = 'A'
    elif  nib_start == 3 and nib_end == WORDSIZEM1:
        field = 'M'

    deb_str_hdr = '{0:05x}  {1:08x}       '.format(RPC, word)
    
    # prepare constant 
    if (family == 0) or (family == 1):
    # used for CONstant source operands in some opcodes
        RR[14] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        RR[14][nib_start] = src
    #print 'src:{0:d} dst: {1:d} left: {2:d} right: {3:d}'.format(src, dst, nib_end, nib_start)
    #print RR
    #print dumpReg(0)
    #print dumpReg(1)
    #print dumpReg(2)
    #print dumpReg(3)
        
    if family == 0:
        if (op & 1) == 1:
            src = 14 # use constant
        if (op == 0) or (op == 1): # 
            deb_str = Neptune_AddB(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif (op == 4) or (op == 5):
            deb_str = Neptune_SubB(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif (op == 6) or (op == 7):
            deb_str = Neptune_RSubB(src, dst, nib_start, nib_end, field)
            RPC += 4
        #elif op == 3:
        #    Neptune_NOTB(src, dst, nib_start, nib_end, field)
        #    RPC += 4
        elif (op == 8) or (op == 9): # 
            deb_str = Neptune_AddD(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif (op == 12) or (op == 13):
            deb_str = Neptune_SubD(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif (op == 14) or (op == 15):
            deb_str = Neptune_RSubD(src, dst, nib_start, nib_end, field)
            RPC += 4
        #elif op == 11:
        #    Neptune_NOTD(src, dst, nib_start, nib_end, field)
        #    RPC += 4
        else:
            print 'unknown opcode: {0:08x}'.format(word)
            err_flag = True
        deb_str = deb_str.ljust(25, ' ') + dumpReg(dst)
    elif family == 1:
        if op == 0:
            deb_str = Neptune_CmpEq(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 1:
            deb_str = Neptune_CmpNEq(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 2:
            deb_str = Neptune_CmpGT(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 3:
            deb_str = Neptune_CmpGTEQ(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 4:
            deb_str = Neptune_CmpLT(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 5:
            deb_str = Neptune_CmpLTEQ(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 6:
            deb_str = Neptune_OR(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 7:
            deb_str = Neptune_XOR(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 8:
            deb_str = Neptune_AND(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 9:
            deb_str = Neptune_MOV(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 10:
            deb_str = Neptune_EX(src, dst, nib_start, nib_end, field)
            RPC += 4
        #elif op == 11:
        #    Neptune_CLR(src, dst, nib_start, nib_end, field)
        #    RPC += 4
        elif op == 12:
            deb_str = Neptune_SRD(src, dst, nib_start, nib_end, field)
            RPC += 4
        elif op == 13:
            deb_str = Neptune_SLD(src, dst, nib_start, nib_end, field)        
            RPC += 4
        #elif op == 14:
        #        Neptune_CSR(src, dst, nib_start, nib_end, field)
        #    RPC += 4
        #elif op == 15:
        #        Neptune_CSL(src, dst, nib_start, nib_end, field)
        #    RPC += 4
        else:
            print 'unknown opcode: {0:08x}'.format(word)
            err_flag = True
        deb_str = deb_str.ljust(25, ' ') + dumpReg(dst)
    elif family == 2: # P opcodes
        if op == 0: #loadp #n
            deb_str = 'LOADP    #{0:02x}'.format(word & WORDSIZEM1)
            RP = word & WORDSIZEM1
            RPC += 4
        elif op == 1: # eqp
            deb_str = 'EQP      #{0:02x}'.format(word & WORDSIZEM1)
            RF[CMPF] = RP == (word & WORDSIZEM1)
            RPC += 4
        elif op == 2: # neqp
            deb_str = 'NEQP     #{0:02x}'.format(word & WORDSIZEM1)
            RF[CMPF] = RP != (word & WORDSIZEM1)
            RPC += 4
        elif op == 3: # incp
            deb_str = 'INCP'
            if RP == WORDSIZEM1:
                RF[CARRYF] = True
                RP = 0
            else:
                RP += 1
                RF[CARRYF] = False
            RPC += 4
        elif op == 4: # decp
            deb_str = 'DECP'
            if RP == 0:
                RP = WORDSIZEM1
                RF[CARRYF] = True
            else:
                RP -= 1
                RF[CARRYF] = False
            RPC += 4
        else:
            print 'unknown opcode: {0:08x}'.format(word)
            err_flag = True
        deb_str =deb_str.ljust(25, ' ') + 'P: {0:x}'.format(RP)
    elif family == 3: # load nibbles at P+n..P, dosn't modify P
        nibs = word & 0x000FFFFF
        if op == 1:
            deb_str = 'LDN      {0:s},#{1:1x}'.format(RN[dst], nibs & 0xF)
        elif op == 2:
            deb_str = 'LDN      {0:s},#{1:02x}'.format(RN[dst], nibs & 0xFF)
        elif op == 3:
            deb_str = 'LDN      {0:s},#{1:03x}'.format(RN[dst], nibs & 0xFFF)
        elif op == 4:
            deb_str = 'LDN      {0:s},#{1:04x}'.format(RN[dst], nibs & 0xFFFF)
        elif op == 5:
            deb_str = 'LDN      {0:s},#{1:05x}'.format(RN[dst], nibs)
        else:
            deb_str = 'LDN invalid number of nibbles {0:d}', op
            err_flag = True
        for j in range(op): 
            RR[dst][RP] = nibs & 15
            nibs = nibs >> 4
        deb_str = deb_str.ljust(25, ' ') + dumpReg(dst)
        RPC += 4
    elif family == 4: # inherent opcodes
        if op == 0: # RET
            if len(RSTACK) == 0:
                deb_str = 'Stack Underflow!'
                err_flag = True
            if DEBUG:
                deb_str = 'RET'
            RPC = RSTACK[len(RSTACK)-1]
            del RSTACK[len(RSTACK)-1]
        elif op == 1: # STOP
            print 'STOP reached'
            return True
    elif family == 5: # jump opcodes
        if op == 0:
            deb_str = 'JMP      {0:05x}'.format(aabs)
            RPC = aabs
        elif op == 1:
            deb_str = 'CALL     {0:05x}'.format(aabs)
            RSTACK.append(RPC + 4)
            RPC = aabs
        elif op == 2:
            deb_str = 'JC       {0:05x}'.format(aabs)
            if RF[CARRYF]:
                RPC = aabs
            else:
               RPC += 4
        elif op == 3:
            deb_str = 'JNC      {0:05x}'.format(aabs)
            if RF[CARRYF]:
                RPC += 4
            else:
               RPC = aabs
        elif op == 4:
            deb_str = 'JT       {0:05x}'.format(aabs)
            if RF[CMPF]:
                RPC = aabs
            else:
               RPC += 4
        elif op == 5:
            deb_str = 'JNT      {0:05x}'.format(aabs)
            if RF[CMPF]:
                RPC += 4
            else:
               RPC = aabs
        else:
            print 'unknown opcode: {0:08x}'.format(word)
            err_flag = True                       

    elif family == 6:
        if dec_bin:
            Neptune_STO(src, dst, nib_start, nib_end, FIELDS[size])
        else:
            Neptune_LOAD(src, dst, nib_start, nib_end, FIELDS[size])
    elif family == 7:
        if src == 0:
            deb_str = 'JMP  {0:05x}'.format(aabs)
            RPC = aabs
        elif src == 1:
            deb_str = 'CALL {0:05x}'.format(aabs)
            RSTACK.append(RPC + 1)
            RPC = aabs
        elif src == 2:
            Neptune_LOAD_ABS(aabs, dst, nib_start, nib_end, FIELDS[size])
        else:
            Neptune_STO_ABS(aabs, dst, nib_start, nib_end, FIELDS[size])
    else:
        print 'unknown opcode: {0:08x}'.format(word)
        err_flag = True
    if DEBUG:
         print deb_str_hdr, deb_str
         
    return err_flag
 
 
print 'PNeptune Simulator v1.00'

bin = open(argv[1])

memory = []

for line in bin:
    line = line.lstrip().rstrip(' \r\n')
    memory.append(int(line, 16))
    
print '{0:5d} words read'.format(len(memory))

Neptune_Reset()

DEBUG = True
flag = False
count = 0
while not flag:
    word = memory[RPC >> 2]
    flag = Neptune_SingleStep(word)
    count += 1
    if flag or count == 1200:
        break
        
