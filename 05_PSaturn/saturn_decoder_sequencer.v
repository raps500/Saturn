/* Parallel Saturn - decoders and sequencer
 * A whole fetched opcode is presented together with
 * the assertion of ibus_ready_in
 * Decode and sequencing
 *
 *
 * masks are inclusive !
 */
`include "saturn_defs.v"


module saturn_decoder_sequencer(
    input wire           clk_in,
	input wire           reset_in,
    input wire           irq_in,
    input wire           irqen_in,       // flag for interrupt enable
    output wire          irq_ack_o,
    //
    output wire          showregs_o,
    // Fetch Bus interface
    output wire [19:0]   ibus_addr_o,    // fetch address
    output wire          ibus_flush_q_o,// force flush the queue
    output wire          ibus_fetch_o,  // fetch strobe, asserted for every new requested fetch
    output wire          ibus_fetch_ack_o,// fetch acknowledged
    //output wire [4:0]   ibus_size_in,    // size of last instruction in nibbles
    input wire [83:0]    ibus_pre_fetched_opcode_in,// pre-fetch buffer 21 nibbles long
    input wire [ 4:0]    ibus_pre_fetched_opcode_length_in,    // valid nibbles
    input wire [19:0]    ibus_pre_fetched_opcode_addr_in,      // address of the prefetched bytes
    input wire           ibus_ready_in,   // asserted when the pre-fetch buffer is full
    // Memory read/write
    output wire          data_write_o,
    output wire          data_read_o,
    input wire           read_write_ready_in,
    // ALRU Control
    output wire          write_dst_o,       // write back the alu operation/memory dat or extra register to the destination register
    output wire          write_op1_o,       // write from alu register to extra register
	output wire			 latch_alu_regs_o,	// latch the masked input arguments to the alu
    output wire          forced_carry_o,    // force carry set
    output wire          forced_hex_o,      // force hex mode
    output reg [5:0]     op1_reg_o,         // register  for op1
    output reg [5:0]     op2_reg_o,         // OP2
    output reg [5:0]     dst_reg_o,         // DST register, ST bit register for clr/test/set
    output wire [63:0]   op_literal_o,      // literal from opcode
    output wire          set_decimal_o,     // set decimal mode
    output wire          set_hexadecimal_o, // set hexadecimal mode
    output reg [3:0]     left_mask_o,       // read/write mask
    output reg [3:0]     right_mask_o,
    output wire[4:0]     alu_op_o,          // alu operation
    output wire [19:0]   addr_o,            // address as argument for PC, Dn operations
    output wire          write_sticky_bit_o,// Writes the sticky bit with the contents of the shifted bit/nib
    output wire          write_carry_o,     // write ALU carry to carry
    output wire          clr_carry_o,       // carry clear
    output wire          set_carry_o,       // carry set
    input wire           carry_in,          // arithmetic carry
    output wire          shift_alu_q_o,     // alu_q and op2 shift before storing in P
    input wire [ 3:0]    reg_P_in,          // actual P register
    output wire          add_pc_o,          // increment PC one nibble
    output wire          load_pc_o,         // load PC
    output wire          push_rstk_o,       // push onto the stack
    output wire          pull_rstk_o,       // pull from stack
    input wire [19:0]    PC_in
`ifdef HAS_TRACE_UNIT
    ,
    output wire         trace_start_o,
    input wire          trace_end_in
`endif
    );

reg [3:0] state = `ST_INIT;
reg [19:0] new_pc_jump = 20'h00000;
reg irq_ack;

// alu control
reg force_carry;    // force carry set for A=A+1, A=A-1, P=P+1, ...
reg force_hex;      // for Dn=Dn+CON

reg write_dst = 1'b0;
reg write_op1 = 1'b0;
reg write_sticky_bit = 1'b0;
reg write_carry = 1'b0;
reg push_rstk = 1'b0;
reg pull_rstk = 1'b0;

wire [2:0] op_field_left;
wire [5:0] op_alu_reg1;
wire [5:0] op_alu_reg2;
wire [5:0] op_alu_dst;
wire [4:0] op_alu_op;
reg [4:0] alu_op;   // latched ALU Operation
// Bus controller i/o

reg ibus_flush_q = 1'b0;
reg ibus_fetch = 1'b0;
reg ibus_fetch_ack = 1'b0;

// Decoding
wire [3:0] op0, op1, op2, op3, op4, op5, op6;
wire op_goc, op_gonc, op_jrel3, op_jrel4, op_govlng;
wire op_gosub, op_gosubl, op_gosbvl;

wire [19:0] ofs_pc_rel2, ofs_pc_rel3, ofs_pc_rel4, new_pc_abs;
wire [19:0] ofs_pc_rel2_ab;

wire op_setdec, op_sethex, op_uncnfg, op_config, op_shutdn;
wire op_intoff, op_inton, op_reset;
wire op_is_lc, op_is_la;
wire op_is_let_ex_cp;
wire op_rw_with_lit_size; // DAT0=A/C n DAT1=A/C n A/C=DAT0 n A/C=DAT1 n used to select op3 as field_end
wire op_alu_and_rtn_on_cs;
wire op_rti;
wire op_rtn;
wire op_rtn_on_carry_clr;
wire op_rtn_on_carry_set;
wire op_set_xm, op_set_carry;
wire op_clr_carry;
wire op_push_ac;
wire op_pull_ac;
wire [2:0] field;
wire [3:0] field_decoded_right, field_decoded_left;

// Lireal extraction from OPCODE
wire op_is_A_A_PM_CON; // A=A+CON, C=C-CON
wire op_is_Dn_P_CON; // D0=D0+CON, D1=D1-CON
wire op_is_load_Dn; // D0=hhh D1=hhhhh
wire op_is_ACBIT; // ABIT=0/1 ?CBIT=0/1
wire op_is_STBIT; // ST=x ?ST
wire op_is_HSBIT; // HS=0 ?HS
wire op_8_1_89A; // field is in op4
wire op_forced_carry;
wire op_forced_hex;
wire op_is_P_CNT; // P=n
wire op_is_QP_CNT; // ?P
wire op_is_P_INC_DEC; // P=P-1 P=P+1

wire op_is_MEM_RD; // Any read memory opcode
wire op_is_MEM_WR; // Any write memory opcode
wire op_pc_ind_ac; // PC=(A) PC=(C)

wire op_goto_on_acbit; // ?ABIT & ?CBIT
wire op_goto_on_cond_true;  // ?HS ?ST ?P ?A ?B ?C ?D
wire op_write_sticky;
wire op_write_dst;
wire op_write_carry;

wire op0_0, op0_1, op0_2, op0_3, op0_4, op0_5, op0_6, op0_7, op0_8, op0_9, op0_A, op0_B, op0_C, op0_D, op0_E, op0_F;
wire op1_0, op1_1, op1_2, op1_3, op1_4, op1_5, op1_6, op1_7, op1_8, op1_9, op1_A, op1_B, op1_C, op1_D, op1_E, op1_F;
wire op2_0, op2_1, op2_2, op2_3, op2_4, op2_5, op2_6, op2_7, op2_8, op2_9, op2_A, op2_B, op2_C, op2_D, op2_E, op2_F;
wire op3_0, op3_1, op3_2, op3_3, op3_4, op3_5, op3_6, op3_7, op3_8, op3_9, op3_A, op3_B, op3_C, op3_D, op3_E, op3_F;

wire [63:0] ascii_opcode;
// Trace
reg trace_start;
// literal from opcode
reg [63:0] op_literal;

// Pre-decode

assign op0 = ibus_pre_fetched_opcode_in[ 3: 0];
assign op1 = ibus_pre_fetched_opcode_in[ 7: 4];
assign op2 = ibus_pre_fetched_opcode_in[11: 8];
assign op3 = ibus_pre_fetched_opcode_in[15:12];
assign op4 = ibus_pre_fetched_opcode_in[19:16];
assign op5 = ibus_pre_fetched_opcode_in[23:20];
assign op6 = ibus_pre_fetched_opcode_in[27:24];

