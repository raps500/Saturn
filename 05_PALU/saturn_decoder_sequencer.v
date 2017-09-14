/* Parallel Saturn - decoders and sequencer
 *
 * Fetch, decode and sequencing
 *
 *
 * masks are inclusive !
 * Program memory is still nibble based
 */
`include "saturn_defs.v"


module saturn_decoder_sequencer(
    input wire          clk_in,
	input wire          reset_in,
    input wire          irq_in,
    input wire          irqen_in,       // flag for interrupt enable
    output wire         irq_ack_o,
    // cpu interface
    input wire [19:0]   pc_in,
    input wire          exe_ack_in,
    input wire          carry_in,
    input wire          condtrue_in,
    input wire [3:0]    reg_p_in,
    output wire         exe_o,
	output wire [3:0]	cpu_state_o,
    // mem interface
    output wire         use_fetch_addr_o,
    output wire         fetch_read_o,
    output wire [19:0]  addr_o,
    input wire [3:0]    data_in,
    input wire          mem_ack_in, // asserted when data is available 
    output wire         mem_read_o,
    output wire         mem_write_o,
    // opcode decoder outputs

    output wire         push_ac_o,
    output wire         pop_ac_o,
    output wire         push_pc_o,
    output wire         pop_pc_o,
    output wire         load_new_pc_o,
    // flags
    output wire         setdec_o,
    output wire         sethex_o,
    output wire         setxm_o,
    output wire         setint_o,
    output wire         tstxm_o,
    output wire         tstmp_o,
    output wire         tstsb_o,
    output wire         tstsr_o,
    output wire         clrxm_o,
    output wire         clrmp_o,
    output wire         clrsb_o,
    output wire         clrsr_o,
    output wire         clrint_o,
    output wire         clrhst_o,
    output wire         clr_carry_o,             // clear carry unconditionally
    output wire         force_carry_o,           // forces carry set at the beginning of an ALU op
    output wire         set_carry_o,             // set carry unconditionally
    output wire         set_carry_on_carry_o,    // set/clr carry on ALU carry out
    output wire         set_carry_on_zero_o,     // set/clr carry on ALU zero (for ADD/SUB)
    output wire         set_carry_on_eq_o,       // set carry on equal/neq
    output wire         setstflag_o,             // sets one flag (alu_lit index to flag)
    output wire         clrstflag_o,             // clears one flag (alu_lit index to flag)
    output wire         tst_0_st_flag_o,         // tests one flag (alu_lit index to flag)
    output wire         tst_1_st_flag_o,         // tests one flag (alu_lit index to flag)
    output wire         tst_p_eq_lit_o,          // tests if p equal literal
    output wire         tst_p_neq_lit_o,         // tests if p doesn't equal literal
    
    // ALU & Regs control
    output wire [3:0]   dmux_o,                     // controls data flow
    output wire [3:0]   alu_op_o,                   // ALU operation
    output wire [3:0]   alu_reg1_o,                 // alu operand, register 1
    output wire [3:0]   alu_reg2_o,                 // alu operand, register 2
    output wire [3:0]   alu_dst_o,                  // destination register, used for everythig 
    output wire [3:0]   alu_lit_o,                  // literal used as extra argument
    output wire         use_alu_lit_as_1_o,         // asserted when op1 is a literal  
    output wire         use_alu_lit_as_2_o,         // asserted when op2 is a literal
    output wire         data_reg_o,
    output wire [3:0]   op1_nib_o,                  // address of operand 1 nibble
    output wire [3:0]   op2_nib_o,                  // address of operand 2 nibble
    output wire [3:0]   dst_nib_o,                  // address of dest nibble
    output wire [1:0]   seq_o,                      // sequencer stage
    output wire         clr_o,
    output wire         tfr_o,                      // write enable for transfers: A=B and so on
    output wire         ex_o,                       // write enable for exchanges
    output wire         we_o,                       // write enable for ALU 
    output wire         force_hex_o,                // forces HEX mode
    output wire         alu_seq_last_nibble_o,      // signals the last nibble in an ALU opration or read/write
    
    output wire [19:0]  new_pc_o,
    output wire [19:0]  data_addr_o,            // current access data address, incremented for each nibble
    input wire [19:0]   data_addr_in            // selected DAT0/DAT1 value
`ifdef HAS_TRACE_UNIT
    ,
    output wire         trace_start_o,
    input wire          trace_end_in
