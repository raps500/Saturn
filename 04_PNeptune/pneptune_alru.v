/**
 * Parallel Neptune core
 * 128 bit Arithmetic, logic and register unit
 *
 *
 *
 */
 
module pneptune_alru(
    input wire          clk_in,
    input wire          write_alu_dest_in,  // write back the alu operation/memory dat or extra register to the destination register
    input wire          write_extra_dest_in,// write from alu register to extra register
	input wire			latch_alu_regs_in,	// latch the masked input arguments to the alu
    input wire          forced_carry_in,
    input wire [1:0]    alu_dest_reg_in,    // alu destination and 2nd register
    input wire [2:0]    alu_src_reg_in,     // alu source register

    input wire [2:0]    extra_reg_in,       // extra register for transfer or exchange
    input wire [1:0]    alu_dest_mux_in,    // dest alu register source mux: ALU, data, extra reg

    input wire          decimal_in,
    
    input wire [127:0]   data_in,
    output wire [127:0]  data_o,             // memory interface
    
    input wire [4:0]    left_mask_in,       // read/write mask
    input wire [4:0]    right_mask_in,
    
    input wire [3:0]    alu_op_in,          // alu operation
    
    output reg          carry_o,
    output wire         condition_true_o
    
);

reg [127:0] A, B, C, D;
reg [127:0] latched_src_reg, latched_dest_reg;


wire [15:0] mask;
reg [15:0] left_mask, right_mask;
reg [63:0] src_reg, dest_reg;
wire [63:0] masked_src_reg, masked_dest_reg;

always @(*)
    begin
        case (left_mask_in)
            5'h00: left_mask = 32'b00000000000000000000000000000001;
            5'h01: left_mask = 32'b00000000000000000000000000000011;
            5'h02: left_mask = 32'b00000000000000000000000000000111;
            5'h03: left_mask = 32'b00000000000000000000000000001111;
            5'h04: left_mask = 32'b00000000000000000000000000011111;
            5'h05: left_mask = 32'b00000000000000000000000000111111;
            5'h06: left_mask = 32'b00000000000000000000000001111111;
            5'h07: left_mask = 32'b00000000000000000000000011111111;
            5'h08: left_mask = 32'b00000000000000000000000111111111;
            5'h09: left_mask = 32'b00000000000000000000001111111111;
            5'h0a: left_mask = 32'b00000000000000000000011111111111;
            5'h0b: left_mask = 32'b00000000000000000000111111111111;
            5'h0c: left_mask = 32'b00000000000000000001111111111111;
            5'h0d: left_mask = 32'b00000000000000000011111111111111;
            5'h0e: left_mask = 32'b00000000000000000111111111111111;
            5'h0f: left_mask = 32'b00000000000000001111111111111111;
            5'h10: left_mask = 32'b00000000000000011111111111111111;
            5'h11: left_mask = 32'b00000000000000111111111111111111;
            5'h12: left_mask = 32'b00000000000001111111111111111111;
            5'h13: left_mask = 32'b00000000000011111111111111111111;
            5'h14: left_mask = 32'b00000000000111111111111111111111;
            5'h15: left_mask = 32'b00000000001111111111111111111111;
            5'h16: left_mask = 32'b00000000011111111111111111111111;
            5'h17: left_mask = 32'b00000000111111111111111111111111;
            5'h18: left_mask = 32'b00000001111111111111111111111111;
            5'h19: left_mask = 32'b00000011111111111111111111111111;
            5'h1a: left_mask = 32'b00000111111111111111111111111111;
            5'h1b: left_mask = 32'b00001111111111111111111111111111;
            5'h1c: left_mask = 32'b00011111111111111111111111111111;
            5'h1d: left_mask = 32'b00111111111111111111111111111111;
            5'h1e: left_mask = 32'b01111111111111111111111111111111;
            5'h1f: left_mask = 32'b11111111111111111111111111111111;
        endcase
    end

