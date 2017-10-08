#!/usr/bin/python
'''
Transforms a microcode listing into a binary file to be read with readmemb

1001_0xxx_0000_xxxx_xxxx_xxxx : 0, 0, 0, 0, 0, 0, 0, 0, 0, 6,`ALU_OP_EQ  , `OP_A  , `K_B  , `OP_A   --

To
00000000011100010000000001000000
'''

from sys import *

OP1 = {
    '`OP_A'       : 0x00 ,
    '`OP_B'       : 0x01 ,
    '`OP_C'       : 0x02 ,
    '`OP_D'       : 0x03 ,
    '`OP_R0'      : 0x08 ,
    '`OP_R1'      : 0x09 ,
    '`OP_R2'      : 0x0a ,
    '`OP_R3'      : 0x0b ,
    '`OP_R4'      : 0x0c ,
    '`OP_R5'      : 0x0d ,
    '`OP_R6'      : 0x0e ,
    '`OP_R7'      : 0x0f ,
    '`OP_MEM'     : 0x10 , 
    '`OP_LIT'     : 0x18 , 
    '`OP_PC'      : 0x20 ,
    '`OP_STK'     : 0x21 ,
    '`OP_D0'      : 0x22 ,
    '`OP_D1'      : 0x23 ,
    '`OP_ST'      : 0x24 ,
    '`OP_IN'      : 0x25 ,
    '`OP_OUT'     : 0x25 , 
    '`OP_P'       : 0x26 ,
    '`OP_ID'      : 0x27 , 
    '`OP_HS'      : 0x28 , 
    '`OP_9'       : 0x30 , 
    '`OP_Z'       : 0x38 ,
    '`OP_1'       : 0x39 
}

KOP = {
    '`K_A':        0 ,
    '`K_B':        1 ,
    '`K_C':        2 ,
    '`K_D':        3 ,
    '`K_9':        4 ,
    '`K_Z':        5 ,
    '`K_1':        6 ,
    '`K_LIT':      7 
}

ALU_OP = {
    '`ALU_OP_NONE': 0x00 ,
    '`ALU_OP_TFR' : 0x01 ,
    '`ALU_OP_EX'  : 0x02 ,
    '`ALU_OP_ADD' : 0x03 ,
    '`ALU_OP_SUB' : 0x04 ,
    '`ALU_OP_RSUB': 0x05 ,
    '`ALU_OP_AND' : 0x06 ,
    '`ALU_OP_OR'  : 0x07 ,
    '`ALU_OP_SL'  : 0x08 ,
    '`ALU_OP_SR'  : 0x09 ,
    '`ALU_OP_SLB' : 0x0A ,
    '`ALU_OP_SRB' : 0x0B ,
    '`ALU_OP_SLC' : 0x0C ,
    '`ALU_OP_SRC' : 0x10 ,
    '`ALU_OP_EQ'  : 0x11 ,
    '`ALU_OP_NEQ' : 0x12 ,
    '`ALU_OP_GTEQ': 0x13 ,
    '`ALU_OP_GT'  : 0x14 ,
    '`ALU_OP_LTEQ': 0x15 ,
    '`ALU_OP_LT'  : 0x16 ,
    '`ALU_OP_RD'  : 0x17 ,
    '`ALU_OP_WR'  : 0x18 ,
    '`ALU_OP_TST1': 0x19 ,
    '`ALU_OP_TST0': 0x1A ,
    '`ALU_OP_ANDN': 0x1B 
}


print 'Transform microcode into binary file for readmemb'
if len(argv) < 3:
    print 'Usage: transform_microcode.py <input_file> <outputfile>'
    quit()
    
ifn = open(argv[1], 'rt')
ofn = open(argv[2], 'wt')
line_cnt = 0
real_line_cnt = 0
for line in ifn:
    
    line = line.split('#') # remove comments
    line = line[0]
    if len(line) > 20: # ignore short lines
        fields = line.split(',')
        for j in range(len(fields)):
            fields[j] = fields[j].lstrip().rstrip()
        print fields
        mc = fields[1]
        mc = mc + fields[2]
        mc = mc + fields[3]
        mc = mc + fields[4]
        mc = mc + fields[5]
        mc = mc + fields[6]
        mc = mc + fields[7]
        mc = mc + fields[8]
        mc = mc + fields[9]
        mc = mc + '{0:03b}'.format(int(fields[10])) # field length
        mc = mc + '{0:05b}'.format(ALU_OP[fields[11]]) # ALU OPCODE
        mc = mc + '{0:06b}'.format(OP1[fields[12]]) # REG 1
        mc = mc + '{0:03b}'.format(KOP[fields[13]]) # REG 2
        mc = mc + '{0:06b}'.format(OP1[fields[14]]) # DEST
        ofn.write(mc + '\n')
        
        line_cnt += 1
    else:
        if line_cnt % 16 != 0:
            print 'Last group was incomplete at line {0:d}'.format(real_line_cnt+1)
    real_line_cnt += 1    
print '{0:d} lines microcode written to {1:s}'.format(line_cnt, argv[2])
ofn.close()
ifn.close()
        
        
    
    