saturn_microcode mc(
    .clk_in(clk_in),
    .rom_en_in(state == `ST_INIT),
    .op0(op0),
    .op1(op1),
    .op2(op2),
    .op3(op3),
    .op4(op4),
    .op5(op5),
    .op_goto_on_cond_true(op_goto_on_cond_true),
    .op_abit            (op_goto_on_acbit),
    .op_write_sticky    (op_write_sticky),
    .op_write_dst       (op_write_dst),
    .op_write_carry     (op_write_carry),
    .op_forced_hex      (op_forced_hex),
    .op_forced_carry    (op_forced_carry),
    .op_field_left      (op_field_left ),
    .op_alu_reg1        (op_alu_reg1   ),
    .op_alu_reg2        (op_alu_reg2   ),
    .op_alu_dst         (op_alu_dst    ),
    .op_alu_op          (op_alu_op     )
    );

saturn_trace_dis dis(
    .op0(op0),
    .op1(op1),
    .op2(op2),
    .op3(op3),
    .op4(op4),
    .op5(op5),
    .pc_in(ibus_pre_fetched_opcode_addr_in),
    .ascii_opcode_o(ascii_opcode)
    );

assign op0_0 = op0 == 4'h0;
assign op0_1 = op0 == 4'h1;
assign op0_2 = op0 == 4'h2;
assign op0_3 = op0 == 4'h3;
assign op0_4 = op0 == 4'h4;
assign op0_5 = op0 == 4'h5;
assign op0_6 = op0 == 4'h6;
assign op0_7 = op0 == 4'h7;
assign op0_8 = op0 == 4'h8;
assign op0_9 = op0 == 4'h9;
assign op0_A = op0 == 4'hA;
assign op0_B = op0 == 4'hB;
assign op0_C = op0 == 4'hC;
assign op0_D = op0 == 4'hD;
assign op0_E = op0 == 4'hE;
assign op0_F = op0 == 4'hF;

assign op1_0 = op1 == 4'h0;
assign op1_1 = op1 == 4'h1;
assign op1_2 = op1 == 4'h2;
assign op1_3 = op1 == 4'h3;
assign op1_4 = op1 == 4'h4;
assign op1_5 = op1 == 4'h5;
assign op1_6 = op1 == 4'h6;
assign op1_7 = op1 == 4'h7;
assign op1_8 = op1 == 4'h8;
assign op1_9 = op1 == 4'h9;
assign op1_A = op1 == 4'hA;
assign op1_B = op1 == 4'hB;
assign op1_C = op1 == 4'hC;
assign op1_D = op1 == 4'hD;
assign op1_E = op1 == 4'hE;
assign op1_F = op1 == 4'hF;

assign op2_0 = op2 == 4'h0;
assign op2_1 = op2 == 4'h1;
assign op2_2 = op2 == 4'h2;
assign op2_3 = op2 == 4'h3;
assign op2_4 = op2 == 4'h4;
assign op2_5 = op2 == 4'h5;
assign op2_6 = op2 == 4'h6;
assign op2_7 = op2 == 4'h7;
assign op2_8 = op2 == 4'h8;
assign op2_9 = op2 == 4'h9;
assign op2_A = op2 == 4'hA;
assign op2_B = op2 == 4'hB;
assign op2_C = op2 == 4'hC;
assign op2_D = op2 == 4'hD;
assign op2_E = op2 == 4'hE;
assign op2_F = op2 == 4'hF;

assign op3_0 = op3 == 4'h0;
assign op3_1 = op3 == 4'h1;
assign op3_2 = op3 == 4'h2;
assign op3_3 = op3 == 4'h3;
assign op3_4 = op3 == 4'h4;
assign op3_5 = op3 == 4'h5;
assign op3_6 = op3 == 4'h6;
assign op3_7 = op3 == 4'h7;
assign op3_8 = op3 == 4'h8;
assign op3_9 = op3 == 4'h9;
assign op3_A = op3 == 4'hA;
assign op3_B = op3 == 4'hB;
assign op3_C = op3 == 4'hC;
assign op3_D = op3 == 4'hD;
assign op3_E = op3 == 4'hE;
assign op3_F = op3 == 4'hF;

assign op_is_load_Dn = op0_1 & (op1_9 | op1_A | op1_B | op1_D | op1_E | op1_F); // Dn=hh
assign op_is_Dn_P_CON = op0_1 & (op1_6 | op1_7 | op1_8 | op1_C); // D0=D0+CON, D1=D1-CON
assign op_is_A_A_PM_CON = op0_8 & op1_1 & op2_8; // A=A+CON, C=C-CON
assign op_is_ACBIT = op0_8 & op1_0 & op2_8 & (op3_4 | op3_5 | op3_6 | op3_7 | op3_8 | op3_9 | op3_A | op3_B); // ABIT=0/1 ?CBIT=0/1
assign op_is_HSBIT = op0_8 & (op1_2 | op1_3); // HS=0 ?HS
assign op_is_STBIT = op0_8 & (op1_4 | op1_5 | op1_6 | op1_7); // ST=x ?ST

assign op_is_lc = (op0_3); // two literals size in op1 and literal in op2..op17

assign op_is_la = ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h2));
assign op_is_let_ex_cp = (op0_8) && ((op1_0) && ((op2_C) || (op2_D) || 
                                                         (op2_F))); // C=P n P=C n CPEX n
assign op_is_P_CNT = (op0_2); // op1 is literal
assign op_is_QP_CNT = (op0_8) && ((op1_8) || (op1_9)); // op2 is literal
assign op_is_P_INC_DEC = (op0_0) && ((op1_C) || (op1_D)); // to force hex mode

// Indirect jumps need extra care in the state machine
assign op_pc_ind_ac = op0_8 & op1_0 & op2_8 & (op3_C | op3_E); // PC=(A) PC=(C) 

// PC=(C) and PC=(A) use the memory interface too
assign op_is_MEM_RD = op0_1 & (op1_4 | op1_5) & 
                     (op2_2 | op2_3 | op2_6 | op2_7 | op2_A | op2_B | op2_E | op2_F);
assign op_is_MEM_WR = op0_1 & (op1_4 | op1_5) & 
                     (op2_0 | op2_1 | op2_4 | op2_5 | op2_8 | op2_9 | op2_C | op2_D);

// Use forced carry as operand and 0 as operand 2
/*
assign op_forced_carry =
            (op0_0 && (op1_C || op1_D)) || // P=P+/-1
            (op0_8 && op1_0 && op2_9) || // C=C+P+1
            (op0_A && (!op1[3]) && (op2_C || op2_D || op2_E || op2_F)) || // A=A-1
            (op0_B && (!op1[3]) && (op2_4 || op2_5 || op2_6 || op2_7)) || // A=A+1
            (op0_B && ( op1[3]) && (op2_C || op2_D || op2_E || op2_F)) || // A=A+1
            (op0_C && (op1_C || op1_D || op1_E || op1_F)) ||              // A=A+1
            (op0_E && (op1_4 || op1_5 || op1_6 || op1_7));                // A=A+1

// these opcodes need the alu execute path, use either ABCD,RxDx,ST,STK

assign op_is_alu =  ~((op0_0 & (op1_0 | op1_1 | op1_2 | op1_3 | op1_4 | op1_5 | op1_F)) |
                      (op0_4) | // GOC
                      (op0_5) | // GONC
                      (op0_6) | // GOTO
                      //(op0_7) | // GOSUB
                      (op0_8 & op1_0 & (op2_4 | op2_5 | op2_7)) |
                      (op0_8 & op1_0 & op2_8 & (op3_0 | op3_1)) |
                      (op0_8 & op1_0 & op2_8 & op3_F) |
                      (op0_8 & op1_0 & (op2_9 | op2_A | op2_E)) |
                      (op0_8 & (op1_C | op1_D )));// GOLONG GOVLNG GOSUBL GOSBVL

// these opcodes are 7 nibbles long
assign op_goto_on_acbit    = ((op0_8) && ((op1_0) && (op2_8) && (op3_6))) || // ?ABIT
                             ((op0_8) && ((op1_0) && (op2_8) && (op3_6))) || // ?ABIT
                             ((op0_8) && ((op1_0) && (op2_8) && (op3_6))) || // ?CBIT
                             ((op0_8) && ((op1_0) && (op2_8) && (op3_6)));   // ?CBIT
                          
assign op_goto_on_cond_set = ((op0_8) && ((op1_3) || (op1_6) || // ?HS, ?ST
                                          (op1_7) || (op1_8) || (op1_9) || // ?P
                                          (op1_A) || (op1_B))) || // ?A
                             (op0_9); // ?A
*/
assign op_alu_and_rtn_on_cs= (op_goto_on_cond_true && (op3 == 4'h0) && (op4 == 4'h0)) ||
                             (op_goto_on_acbit     && (op5 == 4'h0) && (op6 == 4'h0));
                             
assign op_rtn_on_carry_set = op0_4 & op1_0 & op2_0;
assign op_rtn_on_carry_clr = op0_5 & op1_0 & op2_0;
assign op_rtn              = op0_0 & (op1_0 | op1_1 | op1_2 | op1_3); // RTNSXM, RTN RTNSC RTNCC
assign op_rti              = op0_0 & op1_F; // RTNI

assign op_rw_with_lit_size = (op0_1 && op1_5 && (op2[3] == 1'b1));

assign op_goc   = (op0_4); // GOC
assign op_gonc  = (op0_5); // GONC

assign op_jrel3 = (op0_6); // GOTO

assign op_gosub = (op0_7); // GOSUB

assign op_jrel4 = (op0_8 && op1_C); // GOLONG
assign op_gosubl = (op0_8 && op1_E); // GOSUBL

assign op_govlng = (op0_8) && (op1_D); // GOVLNG
assign op_gosbvl = (op0_8) && (op1_F); // GOSBVL

assign op_push_ac = (op0_0 && op1_6); // RSTK=C

assign op_pull_ac =  (op0_0 && op1_7);

assign op_setdec = (op0_0) && (op1_5);
assign op_sethex = (op0_0) && (op1_4);

assign op_uncnfg = (op0_8) && (op1_0) && (op2_4);
assign op_config = (op0_8) && (op1_0) && (op2_5);
assign op_shutdn = (op0_8) && (op1_0) && (op2_7);
assign op_intoff = (op0_8) && (op1_0) && (op2_8) && (op3 == 4'hF);
assign op_inton  = ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h0)) | ((op0_0) && (op1_F)); // INTON & RTI
assign op_reset  = (op0_8) && (op1_0) && (op2_A);

assign op_set_xm =     ((op0_0) && (op1_0)); // RTNSXM
assign op_set_carry =  ((op0_0) && (op1_2)); // RTNSC
assign op_clr_carry =  ((op0_0) && (op1_3)); // RTNCC

assign ofs_pc_rel2 = op0[3] ? { {12{op4[3]}}, op4, op3 }:{ {12{op2[3]}}, op2, op1 };
assign ofs_pc_rel2_ab = { {12{op6[3]}}, op6, op5 };
assign ofs_pc_rel3 = { {8{op3[3]}}, op3, op2, op1 };
assign ofs_pc_rel4 = { {4{op5[3]}}, op5, op4, op3, op2 };
assign new_pc_abs = ibus_pre_fetched_opcode_in[27: 8];

/* Field decoder */

assign op_8_1_89A = op0_8 & op1_1 & (op2_8 | op2_9 | op2_A); //

assign field = (op0_0) ? op2[2:0]: // 0 E a opcodes
               (op0_1 | op_8_1_89A) ? op3[2:0]: // 1 5 X a opcodes, 818f 819fx 81Af1x,
               op1[2:0]; // 9 a, A a, B a

saturn_field_decoder field_decoder(
    .field_in(field), // 3 left most bits
    .p_in(reg_P_in), // register P
    .start_o(field_decoded_right),
    .end_o(field_decoded_left)
    );

wire [19:0] jump_target_addr;
// pre-calculate the jump target address using relative arguments
assign jump_target_addr = ibus_pre_fetched_opcode_addr_in +
                          ((op_goc | op_gonc | op_jrel3) ? 20'h00001:
                           (op_jrel4)            ? 20'h00002:
                           (op_goto_on_cond_true)? 20'h00003:
                           (op_gosub)            ? 20'h00004:
                           (op_goto_on_acbit)    ? 20'h00005:
                           (op_gosubl)           ? 20'h00006:20'h0000) +
                          ((op_goto_on_cond_true | op_goc | op_gonc) ? ofs_pc_rel2:
                           (op_goto_on_acbit) ? ofs_pc_rel2_ab:
                           (op_jrel3 | op_gosub) ? ofs_pc_rel3:
                           (op_jrel4 | op_gosubl)? ofs_pc_rel4:20'h00000);

reg [63:0] unshifted_op_literal;
reg [3:0] op_literal_shift;
always @(*)
    begin
        unshifted_op_literal[63: 0] <= ibus_pre_fetched_opcode_in[71: 8];
        op_literal_shift = reg_P_in;
        if (op_is_la)
            unshifted_op_literal[63: 0] <= ibus_pre_fetched_opcode_in[83:20];
        if (op_is_A_A_PM_CON) // A=A+CON C=C-CON
            begin
                unshifted_op_literal[ 3: 0] <= ibus_pre_fetched_opcode_in[23:20];
                op_literal_shift = field_decoded_right;
            end
    end
                           
                           
// Sequencer
always @(posedge clk_in)
    begin
		if (reset_in == 1'b1)
            begin
                state <= `ST_INIT;
                ibus_flush_q <= 1'b1;
                ibus_fetch <= 1'b0;
                new_pc_jump <= 20'h00000;
            end
		else
            begin
                case (state)
                    `ST_INIT:// waits till an opcode has been fetched
                        begin
                            ibus_flush_q <= 1'b0;
                            ibus_fetch <= 1'b0;
                            
                            if (ibus_ready_in == 1'b1)
                                begin
                                    ibus_fetch_ack <= 1'b1;
                                    state <= `ST_DECODE;
                                end
                        end
                    `ST_DECODE:
                        begin
                            $display("%05X %s", ibus_pre_fetched_opcode_addr_in, ascii_opcode);
                            
                            ibus_fetch_ack <= 1'b0;
                            ibus_flush_q <= 1'b0;
                            ibus_fetch <= 1'b0;
                            if (op_alu_op != `ALU_OP_NONE)
                                state <= `ST_EXE_LATCH;
                            else
                                state <= `ST_EXE_END;
                            
                            // jump target address calculation
                            if (op_goto_on_cond_true | op_goc | op_gonc | op_jrel3 |
                                op_jrel4 | op_gosub | op_gosubl)
                                new_pc_jump <= jump_target_addr;
                            if (op_govlng | op_gosbvl)
                                new_pc_jump <= new_pc_abs;
                            // Process jumps that do not need the ALU
                            if (((op_goc & carry_in) | (op_gonc & (~carry_in)) |
                                op_jrel3 | op_jrel4 | op_govlng) &
                                (~(op_rtn_on_carry_clr | op_rtn_on_carry_set))) // RTNNC & RTNC must go through the ALU
                                state <= `ST_FLUSH_QUEUE; // jump directly
                            
                            // field size
                            if (op_field_left == 3'h6)
                                begin
                                    right_mask_o <= field_decoded_right;
                                    left_mask_o   <= field_decoded_left;
                                end
                            else
                                begin
                                    if (op_is_let_ex_cp) // literal used to indicate position
                                        right_mask_o <= op3;
                                        else
                                            if (op_is_lc | op_is_la)
                                                right_mask_o <= reg_P_in;
                                            else
                                                right_mask_o <= 4'h0;
                                    if (op_is_lc)
                                        left_mask_o <= reg_P_in + op1; // LC
                                    else
                                        if (op_is_la) left_mask_o <= reg_P_in + op4; // LA
                                        else
                                            if (op_is_let_ex_cp | op_rw_with_lit_size) // C=P n P=C n CPEX n, DAT0=A n A=DAT1 n
                                                left_mask_o <= op3;
                                            else
                                                left_mask_o <= op_field_left == 3'h7 ? 4'hf:{ 1'b0, op_field_left };
                                end
                            // ALU registers
                            op1_reg_o    <= op_alu_reg1;
                            op2_reg_o    <= op_alu_reg2;
                            dst_reg_o    <= op_alu_dst;
                            alu_op       <= op_alu_op;
                            force_carry <= op_forced_carry;
                            force_hex <= op_forced_hex; //op_is_Dn_P_CON | op_is_P_INC_DEC;
                            // literal handling, shift to correct position
                            op_literal <= 64'h0; // default value 
                            if (op_is_lc | op_is_la | op_is_A_A_PM_CON)
                                op_literal[63: 0] <= unshifted_op_literal << { op_literal_shift, 2'b00 };
                            if (op_is_ACBIT) // ABIT=0/1 ?CBIT=0/1
                                op_literal[15: 0] <= (16'h1 << op4); // shift bit to test/set/clear position
                            if (op_is_STBIT) // ST=0/1 ?ST=0/1
                                op_literal[15: 0] <= (16'h1 << op2); // shift bit to test/set/clear position
                            // op_is_load_Dn uses between 8 and 20 bits
                            // op_is_Dn_P_CON uses 4 bits 
                            if (op_is_load_Dn | op_is_Dn_P_CON | op_is_QP_CNT | op_is_HSBIT) // first 4 bits
                                op_literal[3: 0] <= ibus_pre_fetched_opcode_in[11: 8];
                            if (op_is_load_Dn) // last 16 bits, size determined in mc table
                                op_literal[19: 4] <= ibus_pre_fetched_opcode_in[27:12];
                            if (op_is_P_CNT) // P=n
                                op_literal[3: 0] <= op1;
                            if (op_gosub | op_gosubl | op_gosbvl) // use ALU to update RSTK
                                begin
                                    push_rstk <= 1'b1; // make place on stack
                                    op_literal[19: 0] <= ibus_pre_fetched_opcode_addr_in + (op_gosub ? 20'h4:op_gosubl ? 20'h6:20'h7);                            
                                end
                            if (op_push_ac)
                                push_rstk <= 1'b1; // make place on stack
                        end
                    `ST_INT_ACK_PUSH:
                        begin // Push actual PC
                            state <= `ST_INT_ACK_JUMP;
                            irq_ack <= 1'b1;
                        end
                    `ST_INT_ACK_JUMP:
                        begin // jump to interrupt handler, use ALU path with jump
                            state <= `ST_EXE_LATCH;
                            // repeat this instruction
                            op_literal[19: 0] <= ibus_pre_fetched_opcode_addr_in;
                            new_pc_jump <= 20'h0000F;
                            op1_reg_o    <= `OP_LIT;
                            dst_reg_o    <= `OP_STK;
                            alu_op       <= `ALU_OP_TFR; // copy address to RSTK
                            left_mask_o  <= 4'h4;
                            right_mask_o <= 4'h0;
                            push_rstk <= 1'b1; // and make place on stack 
                        end
                    `ST_EXE_LATCH: // latch source registers
                        begin
                            push_rstk <= 1'b0;
                            pull_rstk <= 1'b0;
                            state <= `ST_EXE_ALU;
                            write_dst <= op_write_dst;
                            write_op1 <= (op_alu_op == `ALU_OP_EX);
                            write_carry <= op_write_carry;                                         
                            write_sticky_bit <= op_write_sticky;
                        end
                    `ST_EXE_ALU: // write back results, do memory read/write
                        begin
                            if (op_alu_and_rtn_on_cs | op_goto_on_acbit |
                                op_goto_on_cond_true | // need extra cycle to catch new carry
                                op_gosub | op_gosubl | op_gosbvl) // these use the alu path too
                                begin
                                    state <= `ST_EXE_END;
                                    write_dst <= 1'b0;
                                end
                            else
                                begin // fetch next opcode if no test is needed
                                    if ((op_alu_op == `ALU_OP_RD) || (op_alu_op == `ALU_OP_WR))
                                        begin
                                            if (read_write_ready_in)
                                                begin
                                                    state <= `ST_INIT;
                                                    ibus_fetch <= 1'b1;
                                                    write_dst <= 1'b0;
                                                end
                                        end
                                    else
                                        begin
                                            state <= `ST_INIT;
                                            ibus_fetch <= 1'b1;
                                            write_dst <= 1'b0;
                                        end
                                end
                            
                            write_op1 <= 1'b0;
                            write_carry <= 1'b0;
                            write_sticky_bit <= 1'b0;
                        end
                    `ST_EXE_END:
                        begin
                            if (op_pull_ac)
                                pull_rstk <= 1'b1; // adjust stack
                            if (op_pc_ind_ac)
                                state <= `ST_RTN_JMP; // jump, PC was loaded
                            else
                                // Process returns
                                if ((op_alu_and_rtn_on_cs & carry_in) |
                                    (op_rtn_on_carry_set & carry_in) |
                                    (op_rtn_on_carry_clr & (~carry_in)) | op_rtn | op_rti)
                                    begin // Pop PC from Stack using the ALU
                                        op1_reg_o    <= `OP_STK;
                                        dst_reg_o    <= `OP_PC;
                                        alu_op       <= `ALU_OP_TFR; // copy RSTK to PC
                                        left_mask_o  <= 4'h4;
                                        right_mask_o <= 4'h0;
                                        state <= `ST_RTN_LATCH;
                                    end
                                else
                                    begin
                                        if ((op_gosub | op_gosubl | op_gosbvl) |
                                        // process ALU-dependant relative jumps
                                            (op_goto_on_acbit & carry_in) | // ?ABIT, ?CBIT
                                            (op_goto_on_cond_true & carry_in) | // ?HS, ?ST, ?P, ?A
                                            (op_goc & carry_in) | // GOC
                                            (op_gonc & (~carry_in)) | // GONC
                                             irq_ack) // if interrupt jump too
                                            state <= `ST_FLUSH_QUEUE;
                                        else
                                            begin
                                                state <= `ST_INIT; // no jump
                                                ibus_fetch <= 1'b1;
                                            end
                                    end
                            irq_ack <= 1'b0;
                        end
                    `ST_RTN_LATCH:
                        begin // latch arguments
                            pull_rstk <= 1'b0;
                            write_dst <= 1'b1;
                            state <= `ST_RTN_ALU;
                        end
                    `ST_RTN_ALU:
                        begin // write back PC
                            write_dst <= 1'b0;
                            state <= `ST_RTN_JMP;
                            pull_rstk <= 1'b1; // adjust stack                            
                        end
                    `ST_RTN_JMP:
                        begin
                            pull_rstk <= 1'b0;
                            new_pc_jump <= PC_in; // get recovered PC
                            state <= `ST_FLUSH_QUEUE;
                        end
                    `ST_FLUSH_QUEUE:
                        begin
                            ibus_flush_q <= 1'b1;
                            state <= `ST_INIT;
                        end
                endcase
        end
    end
    
// Module outputs
assign showregs_o           = (state == `ST_EXE_END) | (state == `ST_EXE_ALU);
assign ibus_flush_q_o       = ibus_flush_q;
assign ibus_fetch_o         = ibus_fetch;
assign ibus_fetch_ack_o     = ibus_fetch_ack;
assign ibus_addr_o          = new_pc_jump; // used with queue flush
// Memory read write
assign data_write_o         = op_is_MEM_WR & (state == `ST_EXE_LATCH);
assign data_read_o          = op_is_MEM_RD & (state == `ST_EXE_LATCH);
assign write_dst_o          = write_dst;
assign write_op1_o          = write_op1;
assign latch_alu_regs_o     = (state == `ST_EXE_LATCH) || (state == `ST_RTN_LATCH);
assign forced_carry_o       = force_carry;
assign forced_hex_o         = force_hex;

assign set_decimal_o        = op_setdec;// && (state == `ST_EXE_END);
assign set_hexadecimal_o    = op_sethex;// && (state == `ST_EXE_END);
assign alu_op_o             = alu_op;
assign op_literal_o         = op_literal;
assign write_sticky_bit_o   = write_sticky_bit;
assign write_carry_o        = write_carry;
assign clr_carry_o          = op_clr_carry;
assign set_carry_o          = op_set_carry;
assign shift_alu_q_o        = op_is_let_ex_cp; // indicate that the result should be shifted
assign add_pc_o             = 1'b0;
assign push_rstk_o          = push_rstk;
assign pull_rstk_o          = pull_rstk;
assign irq_ack_o            = irq_ack;

`ifdef HAS_TRACE_UNIT
assign trace_start_o = trace_start;
`endif

/* Trace module for simulation */

`ifdef HAS_TRACE_UNIT
saturn_trace trace(
    .clk_in(clk_in),
    .opcode_in({ opcode[6], op5, op4, op3, op2, op1, op0 } ),
    .pc_in(ibus_pre_fetched_opcode_addr_in),
    .fetched_opcode_in(state == `ST_DECODE), //exe_ack_in | exe_int | op_jump),

    .op_is_size_2(op_is_size_2),
    .op_is_size_3(op_is_size_3),
    .op_is_size_4(op_is_size_4),
    .op_is_size_5(op_is_size_5),
    .op_is_size_6(op_is_size_6),
    .op_is_size_7(op_is_size_7),

    /* serial interface */
    .serial_clk_in(),
    .serial_data_o()
    );
