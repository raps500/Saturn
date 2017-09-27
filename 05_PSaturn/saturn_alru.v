/**
 * Parallel Saturn
 * 64 bit Parallel Arithmetic, logic and register unit
 * All registers and flags are contained here
 */
`include "saturn_defs.v"

module saturn_alru(
    input wire          clk_in,
    input wire          write_dst_in,       // write back the alu operation/memory dat or extra register to the destination register
    input wire          write_op1_in,       // write from alu register to extra register
	input wire			latch_alu_regs_in,	// latch the masked input arguments to the alu
    input wire          forced_carry_in,
    input wire          forced_hex_in,
    input wire [5:0]    op1_reg_in,         // register for operand 1
    input wire [5:0]    op2_reg_in,         // Oerand 2
    input wire [5:0]    dst_reg_in,         // DST register, ST bit register for clr/test/set

    input wire          set_decimal_in,         // set decimal mode
    input wire          set_hexadecimal_in,         // set hexadecimal mode
    
    input wire [63:0]   op_literal_in,      // Data embedded in an opcode: LC, LA and so on
    input wire [63:0]   data_in,
    output wire [63:0]  data_o,             // memory interface
    input wire [19:0]   CONFIG_in,          // CONFIGID data
    
    input wire [3:0]    left_mask_in,       // read/write mask
    input wire [3:0]    right_mask_in,
    
    input wire [4:0]    alu_op_in,          // alu operation
    
    input wire [19:0]   addr_in,            // address as argument for PC, Dn operations
     //
    input wire          write_sticky_bit_in,// write the sticky bit with the contents of the shifted bit/nibble
    input wire          write_carry_in,     // write ALU carry to carry
    input wire          clr_carry_in,       // carry clear
    input wire          set_carry_in,       // carry set
    output wire         carry_o,            // arithmetic carry
    // P register
    input wire          shift_alu_q_in,     // shift result before storing in P
    output wire [ 3:0]  P_o,
    // PC
    input wire          add_pc_in,          // increment PC one nibble
    input wire          push_pc_in,         // push onto the stack
    input wire          pop_pc_in,          // pull from stack
    input wire          bwrite_fetched_pc_in, // to store newly fetched PC
    input wire [19:0]   fetched_PC_in,      // fetched PC
    output wire [19:0]  PC_o,
    // IN/OUT
    input wire [15:0]   IN_in,
    output wire [11:0]  OUT_o,
    // DATA Pointer
    input wire          dp_sel_in,          // selected data pointer D1=1, D0=0
    output wire [19:0]  Dn_o
    
    
);
// Register Set
reg [63:0] ABCD[3:0];
reg [63:0] R[7:0];
reg [19:0] D0 = 20'h00000;
reg [19:0] D1 = 20'h00000;
reg [19:0] PC = 20'h00000;
reg [19:0] STK[15:0];                       // 16 level hardware stack
reg [15:0] ST = 16'h0000;
reg [11:0] OUTR = 12'h000;
reg [15:0] INR = 16'h0000;
reg [3:0]  P = 4'h0;
reg [3:0]  HS = 4'h0; // HW registers { MP, SR, SB, XM }
wire [15:0] mask;
reg [63:0] latched_src_reg = 64'h0;
reg [63:0] latched_op2_reg = 64'h0;
reg [15:0] left_mask = 16'h0000;
reg [15:0] right_mask = 16'h0000;
reg [63:0] src_reg;
reg [63:0] op2_reg;
reg f_carry = 1'b0;
reg f_decimal = 1'b0;   // starts in hexadecimal mode
reg alu_carry;
reg alu_sticky_bit;

wire [63:0] masked_src_reg, masked_op2_reg;

wire [19:0] RSTK;

wire [63:0] add_q, sub_q, rsub_q;
reg [63:0] alu_q;
wire add_qc, sub_qc, rsub_qc;
wire gt, gteq, lt, lteq, eq, neq;
wire [15:0] no_src_zero_nibs; // used for stick bit generation
wire [15:0] no_src_zero_bits_l, no_src_zero_bits_r; // used for stick bit generation

wire [63:0] RA, RB, RC, RD;

assign RA = ABCD[0];
assign RB = ABCD[1];
assign RC = ABCD[2];
assign RD = ABCD[3];

assign RSTK = STK[0];
assign P_o = P;
assign PC_o = PC;
assign OUT_o = OUTR;
assign Dn_o = dp_sel_in ? D1:D0;
assign carry_o = f_carry;

always @(posedge clk_in)
    INR <= IN_in;

always @(*)
    begin
        case (left_mask_in)
            4'h0: left_mask = 16'b0000000000000001;
            4'h1: left_mask = 16'b0000000000000011;
            4'h2: left_mask = 16'b0000000000000111;
            4'h3: left_mask = 16'b0000000000001111;
            4'h4: left_mask = 16'b0000000000011111;
            4'h5: left_mask = 16'b0000000000111111;
            4'h6: left_mask = 16'b0000000001111111;
            4'h7: left_mask = 16'b0000000011111111;
            4'h8: left_mask = 16'b0000000111111111;
            4'h9: left_mask = 16'b0000001111111111;
            4'ha: left_mask = 16'b0000011111111111;
            4'hb: left_mask = 16'b0000111111111111;
            4'hc: left_mask = 16'b0001111111111111;
            4'hd: left_mask = 16'b0011111111111111;
            4'he: left_mask = 16'b0111111111111111;
            4'hf: left_mask = 16'b1111111111111111;
        endcase
    end

always @(*)
    begin
        case (right_mask_in)
            4'h0: right_mask = 16'b1111111111111111;
            4'h1: right_mask = 16'b1111111111111110;
            4'h2: right_mask = 16'b1111111111111100;
            4'h3: right_mask = 16'b1111111111111000;
            4'h4: right_mask = 16'b1111111111110000;
            4'h5: right_mask = 16'b1111111111100000;
            4'h6: right_mask = 16'b1111111111000000;
            4'h7: right_mask = 16'b1111111110000000;
            4'h8: right_mask = 16'b1111111100000000;
            4'h9: right_mask = 16'b1111111000000000;
            4'ha: right_mask = 16'b1111110000000000;
            4'hb: right_mask = 16'b1111100000000000;
            4'hc: right_mask = 16'b1111000000000000;
            4'hd: right_mask = 16'b1110000000000000;
            4'he: right_mask = 16'b1100000000000000;
            4'hf: right_mask = 16'b1000000000000000;
        endcase
    end

assign mask = left_mask & right_mask;
// Source path MUX
// All possible sources
// 00 0 0 00
always @(*)
    begin
        src_reg = 64'h0;
        case (op1_reg_in[5:3])
            3'b000: src_reg = ABCD[op1_reg_in[1:0]]; // Arithmetic registers
            3'b001: src_reg = R[op1_reg_in[2:0]]; // Extra registers
            3'b010: src_reg = data_in; // Memory
            3'b011: src_reg = op_literal_in; // literal from opcode, already shifted
            3'b100: 
                case (op1_reg_in[2:0])
                    3'b000: src_reg[19: 0] = PC;
                    3'b001: src_reg[19: 0] = RSTK;
                    3'b010: src_reg[19: 0] = D0;
                    3'b011: src_reg[19: 0] = D1;
                    3'b100: src_reg[15: 0] = ST;
                    3'b101: src_reg[15: 0] = INR;
                    3'b110: src_reg = { P, P, P, P, P, P, P, P, P, P, P, P, P, P, P, P };
                    3'b111: src_reg[19: 0] = CONFIG_in; // config instructions
                endcase
            3'b110: src_reg = f_decimal ? 64'h9999999999999999:64'hFFFFFFFFFFFFFFFF;
            3'b111: src_reg = 64'h0;
        endcase
    end
// OP2 path mux: A, B, C, D, D0, D1, R0..R5(7), P, ST, PC 
always @(*)
    begin
        op2_reg = 64'h0;
        case (op2_reg_in[5:3])
            3'b000: op2_reg =  ABCD[op2_reg_in[1:0]];
            3'b001: op2_reg = R[op2_reg_in[2:0]];
            3'b011: op2_reg = op_literal_in; // literal from opcode, already shifted
            3'b100: 
                case (op2_reg_in)
                    3'b000: op2_reg[19: 0] = PC;
                    3'b001: op2_reg[19: 0] = RSTK;
                    3'b010: op2_reg[19: 0] = D0;
                    3'b011: op2_reg[19: 0] = D1;
                    3'b100: op2_reg[15: 0] = ST;
                    3'b101: op2_reg[15: 0] = INR;
                    3'b110: op2_reg = { P, P, P, P, P, P, P, P, P, P, P, P, P, P, P, P };
                    
                endcase
            3'b110: op2_reg = f_decimal ? 64'h9999999999999999:64'hFFFFFFFFFFFFFFFF;
            3'b111: op2_reg = 64'h0;
        endcase
    end

assign masked_src_reg = { mask[15] ? src_reg[63:60]:4'h0,
                          mask[14] ? src_reg[59:56]:4'h0,  
                          mask[13] ? src_reg[55:52]:4'h0,  
                          mask[12] ? src_reg[51:48]:4'h0,  
                          mask[11] ? src_reg[47:44]:4'h0,  
                          mask[10] ? src_reg[43:40]:4'h0,  
                          mask[ 9] ? src_reg[39:36]:4'h0,  
                          mask[ 8] ? src_reg[35:32]:4'h0,  
                          mask[ 7] ? src_reg[31:28]:4'h0,  
                          mask[ 6] ? src_reg[27:24]:4'h0,  
                          mask[ 5] ? src_reg[23:20]:4'h0,  
                          mask[ 4] ? src_reg[19:16]:4'h0,  
                          mask[ 3] ? src_reg[15:12]:4'h0,  
                          mask[ 2] ? src_reg[11: 8]:4'h0,  
                          mask[ 1] ? src_reg[ 7: 4]:4'h0,  
                          mask[ 0] ? src_reg[ 3: 0]:4'h0 };
                          
assign masked_op2_reg= { mask[15] ? op2_reg[63:60]:4'h0,
                          mask[14] ? op2_reg[59:56]:4'h0,  
                          mask[13] ? op2_reg[55:52]:4'h0,  
                          mask[12] ? op2_reg[51:48]:4'h0,  
                          mask[11] ? op2_reg[47:44]:4'h0,  
                          mask[10] ? op2_reg[43:40]:4'h0,  
                          mask[ 9] ? op2_reg[39:36]:4'h0,  
                          mask[ 8] ? op2_reg[35:32]:4'h0,  
                          mask[ 7] ? op2_reg[31:28]:4'h0,  
                          mask[ 6] ? op2_reg[27:24]:4'h0,  
                          mask[ 5] ? op2_reg[23:20]:4'h0,  
                          mask[ 4] ? op2_reg[19:16]:4'h0,  
                          mask[ 3] ? op2_reg[15:12]:4'h0,  
                          mask[ 2] ? op2_reg[11: 8]:4'h0,  
                          mask[ 1] ? op2_reg[ 7: 4]:4'h0,  
                          mask[ 0] ? op2_reg[ 3: 0]:4'h0 };

assign data_o = masked_src_reg;
                          
always @(posedge clk_in)
    begin
        if (latch_alu_regs_in)
            begin
                latched_src_reg <= masked_src_reg;
                latched_op2_reg <= masked_op2_reg;
            end
    end

saturn_addbcd64  add64(
    latched_src_reg,  
    latched_op2_reg, 
    f_decimal & (~forced_hex_in), 
    forced_carry_in, 
    left_mask_in, 
    right_mask_in, 
    add_q, 
    add_qc
);    
saturn_subbcd64  sub64(latched_src_reg,  latched_op2_reg, f_decimal & (~forced_hex_in), forced_carry_in, left_mask_in, right_mask_in, sub_q, sub_qc);    
saturn_subbcd64 rsub64(latched_op2_reg,  latched_src_reg, f_decimal, forced_carry_in, left_mask_in, right_mask_in, rsub_q, rsub_qc);        
saturn_compare  cmp64(.a_in(latched_op2_reg), .b_in(latched_src_reg), .eq_o(eq), .neq_o(neq),
    .gteq_o(gteq), .gt_o(gt), .lteq_o(lteq), .lt_o(lt));
    
assign no_src_zero_nibs[15] = latched_src_reg[63:60] != 4'h0;
assign no_src_zero_nibs[14] = latched_src_reg[59:56] != 4'h0;
assign no_src_zero_nibs[13] = latched_src_reg[55:52] != 4'h0;
assign no_src_zero_nibs[12] = latched_src_reg[51:48] != 4'h0;
assign no_src_zero_nibs[11] = latched_src_reg[47:44] != 4'h0;
assign no_src_zero_nibs[10] = latched_src_reg[43:40] != 4'h0;
assign no_src_zero_nibs[ 9] = latched_src_reg[39:36] != 4'h0;
assign no_src_zero_nibs[ 8] = latched_src_reg[35:32] != 4'h0;
assign no_src_zero_nibs[ 7] = latched_src_reg[31:28] != 4'h0;
assign no_src_zero_nibs[ 6] = latched_src_reg[27:24] != 4'h0;
assign no_src_zero_nibs[ 5] = latched_src_reg[23:20] != 4'h0;
assign no_src_zero_nibs[ 4] = latched_src_reg[19:16] != 4'h0;
assign no_src_zero_nibs[ 3] = latched_src_reg[15:12] != 4'h0;
assign no_src_zero_nibs[ 2] = latched_src_reg[11: 8] != 4'h0;
assign no_src_zero_nibs[ 1] = latched_src_reg[ 7: 4] != 4'h0;
assign no_src_zero_nibs[ 0] = latched_src_reg[ 3: 0] != 4'h0;    

assign no_src_zero_bits_l[15] = latched_src_reg[63];
assign no_src_zero_bits_l[14] = latched_src_reg[59];
assign no_src_zero_bits_l[13] = latched_src_reg[55];
assign no_src_zero_bits_l[12] = latched_src_reg[51];
assign no_src_zero_bits_l[11] = latched_src_reg[47];
assign no_src_zero_bits_l[10] = latched_src_reg[43];
assign no_src_zero_bits_l[ 9] = latched_src_reg[39];
assign no_src_zero_bits_l[ 8] = latched_src_reg[35];
assign no_src_zero_bits_l[ 7] = latched_src_reg[31];
assign no_src_zero_bits_l[ 6] = latched_src_reg[27];
assign no_src_zero_bits_l[ 5] = latched_src_reg[23];
assign no_src_zero_bits_l[ 4] = latched_src_reg[19];
assign no_src_zero_bits_l[ 3] = latched_src_reg[15];
assign no_src_zero_bits_l[ 2] = latched_src_reg[11];
assign no_src_zero_bits_l[ 1] = latched_src_reg[ 7];
assign no_src_zero_bits_l[ 0] = latched_src_reg[ 3];

assign no_src_zero_bits_r[15] = latched_src_reg[60];
assign no_src_zero_bits_r[14] = latched_src_reg[56];
assign no_src_zero_bits_r[13] = latched_src_reg[52];
assign no_src_zero_bits_r[12] = latched_src_reg[48];
assign no_src_zero_bits_r[11] = latched_src_reg[44];
assign no_src_zero_bits_r[10] = latched_src_reg[40];
assign no_src_zero_bits_r[ 9] = latched_src_reg[36];
assign no_src_zero_bits_r[ 8] = latched_src_reg[32];
assign no_src_zero_bits_r[ 7] = latched_src_reg[28];
assign no_src_zero_bits_r[ 6] = latched_src_reg[24];
assign no_src_zero_bits_r[ 5] = latched_src_reg[20];
assign no_src_zero_bits_r[ 4] = latched_src_reg[16];
assign no_src_zero_bits_r[ 3] = latched_src_reg[12];
assign no_src_zero_bits_r[ 2] = latched_src_reg[ 8];
assign no_src_zero_bits_r[ 1] = latched_src_reg[ 4];
assign no_src_zero_bits_r[ 0] = latched_src_reg[ 0];

always @(*)    
    begin
        alu_q = latched_src_reg;  // TFR, EX, CMP
        case (alu_op_in)
            `ALU_OP_TFR, `ALU_OP_EX: alu_q = latched_src_reg;
            `ALU_OP_ADD: alu_q = add_q;
            `ALU_OP_SUB: alu_q = sub_q;
            `ALU_OP_RSUB:alu_q = rsub_q;
            `ALU_OP_TST0, `ALU_OP_TST1,
            `ALU_OP_AND: alu_q = latched_src_reg & latched_op2_reg;
            `ALU_OP_OR:  alu_q = latched_src_reg | latched_op2_reg;
            `ALU_OP_SL: alu_q = { latched_src_reg[51:0], 4'h0 };
            `ALU_OP_SR: alu_q = { 4'h0, latched_src_reg[55:4] };
            `ALU_OP_SLB: alu_q = { latched_src_reg[54:0], 1'b0 };
            `ALU_OP_SRB: alu_q = { 1'b0, latched_src_reg[55:1] };
            `ALU_OP_SLC: alu_q = { latched_src_reg[51:0], latched_src_reg[55:52] }; // circular shift left
            `ALU_OP_SRC: alu_q = { latched_src_reg[3:0], latched_src_reg[55:4] }; // circular shift right
            `ALU_OP_ANDN: alu_q = latched_src_reg & (~latched_op2_reg);
            default: alu_q = latched_src_reg;
        endcase
    end
  
always @(*)    
    begin
        alu_carry = 1'b0;
        case (alu_op_in)
            `ALU_OP_TFR:  alu_carry = 1'b0;
            `ALU_OP_EX :  alu_carry = 1'b0;
            `ALU_OP_ADD:  alu_carry = add_qc;
            `ALU_OP_SUB:  alu_carry = sub_qc;
            `ALU_OP_RSUB: alu_carry = rsub_qc;
            `ALU_OP_AND:  alu_carry = 1'b0;
            `ALU_OP_OR :  alu_carry = 1'b0;
            `ALU_OP_SL :  alu_carry = 1'b0;
            `ALU_OP_SR :  alu_carry = 1'b0;
            `ALU_OP_SLB:  alu_carry = 1'b0;
            `ALU_OP_SRB:  alu_carry = 1'b0;
            `ALU_OP_SLC:  alu_carry = 1'b0;
            `ALU_OP_SRC:  alu_carry = 1'b0;
            `ALU_OP_EQ:   alu_carry = eq;
            `ALU_OP_NEQ:  alu_carry = neq;
            `ALU_OP_GTEQ: alu_carry = gteq;
            `ALU_OP_GT:   alu_carry = gt;  
            `ALU_OP_LTEQ: alu_carry = lteq;
            `ALU_OP_LT:   alu_carry = lt;
            `ALU_OP_TST0: alu_carry = alu_q[15:0] == 16'h0; // bits are only tested on the first 16 bits
            `ALU_OP_TST1: alu_carry = alu_q[15:0] != 16'h0;
            `ALU_OP_ANDN:  alu_carry = 1'b0;
            default: alu_carry = 1'b0;
        endcase
    end
    
always @(*)
    begin
        alu_sticky_bit = 1'b0;
        case (alu_op_in)
            `ALU_OP_SL: alu_sticky_bit = no_src_zero_nibs[left_mask_in];
            `ALU_OP_SR: alu_sticky_bit = no_src_zero_nibs[right_mask_in];
            `ALU_OP_SLB:alu_sticky_bit = no_src_zero_bits_l[left_mask_in];
            `ALU_OP_SRB:alu_sticky_bit = no_src_zero_bits_r[right_mask_in];
            default:    
                        alu_sticky_bit = 1'b0;
        endcase
    end
wire [3:0] shifted_alu_q, shifted_latched_op2;
assign shifted_alu_q = (alu_q >> (right_mask_in << 2));
assign shifted_latched_op2 = (latched_op2_reg >> (right_mask_in << 2));
    
// result write back, destination register                          
always @(posedge clk_in)
    begin
        if (write_carry_in)
            f_carry <= alu_carry;
        if (set_carry_in)
            f_carry <= 1'b1;
        if (clr_carry_in)
            f_carry <= 1'b0;
        if (set_decimal_in)
            f_decimal <= 1'b1;
        if (set_hexadecimal_in)
            f_decimal <= 1'b0;
        if (write_sticky_bit_in)
            HS[1] <= alu_sticky_bit;
        if (write_dst_in)
            begin
                case (dst_reg_in[5:3])
                    3'b000: 
                        begin
                            if (mask[15]) ABCD[dst_reg_in[1:0]][63:60] <= alu_q[63:60];
                            if (mask[14]) ABCD[dst_reg_in[1:0]][59:56] <= alu_q[59:56];
                            if (mask[13]) ABCD[dst_reg_in[1:0]][55:52] <= alu_q[55:52];
                            if (mask[12]) ABCD[dst_reg_in[1:0]][51:48] <= alu_q[51:48];
                            if (mask[11]) ABCD[dst_reg_in[1:0]][47:44] <= alu_q[47:44];
                            if (mask[10]) ABCD[dst_reg_in[1:0]][43:40] <= alu_q[43:40];
                            if (mask[ 9]) ABCD[dst_reg_in[1:0]][39:36] <= alu_q[39:36];
                            if (mask[ 8]) ABCD[dst_reg_in[1:0]][35:32] <= alu_q[35:32];
                            if (mask[ 7]) ABCD[dst_reg_in[1:0]][31:28] <= alu_q[31:28];
                            if (mask[ 6]) ABCD[dst_reg_in[1:0]][27:24] <= alu_q[27:24];
                            if (mask[ 5]) ABCD[dst_reg_in[1:0]][23:20] <= alu_q[23:20];
                            if (mask[ 4]) ABCD[dst_reg_in[1:0]][19:16] <= alu_q[19:16];
                            if (mask[ 3]) ABCD[dst_reg_in[1:0]][15:12] <= alu_q[15:12];
                            if (mask[ 2]) ABCD[dst_reg_in[1:0]][11: 8] <= alu_q[11: 8];
                            if (mask[ 1]) ABCD[dst_reg_in[1:0]][ 7: 4] <= alu_q[ 7: 4];
                            if (mask[ 0]) ABCD[dst_reg_in[1:0]][ 3: 0] <= alu_q[ 3: 0];
                        end
                    3'b001:
                        begin
                            if (mask[15]) R[dst_reg_in[2:0]][63:60] <= alu_q[63:60];
                            if (mask[14]) R[dst_reg_in[2:0]][59:56] <= alu_q[59:56];
                            if (mask[13]) R[dst_reg_in[2:0]][55:52] <= alu_q[55:52];
                            if (mask[12]) R[dst_reg_in[2:0]][51:48] <= alu_q[51:48];
                            if (mask[11]) R[dst_reg_in[2:0]][47:44] <= alu_q[47:44];
                            if (mask[10]) R[dst_reg_in[2:0]][43:40] <= alu_q[43:40];
                            if (mask[ 9]) R[dst_reg_in[2:0]][39:36] <= alu_q[39:36];
                            if (mask[ 8]) R[dst_reg_in[2:0]][35:32] <= alu_q[35:32];
                            if (mask[ 7]) R[dst_reg_in[2:0]][31:28] <= alu_q[31:28];
                            if (mask[ 6]) R[dst_reg_in[2:0]][27:24] <= alu_q[27:24];
                            if (mask[ 5]) R[dst_reg_in[2:0]][23:20] <= alu_q[23:20];
                            if (mask[ 4]) R[dst_reg_in[2:0]][19:16] <= alu_q[19:16];
                            if (mask[ 3]) R[dst_reg_in[2:0]][15:12] <= alu_q[15:12];
                            if (mask[ 2]) R[dst_reg_in[2:0]][11: 8] <= alu_q[11: 8];
                            if (mask[ 1]) R[dst_reg_in[2:0]][ 7: 4] <= alu_q[ 7: 4];
                            if (mask[ 0]) R[dst_reg_in[2:0]][ 3: 0] <= alu_q[ 3: 0];
                        end
                    3'b100:
                        case (dst_reg_in[2:0])
                            3'b000: PC <= alu_q[19:0];
                            3'b001: STK[0] <= alu_q[19:0];
                            3'b010:
                                begin
                                    if (mask[ 4]) D0[19:16] <= alu_q[19:16];
                                    if (mask[ 3]) D0[15:12] <= alu_q[15:12];
                                    if (mask[ 2]) D0[11: 8] <= alu_q[11: 8];
                                    if (mask[ 1]) D0[ 7: 4] <= alu_q[ 7: 4];
                                    if (mask[ 0]) D0[ 3: 0] <= alu_q[ 3: 0];
                                end
                            3'b011:
                                begin
                                    if (mask[ 4]) D1[19:16] <= alu_q[19:16];
                                    if (mask[ 3]) D1[15:12] <= alu_q[15:12];
                                    if (mask[ 2]) D1[11: 8] <= alu_q[11: 8];
                                    if (mask[ 1]) D1[ 7: 4] <= alu_q[ 7: 4];
                                    if (mask[ 0]) D1[ 3: 0] <= alu_q[ 3: 0];
                                end
                            3'b100: ST <= alu_q[15:0];
                            3'b101: OUTR <= alu_q[11:0];
                            3'b110: P <= shift_alu_q_in ? shifted_alu_q:alu_q[3:0];
                        endcase
                    3'b101: HS <= alu_q[ 3: 0];
                endcase
            end
        if (write_op1_in) // used in exchanges
            begin
                case (op1_reg_in[5:3])
                    3'b000: 
                        begin
                            if (mask[15]) ABCD[op1_reg_in[1:0]][63:60] <= latched_op2_reg[63:60];
                            if (mask[14]) ABCD[op1_reg_in[1:0]][59:56] <= latched_op2_reg[59:56];
                            if (mask[13]) ABCD[op1_reg_in[1:0]][55:52] <= latched_op2_reg[55:52];
                            if (mask[12]) ABCD[op1_reg_in[1:0]][51:48] <= latched_op2_reg[51:48];
                            if (mask[11]) ABCD[op1_reg_in[1:0]][47:44] <= latched_op2_reg[47:44];
                            if (mask[10]) ABCD[op1_reg_in[1:0]][43:40] <= latched_op2_reg[43:40];
                            if (mask[ 9]) ABCD[op1_reg_in[1:0]][39:36] <= latched_op2_reg[39:36];
                            if (mask[ 8]) ABCD[op1_reg_in[1:0]][35:32] <= latched_op2_reg[35:32];
                            if (mask[ 7]) ABCD[op1_reg_in[1:0]][31:28] <= latched_op2_reg[31:28];
                            if (mask[ 6]) ABCD[op1_reg_in[1:0]][27:24] <= latched_op2_reg[27:24];
                            if (mask[ 5]) ABCD[op1_reg_in[1:0]][23:20] <= latched_op2_reg[23:20];
                            if (mask[ 4]) ABCD[op1_reg_in[1:0]][19:16] <= latched_op2_reg[19:16];
                            if (mask[ 3]) ABCD[op1_reg_in[1:0]][15:12] <= latched_op2_reg[15:12];
                            if (mask[ 2]) ABCD[op1_reg_in[1:0]][11: 8] <= latched_op2_reg[11: 8];
                            if (mask[ 1]) ABCD[op1_reg_in[1:0]][ 7: 4] <= latched_op2_reg[ 7: 4];
                            if (mask[ 0]) ABCD[op1_reg_in[1:0]][ 3: 0] <= latched_op2_reg[ 3: 0];
                        end
                    3'b001:
                        begin
                            if (mask[15]) R[op1_reg_in[2:0]][63:60] <= latched_op2_reg[63:60];
                            if (mask[14]) R[op1_reg_in[2:0]][59:56] <= latched_op2_reg[59:56];
                            if (mask[13]) R[op1_reg_in[2:0]][55:52] <= latched_op2_reg[55:52];
                            if (mask[12]) R[op1_reg_in[2:0]][51:48] <= latched_op2_reg[51:48];
                            if (mask[11]) R[op1_reg_in[2:0]][47:44] <= latched_op2_reg[47:44];
                            if (mask[10]) R[op1_reg_in[2:0]][43:40] <= latched_op2_reg[43:40];
                            if (mask[ 9]) R[op1_reg_in[2:0]][39:36] <= latched_op2_reg[39:36];
                            if (mask[ 8]) R[op1_reg_in[2:0]][35:32] <= latched_op2_reg[35:32];
                            if (mask[ 7]) R[op1_reg_in[2:0]][31:28] <= latched_op2_reg[31:28];
                            if (mask[ 6]) R[op1_reg_in[2:0]][27:24] <= latched_op2_reg[27:24];
                            if (mask[ 5]) R[op1_reg_in[2:0]][23:20] <= latched_op2_reg[23:20];
                            if (mask[ 4]) R[op1_reg_in[2:0]][19:16] <= latched_op2_reg[19:16];
                            if (mask[ 3]) R[op1_reg_in[2:0]][15:12] <= latched_op2_reg[15:12];
                            if (mask[ 2]) R[op1_reg_in[2:0]][11: 8] <= latched_op2_reg[11: 8];
                            if (mask[ 1]) R[op1_reg_in[2:0]][ 7: 4] <= latched_op2_reg[ 7: 4];
                            if (mask[ 0]) R[op1_reg_in[2:0]][ 3: 0] <= latched_op2_reg[ 3: 0];
                        end
                    3'b100:
                        case (dst_reg_in) // exchange only in whole register
                            3'b010: D0 <= latched_op2_reg[19:0];
                            3'b011: D1 <= latched_op2_reg[19:0];
                            3'b110: P <= shift_alu_q_in ? shifted_latched_op2:latched_op2_reg[3:0];
                        endcase
                endcase
            end
        if (add_pc_in)
            PC <= PC + addr_in;
        if (bwrite_fetched_pc_in) // keeps track 
            PC <= fetched_PC_in;
        if (push_pc_in)
            begin
                STK[15] <= STK[14]; STK[14] <= STK[13]; STK[13] <= STK[12]; STK[12] <= STK[11];
                STK[11] <= STK[10]; STK[10] <= STK[ 9]; STK[ 9] <= STK[ 8]; STK[ 8] <= STK[ 7];
                STK[ 7] <= STK[ 6]; STK[ 6] <= STK[ 5]; STK[ 5] <= STK[ 4]; STK[ 4] <= STK[ 3];
                STK[ 3] <= STK[ 2]; STK[ 2] <= STK[ 1]; STK[ 1] <= STK[ 0]; STK[ 0] <= PC;
            end
        if (pop_pc_in)
            begin
                STK[14] <= STK[15]; STK[13] <= STK[14]; STK[12] <= STK[13]; STK[11] <= STK[12];
                STK[10] <= STK[11]; STK[ 9] <= STK[10]; STK[ 8] <= STK[ 9]; STK[ 7] <= STK[ 8];
                STK[ 6] <= STK[ 7]; STK[ 5] <= STK[ 6]; STK[ 4] <= STK[ 5]; STK[ 3] <= STK[ 4];
                STK[ 2] <= STK[ 3]; STK[ 1] <= STK[ 2]; STK[ 0] <= STK[ 1]; PC <= STK[ 0];
            end
    end

initial
    begin
        ABCD[0] = 64'h0;
        ABCD[1] = 64'h0;
        ABCD[2] = 64'h0;
        ABCD[3] = 64'h0;
        R[0] = 64'h0;
        R[1] = 64'h0;
        R[2] = 64'h0;
        R[3] = 64'h0;
        R[4] = 64'h0;
        R[5] = 64'h0;
        R[6] = 64'h0;
        R[7] = 64'h0;
    end
    
    
endmodule


module saturn_addbcd64(
    input wire [63:0]   a_in,
    input wire [63:0]   b_in,
    input wire          dec_in,
    input wire          forced_carry_in,
    input wire [3:0]    left_mask_in,   // signals which carry is to be output
    input wire [3:0]    right_mask_in,  // signals which nibble gets the forced carry
    output wire [63:0]  q_out,
    output reg          qc_out
);
wire c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,ca,cb,cc,cd,ce,cf;
reg f0,f1,f2,f3,f4,f5,f6,f7,f8,f9,fa,fb,fc,fd,fe,ff;
always @(*)
	begin
        f0 = 1'b0;
        f1 = 1'b0;
        f2 = 1'b0;
        f3 = 1'b0;
        f4 = 1'b0;
        f5 = 1'b0;
        f6 = 1'b0;
        f7 = 1'b0;
        f8 = 1'b0;
        f9 = 1'b0;
        fa = 1'b0;
        fb = 1'b0;
        fc = 1'b0;
        fd = 1'b0;
        fe = 1'b0;
        ff = 1'b0;
        case (right_mask_in)
            4'h0: f0 = forced_carry_in;
            4'h1: f1 = forced_carry_in;
            4'h2: f2 = forced_carry_in;
            4'h3: f3 = forced_carry_in;
            4'h4: f4 = forced_carry_in;
            4'h5: f5 = forced_carry_in;
            4'h6: f6 = forced_carry_in;
            4'h7: f7 = forced_carry_in;
            4'h8: f8 = forced_carry_in;
            4'h9: f9 = forced_carry_in;
            4'ha: fa = forced_carry_in;
            4'hb: fb = forced_carry_in;
            4'hc: fc = forced_carry_in;
            4'hd: fd = forced_carry_in;
            4'he: fe = forced_carry_in;
            4'hf: ff = forced_carry_in;
        endcase
	end

saturn_addbcd a0 (a_in[ 3: 0], b_in[ 3: 0],        f0, dec_in, q_out[ 3: 0], c0);
saturn_addbcd a1 (a_in[ 7: 4], b_in[ 7: 4],   c0 | f1, dec_in, q_out[ 7: 4], c1);
saturn_addbcd a2 (a_in[11: 8], b_in[11: 8],   c1 | f2, dec_in, q_out[11: 8], c2);
saturn_addbcd a3 (a_in[15:12], b_in[15:12],   c2 | f3, dec_in, q_out[15:12], c3);
saturn_addbcd a4 (a_in[19:16], b_in[19:16],   c3 | f4, dec_in, q_out[19:16], c4);
saturn_addbcd a5 (a_in[23:20], b_in[23:20],   c4 | f5, dec_in, q_out[23:20], c5);
saturn_addbcd a6 (a_in[27:24], b_in[27:24],   c5 | f6, dec_in, q_out[27:24], c6);
saturn_addbcd a7 (a_in[31:28], b_in[31:28],   c6 | f7, dec_in, q_out[31:28], c7);
saturn_addbcd a8 (a_in[35:32], b_in[35:32],   c7 | f8, dec_in, q_out[35:32], c8);
saturn_addbcd a9 (a_in[39:36], b_in[39:36],   c8 | f9, dec_in, q_out[39:36], c9);
saturn_addbcd aa (a_in[43:40], b_in[43:40],   c9 | fa, dec_in, q_out[43:40], ca);
saturn_addbcd ab (a_in[47:44], b_in[47:44],   ca | fb, dec_in, q_out[47:44], cb);
saturn_addbcd ac (a_in[51:48], b_in[51:48],   cb | fc, dec_in, q_out[51:48], cc);
saturn_addbcd ad (a_in[55:52], b_in[55:52],   cc | fd, dec_in, q_out[55:52], cd);
saturn_addbcd ae (a_in[59:56], b_in[59:56],   cd | fe, dec_in, q_out[59:56], ce);
saturn_addbcd af (a_in[63:60], b_in[63:60],   ce | ff, dec_in, q_out[63:60], cf);

always @(*)
        case (left_mask_in)
            4'h0: qc_out = c0;
            4'h1: qc_out = c1;
            4'h2: qc_out = c2;
            4'h3: qc_out = c3;
            4'h4: qc_out = c4;
            4'h5: qc_out = c5;
            4'h6: qc_out = c6;
            4'h7: qc_out = c7;
            4'h8: qc_out = c8;
            4'h9: qc_out = c9;
            4'ha: qc_out = ca;
            4'hb: qc_out = cb;
            4'hc: qc_out = cc;
            4'hd: qc_out = cd;
            4'he: qc_out = ce;
            4'hf: qc_out = cf;
        endcase

endmodule


module saturn_subbcd64(
    input wire [63:0]   a_in,
    input wire [63:0]   b_in,
    input wire          dec_in,
    input wire          forced_carry_in,
    input wire [3:0]    left_mask_in,   // signals which carry is to be output
    input wire [3:0]    right_mask_in,   // signals which nibble gets forced carry
    output wire [63:0]  q_out,
    output reg          qc_out
);
wire c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,ca,cb,cc,cd,ce,cf;
reg f0,f1,f2,f3,f4,f5,f6,f7,f8,f9,fa,fb,fc,fd,fe,ff;
always @(*)
	begin
        f0 = 1'b0;
        f1 = 1'b0;
        f2 = 1'b0;
        f3 = 1'b0;
        f4 = 1'b0;
        f5 = 1'b0;
        f6 = 1'b0;
        f7 = 1'b0;
        f8 = 1'b0;
        f9 = 1'b0;
        fa = 1'b0;
        fb = 1'b0;
        fc = 1'b0;
        fd = 1'b0;
        fe = 1'b0;
        ff = 1'b0;
        case (right_mask_in)
            4'h0: f0 = forced_carry_in;
            4'h1: f1 = forced_carry_in;
            4'h2: f2 = forced_carry_in;
            4'h3: f3 = forced_carry_in;
            4'h4: f4 = forced_carry_in;
            4'h5: f5 = forced_carry_in;
            4'h6: f6 = forced_carry_in;
            4'h7: f7 = forced_carry_in;
            4'h8: f8 = forced_carry_in;
            4'h9: f9 = forced_carry_in;
            4'ha: fa = forced_carry_in;
            4'hb: fb = forced_carry_in;
            4'hc: fc = forced_carry_in;
            4'hd: fd = forced_carry_in;
            4'he: fe = forced_carry_in;
            4'hf: ff = forced_carry_in;
        endcase
	end

saturn_subbcd s0 (a_in[ 3: 0], b_in[ 3: 0],        f0, dec_in, q_out[ 3: 0], c0);
saturn_subbcd s1 (a_in[ 7: 4], b_in[ 7: 4],   c0 | f1, dec_in, q_out[ 7: 4], c1);
saturn_subbcd s2 (a_in[11: 8], b_in[11: 8],   c1 | f2, dec_in, q_out[11: 8], c2);
saturn_subbcd s3 (a_in[15:12], b_in[15:12],   c2 | f3, dec_in, q_out[15:12], c3);
saturn_subbcd s4 (a_in[19:16], b_in[19:16],   c3 | f4, dec_in, q_out[19:16], c4);
saturn_subbcd s5 (a_in[23:20], b_in[23:20],   c4 | f5, dec_in, q_out[23:20], c5);
saturn_subbcd s6 (a_in[27:24], b_in[27:24],   c5 | f6, dec_in, q_out[27:24], c6);
saturn_subbcd s7 (a_in[31:28], b_in[31:28],   c6 | f7, dec_in, q_out[31:28], c7);
saturn_subbcd s8 (a_in[35:32], b_in[35:32],   c7 | f8, dec_in, q_out[35:32], c8);
saturn_subbcd s9 (a_in[39:36], b_in[39:36],   c8 | f9, dec_in, q_out[39:36], c9);
saturn_subbcd sa (a_in[43:40], b_in[43:40],   c9 | fa, dec_in, q_out[43:40], ca);
saturn_subbcd sb (a_in[47:44], b_in[47:44],   ca | fb, dec_in, q_out[47:44], cb);
saturn_subbcd sc (a_in[51:48], b_in[51:48],   cb | fc, dec_in, q_out[51:48], cc);
saturn_subbcd sd (a_in[55:52], b_in[55:52],   cc | fd, dec_in, q_out[55:52], cd);
saturn_subbcd se (a_in[59:56], b_in[59:56],   cd | fe, dec_in, q_out[59:56], ce);
saturn_subbcd sf (a_in[63:60], b_in[63:60],   ce | ff, dec_in, q_out[63:60], cf);

always @(*)
        case (left_mask_in)
            4'h0: qc_out = c0;
            4'h1: qc_out = c1;
            4'h2: qc_out = c2;
            4'h3: qc_out = c3;
            4'h4: qc_out = c4;
            4'h5: qc_out = c5;
            4'h6: qc_out = c6;
            4'h7: qc_out = c7;
            4'h8: qc_out = c8;
            4'h9: qc_out = c9;
            4'ha: qc_out = ca;
            4'hb: qc_out = cb;
            4'hc: qc_out = cc;
            4'hd: qc_out = cd;
            4'he: qc_out = ce;
            4'hf: qc_out = cf;
        endcase

endmodule

module saturn_addbcd(
    a_in,
    b_in,
    c_in,
    dec_in,
    q_out,
    qc_out
);
input wire [3:0] a_in, b_in;
output wire [3:0] q_out;
input wire c_in, dec_in;
output wire qc_out;

wire [4:0] a_plus_b_plus_c;


assign a_plus_b_plus_c = { 1'b0, a_in } + { 1'b0, b_in } + { 4'h0, c_in };
assign qc_out = dec_in ? (a_plus_b_plus_c > 5'h09):a_plus_b_plus_c[4];
assign q_out = dec_in ? (qc_out == 1'b1 ? a_plus_b_plus_c[3:0] + 4'h6:a_plus_b_plus_c[3:0]):a_plus_b_plus_c[3:0];

endmodule


module saturn_subbcd(
    a_in,
    b_in,
    c_in,
    dec_in,
    q_out,
    qc_out
);
input wire [3:0] a_in, b_in;
output wire [3:0] q_out;
input wire c_in, dec_in;
output wire qc_out;

wire [3:0] c9;
wire [4:0] sub;
assign sub = { 1'b0, a_in } - { 1'b0, b_in } - { 4'b0, c_in };
assign c9 = sub[4] ? sub[3:0] - 4'h6:sub[3:0];
assign qc_out = dec_in ? (sub[4:0] > 5'h0a):sub[4];
assign q_out = dec_in ? c9:sub[3:0];

endmodule

module saturn_compare(
    input wire [63:0]   a_in,
    input wire [63:0]   b_in,
    output wire         eq_o,
    output wire         neq_o,
    output wire         gteq_o,
    output wire         gt_o,
    output wire         lteq_o,
    output wire         lt_o
);

wire e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,ea,eb,ec,ed,ee,ef;
wire g0,g1,g2,g3,g4,g5,g6,g7,g8,g9,ga,gb,gc,gd,ge,gf;
wire l0,l1,l2,l3,l4,l5,l6,l7,l8,l9,la,lb,lc,ld,le,lf;
wire eq;
reg gt, lt;
        

assign e0 = a_in[ 3: 0] == b_in[ 3: 0];
assign e1 = a_in[ 7: 4] == b_in[ 7: 4];    
assign e2 = a_in[11: 8] == b_in[11: 8];    
assign e3 = a_in[15:12] == b_in[15:12];    
assign e4 = a_in[19:16] == b_in[19:16];    
assign e5 = a_in[23:20] == b_in[23:20];    
assign e6 = a_in[27:24] == b_in[27:24];    
assign e7 = a_in[31:28] == b_in[31:28];    
assign e8 = a_in[35:32] == b_in[35:32];    
assign e9 = a_in[39:36] == b_in[39:36];    
assign ea = a_in[43:40] == b_in[43:40];    
assign eb = a_in[47:44] == b_in[47:44];    
assign ec = a_in[51:48] == b_in[51:48];    
assign ed = a_in[55:52] == b_in[55:52];    
assign ee = a_in[59:56] == b_in[59:56];    
assign ef = a_in[63:60] == b_in[63:60];    
    
assign g0 = a_in[ 3: 0] > b_in[ 3: 0];
assign g1 = a_in[ 7: 4] > b_in[ 7: 4];    
assign g2 = a_in[11: 8] > b_in[11: 8];    
assign g3 = a_in[15:12] > b_in[15:12];    
assign g4 = a_in[19:16] > b_in[19:16];    
assign g5 = a_in[23:20] > b_in[23:20];    
assign g6 = a_in[27:24] > b_in[27:24];    
assign g7 = a_in[31:28] > b_in[31:28];    
assign g8 = a_in[35:32] > b_in[35:32];    
assign g9 = a_in[39:36] > b_in[39:36];    
assign ga = a_in[43:40] > b_in[43:40];    
assign gb = a_in[47:44] > b_in[47:44];    
assign gc = a_in[51:48] > b_in[51:48];    
assign gd = a_in[55:52] > b_in[55:52];    
assign ge = a_in[59:56] > b_in[59:56];    
assign gf = a_in[63:60] > b_in[63:60];    

assign l0 = a_in[ 3: 0] < b_in[ 3: 0];
assign l1 = a_in[ 7: 4] < b_in[ 7: 4];    
assign l2 = a_in[11: 8] < b_in[11: 8];    
assign l3 = a_in[15:12] < b_in[15:12];    
assign l4 = a_in[19:16] < b_in[19:16];    
assign l5 = a_in[23:20] < b_in[23:20];    
assign l6 = a_in[27:24] < b_in[27:24];    
assign l7 = a_in[31:28] < b_in[31:28];    
assign l8 = a_in[35:32] < b_in[35:32];    
assign l9 = a_in[39:36] < b_in[39:36];    
assign la = a_in[43:40] < b_in[43:40];    
assign lb = a_in[47:44] < b_in[47:44];    
assign lc = a_in[51:48] < b_in[51:48];    
assign ld = a_in[55:52] < b_in[55:52];    
assign le = a_in[59:56] < b_in[59:56];    
assign lf = a_in[63:60] < b_in[63:60];    

assign eq = e0 & e1 & e2 & e3 & e4 & e5 & e6 & e7 & 
            e8 & e9 & ea & eb & ec & ed & ee & ef;
assign eq_o = eq;    
assign neq_o = ~eq;   

always @(*)
    begin
        gt = 1'b0;
        if (gf) gt = 1'b1;
        else
        if (ef) 
        if (ge) gt = 1'b1;
        else
        if (ee) 
        if (gd) gt = 1'b1;
        else
        if (ed) 
        if (gc) gt = 1'b1;
        else
        if (ec) 
        if (gb) gt = 1'b1;
        else
        if (eb) 
        if (ga) gt = 1'b1;
        else
        if (ea) 
        if (g9) gt = 1'b1;
        else
        if (e9) 
        if (g8) gt = 1'b1;
        else
        if (e8) 
        if (g7) gt = 1'b1;
        else
        if (e7) 
        if (g6) gt = 1'b1;
        else
        if (e6) 
        if (g5) gt = 1'b1;
        else
        if (e5) 
        if (g4) gt = 1'b1;
        else
        if (e4) 
        if (g3) gt = 1'b1;
        else
        if (e3) 
        if (g2) gt = 1'b1;
        else
        if (e2) 
        if (g1) gt = 1'b1;
        else
        if (e1) 
        if (g0) gt = 1'b1;
    end
always @(*)
    begin
        lt = 1'b0;
        if (lf) lt = 1'b1;
        else
        if (ef) 
        if (le) lt = 1'b1;
        else
        if (ee) 
        if (ld) lt = 1'b1;
        else
        if (ed) 
        if (lc) lt = 1'b1;
        else
        if (ec) 
        if (lb) lt = 1'b1;
        else
        if (eb) 
        if (la) lt = 1'b1;
        else
        if (ea) 
        if (l9) lt = 1'b1;
        else
        if (e9) 
        if (l8) lt = 1'b1;
        else
        if (e8) 
        if (l7) lt = 1'b1;
        else
        if (e7) 
        if (l6) lt = 1'b1;
        else
        if (e6) 
        if (l5) lt = 1'b1;
        else
        if (e5) 
        if (l4) lt = 1'b1;
        else
        if (e4) 
        if (l3) lt = 1'b1;
        else
        if (e3) 
        if (l2) lt = 1'b1;
        else
        if (e2) 
        if (l1) lt = 1'b1;
        else
        if (e1) 
        if (l0) lt = 1'b1;
    end


assign gt_o = gt;
assign gteq_o = gt | eq;
assign lt_o = lt;
assign lteq_o = lt | eq;
endmodule