always @(*)
    begin
        case (right_mask_in)
            5'h00: right_mask = 16'b11111111111111111111111111111111;
            5'h01: right_mask = 16'b11111111111111111111111111111110;
            5'h02: right_mask = 16'b11111111111111111111111111111100;
            5'h03: right_mask = 16'b11111111111111111111111111111000;
            5'h04: right_mask = 16'b11111111111111111111111111110000;
            5'h05: right_mask = 16'b11111111111111111111111111100000;
            5'h06: right_mask = 16'b11111111111111111111111111000000;
            5'h07: right_mask = 16'b11111111111111111111111110000000;
            5'h08: right_mask = 16'b11111111111111111111111100000000;
            5'h09: right_mask = 16'b11111111111111111111111000000000;
            5'h0a: right_mask = 16'b11111111111111111111110000000000;
            5'h0b: right_mask = 16'b11111111111111111111100000000000;
            5'h0c: right_mask = 16'b11111111111111111111000000000000;
            5'h0d: right_mask = 16'b11111111111111111110000000000000;
            5'h0e: right_mask = 16'b11111111111111111100000000000000;
            5'h0f: right_mask = 16'b11111111111111111000000000000000;
            5'h10: right_mask = 16'b11111111111111110000000000000000;
            5'h11: right_mask = 16'b11111111111111100000000000000000;
            5'h12: right_mask = 16'b11111111111111000000000000000000;
            5'h13: right_mask = 16'b11111111111110000000000000000000;
            5'h14: right_mask = 16'b11111111111100000000000000000000;
            5'h15: right_mask = 16'b11111111111000000000000000000000;
            5'h16: right_mask = 16'b11111111110000000000000000000000;
            5'h17: right_mask = 16'b11111111100000000000000000000000;
            5'h18: right_mask = 16'b11111111000000000000000000000000;
            5'h19: right_mask = 16'b11111110000000000000000000000000;
            5'h1a: right_mask = 16'b11111100000000000000000000000000;
            5'h1b: right_mask = 16'b11111000000000000000000000000000;
            5'h1c: right_mask = 16'b11110000000000000000000000000000;
            5'h1d: right_mask = 16'b11100000000000000000000000000000;
            5'h1e: right_mask = 16'b11000000000000000000000000000000;
            5'h1f: right_mask = 16'b10000000000000000000000000000000;
        endcase
    end

assign mask = left_mask & right_mask;

