// Parallel Saturn core
// global defines
`default_nettype none
`define OP_A       6'h00
`define OP_B       6'h01
`define OP_C       6'h02
`define OP_D       6'h03

`define OP_R0      6'h08
`define OP_R1      6'h09
`define OP_R2      6'h0a
`define OP_R3      6'h0b
`define OP_R4      6'h0c
`define OP_R5      6'h0d
`define OP_R6      6'h0e
`define OP_R7      6'h0f
`define OP_MEM     6'h10 // memory port
`define OP_LIT     6'h18 // literal from opcode

`define OP_PC      6'h20
`define OP_STK     6'h21
`define OP_D0      6'h22
`define OP_D1      6'h23
`define OP_ST      6'h24
`define OP_IN      6'h25
`define OP_OUT     6'h25 // only as destination
`define OP_P       6'h26
`define OP_ID      6'h27 // CONFIGID value or BUS commands
`define OP_HS      6'h28 // 4 HW status bits
`define OP_9       6'h30 // 9s or Fs depending on the decimal flag
`define OP_Z       6'h38
`define OP_1       6'h39 // must be 39 because it uses the force carry flag

// ALU operations
`define ALU_OP_TFR  5'h01
`define ALU_OP_EX   5'h02
`define ALU_OP_ADD  5'h03
`define ALU_OP_SUB  5'h04
`define ALU_OP_RSUB 5'h05
`define ALU_OP_AND  5'h06
`define ALU_OP_OR   5'h07
`define ALU_OP_SL   5'h08
`define ALU_OP_SR   5'h09
`define ALU_OP_SLB  5'h0A
`define ALU_OP_SRB  5'h0B
`define ALU_OP_SLC  5'h0C
`define ALU_OP_SRC  5'h10
`define ALU_OP_EQ   5'h11
`define ALU_OP_NEQ  5'h12
`define ALU_OP_GTEQ 5'h13
`define ALU_OP_GT   5'h14
`define ALU_OP_LTEQ 5'h15
`define ALU_OP_LT   5'h16
`define ALU_OP_RD   5'h17
`define ALU_OP_WR   5'h18
`define ALU_OP_TST1 5'h19 // Test if set
`define ALU_OP_TST0 5'h1A // test if clear
`define ALU_OP_ANDN 5'h1B // AND with negated op2, used to clear bits on HS and ST
// Sequencer States
`define ST_INIT         4'h0
`define ST_DECODE       4'h1
`define ST_EXE_LATCH    4'h2
`define ST_EXE_ALU      4'h3
`define ST_EXE_END      4'h4
`define ST_INT_ACK_PUSH 4'h5
`define ST_INT_ACK_JUMP 4'h6
`define ST_FLUSH_QUEUE  4'h7