`endif
    );


reg [3:0] opcode [7:0]; // fully buffered opcode
reg opcode_complete;
reg [3:0] state;
reg [19:0] fetch_addr, new_pc, base_pc_rel_jump, new_pc_jump, curr_data_addr;

reg [3:0] field_start, field_end;       /* Size fields */
reg [3:0] alu_reg1, alu_reg2;
reg [3:0] alu_dst;  /* Alu operators */
reg [3:0] alu_op;                       /* Alu opcode */
reg [3:0] dmux_op;

reg load_new_pc, irq_ack;

reg [3:0] alu_lit;
reg [3:0] seq_state;
reg [3:0] field_counter, field_ofs;
reg [3:0] field_start_op1;

wire [3:0] op_field_end;
wire [3:0] op_alu_reg1;
wire [3:0] op_alu_reg2;
wire [3:0] op_alu_dst;
wire [3:0] op_alu_op;
wire [3:0] op_dmux;
wire op_field_fv; // field fied or variable i.e. opcode field

/* Jump/Gosub address calculation */

wire [3:0] op0, op1, op2, op3, op4, op5;

assign op0 = opcode[0];
assign op1 = opcode[1];
assign op2 = opcode[2];
assign op3 = opcode[3];
assign op4 = opcode[4];
assign op5 = opcode[5];

/* Pre-decode */

wire op_is_size_2;
wire op_is_size_3, op_is_size_3b;
wire op_is_size_4, op_is_size_4b;
wire op_is_size_5;
wire op_is_size_6;
wire op_is_size_7;

wire op_is_direct, op_is_alu, op_has_read, op_has_write, op_has_fetch;
wire op_jrel2, op_jrel3, op_jrel4, op_jabs, op_gosub, op_gosubl;
wire op_j_on_c_clr, op_j_on_c_set;
wire op_rtn_on_carry_set, op_goto_on_cond_set; /* for tests */

wire [19:0] ofs_pc_rel2, ofs_pc_rel3, ofs_pc_rel4, new_pc_abs;

wire [19:0] pc_plus1, pc_plus2, pc_plus3, pc_plus4, pc_plus6;

reg [2:0] opcde_cnt;
reg alu_reg1_is_zero; // set at the beginning of a shift to force input a zero on the needed side

wire op_clrst;
wire op_push_ac; // RSTK=C
wire op_pop_ac;  // C=RSTK
wire op_push_pc;
wire op_pop_pc;                         /* rtn */
wire use_alu_lit; // asserted when alu_lit carries the first operand for add or sub
wire op_setdec, op_sethex, op_uncnfg, op_config, op_shutdn;
wire op_intoff, op_inton, op_reset;
wire op_clr_xm, op_clr_sb, op_clr_sr, op_clr_mp, op_clr_hst;
wire op_tstxm, op_tstmp, op_tstsb, op_tstsr;
wire op_clr_st_flag, op_tst_0_st_flag, op_tst_1_st_flag, op_set_st_flag;
wire op_tst_p_eq_lit, op_tst_p_neq_lit;
wire op_data_reg; // Selects data register (D0/D1) for address output during memory read/write
wire op_is_lc, op_is_let_p, op_is_la, op_is_as_Dn, op_is_let_st;
wire op_is_q_st, op_is_q_p, op_is_let_ex_cp;
wire op_lit_in_op1, op_lit_in_op2, op_lit_in_op3, op_lit_in_op4;
wire op_has_lit;
wire op_lit_0_as_op1; // 0 as literal in op1 for A=0-A, B=0-B, C=0-C, D=0-D
wire use_alu_lit_as_1, use_alu_lit_as_2; // asserted when needed
wire op_lit_1, op_lit_9, op_lit_0, op_lit_P;
wire op_cppp1; // C+P+1
wire op_rw_with_lit_size; // DAT0=A/C n DAT1=A/C n A/C=DAT0 n A/C=DAT1 n used to select op3 as field_end
wire op_force_carry, op_force_hex;
wire op0_0, op0_1, op0_2, op0_3, op0_4, op0_5, op0_6, op0_7, op0_8, op0_9, op0_A, op0_B, op0_C, op0_D, op0_E, op0_F;
wire op1_0, op1_1, op1_2, op1_3, op1_4, op1_5, op1_6, op1_7, op1_8, op1_9, op1_A, op1_B, op1_C, op1_D, op1_E, op1_F;
wire op2_0, op2_1, op2_2, op2_3, op2_4, op2_5, op2_6, op2_7, op2_8, op2_9, op2_A, op2_B, op2_C, op2_D, op2_E, op2_F;

wire [63:0] ascii_opcode;
// Trace
reg trace_start;


saturn_microcode mc(
    .op0(op0),
    .op1(op1),
    .op2(op2),
    .op3(op3),
    .op_field_end  (op_field_end  ),
    .op_alu_reg1   (op_alu_reg1   ),
    .op_alu_reg2   (op_alu_reg2   ),
    .op_alu_dst    (op_alu_dst    ),
    .op_alu_op     (op_alu_op     ),
    .op_dmux       (op_dmux       )
    
    );
	
saturn_trace_dis dis(
    .opcode_in({op5, op4, op3, op2, op1, op0 }),
    .pc_in(pc_in),
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


assign op_is_size_2 = ((op0_0) && (op1 != 4'hE)) || 
                      ((op0_1) && ((op1_9) || (op1_A) || (op1_B) ||   // Dx=(n)
                                   (op1_D) || (op1_E) || (op1_F))) || // Dx=(n)
                      (op0_2) ||
                      (op0_3) || // starting size anyways
                      (op0_C) ||
                      (op0_D) ||
                      (op0_E) ||
                      (op0_F);

assign op_is_size_3 = ((op0_1) && ((op1_0) || (op1_1) || (op1_2) || 
                                         (op1_3) || (op1_4) || (op1_6) ||
                                         (op1_7) || (op1_8) || (op1_C))) ||
                      (op0_4) ||
                      (op0_5) ||
                      ((op0_8) && ((op1_1) || (op1_2) || (op1_4) || (op1_5))) ||
                      (op0_A) ||
                      (op0_B);

assign op_is_size_3b = ((op0_8) && (op1_0) && (~((op2_8) || (op2_C) || 
                                                 (op2_D) || (op2_F))) ); // 

assign op_is_size_4 = ((op0_0) && (op1_E)) ||
                      ((op0_1) && (op1_5)) ||
                      (op0_6) ||
                      (op0_7);
// this needs a third nibble before its size is known
assign op_is_size_4b= ((op0_8) && (op1_0) && ((op2_8) || (op2_C) || 
                                              (op2_D) || (op2_F)));

assign op_is_size_5 = ((op0_8) && ((op1_3) || (op1_6) || (op1_7) || 
                                         (op1_8) || (op1_9) || (op1_A) ||
                                         (op1_B))) ||
                      (op0_9);

assign op_is_size_6 = ((op0_8) && ((op1_C) || (op1_E)));
assign op_is_size_7 = ((op0_8) && ((op1_D) || (op1_F)));

         
assign op_is_lc = (op0_3);
assign op_is_let_p = (op0_2); // P=n
assign op_is_la = ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h2));
assign op_is_as_Dn = (op0_1) && ((op1_6) || (op1_7) || (op1_8) || (op1_C)); // D0=D0+n D1=D1+n D0=D0-n D1=D1-n
assign op_is_let_st = (op0_8) && ((op1_4) || (op1_5)); // ST(n) =1/0
assign op_is_q_st = (op0_8) && ((op1_6) || (op1_7)); // ?ST=0  ?ST#0
assign op_is_q_p = (op0_8) && ((op1_8) || (op1_9));  // ?P=n ?P#n
assign op_is_let_ex_cp = (op0_8) && ((op1_0) && ((op2_C) || (op2_D) || 
                                                         (op2_F))); // C=P n P=C n CPEX n
assign op_cppp1 = op0_8 && op1_0 && op2_9; // C+P+1
assign op_lit_in_op1 = op_is_lc;
assign op_lit_in_op2 = op_is_let_st | op_is_q_st | op_is_q_p | op_is_as_Dn;
assign op_lit_in_op3 = op_is_let_ex_cp;
assign op_lit_in_op4 = op_is_la;
// fixed literals used by some instructions, this avoids extra reading ports and register widths
assign op_lit_1 = (op0_0 && (op1_C || op1_D)) || // P=P+/-1
                  (op0_A && (!op1[3]) && (op2_C || op2_D || op2_E || op2_F)) || // A=A-1
                  (op0_B && (!op1[3]) && (op2_4 || op2_5 || op2_6 || op2_7)) || // A=A+1
                  (op0_B && ( op1[3]) && (op2_C || op2_D || op2_E || op2_F)) || // A=A+1
                  (op0_C && (op1_C || op1_D || op1_E || op1_F)) ||              // A=A+1
                  (op0_E && (op1_4 || op1_5 || op1_6 || op1_7));                // A=A+1
                  
assign op_lit_9 = (op0_B && ( op1[3]) && (op2_C || op2_D || op2_E || op2_F)) || // A=-A-1
                  (op0_F && (op1_C || op1_D || op1_E || op1_F));                  // A=-A-1
// zero as op2
assign op_lit_0 = (op0_8 && op1_A && (op2[3] == 1'b1)) ||       // ?A=0 ?A#0
                  (op0_9 && (~op1[3]) && (op2[3] == 1'b1));     // ?A=0 ?A#0
assign op_lit_0_as_op1 = // dst=op1-op2 zero must be op1
                  (op0_B && (op1[3]) && (op2[3:2] == 2'b10)) || // A=-A, B=-B and so on
                  (op0_F && (op1[3:2] == 2'b10));   // A=-A, B=-B and so on
                  
assign op_lit_P = op_cppp1; // C+P+1
assign use_alu_lit_as_1 = op_lit_9 | op_lit_0_as_op1; // A=-A-1 ~ A=9-A, A=-A
assign use_alu_lit_as_2 = op_lit_0 | op_lit_1 | op_is_q_p | op_is_as_Dn | op_lit_P; // ?A=/#0 A=A+/-1
                  
                  
// a literal from the opcode is used by the alu 
assign op_has_lit = op_lit_in_op1 | op_lit_in_op2 | op_lit_in_op3 | op_lit_in_op4;
assign use_alu_lit = op_is_as_Dn;
                                                          
// this opcodes need the alu execute path, use either ABCD,RxDx,ST,STK
assign op_is_alu =    ((op0_0) && ((op1_6) || (op1_7) || (op1_8) || 
                                         (op1_9) || (op1_A) || (op1_B) ||
                                         (op1_C) || (op1_D) || (op1_E))) ||
                      (op0_1) ||
                      (op0_2) || // P=n
                      (op0_3) || // LC
                      ((op0_8) && (((op1_0) && ((op2[3:2] == 2'h0) || (op2_6) || (op2_8 && op3 == 4'h2) ||
                                                (op2_9) || (op2_C) || (op2_D) || (op2_F))) ||
                                   (op1_1) || (op1_A) || (op1_B))) ||
                      (op0_9) ||
                      (op0_A) ||
                      (op0_B) ||
                      (op0_C) ||
                      (op0_D) ||
                      (op0_E) ||
                      (op0_F);

assign op_goto_on_cond_set = ((op0_8) && ((op1_3) || (op1_6) ||
                                          (op1_7) || (op1_8) || (op1_9) ||
                                          (op1_A) || (op1_B))) || 
                             (op0_9);

assign op_rtn_on_carry_set = op_goto_on_cond_set && (op3 == 4'h9) && (op4 == 4'h9);

assign op_is_direct = !op_is_alu;

assign op_has_fetch = ((op0_1) && ((op1_9) || (op1_A) || (op1_B) || 
                                   (op1_D) || (op1_E) || (op1_F))) || // Dx=(n)
                      (op0_2) || // P=n
                      (op0_3) || // LC
                      ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h2)); // LA
assign op_has_write = ((op0_1) && (op1[3:1] == 3'b010)) && (op2[1] == 1'b0);
assign op_has_read  = ((op0_1) && (op1[3:1] == 3'b010)) && (op2[1] == 1'b1);

assign op_rw_with_lit_size = (op0_1 && op1_5 && (op2[3] == 1'b1));

assign op_jrel2 = (op0_4) || // GOC
                  (op0_5);   // GONC

assign op_jrel3 = (op0_6); // GOTO
                  
assign op_gosub = (op0_7); // GOSUB

assign op_j_on_c_set = (op0_4);
assign op_j_on_c_clr = (op0_5);
                  
assign op_jrel4 = (op0_8 && op1_C); // GOLONG
assign op_gosubl = (op0_8 && op1_E); // GOSUBL

assign op_jabs = ((op0_8) && (op1_D | op1_F)); // GOVLNG GOSBVL

assign op_push_ac = (op0_0 && op1_6); // RSTK=C
assign op_push_pc = op_gosub || op_gosubl ||
                    (op0_8 && op1_F); // GOSUBL GOSBVL

assign op_pop_pc =  (op0_0) && ((op1_0) || (op1_1) || (op1_2) || 
                                      (op1_3) || (op1_F));
assign op_pop_ac =  (op0_0 && op1_7);
 
assign op_setdec = (op0_0) && (op1_5);
assign op_sethex = (op0_0) && (op1_4);

assign op_uncnfg = (op0_8) && (op1_0) && (op2_4);
assign op_config = (op0_8) && (op1_0) && (op2_5);
assign op_shutdn = (op0_8) && (op1_0) && (op2_7);
assign op_intoff = (op0_8) && (op1_0) && (op2_8) && (op3 == 4'hF);
assign op_inton  = ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h0)) | ((op0_0) && (op1_F)); // INTON & RTI
assign op_reset  = (op0_8) && (op1_0) && (op2_A);

wire op_set_carry_on_zero, op_set_sb, op_set_xm, op_set_carry;
wire op_clr_carry, op_set_carry_on_carry, op_set_carry_on_eq;

// sets the sticky bit on carry set: used by shift bit, nibble
//assign op_set_sb_on_c_set = ((op0_8) && (op1_1) && (op2[3:2] == 2'b11)) || // A/B/C/DSRB
//                            ((op0_8) && (op1_8) && (op2[3] == 1'b0)) || // ASR/ASL
//                            ((op0_B) && (op1[3] == 1'h1) && (op2[3] == 1'b0)) || // ASR/ASL
//                            ((op0_F) && (op1[3] == 1'b0)); // ASR/ASL
                            
// sets the carry to the state of the zero flag. Used for C+P+1, 
assign op_set_carry_on_zero = ((op0_8) && (op1_0) && (op1_9));

assign op_set_xm =     ((op0_0) && (op1_0)); // RTNSXM
assign op_set_carry =  ((op0_0) && (op1_2)); // RTNSC
assign op_clr_carry =  ((op0_0) && (op1_3)); // RTNCC
// Carry will be set/cleared according to the result of the opcode
assign op_set_carry_on_carry = ((op0_0) && ((op1_C) || (op1_D))) || // P=P+/-1
                               ((op0_1) && ((op1_6) || (op1_7) ||   // D0=D0+ D1=D1+
                                                  (op1_8) || (op1_C))) || // D0=D0- D1=D1-
                               (op0_A && (~op1[3])) || 
                               (op0_B && (~op1[3])) || 
                               (op0_B && (op1[3]) && (op2[3])) || 
                               (op0_C) || // 
                               (op0_E) || // B=B-A
                               (op0_F && (op1[3])); // A=-A, A=9-A

assign op_set_carry_on_eq = ((op0_8) && ((op1_A) || (op1_B)) || (op0_9)); // ?A#/=0,ABCD ?B#/=0,ABCD,?A>...
// accept combinations too
assign op_clr_xm =  ((op0_8) && (op1_2) && (op2[0]));
assign op_clr_sb =  ((op0_8) && (op1_2) && (op2[1]));
assign op_clr_sr =  ((op0_8) && (op1_2) && (op2[2]));
assign op_clr_mp =  ((op0_8) && (op1_2) && (op2[3]));
assign op_clr_hst = ((op0_8) && (op1_2) && (op2_F));

assign op_tstxm         = op0_8 && op1_3 && op2_1;
assign op_tstmp         = op0_8 && op1_3 && op2_8;
assign op_tstsb         = op0_8 && op1_3 && op2_2;
assign op_tstsr         = op0_8 && op1_3 && op2_4;
assign op_clr_st_flag   = op0_8 && op1_4;
assign op_set_st_flag   = op0_8 && op1_5;
assign op_tst_0_st_flag = op0_8 && op1_6;
assign op_tst_1_st_flag = op0_8 && op1_7;

assign op_tst_p_eq_lit  = op0_8 && op1_9;
assign op_tst_p_neq_lit = op0_8 && op1_8;

assign op_force_carry = op_is_as_Dn | op_cppp1;
assign op_force_hex = op_is_as_Dn | op_cppp1 | ((op0_0) && ((op1_C) || (op1_D)));
assign op_data_reg = op2[0]; // for A=DATn/C=DATn & DATn=A/C

assign ofs_pc_rel2 = op0[3] ? { {12{op4[3]}}, op4, op3 }:{ {12{op2[3]}}, op2, op1 };
assign ofs_pc_rel3 = { {8{op3[3]}}, op3, op2, op1 };
assign ofs_pc_rel4 = { {4{op5[3]}}, op5, op4, op3, op2 };
assign new_pc_abs = { opcode[6], op5, op4, op3, op2 };
assign pc_plus1 = pc_in + 20'h1;
assign pc_plus2 = pc_in + 20'h2;
assign pc_plus3 = pc_in + 20'h3;
wire  op_dmux_shift_bit, op_dmux_shift_circular, op_dmux_shift_left, op_dmux_shift_right;
wire op_dmux_ltor, op_dmux_exchange, op_dmux_transfer, op_dmux_clear;
assign op_dmux_shift_bit        = (op0_8 && op1_1 && (op2[3:2] == 2'b11));
assign op_dmux_shift_circular   = (op0_8 && op1_1 && (op2[3] == 1'b0));
                                   
assign op_dmux_shift_left       = (op0_8 && op1_1 && (op2[3:2] == 2'b00)) ||  // ASLC
                                  (op0_B && (op1[3] == 1'b1) && (op2[3:2] == 2'b00)) || (op0_F && (op1[3:2] == 2'b00));// ASL
assign op_dmux_shift_right      = (op0_8 && op1_1 && (op2[2] == 1'b1)) || // ASRB/ASRC
                                  (op0_B && (op1[3] == 1'b1) && (op2[3:2] == 2'b01)) || (op0_F && (op1[3:2] == 2'b01)); // ASR

assign op_dmux_ltor             = op_dmux_shift_right || // ASRB, ASRC
                                  (op0_8 && (op1_A || op1_B ) ) ||
                                   op1_9;
                                   
assign op_dmux_exchange         = (op0_0 && op1_B) || // CSTEX
                                  (op0_1 && op1_2) || // AEXRn, CEXRn partial decoding
                                  (op0_1 && op1_3 && (op2[1] == 1'b1)) || // AEXDn CEXDn
                                  (op0_8 && op1_0 && op2_F) || // CPEX n
                                  (op0_A && (op1[3] == 1'b1) && (op2[3:2] == 2'b11)) || // ABEX and so on
                                  (op0_D && (op1[3:2] == 2'b11)); // ABEX and so on
                                  
assign op_dmux_transfer         = (op0_0 && (op1_6 || op1_7 || op1_9 || op1_A) ) || // RSTK=C, C=RSTK, C=ST, ST=C
                                  (op0_1 && op1_0) || // Rn=A, Rn=C partial decoding
                                  (op0_1 && op1_1) || // A=Rn, C=Rn partial decoding
                                  (op0_1 && op1_3 && (op2[1] == 1'b0)) || // Dn=A Dn=C
                                  (op0_8 && op1_0 && (op2[3:2] == 2'b00)) || // OUT=C, A=IN, C=IN
                                  (op0_8 && op1_0 && (op2[3:1] == 3'b110)) || // C=P n, P=C n
                                  (op0_A && (op1[3] == 1'b1) && ((op2[3:2] == 2'b01) || (op2[3:2] == 2'b10))) || //B=A
                                  (op0_D && ((op1[3:2] == 2'b01) || (op1[3:2] == 2'b10))); //B=A
                                  
assign op_dmux_clear            = (op0_0 && op1_B) || // CLRST
                                  (op0_A && (op1[3] == 1'b1) && (op2[3:2] == 2'b00)) || // A=0
                                  (op0_D && (op1[3:2] == 2'b00)); // A=0

/* Field decoder */
wire op_has_field;
wire [2:0] field;
wire [3:0] field_dec_start, field_dec_end;
assign field = (op0 == 4'h0) ? op2[2:0]: // 0 E a opcodes
               (op0 == 4'h1) ? op3[2:0]: // 1 5 X a opcodes
               op1[2:0]; // 9 a, A a, B a
assign op_has_field = (op0_0 && op1_E) |  // 0 E a opcodes
                      (op0_1 && op1_5 && (op2[3] == 1'b0)) |
                      (op0_9) | (op0_A) | (op0_B);

saturn_field_decoder field_decoder(
    .field_in(field), // 3 left most bits
    .p_in(reg_p_in), // register P
    .start_o(field_dec_start), 
    .end_o(field_dec_end)
    );

// fetch
always @(posedge clk_in) // or negedge reset_in)
    begin
        load_new_pc <= 1'b0; // not exe dependant
        irq_ack <= 1'b0;
        
		if (reset_in == 1'b1)
            state <= `ST_INIT;
		else
        case (state)
            `ST_INIT:
                begin
                    fetch_addr <= pc_in;
                    opcde_cnt <= 3'h0;
`ifdef HAS_TRACE_UNIT
                    state <= `ST_TRACE_START;
`else
                    state <= `ST_FETCH_ADDR;
`endif
                end