always @(*)
    begin
        case (alu_src_reg_in)
            3'b000: src_reg =  A;//{ A[15],A[14],A[13],A[12],A[11],A[10],A[ 9],A[ 8],
                                 //A[ 7],A[ 6],A[ 5],A[ 4],A[ 3],A[ 2],A[ 1],A[ 0] };
            3'b001: src_reg =  B;//{ B[15],B[14],B[13],B[12],B[11],B[10],B[ 9],B[ 8],  
                                 //B[ 7],B[ 6],B[ 5],B[ 4],B[ 3],B[ 2],B[ 1],B[ 0] };
            3'b010: src_reg =  C;//{ C[15],C[14],C[13],C[12],C[11],C[10],C[ 9],C[ 8],
                                 //C[ 7],C[ 6],C[ 5],C[ 4],C[ 3],C[ 2],C[ 1],C[ 0] };
            3'b011: src_reg =  D;//{ D[15],D[14],D[13],D[12],D[11],D[10],D[ 9],D[ 8],
                                 //D[ 7],D[ 6],D[ 5],D[ 4],D[ 3],D[ 2],D[ 1],D[ 0] };
            3'b100: src_reg = 128'h0;
            3'b101: src_reg = { mask[14] ? { 3'h0, forced_carry_in }:4'h9, // decimal
                                mask[13] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[12] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[11] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[10] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 9] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 8] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 7] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 6] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 5] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 4] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 3] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 2] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 1] ? { 3'h0, forced_carry_in }:4'h9,
                                mask[ 0] ? { 3'h0, forced_carry_in }:4'h9,  
                                              forced_carry_in ? 4'h1:4'h9 };
            3'b101: src_reg = { mask[14] ? { 3'h0, forced_carry_in }:4'hf, // hex
                                mask[13] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[12] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[11] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[10] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 9] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 8] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 7] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 6] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 5] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 4] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 3] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 2] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 1] ? { 3'h0, forced_carry_in }:4'hf,
                                mask[ 0] ? { 3'h0, forced_carry_in }:4'hf,  
                                              forced_carry_in ? 4'h1:4'hf };
        endcase
    end
    
always @(*)
    begin
        case (alu_dest_reg_in)
            2'b00: dest_reg = A;//{ A[15],A[14],A[13],A[12],A[11],A[10],A[ 9],A[ 8],
                                //A[ 7],A[ 6],A[ 5],A[ 4],A[ 3],A[ 2],A[ 1],A[ 0] };
            2'b01: dest_reg = B;//{ B[15],B[14],B[13],B[12],B[11],B[10],B[ 9],B[ 8],  
                                //B[ 7],B[ 6],B[ 5],B[ 4],B[ 3],B[ 2],B[ 1],B[ 0] };
            2'b10: dest_reg = C;//{ C[15],C[14],C[13],C[12],C[11],C[10],C[ 9],C[ 8],
                                //C[ 7],C[ 6],C[ 5],C[ 4],C[ 3],C[ 2],C[ 1],C[ 0] };
            2'b11: dest_reg = D;//{ D[15],D[14],D[13],D[12],D[11],D[10],D[ 9],D[ 8],
                                //D[ 7],D[ 6],D[ 5],D[ 4],D[ 3],D[ 2],D[ 1],D[ 0] };
        endcase
    end

assign masked_src_reg = { mask[31] ? src_reg[127:124]:4'h0,
                          mask[30] ? src_reg[123:120]:4'h0,  
                          mask[29] ? src_reg[119:116]:4'h0,  
                          mask[28] ? src_reg[115:112]:4'h0,  
                          mask[27] ? src_reg[111:108]:4'h0,  
                          mask[26] ? src_reg[107:104]:4'h0,  
                          mask[25] ? src_reg[103:100]:4'h0,  
                          mask[24] ? src_reg[ 99: 96]:4'h0,  
                          mask[23] ? src_reg[ 95: 92]:4'h0,  
                          mask[22] ? src_reg[ 91: 88]:4'h0,  
                          mask[21] ? src_reg[ 87: 84]:4'h0,  
                          mask[20] ? src_reg[ 83: 80]:4'h0,  
                          mask[19] ? src_reg[ 79: 76]:4'h0,  
                          mask[18] ? src_reg[ 75: 72]:4'h0,  
                          mask[17] ? src_reg[ 71: 68]:4'h0,  
                          mask[16] ? src_reg[ 67: 64]:4'h0,
                          mask[15] ? src_reg[ 63: 60]:4'h0,
                          mask[14] ? src_reg[ 59: 56]:4'h0,  
                          mask[13] ? src_reg[ 55: 52]:4'h0,  
                          mask[12] ? src_reg[ 51: 48]:4'h0,  
                          mask[11] ? src_reg[ 47: 44]:4'h0,  
                          mask[10] ? src_reg[ 43: 40]:4'h0,  
                          mask[ 9] ? src_reg[ 39: 36]:4'h0,  
                          mask[ 8] ? src_reg[ 35: 32]:4'h0,  
                          mask[ 7] ? src_reg[ 31: 28]:4'h0,  
                          mask[ 6] ? src_reg[ 27: 24]:4'h0,  
                          mask[ 5] ? src_reg[ 23: 20]:4'h0,  
                          mask[ 4] ? src_reg[ 19: 16]:4'h0,  
                          mask[ 3] ? src_reg[ 15: 12]:4'h0,  
                          mask[ 2] ? src_reg[ 11:  8]:4'h0,  
                          mask[ 1] ? src_reg[  7:  4]:4'h0,  
                          mask[ 0] ? src_reg[  3:  0]:4'h0 };
                          
assign masked_dst_reg = { mask[31] ? dst_reg[127:124]:4'h0,
                          mask[30] ? dst_reg[123:120]:4'h0,  
                          mask[29] ? dst_reg[119:116]:4'h0,  
                          mask[28] ? dst_reg[115:112]:4'h0,  
                          mask[27] ? dst_reg[111:108]:4'h0,  
                          mask[26] ? dst_reg[107:104]:4'h0,  
                          mask[25] ? dst_reg[103:100]:4'h0,  
                          mask[24] ? dst_reg[ 99: 96]:4'h0,  
                          mask[23] ? dst_reg[ 95: 92]:4'h0,  
                          mask[22] ? dst_reg[ 91: 88]:4'h0,  
                          mask[21] ? dst_reg[ 87: 84]:4'h0,  
                          mask[20] ? dst_reg[ 83: 80]:4'h0,  
                          mask[19] ? dst_reg[ 79: 76]:4'h0,  
                          mask[18] ? dst_reg[ 75: 72]:4'h0,  
                          mask[17] ? dst_reg[ 71: 68]:4'h0,  
                          mask[16] ? dst_reg[ 67: 64]:4'h0,
                          mask[15] ? dst_reg[ 63: 60]:4'h0,
                          mask[14] ? dst_reg[ 59: 56]:4'h0,  
                          mask[13] ? dst_reg[ 55: 52]:4'h0,  
                          mask[12] ? dst_reg[ 51: 48]:4'h0,  
                          mask[11] ? dst_reg[ 47: 44]:4'h0,  
                          mask[10] ? dst_reg[ 43: 40]:4'h0,  
                          mask[ 9] ? dst_reg[ 39: 36]:4'h0,  
                          mask[ 8] ? dst_reg[ 35: 32]:4'h0,  
                          mask[ 7] ? dst_reg[ 31: 28]:4'h0,  
                          mask[ 6] ? dst_reg[ 27: 24]:4'h0,  
                          mask[ 5] ? dst_reg[ 23: 20]:4'h0,  
                          mask[ 4] ? dst_reg[ 19: 16]:4'h0,  
                          mask[ 3] ? dst_reg[ 15: 12]:4'h0,  
                          mask[ 2] ? dst_reg[ 11:  8]:4'h0,  
                          mask[ 1] ? dst_reg[  7:  4]:4'h0,  
                          mask[ 0] ? dst_reg[  3:  0]:4'h0 };

assign data_o = masked_src_reg;
                          
always @(posedge clk_in)
    begin
        if (latch_alu_regs_in)
            begin
                latched_src_reg <= masked_src_reg;
                latched_dst_reg <= masked_dst_reg;
            end
    end

wire [127:0] add_q, sub_q, rsub_q;
reg [127:0] alu_q;
wire add_qc, sub_qc, rsub_qc;
wire [15:0] no_src_zero_nibs;

pneptune_addbcd64  add64(latched_src_reg,  latched_dst_reg, decimal_in, left_mask_in, right?mask?in,  add_q,  add_qc);    
pneptune_subbcd64  sub64(latched_src_reg,  latched_dst_reg, decimal_in, left_mask_in, right?mask?in,  sub_q,  sub_qc);    
pneptune_subbcd64 rsub64(latched_dst_reg,  latched_src_reg, decimal_in, left_mask_in, right?mask?in, rsub_q, rsub_qc);        
    
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
    
always @(*)    
    begin
        case (alu_dest_mux_in)
            3'b000: // alu output
                case (alu_op_in)
                    4'h0: alu_q = add_q;
                    4'h1: alu_q = sub_q;
                    4'h2: alu_q = rsub_q;
                    4'h3: begin end // CMP
                    4'h4: alu_q = latched_src_reg & latched_dest_reg;
                    4'h5: alu_q = latched_src_reg | latched_dest_reg;
                    4'h6: alu_q = latched_src_reg << 4;
                    4'h7: alu_q = latched_src_reg >> 4;
                endcase
            3'b001: // pass-through
                alu_q = latched_src_reg;
            3'b010: // data_in
                alu_q = data_in;
            3'b011: // extra reg
                alu_q = R[extra_reg_in];
        endcase
    end
    
always @(*)    
    begin
        case (alu_dest_mux_in)
            3'b000: // alu output
                case (alu_op_in)
                    4'h0: carry_o = add_qc;
                    4'h1: carry_o = sub_qc;
                    4'h2: carry_o = rsub_qc;
                    4'h3: carry_o = rsub_qc;
                    4'h4: carry_o = 1'b0;
                    4'h5: carry_o = 1'b0;
                    4'h6: carry_o = no_src_zero_nibs[left_mask_in];
                    4'h7: carry_o = no_src_zero_nibs[right_mask_in];
                endcase
            3'b001: // pass-through
                carry_o = 1'b0;
            3'b010: // data_in
                carry_o = 1'b0;
            3'b011: // extra reg
                carry_o = 1'b0;
        endcase
    end
                          
always @(posedge clk_in)
    begin
        if (write_alu_dest_in)
            begin
                case (alu_dest_reg_in)
                    2'b00: 
                        begin
                            if (mask[31]) A[127:124] <= alu_q[127:124];
                            if (mask[30]) A[123:120] <= alu_q[123:120];
                            if (mask[29]) A[119:116] <= alu_q[119:116];
                            if (mask[28]) A[115:112] <= alu_q[115:112];
                            if (mask[27]) A[111:108] <= alu_q[111:108];
                            if (mask[26]) A[107:104] <= alu_q[107:104];
                            if (mask[25]) A[103:100] <= alu_q[103:100];
                            if (mask[24]) A[ 99: 96] <= alu_q[ 99: 96];
                            if (mask[23]) A[ 95: 92] <= alu_q[ 95: 92];
                            if (mask[22]) A[ 91: 88] <= alu_q[ 91: 88];
                            if (mask[21]) A[ 87: 84] <= alu_q[ 87: 84];
                            if (mask[20]) A[ 83: 80] <= alu_q[ 83: 80];
                            if (mask[19]) A[ 79: 76] <= alu_q[ 79: 76];
                            if (mask[18]) A[ 75: 72] <= alu_q[ 75: 72];
                            if (mask[17]) A[ 71: 68] <= alu_q[ 71: 68];
                            if (mask[16]) A[ 67: 64] <= alu_q[ 67: 64];
                            if (mask[15]) A[ 63: 60] <= alu_q[ 63: 60];
                            if (mask[14]) A[ 59: 56] <= alu_q[ 59: 56];
                            if (mask[13]) A[ 55: 52] <= alu_q[ 55: 52];
                            if (mask[12]) A[ 51: 48] <= alu_q[ 51: 48];
                            if (mask[11]) A[ 47: 44] <= alu_q[ 47: 44];
                            if (mask[10]) A[ 43: 40] <= alu_q[ 43: 40];
                            if (mask[ 9]) A[ 39: 36] <= alu_q[ 39: 36];
                            if (mask[ 8]) A[ 35: 32] <= alu_q[ 35: 32];
                            if (mask[ 7]) A[ 31: 28] <= alu_q[ 31: 28];
                            if (mask[ 6]) A[ 27: 24] <= alu_q[ 27: 24];
                            if (mask[ 5]) A[ 23: 20] <= alu_q[ 23: 20];
                            if (mask[ 4]) A[ 19: 16] <= alu_q[ 19: 16];
                            if (mask[ 3]) A[ 15: 12] <= alu_q[ 15: 12];
                            if (mask[ 2]) A[ 11:  8] <= alu_q[ 11:  8];
                            if (mask[ 1]) A[  7:  4] <= alu_q[  7:  4];
                            if (mask[ 0]) A[  3:  0] <= alu_q[  3:  0];
                        end
                    2'b01: 
                        begin
                            if (mask[31]) B[127:124] <= alu_q[127:124];
                            if (mask[30]) B[123:120] <= alu_q[123:120];
                            if (mask[29]) B[119:116] <= alu_q[119:116];
                            if (mask[28]) B[115:112] <= alu_q[115:112];
                            if (mask[27]) B[111:108] <= alu_q[111:108];
                            if (mask[26]) B[107:104] <= alu_q[107:104];
                            if (mask[25]) B[103:100] <= alu_q[103:100];
                            if (mask[24]) B[ 99: 96] <= alu_q[ 99: 96];
                            if (mask[23]) B[ 95: 92] <= alu_q[ 95: 92];
                            if (mask[22]) B[ 91: 88] <= alu_q[ 91: 88];
                            if (mask[21]) B[ 87: 84] <= alu_q[ 87: 84];
                            if (mask[20]) B[ 83: 80] <= alu_q[ 83: 80];
                            if (mask[19]) B[ 79: 76] <= alu_q[ 79: 76];
                            if (mask[18]) B[ 75: 72] <= alu_q[ 75: 72];
                            if (mask[17]) B[ 71: 68] <= alu_q[ 71: 68];
                            if (mask[16]) B[ 67: 64] <= alu_q[ 67: 64];
                            if (mask[15]) B[ 63: 60] <= alu_q[ 63: 60];
                            if (mask[14]) B[ 59: 56] <= alu_q[ 59: 56];
                            if (mask[13]) B[ 55: 52] <= alu_q[ 55: 52];
                            if (mask[12]) B[ 51: 48] <= alu_q[ 51: 48];
                            if (mask[11]) B[ 47: 44] <= alu_q[ 47: 44];
                            if (mask[10]) B[ 43: 40] <= alu_q[ 43: 40];
                            if (mask[ 9]) B[ 39: 36] <= alu_q[ 39: 36];
                            if (mask[ 8]) B[ 35: 32] <= alu_q[ 35: 32];
                            if (mask[ 7]) B[ 31: 28] <= alu_q[ 31: 28];
                            if (mask[ 6]) B[ 27: 24] <= alu_q[ 27: 24];
                            if (mask[ 5]) B[ 23: 20] <= alu_q[ 23: 20];
                            if (mask[ 4]) B[ 19: 16] <= alu_q[ 19: 16];
                            if (mask[ 3]) B[ 15: 12] <= alu_q[ 15: 12];
                            if (mask[ 2]) B[ 11:  8] <= alu_q[ 11:  8];
                            if (mask[ 1]) B[  7:  4] <= alu_q[  7:  4];
                            if (mask[ 0]) B[  3:  0] <= alu_q[  3:  0];
                        end
                    2'b10: 
                        begin
                            if (mask[31]) C[127:124] <= alu_q[127:124];
                            if (mask[30]) C[123:120] <= alu_q[123:120];
                            if (mask[29]) C[119:116] <= alu_q[119:116];
                            if (mask[28]) C[115:112] <= alu_q[115:112];
                            if (mask[27]) C[111:108] <= alu_q[111:108];
                            if (mask[26]) C[107:104] <= alu_q[107:104];
                            if (mask[25]) C[103:100] <= alu_q[103:100];
                            if (mask[24]) C[ 99: 96] <= alu_q[ 99: 96];
                            if (mask[23]) C[ 95: 92] <= alu_q[ 95: 92];
                            if (mask[22]) C[ 91: 88] <= alu_q[ 91: 88];
                            if (mask[21]) C[ 87: 84] <= alu_q[ 87: 84];
                            if (mask[20]) C[ 83: 80] <= alu_q[ 83: 80];
                            if (mask[19]) C[ 79: 76] <= alu_q[ 79: 76];
                            if (mask[18]) C[ 75: 72] <= alu_q[ 75: 72];
                            if (mask[17]) C[ 71: 68] <= alu_q[ 71: 68];
                            if (mask[16]) C[ 67: 64] <= alu_q[ 67: 64];
                            if (mask[15]) C[ 63: 60] <= alu_q[ 63: 60];
                            if (mask[14]) C[ 59: 56] <= alu_q[ 59: 56];
                            if (mask[13]) C[ 55: 52] <= alu_q[ 55: 52];
                            if (mask[12]) C[ 51: 48] <= alu_q[ 51: 48];
                            if (mask[11]) C[ 47: 44] <= alu_q[ 47: 44];
                            if (mask[10]) C[ 43: 40] <= alu_q[ 43: 40];
                            if (mask[ 9]) C[ 39: 36] <= alu_q[ 39: 36];
                            if (mask[ 8]) C[ 35: 32] <= alu_q[ 35: 32];
                            if (mask[ 7]) C[ 31: 28] <= alu_q[ 31: 28];
                            if (mask[ 6]) C[ 27: 24] <= alu_q[ 27: 24];
                            if (mask[ 5]) C[ 23: 20] <= alu_q[ 23: 20];
                            if (mask[ 4]) C[ 19: 16] <= alu_q[ 19: 16];
                            if (mask[ 3]) C[ 15: 12] <= alu_q[ 15: 12];
                            if (mask[ 2]) C[ 11:  8] <= alu_q[ 11:  8];
                            if (mask[ 1]) C[  7:  4] <= alu_q[  7:  4];
                            if (mask[ 0]) C[  3:  0] <= alu_q[  3:  0];
                        end
                    2'b11: 
                        begin
                            if (mask[31]) D[127:124] <= alu_q[127:124];
                            if (mask[30]) D[123:120] <= alu_q[123:120];
                            if (mask[29]) D[119:116] <= alu_q[119:116];
                            if (mask[28]) D[115:112] <= alu_q[115:112];
                            if (mask[27]) D[111:108] <= alu_q[111:108];
                            if (mask[26]) D[107:104] <= alu_q[107:104];
                            if (mask[25]) D[103:100] <= alu_q[103:100];
                            if (mask[24]) D[ 99: 96] <= alu_q[ 99: 96];
                            if (mask[23]) D[ 95: 92] <= alu_q[ 95: 92];
                            if (mask[22]) D[ 91: 88] <= alu_q[ 91: 88];
                            if (mask[21]) D[ 87: 84] <= alu_q[ 87: 84];
                            if (mask[20]) D[ 83: 80] <= alu_q[ 83: 80];
                            if (mask[19]) D[ 79: 76] <= alu_q[ 79: 76];
                            if (mask[18]) D[ 75: 72] <= alu_q[ 75: 72];
                            if (mask[17]) D[ 71: 68] <= alu_q[ 71: 68];
                            if (mask[16]) D[ 67: 64] <= alu_q[ 67: 64];
                            if (mask[15]) D[ 63: 60] <= alu_q[ 63: 60];
                            if (mask[14]) D[ 59: 56] <= alu_q[ 59: 56];
                            if (mask[13]) D[ 55: 52] <= alu_q[ 55: 52];
                            if (mask[12]) D[ 51: 48] <= alu_q[ 51: 48];
                            if (mask[11]) D[ 47: 44] <= alu_q[ 47: 44];
                            if (mask[10]) D[ 43: 40] <= alu_q[ 43: 40];
                            if (mask[ 9]) D[ 39: 36] <= alu_q[ 39: 36];
                            if (mask[ 8]) D[ 35: 32] <= alu_q[ 35: 32];
                            if (mask[ 7]) D[ 31: 28] <= alu_q[ 31: 28];
                            if (mask[ 6]) D[ 27: 24] <= alu_q[ 27: 24];
                            if (mask[ 5]) D[ 23: 20] <= alu_q[ 23: 20];
                            if (mask[ 4]) D[ 19: 16] <= alu_q[ 19: 16];
                            if (mask[ 3]) D[ 15: 12] <= alu_q[ 15: 12];
                            if (mask[ 2]) D[ 11:  8] <= alu_q[ 11:  8];
                            if (mask[ 1]) D[  7:  4] <= alu_q[  7:  4];
                            if (mask[ 0]) D[  3:  0] <= alu_q[  3:  0];
                        end
            endcase
		end
    end

always @(posedge clk_in)
    begin
        if (write_extra_dest_in)
            R[extra_reg_in] <= masked_src_reg; // transfer or exchange
    end

endmodule


module pneptune_addbcd64(
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

pneptune_addbcd a0 (a_in[ 3: 0], b_in[ 3: 0],        f0, dec_in, q_out[ 3: 0], c0);
pneptune_addbcd a1 (a_in[ 7: 4], b_in[ 7: 4],   c0 | f1, dec_in, q_out[ 7: 4], c1);
pneptune_addbcd a2 (a_in[11: 8], b_in[11: 8],   c1 | f2, dec_in, q_out[11: 8], c2);
pneptune_addbcd a3 (a_in[15:12], b_in[15:12],   c2 | f3, dec_in, q_out[15:12], c3);
pneptune_addbcd a4 (a_in[19:16], b_in[19:16],   c3 | f4, dec_in, q_out[19:16], c4);
pneptune_addbcd a5 (a_in[23:20], b_in[23:20],   c4 | f5, dec_in, q_out[23:20], c5);
pneptune_addbcd a6 (a_in[27:24], b_in[27:24],   c5 | f6, dec_in, q_out[27:24], c6);
pneptune_addbcd a7 (a_in[31:28], b_in[31:28],   c6 | f7, dec_in, q_out[31:28], c7);
pneptune_addbcd a8 (a_in[35:32], b_in[35:32],   c7 | f8, dec_in, q_out[35:32], c8);
pneptune_addbcd a9 (a_in[39:36], b_in[39:36],   c8 | f9, dec_in, q_out[39:36], c9);
pneptune_addbcd aa (a_in[43:40], b_in[43:40],   c9 | fa, dec_in, q_out[43:40], ca);
pneptune_addbcd ab (a_in[47:44], b_in[47:44],   ca | fb, dec_in, q_out[47:44], cb);
pneptune_addbcd ac (a_in[51:48], b_in[51:48],   cb | fc, dec_in, q_out[51:48], cc);
pneptune_addbcd ad (a_in[55:52], b_in[55:52],   cc | fd, dec_in, q_out[55:52], cd);
pneptune_addbcd ae (a_in[59:56], b_in[59:56],   cd | fe, dec_in, q_out[59:56], ce);
pneptune_addbcd af (a_in[63:60], b_in[63:60],   ce | ff, dec_in, q_out[63:60], cf);

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


module pneptune_subbcd64(
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

pneptune_subbcd s0 (a_in[ 3: 0], b_in[ 3: 0],        f0, dec_in, q_out[ 3: 0], c0);
pneptune_subbcd s1 (a_in[ 7: 4], b_in[ 7: 4],   c0 | f1, dec_in, q_out[ 7: 4], c1);
pneptune_subbcd s2 (a_in[11: 8], b_in[11: 8],   c1 | f2, dec_in, q_out[11: 8], c2);
pneptune_subbcd s3 (a_in[15:12], b_in[15:12],   c2 | f3, dec_in, q_out[15:12], c3);
pneptune_subbcd s4 (a_in[19:16], b_in[19:16],   c3 | f4, dec_in, q_out[19:16], c4);
pneptune_subbcd s5 (a_in[23:20], b_in[23:20],   c4 | f5, dec_in, q_out[23:20], c5);
pneptune_subbcd s6 (a_in[27:24], b_in[27:24],   c5 | f6, dec_in, q_out[27:24], c6);
pneptune_subbcd s7 (a_in[31:28], b_in[31:28],   c6 | f7, dec_in, q_out[31:28], c7);
pneptune_subbcd s8 (a_in[35:32], b_in[35:32],   c7 | f8, dec_in, q_out[35:32], c8);
pneptune_subbcd s9 (a_in[39:36], b_in[39:36],   c8 | f9, dec_in, q_out[39:36], c9);
pneptune_subbcd sa (a_in[43:40], b_in[43:40],   c9 | fa, dec_in, q_out[43:40], ca);
pneptune_subbcd sb (a_in[47:44], b_in[47:44],   ca | fb, dec_in, q_out[47:44], cb);
pneptune_subbcd sc (a_in[51:48], b_in[51:48],   cb | fc, dec_in, q_out[51:48], cc);
pneptune_subbcd sd (a_in[55:52], b_in[55:52],   cc | fd, dec_in, q_out[55:52], cd);
pneptune_subbcd se (a_in[59:56], b_in[59:56],   cd | fe, dec_in, q_out[59:56], ce);
pneptune_subbcd sf (a_in[63:60], b_in[63:60],   ce | ff, dec_in, q_out[63:60], cf);

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

module pneptune_addbcd(
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
wire a_p_b_p_c_c;

assign a_plus_b_plus_c = { 1'b0, a_in } + { 1'b0, b_in } + { 4'h0, c_in };
assign qc_out = dec_in ? (a_plus_b_plus_c > 5'h09):a_plus_b_plus_c[4];
assign q_out = dec_in ? (qc_out == 1'b1 ? a_plus_b_plus_c[3:0] + 4'h6:a_plus_b_plus_c[3:0]):a_plus_b_plus_c[3:0];

endmodule


module pneptune_subbcd(
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

wire [3:0] c9, a_m_b_s1;
wire [4:0] sub;
assign sub = { 1'b0, a_in } - { 1'b0, b_in } - { 4'b0, c_in };
assign c9 = sub[4] ? sub[3:0] - 4'h6:sub[3:0];
assign qc_out = dec_in ? (sub[4:0] > 5'h0a):sub[4];
assign q_out = dec_in ? c9:sub[3:0];

endmodule