`endif

endmodule

module saturn_field_decoder(
    input wire [2:0] field_in, // 3 left most bits
    input wire [3:0] p_in, // register P
    output reg [3:0] start_o,
    output reg [3:0] end_o
    );

always @(field_in, p_in)
    case(field_in)
        3'h0: begin start_o = p_in; end_o = p_in; end // Pointer field
        3'h1: begin start_o = 4'h0; end_o = p_in; end // WP
        3'h2: begin start_o = 4'h2; end_o = 4'h2; end // XS
        3'h3: begin start_o = 4'h0; end_o = 4'h2; end // X
        3'h4: begin start_o = 4'hf; end_o = 4'hf; end // S
        3'h5: begin start_o = 4'h3; end_o = 4'he; end // M
        3'h6: begin start_o = 4'h0; end_o = 4'h1; end // B
        3'h7: begin start_o = 4'h0; end_o = 4'hf; end // W
    endcase

endmodule


module saturn_field_unit(
);

endmodule

/* Trace module for simulation
 *
 */
`ifdef HAS_TRACE_UNIT
module saturn_trace(
    input wire clk_in,
    input wire [27:0] opcode_in,
    input wire [19:0] pc_in,
    input wire fetched_opcode_in,
    input wire op_is_size_2,
    input wire op_is_size_3,
    input wire op_is_size_4,
    input wire op_is_size_5,
    input wire op_is_size_6,
    input wire op_is_size_7,

    /* serial interface */
    input wire serial_clk_in,
    output wire serial_data_o
    );