`ifdef HAS_TRACE_UNIT
            `ST_TRACE_START: // output address
                begin
                    trace_start <= 1'b1;
                    state <= `ST_TRACE;
                end
            `ST_TRACE: // wait for trace unit to finish transmission of data
                begin
                    if (trace_end_in)
                        state <= `ST_FETCH_ADDR;
                    trace_start <= 1'b0;
                end
`endif
            `ST_FETCH_ADDR:
                begin
                    if (irq_in & irqen_in)
                        begin
                            state <= `ST_INT_ACK_PUSH;
                        end
                    else
                        begin
                            state <= `ST_FETCH;
                            case (opcde_cnt)
                                3'h2: if (op_is_size_2) state <= `ST_DECODE;
                                3'h3: if (op_is_size_3 | op_is_size_3b) state <= `ST_DECODE;
                                3'h4: if (op_is_size_4 | op_is_size_4b) state <= `ST_DECODE;
                                3'h5: if (op_is_size_5) state <= `ST_DECODE;
                                3'h6: if (op_is_size_6) state <= `ST_DECODE;
                                3'h7: if (op_is_size_7) state <= `ST_DECODE;
                                    else // unrecognized opcode
                                        begin 
                                            // force reset or stop
                                            $display("Unknown opcode %06x:%x%x%x%x%x", pc_in, op0, op1, op2, op3, op4, op5);
                                            $finish;
                                        end
                            endcase
                        end
                end
            `ST_FETCH: // read
                if (mem_ack_in)
                    begin
                        opcode[opcde_cnt] <= data_in;
                        fetch_addr <= fetch_addr + 20'h1;
                        opcde_cnt <= opcde_cnt + 3'h1;
                        state <= `ST_FETCH_ADDR;
                    end
            `ST_INT_ACK_PUSH:
                begin // Push actual PC
                    state <= `ST_INT_ACK_JUMP;
                    irq_ack <= 1'b1;
                end
            `ST_INT_ACK_JUMP:
                begin // load new PC actual PC
                    state <= `ST_FETCH_ADDR;
                    fetch_addr <= 20'h0000F;
                    new_pc <= 20'h0000F;
                    load_new_pc <= 1'b1; // now load
                end
            `ST_DECODE:
                begin
					$display("%05X %s", pc_in, ascii_opcode);
                    if (op_is_let_p)
                        fetch_addr <= fetch_addr - 20'h1; // it went too far
                    if (op_goto_on_cond_set)
                        new_pc_jump <= pc_plus3 + ofs_pc_rel2;
                    if (op_jrel2)
                        new_pc_jump <= pc_plus1 + ofs_pc_rel2;
                    if (op_jrel3)
                        new_pc_jump <= pc_plus1 + ofs_pc_rel3;
                    if (op_jrel4)
                        new_pc_jump <= pc_plus2 + ofs_pc_rel4;
                    if (op_gosub)
                        new_pc_jump <= fetch_addr + ofs_pc_rel3; // GOSUB
                    if (op_gosubl)
                        new_pc_jump <= fetch_addr + ofs_pc_rel4; // GOSUBL
                    if (op_is_alu)
                        state <= `ST_EXE_INIT;
                    else
                        state <= `ST_EXE_END;
                    if (op_has_field)
                        begin
                            field_start <= field_dec_start;
                            field_end   <= field_dec_end;
                        end
                    else
                        begin
                            if (op_is_let_ex_cp) // literal used to indicate position
                                field_start <= op3;
                                else
                                    if (op_is_lc | op_is_la) 
                                        field_start <= reg_p_in;
                                    else
                                        field_start <= 4'h0;
                            if (op_is_lc) 
                                field_end <= reg_p_in + op1; // LC
                            else
                                if (op_is_la) field_end <= reg_p_in + op4; // LA
                                else
                                    if (op_is_let_ex_cp | op_rw_with_lit_size) // C=P n P=C n CPEX n, DAT0=A n A=DAT1 n
                                        field_end <= op3;
                                    else
                                        field_end   <= op_field_end;
                        end    
                            /*
                            case (op_field_start)
                                2'h0: begin end // field_start <= 4'h0;
                                2'h1: 
                                    begin 
                                        field_start <= reg_p_in; 
                                        if (op_is_lc) field_end <= reg_p_in + op1; // LC
                                        if (op_is_la) field_end <= reg_p_in + op4; // LA
                                    end
                                2'h2: field_end <= op3; // DATx=A/C n
                                2'h3: field_start <= 4'hf;
                            endcase
                        end
                    if (op_is_let_ex_cp) // literal used to indicate position
                        begin
                            field_start <= op3;
                            field_end <= op3;
                        end
                        */
                    alu_reg1    <= op_alu_reg1;
                    alu_reg2    <= op_alu_reg2;
                    alu_dst     <= op_alu_dst;
                    alu_op      <= op_alu_op;
                    dmux_op     <= op_dmux;
                    curr_data_addr <= data_addr_in; // sample data address
                    if (op_lit_in_op1)
                        alu_lit <= op1;
                    else
                        if (op_lit_in_op2)
                            alu_lit <= op2;
                        else
                            if (op_lit_in_op3)
                                alu_lit <= op3;
                            else
                                alu_lit <= op4;
                    if (op_lit_0 | op_lit_0_as_op1)
                        alu_lit <= 4'h0;
                    if (op_lit_1)
                        alu_lit <= 4'h1;
                    if (op_lit_9)
                        alu_lit <= 4'h9;
                    if (op_lit_P) // C+P+1
                        alu_lit <= reg_p_in;
                    if (op_push_pc) // force write-back of next PC for pushing onto the stack
                        begin
                            new_pc <= fetch_addr;
                            load_new_pc <= 1'b1; // now load
                        end
                end
            `ST_EXE_INIT:
                begin
                    field_counter <= field_end - field_start;
                    field_ofs <= 4'h1; // default increment pointer
                    field_start_op1 <= field_start;
                    state <= `ST_EXE_RUN;
                    alu_reg1_is_zero <= 1'b0;
                    case (dmux_op)
                        `DMUX_TFR, `DMUX_EX: begin end // dst = reg1
                        `DMUX_WR: begin state <= `ST_EXE_ADDR; end // memory i/o needs a special state machine
                        `DMUX_RD: begin state <= `ST_EXE_ADDR; end
                        `DMUX_IN: begin end
                        `DMUX_OUT: begin end
                        `DMUX_RTOL, `DMUX_CLR: begin end
                        `DMUX_SL: 
                            begin 
                                field_start_op1 <= field_end - 4'h1;
                                field_start <= field_end;
                                field_ofs <= 4'hf; // decrement pointer
                                alu_reg1_is_zero <= field_end == field_start; // shift a zero in for single nibble shifts
                            end
                        `DMUX_SR: 
                            begin 
                                field_start_op1 <= field_start + 4'h1;
                                alu_reg1_is_zero <= field_end == field_start; // shift a zero in for single nibble shifts
                            end
                        `DMUX_SLC: // use 14 exchanges for circular shifts
                            begin 
                                field_start_op1 <= field_end - 4'h1;
                                field_start <= field_end;
                                field_counter <= 4'he; // 14 exchanges
                                field_ofs <= 4'hf; // decrement pointer
                            end
                        `DMUX_SRC:  // use 14 exchanges for circular shifts
                            begin 
                                field_start_op1 <= field_start + 4'h1;
                                field_counter <= 4'he; // 14 exchanges
                            end
                        `DMUX_LTOR: // comparisons are done left to right
                            begin
                                field_start <=  field_end; // reversed order
                                field_start_op1 <= field_end;
                                field_ofs <= 4'hf; // decrement pointer
                            end
                    endcase
                end
            `ST_EXE_RUN: // Do ALU                
                begin
                    if (field_counter != 4'h0)
                        begin
                            field_counter <= field_counter - 4'h1;
                        end
                    else
                        state <= `ST_EXE_DONE;
                    if (!op_lit_9) // 9/F is used for every digit, all others are cleared after the first digit
                        alu_lit <= 4'h0; // the value is used only once and then it is replaced with zero

                    case (dmux_op)
                        `DMUX_SL, `DMUX_SR: //, `DMUX_SLC, `DMUX_SRC:
                            begin 
                                alu_reg1_is_zero <= (field_counter == 4'h1);
                            end
                    endcase
                    field_start <= field_start + field_ofs;
                    field_start_op1 <= field_start_op1 + field_ofs;
                end
            `ST_EXE_DONE: // write back results
                begin
                    state <= `ST_EXE_END;
                end
            `ST_EXE_ADDR: // read/write mem
                begin
                    // keep old values
                    state <= `ST_EXE_RW;
                end
            `ST_EXE_RW: // Do memory read (also P=n and LA/LC) and write
                begin
                    if (mem_ack_in)
                        begin
                            if (field_counter != 4'h0)
                                begin
                                    field_counter <= field_counter - 4'h1;
                                    state <= `ST_EXE_ADDR;
                                end
                            else
                                state <= `ST_EXE_END;

                            field_start <= field_start + field_ofs;
                            field_start_op1 <= field_start_op1 + field_ofs;
                            if (op_has_fetch)
                                fetch_addr <= fetch_addr + 20'h1;
                            else
                                curr_data_addr <= curr_data_addr + 20'h1;
                        end
                end
            `ST_EXE_END:
                begin
                    // calculate new PC
                    
                    if (op_jabs)
                        begin
                            new_pc <= new_pc_abs;
                            fetch_addr <= new_pc_abs;
                        end
                    else
                        if ((op_goto_on_cond_set & condtrue_in) |
                            (op_j_on_c_set & carry_in) |
                            (op_j_on_c_clr & ~carry_in) |
                            op_gosub | op_gosubl |
                            op_jrel3 | op_jrel4)                            
                            begin
                                new_pc <= new_pc_jump;
                                fetch_addr <= new_pc_jump;
                            end
                        else
                            if (~(op_gosub | op_gosubl))
                                new_pc <= fetch_addr; // we fetched as much as needed and thus we use that address as next i
                
                    alu_reg1_is_zero <= 1'b0;
                    if (!op_pop_pc)
                        load_new_pc <= 1'b1; // now load
                    if (op_pop_pc)
                        state <= `ST_NEW_FA;
                    else
`ifdef HAS_TRACE_UNIT
                        state <= `ST_TRACE_START;
`else
                        state <= `ST_FETCH_ADDR;
`endif
                    opcde_cnt <= 3'h0;
                end
            `ST_EXE_GOSUB:
                begin
                    new_pc <= new_pc_jump;
                    fetch_addr <= new_pc_jump;
                    state <= `ST_NEW_FA;
                end
            `ST_NEW_FA: // reloads the fetch address
                begin
                    fetch_addr <= pc_in;
`ifdef HAS_TRACE_UNIT
                    state <= `ST_TRACE_START;
`else
                    state <= `ST_FETCH_ADDR;
`endif
                end
        endcase
    end
/* Module outputs */

assign exe_o = (state == `ST_EXE_END) | (op_has_fetch & (state != `ST_EXE_END));
assign cpu_state_o = state;
assign use_fetch_addr_o = (state == `ST_FETCH_ADDR) | (state == `ST_FETCH) |
                          (((state == `ST_EXE_ADDR) | (state == `ST_EXE_RW)) & op_has_fetch);
assign fetch_read_o = (state == `ST_FETCH_ADDR) | (state == `ST_FETCH);
assign addr_o = fetch_addr; 
assign alu_op_o = alu_op;
assign alu_reg1_o = alu_reg1;
assign alu_reg2_o = alu_reg2;
assign alu_dst_o = alu_dst;

assign new_pc_o = new_pc;
assign irq_ack_o = irq_ack;

assign push_pc_o = (op_push_pc && (state == `ST_EXE_END)) || (state == `ST_INT_ACK_PUSH);
assign pop_pc_o = op_pop_pc && (state == `ST_EXE_END);
assign push_ac_o = op_push_ac && (state == `ST_EXE_INIT); // make place first and then move
assign pop_ac_o = op_pop_ac && (state == `ST_EXE_END);
assign load_new_pc_o = load_new_pc;
/* Sequencer */
assign dmux_o = dmux_op;
assign clr_o = (state == `ST_EXE_RUN) && ((dmux_op == `DMUX_CLR) || alu_reg1_is_zero);
assign tfr_o = (state == `ST_EXE_RUN) && ((dmux_op == `DMUX_TFR) || 
                                          (dmux_op == `DMUX_SL) || 
                                          (dmux_op == `DMUX_SR));// || 
                                          //(dmux_op == `DMUX_SLC) || 
                                          //(dmux_op == `DMUX_SRC));
                                         
assign ex_o = (state == `ST_EXE_RUN) && ((dmux_op == `DMUX_EX) ||
                                         (dmux_op == `DMUX_SLC) || 
                                         (dmux_op == `DMUX_SRC));
                                         
assign we_o = ((state == `ST_EXE_RW) && (dmux_op == `DMUX_RD)) || 
              (state == `ST_EXE_RUN) && ((dmux_op == `DMUX_RTOL) || 
                                         ((dmux_op == `DMUX_LTOR) && (op_alu_op == `ALU_SRB))|| 
                                         (dmux_op == `DMUX_RD)); 

assign mem_read_o = ((state == `ST_EXE_ADDR) | (state == `ST_EXE_RW)) & (op_has_read | op_has_fetch); // also used for LC/LA
assign mem_write_o = (state == `ST_EXE_RW) & (op_has_write);

assign op1_nib_o = field_start_op1;
assign op2_nib_o = field_start;
assign dst_nib_o = field_start;

assign alu_lit_o = alu_lit;
assign use_alu_lit_as_1_o = use_alu_lit_as_1;
assign use_alu_lit_as_2_o = use_alu_lit_as_2;

assign seq_o = (state == `ST_EXE_INIT) ? `SEQ_INIT:
               (state == `ST_EXE_RUN) | (state == `ST_EXE_RW) ?`SEQ_RUN:
               (state == `ST_EXE_DONE) ?`SEQ_DONE:`SEQ_IDLE;

assign setxm_o = op_set_xm;

assign alu_seq_last_nibble_o = ((state == `ST_EXE_RW) || (state == `ST_EXE_RUN)) && (field_counter == 4'h0);

assign setdec_o = op_setdec;// && (state == `ST_EXE_END);
assign sethex_o = op_sethex;// && (state == `ST_EXE_END);
assign setint_o = op_inton && (state == `ST_EXE_END);
assign clrxm_o = op_clr_xm && (state == `ST_EXE_END);
assign clrmp_o = op_clr_mp && (state == `ST_EXE_END);
assign clrsb_o = op_clr_sb && (state == `ST_EXE_END);
assign clrsr_o = op_clr_sr && (state == `ST_EXE_END);
assign clrint_o = op_intoff && (state == `ST_EXE_END);
assign clrhst_o = op_clr_hst && (state == `ST_EXE_END);

assign tstxm_o       = op_tstxm;
assign tstmp_o       = op_tstmp;
assign tstsb_o       = op_tstsb;
assign tstsr_o       = op_tstsr;
assign clrstflag_o   = op_clr_st_flag && (state == `ST_EXE_END);
assign tst_0_st_flag_o = op_tst_0_st_flag;
assign tst_1_st_flag_o = op_tst_1_st_flag;
assign setstflag_o   = op_set_st_flag && (state == `ST_EXE_END);
assign tst_p_eq_lit_o = op_tst_p_eq_lit;
assign tst_p_neq_lit_o = op_tst_p_neq_lit;
assign force_hex_o = op_force_hex;
assign force_carry_o = op_force_carry;
assign set_carry_o = op_set_carry;        
assign set_carry_on_carry_o = op_set_carry_on_carry;
assign set_carry_on_zero_o = op_set_carry_on_zero;
assign set_carry_on_eq_o = op_set_carry_on_eq;                 
assign clr_carry_o = op_clr_carry;
assign data_reg_o = op_data_reg;
assign data_addr_o = curr_data_addr;

`ifdef HAS_TRACE_UNIT
assign trace_start_o = trace_start;
`endif

/* Trace module for simulation */

`ifdef SIMULATOR
saturn_trace trace(
    .clk_in(clk_in),
    .opcode_in({ opcode[6], op5, op4, op3, op2, op1, op0 } ),
    .pc_in(pc_in),
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

initial
    begin
        fetch_addr = 20'h0; // initial PC
        state = 4'h0;
        opcode[1] = 4'h0;
        opcode[2] = 4'h0;
        opcode[3] = 4'h0;
        opcode[4] = 4'h0;
        opcode[5] = 4'h0;
        opcode[6] = 4'h0;
        opcode[7] = 4'h0;
        load_new_pc = 1'b0;
        seq_state = `SEQ_IDLE;
        irq_ack = 1'b0;
        trace_start = 1'b0;
    end
    
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
`ifdef SIMULATOR
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
    .opcode_in(last_opcode),
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
    input wire [27:0] opcode_in,
    input wire [19:0] pc_in,
    output wire [63:0] ascii_opcode_o
    );
    
reg [47:0] o;
wire [3:0] op0, op1, op2, op3, op4, op5;

assign ascii_opcode_o = use_xf ? { o, xfield }:{ o, xf2 };

assign op0 = opcode_in[3:0];
assign op1 = opcode_in[7:4];
assign op2 = opcode_in[11:8];
assign op3 = opcode_in[15:12];
assign op4 = opcode_in[19:16];
assign op5 = opcode_in[23:20];
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

assign sop = { opcode_in[0] > 4'h9 ? 8'h55+opcode_in[0]:8'h48+opcode_in[0],
               opcode_in[1] > 4'h9 ? 8'h55+opcode_in[1]:8'h48+opcode_in[1],
               opcode_in[2] > 4'h9 ? 8'h55+opcode_in[2]:8'h48+opcode_in[2],
               opcode_in[3] > 4'h9 ? 8'h55+opcode_in[3]:8'h48+opcode_in[3],
               opcode_in[4] > 4'h9 ? 8'h55+opcode_in[4]:8'h48+opcode_in[4] };
               
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
                    o = "LC   ";
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
                            4'h8: if (op3 == 4'hf) o = "INTOFF"; else o = "INTON ";
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

module saturn_microcode(
    input wire  [3:0] op0,
    input wire  [3:0] op1,
    input wire  [3:0] op2,
    input wire  [3:0] op3,
    output wire [3:0] op_field_end,  
    output wire [3:0] op_alu_reg1,
    output wire [3:0] op_alu_reg2,
    output wire [3:0] op_alu_dst,
    output wire [3:0] op_alu_op,
    output wire [3:0] op_dmux      
    );

reg [22:0] mc;

assign op_field_end      = { (mc[22:20] == 3'h7) ? 1'b1:1'b0, mc[22:20] };
assign op_dmux           = mc[19:16];
assign op_alu_op         = mc[15:12];
assign op_alu_reg1       = mc[11: 8];
assign op_alu_reg2       = mc[ 7: 4];
assign op_alu_dst        = mc[ 3: 0];

always @(*)
    casex ({op0, op1, op2, op3})
        // order left to right
        // field_start 0:0, 01:f, 10 = P
        // field_end 0, 1, 2, 3, 4, f
        // alu_op
        // alu_reg1
        // alu_reg2
        // alu_dst
        //                               fend   dmux     alu_op     reg1    reg2     dst
        16'b0000_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_C  , `OP_STK };//RSTK=C
        16'b0000_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_STK, `OP_STK, `OP_C   };//C=RSTK
        16'b0000_1000_xxxx_xxxx: mc = { 3'h2,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_ST , `OP_ST  };//CLRST
        16'b0000_1001_xxxx_xxxx: mc = { 3'h2,`DMUX_TFR ,`ALU_ADD , `OP_ST , `OP_ST , `OP_C   };//C=ST
        16'b0000_1010_xxxx_xxxx: mc = { 3'h2,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_C  , `OP_ST  };//ST=C
        16'b0000_1011_xxxx_xxxx: mc = { 3'h2,`DMUX_EX  ,`ALU_ADD , `OP_ST , `OP_C  , `OP_C   };//CSTEX
        16'b0000_1100_xxxx_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_P  , `OP_1  , `OP_P   };//P=P+1
        16'b0000_1101_xxxx_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_P  , `OP_1  , `OP_P   };//P=P-1
        // 0Ean 0EFn                    
        16'b0000_1110_xxxx_0000: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_A  , `OP_B  , `OP_A   };//A=A&B
        16'b0000_1110_xxxx_0001: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_B  , `OP_C  , `OP_B   };//B=B&C
        16'b0000_1110_xxxx_0010: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_C  , `OP_A  , `OP_C   };//A=A&B
        16'b0000_1110_xxxx_0011: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_D  , `OP_C  , `OP_D   };//B=B&C
        16'b0000_1110_xxxx_0100: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_B  , `OP_A  , `OP_B   };//A=A&B
        16'b0000_1110_xxxx_0101: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_C  , `OP_B  , `OP_C   };//B=B&C
        16'b0000_1110_xxxx_0110: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_A  , `OP_C  , `OP_A   };//A=A&B
        16'b0000_1110_xxxx_0111: mc = { 3'h2,`DMUX_RTOL,`ALU_AND , `OP_C  , `OP_D  , `OP_C   };//B=B&C
        16'b0000_1110_xxxx_1000: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_A  , `OP_B  , `OP_A   };//A=A!B
        16'b0000_1110_xxxx_1001: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_B  , `OP_C  , `OP_B   };//B=B!C
        16'b0000_1110_xxxx_1010: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_C  , `OP_A  , `OP_C   };//A=A!B
        16'b0000_1110_xxxx_1011: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_D  , `OP_C  , `OP_D   };//B=B!C
        16'b0000_1110_xxxx_1100: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_B  , `OP_A  , `OP_B   };//A=A!B
        16'b0000_1110_xxxx_1101: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_C  , `OP_B  , `OP_C   };//B=B!C
        16'b0000_1110_xxxx_1110: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_A  , `OP_C  , `OP_A   };//A=A!B
        16'b0000_1110_xxxx_1111: mc = { 3'h2,`DMUX_RTOL,`ALU_OR  , `OP_C  , `OP_D  , `OP_C   };//B=B!C
        // 10 A=Rn C=Rn                 
        16'b0001_0000_0000_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_R0  };
        16'b0001_0000_0001_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_R1  };
        16'b0001_0000_0010_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_R2  };
        16'b0001_0000_0011_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_R3  };
        16'b0001_0000_0100_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_R4  };
        16'b0001_0000_1000_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_R0  };
        16'b0001_0000_1001_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_R1  };
        16'b0001_0000_1010_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_R2  };
        16'b0001_0000_1011_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_R3  };
        16'b0001_0000_1100_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_R4  };
        // 11n A=Rn C=Rn                
        16'b0001_0001_0000_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R0 , `OP_A  , `OP_A   };
        16'b0001_0001_0001_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R1 , `OP_A  , `OP_A   };
        16'b0001_0001_0010_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R2 , `OP_A  , `OP_A   };
        16'b0001_0001_0011_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R3 , `OP_A  , `OP_A   };
        16'b0001_0001_0100_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R4 , `OP_A  , `OP_A   };
        16'b0001_0001_1000_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R0 , `OP_A  , `OP_C   };
        16'b0001_0001_1001_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R1 , `OP_A  , `OP_C   };
        16'b0001_0001_1010_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R2 , `OP_A  , `OP_C   };
        16'b0001_0001_1011_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R3 , `OP_A  , `OP_C   };
        16'b0001_0001_1100_xxxx: mc = { 3'h7,`DMUX_TFR ,`ALU_ADD , `OP_R4 , `OP_A  , `OP_C   };
        // 12n ARnEX CRnEX                             reg1     reg2     dst
        16'b0001_0010_0000_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R0 , `OP_A  , `OP_A   };
        16'b0001_0010_0001_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R1 , `OP_A  , `OP_A   };
        16'b0001_0010_0010_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R2 , `OP_A  , `OP_A   };
        16'b0001_0010_0011_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R3 , `OP_A  , `OP_A   };
        16'b0001_0010_0100_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R4 , `OP_A  , `OP_A   };
        16'b0001_0010_1000_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R0 , `OP_C  , `OP_C   };
        16'b0001_0010_1001_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R1 , `OP_C  , `OP_C   };
        16'b0001_0010_1010_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R2 , `OP_C  , `OP_C   };
        16'b0001_0010_1011_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R3 , `OP_C  , `OP_C   };
        16'b0001_0010_1100_xxxx: mc = { 3'h7,`DMUX_EX  ,`ALU_ADD , `OP_R4 , `OP_C  , `OP_C   };
        // 13n                          
        16'b0001_0011_0000_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D0  };
        16'b0001_0011_0001_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D1  };
        16'b0001_0011_0010_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_D0 , `OP_A  , `OP_A   };
        16'b0001_0011_0011_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_D1 , `OP_A  , `OP_A   };
        16'b0001_0011_0100_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D0  };
        16'b0001_0011_0101_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D1  };
        16'b0001_0011_0110_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_D0 , `OP_C  , `OP_C   };
        16'b0001_0011_0111_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_D1 , `OP_C  , `OP_C   };
        16'b0001_0011_1000_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D0  };
        16'b0001_0011_1001_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D1  };
        16'b0001_0011_1010_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_D0 , `OP_A  , `OP_A   };
        16'b0001_0011_1011_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_D1 , `OP_A  , `OP_A   };
        16'b0001_0011_1100_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D0  };
        16'b0001_0011_1101_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D1  };
        16'b0001_0011_1110_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_D0 , `OP_C  , `OP_C   };
        16'b0001_0011_1111_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_D1 , `OP_C  , `OP_C   };
        // DATn=A/C  A/C=DATn           
        16'b0001_0100_0000_xxxx: mc = { 3'h4,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_0001_xxxx: mc = { 3'h4,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_0010_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_0011_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_0100_xxxx: mc = { 3'h4,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0100_0101_xxxx: mc = { 3'h4,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0100_0110_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0100_0111_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0100_1000_xxxx: mc = { 3'h1,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_1001_xxxx: mc = { 3'h1,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_1010_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_1011_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0100_1100_xxxx: mc = { 3'h1,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0100_1101_xxxx: mc = { 3'h1,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0100_1110_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0100_1111_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        // DATn=A/C  A/C=DATn           
        16'b0001_0101_0000_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_0001_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_0010_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_0011_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_0100_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0101_0101_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0101_0110_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0101_0111_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0101_1000_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_1001_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_1010_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_1011_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b0001_0101_1100_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0101_1101_xxxx: mc = { 3'h0,`DMUX_WR  ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b0001_0101_1110_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b0001_0101_1111_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        // D0+D0+n                     
        16'b0001_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_D0 , `OP_A  , `OP_D0  }; // D0=D0+n
        16'b0001_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_D1 , `OP_A  , `OP_D1  }; // D1=D1+n
        16'b0001_1000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_D0 , `OP_A  , `OP_D0  }; // D0=D0-n
                                        
        // Dx=(n)                       
        16'b0001_1001_xxxx_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D0  };
        16'b0001_1010_xxxx_xxxx: mc = { 3'h3,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D0  };
        16'b0001_1011_xxxx_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D0  };
        16'b0001_1100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_D1 , `OP_A  , `OP_D1  }; // D1=D1-n
        16'b0001_1101_xxxx_xxxx: mc = { 3'h1,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D1  };
        16'b0001_1110_xxxx_xxxx: mc = { 3'h3,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D1  };
        16'b0001_1111_xxxx_xxxx: mc = { 3'h4,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_D1  };
        //                              
        16'b0010_xxxx_xxxx_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_P   }; // P=n
        16'b0011_xxxx_xxxx_xxxx: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   }; // LC(n)
        // 80x                                                      reg1    reg2      dst
        16'b1000_0000_0000_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_OUT }; // OUT=C
        16'b1000_0000_0001_xxxx: mc = { 3'h2,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_OUT }; // OUT=C
        16'b1000_0000_0010_xxxx: mc = { 3'h3,`DMUX_TFR ,`ALU_ADD , `OP_IN , `OP_A  , `OP_A   }; // A=IN
        16'b1000_0000_0011_xxxx: mc = { 3'h3,`DMUX_TFR ,`ALU_ADD , `OP_IN , `OP_A  , `OP_C   }; // C=IN
        16'b1000_0000_0110_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_ID , `OP_A  , `OP_C   }; // C=ID, 
        // 8082 LA(n) starting at P witath
        16'b1000_0000_1000_0010: mc = { 3'h0,`DMUX_RD  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        //809 C+P+1, carry is forced set1, literal used with P
        16'b1000_0000_1001_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_P  , `OP_C   }; // sets carry if end filed is zero
                                        
        16'b1000_0000_1100_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_P  , `OP_A  , `OP_C   }; // C=P n
        16'b1000_0000_1101_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_P   }; // P=C n
        16'b1000_0000_1111_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_C  , `OP_P  , `OP_P   }; // CPEX n
        // 81x ASLC/ASRC/ASRB          
        16'b1000_0001_0000_xxxx: mc = { 3'h7,`DMUX_SLC ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // ASLC
        16'b1000_0001_0001_xxxx: mc = { 3'h7,`DMUX_SLC ,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   }; // BSLC
        16'b1000_0001_0010_xxxx: mc = { 3'h7,`DMUX_SLC ,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   }; // CSLC
        16'b1000_0001_0011_xxxx: mc = { 3'h7,`DMUX_SLC ,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // DSLC
        16'b1000_0001_0100_xxxx: mc = { 3'h7,`DMUX_SRC ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   };
        16'b1000_0001_0101_xxxx: mc = { 3'h7,`DMUX_SRC ,`ALU_ADD , `OP_B  , `OP_A  , `OP_B   };
        16'b1000_0001_0110_xxxx: mc = { 3'h7,`DMUX_SRC ,`ALU_ADD , `OP_C  , `OP_A  , `OP_C   };
        16'b1000_0001_0111_xxxx: mc = { 3'h7,`DMUX_SRC ,`ALU_ADD , `OP_D  , `OP_A  , `OP_D   };
        16'b1000_0001_1100_xxxx: mc = { 3'h7,`DMUX_LTOR,`ALU_SRB , `OP_A  , `OP_A  , `OP_A   };
        16'b1000_0001_1101_xxxx: mc = { 3'h7,`DMUX_LTOR,`ALU_SRB , `OP_B  , `OP_A  , `OP_B   };
        16'b1000_0001_1110_xxxx: mc = { 3'h7,`DMUX_LTOR,`ALU_SRB , `OP_C  , `OP_A  , `OP_C   };
        16'b1000_0001_1111_xxxx: mc = { 3'h7,`DMUX_LTOR,`ALU_SRB , `OP_D  , `OP_A  , `OP_D   };
        // 8Ax                          
        16'b1000_1010_0000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1010_0001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1010_0010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_C  , `OP_A   };
        16'b1000_1010_0011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_C  , `OP_D  , `OP_A   };
        16'b1000_1010_0100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1010_0101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1010_0110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_C  , `OP_A   };
        16'b1000_1010_0111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_C  , `OP_D  , `OP_A   };
        16'b1000_1010_1000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_Z  , `OP_A   };
        16'b1000_1010_1001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_B  , `OP_Z  , `OP_A   };
        16'b1000_1010_1010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_C  , `OP_Z  , `OP_A   };
        16'b1000_1010_1011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_EQ  , `OP_D  , `OP_Z  , `OP_A   };
        16'b1000_1010_1100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_Z  , `OP_A   };
        16'b1000_1010_1101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_B  , `OP_Z  , `OP_A   };
        16'b1000_1010_1110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_C  , `OP_Z  , `OP_A   };
        16'b1000_1010_1111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_NEQ , `OP_D  , `OP_Z  , `OP_A   };
        // 8B                          
        16'b1000_1011_0000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1011_0001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1011_0010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_C  , `OP_A  , `OP_A   };
        16'b1000_1011_0011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_D  , `OP_C  , `OP_A   };
        16'b1000_1011_0100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1011_0101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1011_0110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_C  , `OP_A  , `OP_A   };
        16'b1000_1011_0111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_D  , `OP_C  , `OP_A   };
        16'b1000_1011_1000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1011_1001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1011_1010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_C  , `OP_A  , `OP_A   };
        16'b1000_1011_1011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_D  , `OP_C  , `OP_A   };
        16'b1000_1011_1100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_A  , `OP_B  , `OP_A   };
        16'b1000_1011_1101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_B  , `OP_C  , `OP_A   };
        16'b1000_1011_1110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_C  , `OP_A  , `OP_A   };
        16'b1000_1011_1111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_D  , `OP_C  , `OP_A   };
        // 9a                           
        16'b1001_0xxx_0000_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_B  , `OP_A   };
        16'b1001_0xxx_0001_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_B  , `OP_C  , `OP_A   };
        16'b1001_0xxx_0010_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_C  , `OP_A   };
        16'b1001_0xxx_0011_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_C  , `OP_D  , `OP_A   };
        16'b1001_0xxx_0100_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_B  , `OP_A   };
        16'b1001_0xxx_0101_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_B  , `OP_C  , `OP_A   };
        16'b1001_0xxx_0110_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_C  , `OP_A   };
        16'b1001_0xxx_0111_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_C  , `OP_D  , `OP_A   };
        16'b1001_0xxx_1000_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_A  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1001_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_B  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1010_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_C  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1011_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_EQ  , `OP_D  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1100_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_A  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1101_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_B  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1110_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_C  , `OP_Z  , `OP_A   };
        16'b1001_0xxx_1111_xxxx: mc = { 3'h0,`DMUX_LTOR,`ALU_NEQ , `OP_D  , `OP_Z  , `OP_A   };
        // 9b                           
        16'b1001_1xxx_0000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_A  , `OP_B  , `OP_A   };
        16'b1001_1xxx_0001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_B  , `OP_C  , `OP_A   };
        16'b1001_1xxx_0010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_C  , `OP_A  , `OP_A   };
        16'b1001_1xxx_0011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GT  , `OP_D  , `OP_C  , `OP_A   };
        16'b1001_1xxx_0100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_A  , `OP_B  , `OP_A   };
        16'b1001_1xxx_0101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_B  , `OP_C  , `OP_A   };
        16'b1001_1xxx_0110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_C  , `OP_A  , `OP_A   };
        16'b1001_1xxx_0111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LT  , `OP_D  , `OP_C  , `OP_A   };
        16'b1001_1xxx_1000_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_A  , `OP_B  , `OP_A   };
        16'b1001_1xxx_1001_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_B  , `OP_C  , `OP_A   };
        16'b1001_1xxx_1010_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_C  , `OP_A  , `OP_A   };
        16'b1001_1xxx_1011_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_GTEQ, `OP_D  , `OP_C  , `OP_A   };
        16'b1001_1xxx_1100_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_A  , `OP_B  , `OP_A   };
        16'b1001_1xxx_1101_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_B  , `OP_C  , `OP_A   };
        16'b1001_1xxx_1110_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_C  , `OP_A  , `OP_A   };
        16'b1001_1xxx_1111_xxxx: mc = { 3'h4,`DMUX_LTOR,`ALU_LTEQ, `OP_D  , `OP_C  , `OP_A   };
        // Aa                           
        16'b1010_0xxx_0000_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_B  , `OP_A   }; // A=A+B
        16'b1010_0xxx_0001_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_C  , `OP_B   };
        16'b1010_0xxx_0010_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_A  , `OP_C   };
        16'b1010_0xxx_0011_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_C  , `OP_D   };
        16'b1010_0xxx_0100_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // A=A+A
        16'b1010_0xxx_0101_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   };
        16'b1010_0xxx_0110_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   };
        16'b1010_0xxx_0111_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // D=D+D
        16'b1010_0xxx_1000_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_A  , `OP_B   };
        16'b1010_0xxx_1001_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_B  , `OP_C   };
        16'b1010_0xxx_1010_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_C  , `OP_A   };
        16'b1010_0xxx_1011_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_D  , `OP_C   };
        16'b1010_0xxx_1100_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_1  , `OP_A   };
        16'b1010_0xxx_1101_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_1  , `OP_B   };
        16'b1010_0xxx_1110_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_1  , `OP_C   };
        16'b1010_0xxx_1111_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_1  , `OP_D   };
        //Ab                            
        16'b1010_1xxx_0000_xxxx: mc = { 3'h0,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_A   }; // A=0
        16'b1010_1xxx_0001_xxxx: mc = { 3'h0,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_B   };
        16'b1010_1xxx_0010_xxxx: mc = { 3'h0,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_C   };
        16'b1010_1xxx_0011_xxxx: mc = { 3'h0,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_D   };
        16'b1010_1xxx_0100_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_B  , `OP_A  , `OP_A   }; // A=B 
        16'b1010_1xxx_0101_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_B   };
        16'b1010_1xxx_0110_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b1010_1xxx_0111_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D   }; // D=C
        16'b1010_1xxx_1000_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_B   };
        16'b1010_1xxx_1001_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_B  , `OP_A  , `OP_C   };
        16'b1010_1xxx_1010_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b1010_1xxx_1011_xxxx: mc = { 3'h0,`DMUX_TFR ,`ALU_ADD , `OP_D  , `OP_A  , `OP_C   };
        16'b1010_1xxx_1100_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_B  , `OP_A  , `OP_A   };
        16'b1010_1xxx_1101_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_C  , `OP_B  , `OP_B   };
        16'b1010_1xxx_1110_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_A  , `OP_C  , `OP_C   };
        16'b1010_1xxx_1111_xxxx: mc = { 3'h0,`DMUX_EX  ,`ALU_ADD , `OP_C  , `OP_D  , `OP_D   };
        //Ba                            
        16'b1011_0xxx_0000_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_B  , `OP_A   }; // A=A-B
        16'b1011_0xxx_0001_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_C  , `OP_B   };
        16'b1011_0xxx_0010_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_A  , `OP_C   };
        16'b1011_0xxx_0011_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_C  , `OP_D   };
        16'b1011_0xxx_0100_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_1  , `OP_A   }; // A=A+1
        16'b1011_0xxx_0101_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_1  , `OP_B   };
        16'b1011_0xxx_0110_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_1  , `OP_C   };
        16'b1011_0xxx_0111_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_1  , `OP_D   }; // D=D+1
        16'b1011_0xxx_1000_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_A  , `OP_B   }; // B=B-A
        16'b1011_0xxx_1001_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_B  , `OP_C   };
        16'b1011_0xxx_1010_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_C  , `OP_A   };
        16'b1011_0xxx_1011_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_D  , `OP_C   }; // C=C-D
        16'b1011_0xxx_1100_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_B  , `OP_A   }; // A=A-B
        16'b1011_0xxx_1101_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_B  , `OP_B   };
        16'b1011_0xxx_1110_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_C  , `OP_C   };
        16'b1011_0xxx_1111_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_D  , `OP_D   }; // D=C-D
        //Bb                            
        16'b1011_1xxx_0000_xxxx: mc = { 3'h0,`DMUX_SL  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // ASL
        16'b1011_1xxx_0001_xxxx: mc = { 3'h0,`DMUX_SL  ,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   }; // BSL
        16'b1011_1xxx_0010_xxxx: mc = { 3'h0,`DMUX_SL  ,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   }; // CSL
        16'b1011_1xxx_0011_xxxx: mc = { 3'h0,`DMUX_SL  ,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // DSL
        16'b1011_1xxx_0100_xxxx: mc = { 3'h0,`DMUX_SR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // ASR
        16'b1011_1xxx_0101_xxxx: mc = { 3'h0,`DMUX_SR  ,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   }; // BSR
        16'b1011_1xxx_0110_xxxx: mc = { 3'h0,`DMUX_SR  ,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   }; // CSR
        16'b1011_1xxx_0111_xxxx: mc = { 3'h0,`DMUX_SR  ,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // DSR
        16'b1011_1xxx_1000_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_A  , `OP_A   }; // A=0-A
        16'b1011_1xxx_1001_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_B  , `OP_B   }; // B=0-B
        16'b1011_1xxx_1010_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_C  , `OP_C   }; // C=0-C
        16'b1011_1xxx_1011_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_D  , `OP_D   }; // D=0-D
        16'b1011_1xxx_1100_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_9  , `OP_A   }; // A=-A-1 == A=A-9
        16'b1011_1xxx_1101_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_9  , `OP_B   };
        16'b1011_1xxx_1110_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_9  , `OP_C   };
        16'b1011_1xxx_1111_xxxx: mc = { 3'h0,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_9  , `OP_D   };
        // C                            
        16'b1100_0000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_B  , `OP_A   }; // A=A+B
        16'b1100_0001_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_C  , `OP_B   };
        16'b1100_0010_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_A  , `OP_C   };
        16'b1100_0011_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_C  , `OP_D   };
        16'b1100_0100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // A=A+A
        16'b1100_0101_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   };
        16'b1100_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   };
        16'b1100_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // D=D+D
        16'b1100_1000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_A  , `OP_B   };
        16'b1100_1001_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_B  , `OP_C   };
        16'b1100_1010_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_C  , `OP_A   };
        16'b1100_1011_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_D  , `OP_C   };
        16'b1100_1100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_1  , `OP_A   };
        16'b1100_1101_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_1  , `OP_B   };
        16'b1100_1110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_1  , `OP_C   };
        16'b1100_1111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_1  , `OP_D   };
        //D                             
        16'b1101_0000_xxxx_xxxx: mc = { 3'h4,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_A   }; // A=0
        16'b1101_0001_xxxx_xxxx: mc = { 3'h4,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_B   };
        16'b1101_0010_xxxx_xxxx: mc = { 3'h4,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_C   };
        16'b1101_0011_xxxx_xxxx: mc = { 3'h4,`DMUX_CLR ,`ALU_ADD , `OP_Z  , `OP_A  , `OP_D   };
        16'b1101_0100_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_B  , `OP_A  , `OP_A   }; // A=B 
        16'b1101_0101_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_B   };
        16'b1101_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_C   };
        16'b1101_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_D   }; // D=C
        16'b1101_1000_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_A  , `OP_A  , `OP_B   };
        16'b1101_1001_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_B  , `OP_A  , `OP_C   };
        16'b1101_1010_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_C  , `OP_A  , `OP_A   };
        16'b1101_1011_xxxx_xxxx: mc = { 3'h4,`DMUX_TFR ,`ALU_ADD , `OP_D  , `OP_A  , `OP_C   };
        16'b1101_1100_xxxx_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_B  , `OP_A  , `OP_A   };
        16'b1101_1101_xxxx_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_C  , `OP_B  , `OP_B   };
        16'b1101_1110_xxxx_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_A  , `OP_C  , `OP_C   };
        16'b1101_1111_xxxx_xxxx: mc = { 3'h4,`DMUX_EX  ,`ALU_ADD , `OP_C  , `OP_D  , `OP_D   };
        //E                             
        16'b1110_0000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_B  , `OP_A   }; // A=A-B
        16'b1110_0001_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_C  , `OP_B   };
        16'b1110_0010_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_A  , `OP_C   };
        16'b1110_0011_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_C  , `OP_D   };
        16'b1110_0100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_A  , `OP_1  , `OP_A   }; // A=A-1
        16'b1110_0101_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_B  , `OP_1  , `OP_B   };
        16'b1110_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_C  , `OP_1  , `OP_C   };
        16'b1110_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_ADD , `OP_D  , `OP_1  , `OP_D   }; // D=D-1
        16'b1110_1000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_A  , `OP_B   }; // B=B-A
        16'b1110_1001_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_B  , `OP_C   };
        16'b1110_1010_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_C  , `OP_A   };
        16'b1110_1011_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_D  , `OP_C   }; // C=C-D
        16'b1110_1100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_B  , `OP_A   }; // A=A-B
        16'b1110_1101_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_B  , `OP_B   };
        16'b1110_1110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_C  , `OP_C   };
        16'b1110_1111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_D  , `OP_D   }; // D=C-D
        //F                             
        16'b1111_0000_xxxx_xxxx: mc = { 3'h4,`DMUX_SL  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // ASL
        16'b1111_0001_xxxx_xxxx: mc = { 3'h4,`DMUX_SL  ,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   };
        16'b1111_0010_xxxx_xxxx: mc = { 3'h4,`DMUX_SL  ,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   };
        16'b1111_0011_xxxx_xxxx: mc = { 3'h4,`DMUX_SL  ,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   };
        16'b1111_0100_xxxx_xxxx: mc = { 3'h4,`DMUX_SR  ,`ALU_ADD , `OP_A  , `OP_A  , `OP_A   }; // ASR
        16'b1111_0101_xxxx_xxxx: mc = { 3'h4,`DMUX_SR  ,`ALU_ADD , `OP_B  , `OP_B  , `OP_B   };
        16'b1111_0110_xxxx_xxxx: mc = { 3'h4,`DMUX_SR  ,`ALU_ADD , `OP_C  , `OP_C  , `OP_C   };
        16'b1111_0111_xxxx_xxxx: mc = { 3'h4,`DMUX_SR  ,`ALU_ADD , `OP_D  , `OP_D  , `OP_D   }; // DSR
        16'b1111_1000_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_A  , `OP_A   }; // A=0-A
        16'b1111_1001_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_B  , `OP_B   }; // B=0-B
        16'b1111_1010_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_C  , `OP_C   }; // C=0-C
        16'b1111_1011_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_Z  , `OP_D  , `OP_D   }; // D=0-D
        16'b1111_1100_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_A  , `OP_9  , `OP_A   }; // A=-A-1 == A=A-9
        16'b1111_1101_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_B  , `OP_9  , `OP_B   };
        16'b1111_1110_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_C  , `OP_9  , `OP_C   };
        16'b1111_1111_xxxx_xxxx: mc = { 3'h4,`DMUX_RTOL,`ALU_SUB , `OP_D  , `OP_9  , `OP_D   };
        
        default:
            mc = { 3'h0,`DMUX_RTOL,`ALU_ADD, `OP_A  , `OP_A  , `OP_A   };
    endcase
    
endmodule