reg [27:0] tb_opcode [7:0];
reg [19:0] tb_pc [7:0];

reg [2:0] tb_ptr;

reg [27:0] last_opcode;
wire [19:0] last_pc;
wire [63:0] ascii_opcode;
//assign last_opcode = tb_opcode[tb_ptr - 3'd1];
assign last_pc = tb_pc[tb_ptr - 3'd1];

always @(posedge clk_in)
    begin
        if (fetched_opcode_in)
            begin
                tb_opcode[tb_ptr] <= opcode_in;
                last_opcode <= opcode_in;
                tb_pc[tb_ptr] <= pc_in;
                tb_ptr <= tb_ptr + 3'd1;
            end
    end
saturn_trace_dis dis(
    .op0(opcode_in[ 3: 0]),
    .op1(opcode_in[ 7: 4]),
    .op2(opcode_in[11: 8]),
    .op3(opcode_in[15:12]),
    .op4(opcode_in[19:16]),
    .op5(opcode_in[23:20]),
    .ascii_opcode_o(ascii_opcode)
    );
initial
    begin
        tb_ptr = 0;
    end
endmodule
`endif


module saturn_trace_field_decoder(
    input wire [2:0] field_in, // 3 left most bits
    output reg [15:0] field_o
    );

always @(field_in)
    case(field_in)
        3'h0: field_o = "P ";  // Pointer field
        3'h1: field_o = "WP";  // WP
        3'h2: field_o = "XS";  // XS
        3'h3: field_o = "X ";  // X
        3'h4: field_o = "S ";  // S
        3'h5: field_o = "M ";  // M
        3'h6: field_o = "B ";  // B
        3'h7: field_o = "W ";  // W
    endcase

endmodule

module saturn_trace_dis(
    input wire [3:0] op0,
    input wire [3:0] op1,
    input wire [3:0] op2,
    input wire [3:0] op3,
    input wire [3:0] op4,
    input wire [3:0] op5,
    input wire [19:0] pc_in,
    output wire [63:0] ascii_opcode_o
    );

reg [47:0] o;

assign ascii_opcode_o = use_xf ? { o, xfield }:{ o, xf2 };

wire [39:0] spc, sop;
wire [2:0] field;
wire [15:0] xfield;

reg use_xf;
reg [15:0] xf2;

assign field = (op0 == 4'h0) ? op2[2:0]: // 0 E a opcodes
               (op0 == 4'h1) ? op3[2:0]: // 1 5 X a opcodes
               op1[2:0]; // 9 a, A a, B a

assign spc = { pc_in[4] > 4'h9 ? 8'h55+pc_in[4]:8'h48+pc_in[4],
               pc_in[3] > 4'h9 ? 8'h55+pc_in[3]:8'h48+pc_in[3],
               pc_in[2] > 4'h9 ? 8'h55+pc_in[2]:8'h48+pc_in[2],
               pc_in[1] > 4'h9 ? 8'h55+pc_in[1]:8'h48+pc_in[1],
               pc_in[0] > 4'h9 ? 8'h55+pc_in[0]:8'h48+pc_in[0] };

assign sop = { op0 > 4'h9 ? 8'h55 + op0:8'h48 + op0,
               op1 > 4'h9 ? 8'h55 + op1:8'h48 + op1,
               op2 > 4'h9 ? 8'h55 + op2:8'h48 + op2,
               op3 > 4'h9 ? 8'h55 + op3:8'h48 + op3,
               op4 > 4'h9 ? 8'h55 + op4:8'h48 + op4 };

saturn_trace_field_decoder field_dec(
    .field_in(field), // 3 left most bits
    .field_o(xfield)
    );

wire [7:0] so1, so2, so3, so4;

assign so1 = (op1 > 4'h9) ? (8'h37+{ 4'h0, op1 }):(8'h30+{ 4'h0, op1 });
assign so2 = (op2 > 4'h9) ? (8'h37+{ 4'h0, op2 }):(8'h30+{ 4'h0, op2 });
assign so3 = (op3 > 4'h9) ? (8'h37+{ 4'h0, op3 }):(8'h30+{ 4'h0, op3 });
assign so4 = (op4 > 4'h9) ? (8'h37+{ 4'h0, op4 }):(8'h30+{ 4'h0, op4 });


always @(*)
    begin
        use_xf = 1'b0;
        xf2 = "  ";
        o = "??????";
        case (op0)
            4'h0:
                case (op1)
                    4'h0: o = "RTNSXM";
                    4'h1: o = "RTN   ";
                    4'h2: o = "RTNSC ";
                    4'h3: o = "RTNCC ";
                    4'h4: o = "SETHEX";
                    4'h5: o = "SETDEC";
                    4'h6: o = "RSTK=C";
                    4'h7: o = "C=RSTK";
                    4'h8: o = "CLRST ";
                    4'h9: o = "C=ST  ";
                    4'ha: o = "ST=C  ";
                    4'hb: o = "CSTEX ";
                    4'hc: o = "P=P+1 ";
                    4'hd: o = "P=P-1 ";
                    4'he:
                        if (op2 < 4'h8)
                            case (op3)
                                4'h0: o = "A=A&B ";
                                4'h1: o = "B=B&C ";
                                4'h2: o = "C=C&A ";
                                4'h3: o = "D=D&C ";
                                4'h4: o = "B=B&A ";
                                4'h5: o = "C=C&B ";
                                4'h6: o = "A=A&C ";
                                4'h7: o = "C=C&D ";
                                4'h8: o = "A=A!B ";
                                4'h9: o = "B=B!C ";
                                4'ha: o = "C=C!A ";
                                4'hb: o = "D=A!B ";
                                4'hc: o = "B=B!A ";
                                4'hd: o = "C=C!B ";
                                4'he: o = "A=A!C ";
                                4'hf: o = "C=C!D ";
                            endcase
                        else
                            case (op3)
                                4'h0: o = "A=A&B ";
                                4'h1: o = "B=B&C ";
                                4'h2: o = "C=C&A ";
                                4'h3: o = "D=D&C ";
                                4'h4: o = "B=B&A ";
                                4'h5: o = "C=C&B ";
                                4'h6: o = "A=A&C ";
                                4'h7: o = "C=C&D ";
                                4'h8: o = "A=A!B ";
                                4'h9: o = "B=B!C ";
                                4'ha: o = "C=C!A ";
                                4'hb: o = "D=A!B ";
                                4'hc: o = "B=B!A ";
                                4'hd: o = "C=C!B ";
                                4'he: o = "A=A!C ";
                                4'hf: o = "C=C!D ";
                            endcase
                    4'hf: o = "RTI   ";
                endcase
            4'h1: case (op1)
                    4'h0:
                        case (op2)
                            4'h0: begin o = "R0=A  "; xf2 = "W "; end
                            4'h1: begin o = "R1=A  "; xf2 = "W "; end
                            4'h2: begin o = "R2=A  "; xf2 = "W "; end
                            4'h3: begin o = "R3=A  "; xf2 = "W "; end
                            4'h4: begin o = "R4=A  "; xf2 = "W "; end
                            4'h5: o = "?     ";
                            4'h6: o = "?     ";
                            4'h7: o = "?     ";
                            4'h8: begin o = "R0=C  "; xf2 = "W "; end
                            4'h9: begin o = "R1=C  "; xf2 = "W "; end
                            4'ha: begin o = "R2=C  "; xf2 = "W "; end
                            4'hb: begin o = "R3=C  "; xf2 = "W "; end
                            4'hc: begin o = "R4=C  "; xf2 = "W "; end
                            4'hd: o = "?     ";
                            4'he: o = "?     ";
                            4'hf: o = "?     ";
                        endcase
                    4'h1:
                        case (op2)
                            4'h0: begin o = "A=R0  "; xf2 = "W "; end
                            4'h1: begin o = "A=R1  "; xf2 = "W "; end
                            4'h2: begin o = "A=R2  "; xf2 = "W "; end
                            4'h3: begin o = "A=R3  "; xf2 = "W "; end
                            4'h4: begin o = "A=R4  "; xf2 = "W "; end
                            4'h5: o = "?     ";
                            4'h6: o = "?     ";
                            4'h7: o = "?     ";
                            4'h8: begin o = "C=R0  "; xf2 = "W "; end
                            4'h9: begin o = "C=R1  "; xf2 = "W "; end
                            4'ha: begin o = "C=R2  "; xf2 = "W "; end
                            4'hb: begin o = "C=R3  "; xf2 = "W "; end
                            4'hc: begin o = "C=R4  "; xf2 = "W "; end
                            4'hd: o = "?     ";
                            4'he: o = "?     ";
                            4'hf: o = "?     ";
                        endcase
                    4'h2:
                        case (op2)
                            4'h0: begin o = "AR0EX "; xf2 = "W "; end
                            4'h1: begin o = "AR1EX "; xf2 = "W "; end
                            4'h2: begin o = "AR2EX "; xf2 = "W "; end
                            4'h3: begin o = "AR3EX "; xf2 = "W "; end
                            4'h4: begin o = "AR4EX "; xf2 = "W "; end
                            4'h5: o = "?     ";
                            4'h6: o = "?     ";
                            4'h7: o = "?     ";
                            4'h8: begin o = "CR0EX "; xf2 = "W "; end
                            4'h9: begin o = "CR1EX "; xf2 = "W "; end
                            4'ha: begin o = "CR2EX "; xf2 = "W "; end
                            4'hb: begin o = "CR3EX "; xf2 = "W "; end
                            4'hc: begin o = "CR4EX "; xf2 = "W "; end
                            4'hd: o = "?     ";
                            4'he: o = "?     ";
                            4'hf: o = "?     ";
                        endcase
                    4'h3:
                        begin
                            case (op2)
                                4'h0: begin o = "D0=A  "; xf2 = "A "; end
                                4'h1: begin o = "D1=A  "; xf2 = "A "; end
                                4'h2: begin o = "AD0EX "; xf2 = "A "; end
                                4'h3: begin o = "AD1EX "; xf2 = "A "; end
                                4'h4: begin o = "D0=C  "; xf2 = "A "; end
                                4'h5: begin o = "D1=C  "; xf2 = "A "; end
                                4'h6: begin o = "CD0EX "; xf2 = "A "; end
                                4'h7: begin o = "CD1EX "; xf2 = "A "; end
                                4'h8: begin o = "D0=AS "; xf2 = "S "; end
                                4'h9: begin o = "D1=AS "; xf2 = "S "; end
                                4'ha: begin o = "AD0SX "; xf2 = "S "; end
                                4'hb: begin o = "AD1EX "; xf2 = "S "; end
                                4'hc: begin o = "D0=CS "; xf2 = "S "; end
                                4'hd: begin o = "D1=CS "; xf2 = "S "; end
                                4'he: begin o = "CD0XS "; xf2 = "S "; end
                                4'hf: begin o = "CD1XS "; xf2 = "S "; end
                            endcase
                        end
                    4'h4:
                        case (op2)
                            4'h0: begin o = "DAT0=A"; xf2 = "A "; end
                            4'h1: begin o = "DAT1=A"; xf2 = "A "; end
                            4'h2: begin o = "A=DAT0"; xf2 = "A "; end
                            4'h3: begin o = "A=DAT1"; xf2 = "A "; end
                            4'h4: begin o = "DAT0=C"; xf2 = "A "; end
                            4'h5: begin o = "DAT1=C"; xf2 = "A "; end
                            4'h6: begin o = "C=DAT0"; xf2 = "A "; end
                            4'h7: begin o = "C=DAT1"; xf2 = "A "; end
                            4'h8: begin o = "DAT0=A"; xf2 = "B "; end
                            4'h9: begin o = "DAT1=A"; xf2 = "B "; end
                            4'ha: begin o = "A=DAT0"; xf2 = "B "; end
                            4'hb: begin o = "A=DAT1"; xf2 = "B "; end
                            4'hc: begin o = "DAT0=C"; xf2 = "B "; end
                            4'hd: begin o = "DAT1=C"; xf2 = "B "; end
                            4'he: begin o = "C=DAT0"; xf2 = "B "; end
                            4'hf: begin o = "C=DAT1"; xf2 = "B "; end
                        endcase
                    4'h5:
                        begin
                            use_xf = 1'b1;
                            case (op2)
                                4'h0: begin o = "DAT0=A"; xf2 = "A "; end
                                4'h1: begin o = "DAT1=A"; xf2 = "A "; end
                                4'h2: begin o = "A=DAT0"; xf2 = "A "; end
                                4'h3: begin o = "A=DAT1"; xf2 = "A "; end
                                4'h4: begin o = "DAT0=C"; xf2 = "A "; end
                                4'h5: begin o = "DAT1=C"; xf2 = "A "; end
                                4'h6: begin o = "C=DAT0"; xf2 = "A "; end
                                4'h7: begin o = "C=DAT1"; xf2 = "A "; end
                                4'h8: begin o = "DAT0=A"; xf2 = "B "; end
                                4'h9: begin o = "DAT1=A"; xf2 = "B "; end
                                4'ha: begin o = "A=DAT0"; xf2 = "B "; end
                                4'hb: begin o = "A=DAT1"; xf2 = "B "; end
                                4'hc: begin o = "DAT0=C"; xf2 = "B "; end
                                4'hd: begin o = "DAT1=C"; xf2 = "B "; end
                                4'he: begin o = "C=DAT0"; xf2 = "B "; end
                                4'hf: begin o = "C=DAT1"; xf2 = "B "; end
                            endcase
                        end
                    4'h6: begin o = "D0=D0+"; xf2 = op2 > 4'h9 ? {8'h31, 8'd39+op2 }:{ 8'h31+op2, " " }; end
                    4'h7: begin o = "D1=D1+"; xf2 = op2 > 4'h9 ? {8'h31, 8'd39+op2 }:{ 8'h31+op2, " " }; end
                    4'h8: begin o = "D0=D0-"; xf2 = op2 > 4'h9 ? {8'h31, 8'd39+op2 }:{ 8'h31+op2, " " }; end
                    4'h9: o = "D0=(2)";
                    4'hA: o = "D0=(4)";
                    4'hB: o = "D0=(5)";
                    4'hc: begin o = "D1=D1-"; xf2 = op2 > 4'h9 ? {8'h31, 8'd38+op2 }:{ 8'h31+op2, " " }; end
                    4'hD: o = "D1=(2)";
                    4'hE: o = "D1=(4)";
                    4'hF: o = "D1=(5)";
                endcase
            4'h2: begin o = "P=    "; xf2 = op1 > 4'h9 ? {8'h31, 8'd38+op1 }:{ 8'h30+op1, " " }; end
            4'h3:
                begin
                    xf2 = so1; // size given in opcode from the beginning
                    o = "LC    ";
                end
            4'h4: if ((op1 == 0) && (op2 == 0))
                    o = "RTNC  ";
                else
                    o = "GOC   ";
            4'h5: if ((op1 == 0) && (op2 == 0))
                    o = "RTNNC ";
                else
                    o = "GONC  ";
            4'h6: o = "GOTO  ";
            4'h7: o = "GOSUB ";
            4'h8:
                case (op1)
                    4'h0:
                        case (op2)
                            4'h0: o = "OUT=CS";
                            4'h1: o = "OUT=C ";
                            4'h2: o = "A=IN  ";
                            4'h3: o = "C=IN  ";
                            4'h4: o = "UNCNFG";
                            4'h5: o = "CONFIG";
                            4'h6: o = "C=ID  ";
                            4'h7: o = "SHUTDN";
                            4'h8: 
                                case (op3)
                                    4'h0: o = "INTON ";
                                    4'h1: o = "RSI   ";
                                    4'h2: o = "LA    ";
                                    4'h3: o = "BUSCB ";
                                    4'h4: o = "ABIT=0";
                                    4'h5: o = "ABIT=1";
                                    4'h6: o = "?ABIT=0";
                                    4'h7: o = "?ABIT=1";
                                    4'h8: o = "CBIT=0";
                                    4'h9: o = "CBIT=1";
                                    4'hA: o = "?CBIT=0";
                                    4'hB: o = "?CBIT=1";
                                    4'hC: o = "PC=(A)";
                                    4'hD: o = "BUSCD ";
                                    4'hE: o = "PC=(C)";
                                    4'hF: o = "INTOFF";
                                endcase
                            4'h9: o = "C+P+1 ";
                            4'ha: o = "RESET ";
                            4'hb: o = "BUSCC ";
                            4'hc: begin o = "C=P   "; xf2 = so3; end
                            4'hd: begin o = "P=C   "; xf2 = so3; end
                            4'he: o = "SREQ? ";
                            4'hf: begin o = "CPEX  "; xf2 = so3; end
                        endcase
                    4'h1:
                        begin
                            xf2 = "W ";
                            case (op2)
                                4'h0: o = "ASLC ";
                                4'h1: o = "BSLC ";
                                4'h2: o = "CSLC ";
                                4'h3: o = "DSLC ";
                                4'h4: o = "ASRC ";
                                4'h5: o = "BSRC ";
                                4'h6: o = "CSRC ";
                                4'h7: o = "DSRC ";
                                4'h8: o = "?    ";
                                4'h9: o = "?    ";
                                4'ha: o = "?    ";
                                4'hb: o = "?    ";
                                4'hc: o = "ASLB ";
                                4'hd: o = "BSLB ";
                                4'he: o = "CSLB ";
                                4'hf: o = "DSLB ";
                            endcase
                        end
                    4'h2:
                        case (op2)
                            4'h0: o = "?     ";
                            4'h1: o = "XM=0  ";
                            4'h2: o = "SB=0  ";
                            4'h3: o = "?     ";
                            4'h4: o = "SR=0  ";
                            4'h5: o = "?     ";
                            4'h6: o = "?     ";
                            4'h7: o = "?     ";
                            4'h8: o = "MP=0  ";
                            4'h9: o = "?     ";
                            4'ha: o = "?     ";
                            4'hb: o = "?     ";
                            4'hc: o = "?     ";
                            4'hd: o = "?     ";
                            4'he: o = "?     ";
                            4'hf: o = "CLRHST";
                        endcase
                    4'h3:
                        case (op2)
                            4'h0: o = "?     ";
                            4'h1: o = "?XM=0 ";
                            4'h2: o = "?SB=0 ";
                            4'h3: o = "?     ";
                            4'h4: o = "?SR=0 ";
                            4'h5: o = "?     ";
                            4'h6: o = "?     ";
                            4'h7: o = "?     ";
                            4'h8: o = "?MP=0 ";
                            4'h9: o = "?     ";
                            4'ha: o = "?     ";
                            4'hb: o = "?     ";
                            4'hc: o = "?     ";
                            4'hd: o = "?     ";
                            4'he: o = "?     ";
                            4'hf: o = "CLRHST";
                        endcase
                    4'h4: begin o = "ST=0  "; xf2 = so2; end
                    4'h5: begin o = "ST=1  "; xf2 = so2; end
                    4'h6: begin o = "?ST=0 "; xf2 = so2; end
                    4'h7: begin o = "?ST=1 "; xf2 = so2; end
                    4'h8: begin o = "?P#   "; xf2 = so2; end
                    4'h9: begin o = "?P=   "; xf2 = so2; end
                    4'ha:
                        begin
                        xf2 = "A ";
                            case (op2)
                                4'h0: o = "?A=B  ";
                                4'h1: o = "?B=C  ";
                                4'h2: o = "?A=C  ";
                                4'h3: o = "?C=D  ";
                                4'h4: o = "?A#B  ";
                                4'h5: o = "?B#C  ";
                                4'h6: o = "?A#C  ";
                                4'h7: o = "?C#D  ";
                                4'h8: o = "?A=0  ";
                                4'h9: o = "?B=0  ";
                                4'ha: o = "?C=0  ";
                                4'hb: o = "?D=0  ";
                                4'hc: o = "?A#0  ";
                                4'hd: o = "?B#0  ";
                                4'he: o = "?C#0  ";
                                4'hf: o = "?D#0  ";
                            endcase
                        end
                    4'hb:
                        begin
                        xf2 = "A ";
                            case (op2)
                                4'h0: o = "?A>B  ";
                                4'h1: o = "?B>C  ";
                                4'h2: o = "?C>A  ";
                                4'h3: o = "?D>C  ";
                                4'h4: o = "?A<B  ";
                                4'h5: o = "?B<C  ";
                                4'h6: o = "?C<A  ";
                                4'h7: o = "?D<D  ";
                                4'h8: o = "?A>=B ";
                                4'h9: o = "?B>=C ";
                                4'ha: o = "?C>=A ";
                                4'hb: o = "?D>=C ";
                                4'hc: o = "?A<=B ";
                                4'hd: o = "?B<=C ";
                                4'he: o = "?C<=A ";
                                4'hf: o = "?D<=C ";
                            endcase
                        end
                    4'hc: o = "GOLONG";
                    4'hd: o = "GOVLNG";
                    4'he: o = "GOSUBL";
                    4'hf: o = "GOSBVL";
                endcase
            4'h9:
                if (op1 < 4'h8)
                    begin
                        use_xf = 1'b1;
                        case (op2)
                            4'h0: o = "?A=B  ";
                            4'h1: o = "?B=C  ";
                            4'h2: o = "?A=C  ";
                            4'h3: o = "?C=D  ";
                            4'h4: o = "?A#B  ";
                            4'h5: o = "?B#C  ";
                            4'h6: o = "?A#C  ";
                            4'h7: o = "?C#D  ";
                            4'h8: o = "?A=0  ";
                            4'h9: o = "?B=0  ";
                            4'ha: o = "?C=0  ";
                            4'hb: o = "?D=0  ";
                            4'hc: o = "?A#0  ";
                            4'hd: o = "?B#0  ";
                            4'he: o = "?C#0  ";
                            4'hf: o = "?D#0  ";
                        endcase
                    end
                else
                    begin
                        use_xf = 1'b1;
                        case (op2)
                            4'h0: o = "?A>B  ";
                            4'h1: o = "?B>C  ";
                            4'h2: o = "?C>A  ";
                            4'h3: o = "?D>C  ";
                            4'h4: o = "?A<B  ";
                            4'h5: o = "?B<C  ";
                            4'h6: o = "?C<A  ";
                            4'h7: o = "?D<D  ";
                            4'h8: o = "?A>=B ";
                            4'h9: o = "?B>=C ";
                            4'ha: o = "?C>=A ";
                            4'hb: o = "?D>=C ";
                            4'hc: o = "?A<=B ";
                            4'hd: o = "?B<=C ";
                            4'he: o = "?C<=A ";
                            4'hf: o = "?D<=C ";
                        endcase
                    end
            4'hA: // three nibble opcodes here
                begin
                    use_xf = 1'b1;
                    if (!op1[3])
                        begin
                            case (op2)
                                4'h0: o = "A=A+B ";
                                4'h1: o = "B=B+C ";
                                4'h2: o = "C=C+A ";
                                4'h3: o = "D=D+C ";
                                4'h4: o = "A=A+A ";
                                4'h5: o = "B=B+B ";
                                4'h6: o = "C=C+C ";
                                4'h7: o = "D=D+D ";
                                4'h8: o = "B=B+A ";
                                4'h9: o = "C=C+B ";
                                4'ha: o = "A=A+C ";
                                4'hb: o = "C=C+D ";
                                4'hc: o = "A=A-1 ";
                                4'hd: o = "B=B-1 ";
                                4'he: o = "C=C-1 ";
                                4'hf: o = "D=D-1 ";
                            endcase
                        end
                    else
                        begin
                            case (op2)
                                4'h0: o = "A=0   ";
                                4'h1: o = "B=0   ";
                                4'h2: o = "C=0   ";
                                4'h3: o = "D=0   ";
                                4'h4: o = "A=B   ";
                                4'h5: o = "B=C   ";
                                4'h6: o = "C=A   ";
                                4'h7: o = "D=C   ";
                                4'h8: o = "B=A   ";
                                4'h9: o = "C=B   ";
                                4'ha: o = "A=C   ";
                                4'hb: o = "C=D   ";
                                4'hc: o = "ABEX  ";
                                4'hd: o = "BCEX  ";
                                4'he: o = "ACEX  ";
                                4'hf: o = "DCEX  ";
                            endcase
                        end
                end
            4'hB:  // three nibble opcodes here
                begin
                    use_xf = 1'b1;
                    if (!op1[3])
                        begin
                            case (op2)
                                4'h0: o = "A=A-B ";
                                4'h1: o = "B=B-C ";
                                4'h2: o = "C=C-A ";
                                4'h3: o = "D=D-C ";
                                4'h4: o = "A=A+1 ";
                                4'h5: o = "B=B+1 ";
                                4'h6: o = "C=C+1 ";
                                4'h7: o = "D=D+1 ";
                                4'h8: o = "B=B-A ";
                                4'h9: o = "C=C-B ";
                                4'ha: o = "A=A-C ";
                                4'hb: o = "C=C-D ";
                                4'hc: o = "A=B-A ";
                                4'hd: o = "B=C-B ";
                                4'he: o = "C=A-C ";
                                4'hf: o = "D=C-D ";
                            endcase
                        end
                    else
                        begin
                            case (op2)
                                4'h0: o = "ASL   ";
                                4'h1: o = "BSL   ";
                                4'h2: o = "CSL   ";
                                4'h3: o = "DSL   ";
                                4'h4: o = "ASR   ";
                                4'h5: o = "BSR   ";
                                4'h6: o = "CSR   ";
                                4'h7: o = "DSR   ";
                                4'h8: o = "A=-A  ";
                                4'h9: o = "B=-B  ";
                                4'ha: o = "C=-C  ";
                                4'hb: o = "D=-D  ";
                                4'hc: o = "A=9-A ";
                                4'hd: o = "B=9-B ";
                                4'he: o = "C=9-C ";
                                4'hf: o = "D=9-D ";
                            endcase
                        end
                end
            4'hC:
                begin
                    xf2 = "A ";
                    case (op1)
                        4'h0: o = "A=A+B ";
                        4'h1: o = "B=B+C ";
                        4'h2: o = "C=C+A ";
                        4'h3: o = "D=D+C ";
                        4'h4: o = "A=A+A ";
                        4'h5: o = "B=B+B ";
                        4'h6: o = "C=C+C ";
                        4'h7: o = "D=D+D ";
                        4'h8: o = "B=B+A ";
                        4'h9: o = "C=C+B ";
                        4'ha: o = "A=A+C ";
                        4'hb: o = "C=C+D ";
                        4'hc: o = "A=A-1 ";
                        4'hd: o = "B=B-1 ";
                        4'he: o = "C=C-1 ";
                        4'hf: o = "D=D-1 ";
                    endcase
                end
            4'hD:
                begin
                    xf2 = "A ";
                    case (op1)
                        4'h0: o = "A=0   ";
                        4'h1: o = "B=0   ";
                        4'h2: o = "C=0   ";
                        4'h3: o = "D=0   ";
                        4'h4: o = "A=B   ";
                        4'h5: o = "B=C   ";
                        4'h6: o = "C=A   ";
                        4'h7: o = "D=C   ";
                        4'h8: o = "B=A   ";
                        4'h9: o = "C=B   ";
                        4'ha: o = "A=C   ";
                        4'hb: o = "C=D   ";
                        4'hc: o = "ABEX  ";
                        4'hd: o = "BCEX  ";
                        4'he: o = "ACEX  ";
                        4'hf: o = "DCEX  ";
                    endcase
                end
            4'hE:
                begin
                    xf2 = "A ";
                    case (op1)
                        4'h0: o = "A=A-B ";
                        4'h1: o = "B=B-C ";
                        4'h2: o = "C=C-A ";
                        4'h3: o = "D=D-C ";
                        4'h4: o = "A=A+1 ";
                        4'h5: o = "B=B+1 ";
                        4'h6: o = "C=C+1 ";
                        4'h7: o = "D=D+1 ";
                        4'h8: o = "B=B-A ";
                        4'h9: o = "C=C-B ";
                        4'ha: o = "A=A-C ";
                        4'hb: o = "C=C-D ";
                        4'hc: o = "A=B-A ";
                        4'hd: o = "B=C-B ";
                        4'he: o = "C=A-C ";
                        4'hf: o = "D=C-D ";
                    endcase
                end
            4'hF:
                begin
                    xf2 = "A ";
                    case (op1)
                        4'h0: o = "ASL   ";
                        4'h1: o = "BSL   ";
                        4'h2: o = "CSL   ";
                        4'h3: o = "DSL   ";
                        4'h4: o = "ASR   ";
                        4'h5: o = "BSR   ";
                        4'h6: o = "CSR   ";
                        4'h7: o = "DSR   ";
                        4'h8: o = "A=-A  ";
                        4'h9: o = "B=-B  ";
                        4'ha: o = "C=-C  ";
                        4'hb: o = "D=-D  ";
                        4'hc: o = "A=9-A ";
                        4'hd: o = "B=9-B ";
                        4'he: o = "C=9-C ";
                        4'hf: o = "D=9-D ";
                    endcase
                end
        endcase
    end

endmodule
/**
 * The opcodes that modify registers or memory
 * are decoded here.
 * op_field_left has the left most used nibble
 * 0 : rightmost nibble
 * 1 : byte field 
 * 2 : 3 nibbles field (ST)
 * 3 : 4 nibbles field Dn and so on
 * 4 : A field
 * 5 : not used
 * 6 : use field from opcode and decode it 
 * 7 : Word field
 */
module saturn_microcode(
    input wire          clk_in,
    input wire          rom_en_in,
    input wire  [3:0] op0,
    input wire  [3:0] op1,
    input wire  [3:0] op2,
    input wire  [3:0] op3,
    input wire  [3:0] op4,
    input wire  [3:0] op5,
    output wire         op_goto_on_cond_true,
    output wire         op_abit,
    output wire         op_write_sticky,
    output wire         op_write_dst,
    output wire         op_write_carry,
    output wire         op_forced_hex,
    output wire         op_forced_carry,
    output wire [2:0] op_field_left,
    output wire [5:0] op_alu_reg1,
    output wire [5:0] op_alu_reg2,
    output wire [5:0] op_alu_dst,
    output wire [4:0] op_alu_op
    );

wire [31:0] mc;
assign op_goto_on_cond_true = mc[25];
assign op_abit          = mc[26];
assign op_write_sticky  = mc[27];
assign op_write_dst     = mc[28];
assign op_write_carry   = mc[29];
assign op_forced_hex    = mc[30];
assign op_forced_carry  = mc[31];
assign op_field_left     = mc[22:20];
assign op_alu_op         = mc[19:15];
assign op_alu_reg1       = mc[14: 9];
assign op_alu_reg2       = mc[ 8: 6];
assign op_alu_dst        = mc[ 5: 0];

reg [8:0] mca; // microcode address

always @(*)
    begin
        mca = 9'h0;
        case (op0)
            4'h0:
                if (op1 == 4'hE) mca = { 5'h00, op3 }; 
                else mca = { 5'h01, op1 };
            4'h1: case (op1)
                    4'h0: mca = { 5'h02, op2 };
                    4'h1: mca = { 5'h03, op2 };
                    4'h2: mca = { 5'h04, op2 };
                    4'h3: mca = { 5'h05, op2 };
                    4'h4: mca = { 5'h06, op2 };
                    4'h5: mca = { 5'h07, op2 };
                    default: mca = { 5'h08, op1 };
                endcase
            4'h2: mca = 9'h1F2;
            4'h3: mca = 9'h1F3;
            4'h4: mca = 9'h1F4;
            4'h5: mca = 9'h1F5;
            4'h6: mca = 9'h1F6;
            4'h7: mca = 9'h1F7;
            4'h8: case (op1)
                    4'h0: if (op2 == 4'h8) mca = { 5'h09, op3 }; else mca = { 5'h0A, op2 };
                    4'h1: case (op2)
                            4'h8: mca = { 5'h0B, op4 };
                            4'h9: mca = { 5'h0C, op4 };
                            4'hA: 
                                case (op4)
                                    4'h0: mca = { 5'h0D, op5 };
                                    4'h1: mca = { 5'h0E, op5 };
                                    4'h2: mca = { 5'h0F, op5 };
                                endcase
                            4'hB: mca = { 5'h10, op3 };
                            default: mca = { 5'h11, op2 };
                          endcase
                    4'hA: mca = { 5'h12, op2 };
                    4'hB: mca = { 5'h13, op2 };
                    default: mca = { 5'h14, op1 };
                  endcase
            4'h9: mca = (op1[3]) ? { 5'h16, op2 }:{ 5'h15, op2 };
            4'hA: mca = (op1[3]) ? { 5'h18, op2 }:{ 5'h17, op2 };
            4'hB: mca = (op1[3]) ? { 5'h1A, op2 }:{ 5'h19, op2 };
            4'hC: mca = { 5'h1B, op1 };
            4'hD: mca = { 5'h1C, op1 };
            4'hE: mca = { 5'h1D, op1 };
            4'hF: mca = { 5'h1E, op1 };
        endcase
    end

mcrom mcrom_i(
    .Address(mca),
    .OutClock(clk_in),
    .OutClockEn(rom_en_in),
    .Reset(1'b0),
    .Q(mc)
    );

endmodule
// mimic a block ROM
`ifdef SIMULATOR
module mcrom (
    input wire [8:0] Address,
    input wire OutClock,
    input wire OutClockEn,
    input wire Reset,
    output reg [31:0] Q
    );
    
reg [31:0] mcrom[511:0];

always @(posedge OutClock)
    if (OutClockEn)
        Q <= mcrom[Address];

initial
    $readmemb("C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/mc_tbl.bin", mcrom);
    
endmodule
`endif