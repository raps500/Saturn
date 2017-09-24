/*
 * Test bench for Parallel 1LF2 top entity
 *
 *
 *
 */
`timescale 1ns/1ns
 
module tb_llf2_alru();

reg clk;

reg [ 0: 0] write_dst_in      ;
reg [ 0: 0] write_op1_in      ;
reg [ 0: 0] latch_alu_regs_in ;
reg [ 0: 0] forced_carry_in   ;
reg [ 1: 0] op1_type_reg_in   ;
reg [ 2: 0] op1_reg_in        ;
reg [ 1: 0] dst_type_reg_in   ;
reg [ 3: 0] dst_reg_in        ;
reg [ 1: 0] alu_dest_mux_in   ;
reg [ 0: 0] decimal_in        ;
reg [63: 0] data_in           ;
reg [ 3: 0] left_mask_in      ;
reg [ 3: 0] right_mask_in     ;
reg [ 3: 0] alu_op_in         ;
reg [19: 0] addr_in           ;
reg [ 0: 0] testeq_0_bit_a_in ;
reg [ 0: 0] testeq_0_bit_c_in ;
reg [ 0: 0] testeq_1_bit_a_in ;
reg [ 0: 0] testeq_1_bit_c_in ;
reg [ 0: 0] testeq_0_bit_st_in;
reg [ 0: 0] testeq_1_bit_st_in;
reg [ 0: 0] clr_bit_st_in     ;
reg [ 0: 0] set_bit_st_in     ;
reg [ 0: 0] clr_carry_in      ;
reg [ 0: 0] set_carry_in      ;
reg [ 0: 0] inc_p_in          ;
reg [ 0: 0] dec_p_in          ;
reg [ 0: 0] tsteq_p_in        ;
reg [ 0: 0] tstneq_p_in       ;
reg [ 0: 0] write_p_in        ;
reg [ 0: 0] add_pc_in         ;
reg [ 0: 0] load_pc_in        ;
reg [ 0: 0] push_pc_in        ;
reg [ 0: 0] pop_pc_in         ;
reg [15: 0] IN_in             ;
reg [ 0: 0] write_d0_5_in     ;
reg [ 0: 0] write_d1_5_in     ;
reg [ 0: 0] write_d0_4_in     ;
reg [ 0: 0] write_d1_4_in     ;
reg [ 0: 0] dp_sel_in         ;
              

saturn_alru alru(
	.clk_in                 (clk),
    .write_dst_in           (write_dst_in      ),       
    .write_op1_in           (write_op1_in      ),       
    .latch_alu_regs_in      (latch_alu_regs_in ),	
    .forced_carry_in        (forced_carry_in   ),
    .op1_type_reg_in        (op1_type_reg_in   ),    
    .op1_reg_in             (op1_reg_in        ),         
    .dst_type_reg_in        (dst_type_reg_in   ),    
    .dst_reg_in             (dst_reg_in        ),
    .alu_dest_mux_in        (alu_dest_mux_in   ),
    .decimal_in             (decimal_in        ), 
    .data_in                (data_in           ),
    .data_o                 (data_o            ),
    .left_mask_in           (left_mask_in      ),       
    .right_mask_in          (right_mask_in     ),
    .alu_op_in              (alu_op_in         ),
    .addr_in                (addr_in           ), 
    .testeq_0_bit_a_in      (testeq_0_bit_a_in ),  
    .testeq_0_bit_c_in      (testeq_0_bit_c_in ),
    .testeq_1_bit_a_in      (testeq_1_bit_a_in ),
    .testeq_1_bit_c_in      (testeq_1_bit_c_in ),
    .testeq_0_bit_st_in     (testeq_0_bit_st_in), 
    .testeq_1_bit_st_in     (testeq_1_bit_st_in),
    .clr_bit_st_in          (clr_bit_st_in     ),      
    .set_bit_st_in          (set_bit_st_in     ),
    .clr_carry_in           (clr_carry_in     ),      
    .set_carry_in           (set_carry_in     ),
    .carry_o                (carry_o           ),            
    .condition_true_o       (condition_true_o  ),
    .inc_p_in               (inc_p_in          ),
    .dec_p_in               (dec_p_in          ),
    .tsteq_p_in             (tsteq_p_in        ),
    .tstneq_p_in            (tstneq_p_in       ),
    .write_p_in             (write_p_in        ),
    .add_pc_in              (add_pc_in         ),          
    .load_pc_in             (load_pc_in        ),         
    .push_pc_in             (push_pc_in        ),         
    .pop_pc_in              (pop_pc_in         ),          
    .PC_o                   (PC_o              ),
    .IN_in                  (IN_in             ),
    .OUT_o                  (OUT_o             ),
    .write_d0_5_in          (write_d0_5_in     ),
    .write_d1_5_in          (write_d1_5_in     ),
    .write_d0_4_in          (write_d0_4_in     ),
	.write_d1_4_in          (write_d1_4_in     ),
    .dp_sel_in              (dp_sel_in         ),          
    .Dn_o                   (Dn_o              )
    );
    
//always 
//	#100 clk = ~clk;   //  5 MHz clock
	
initial
	begin
	$dumpfile("tb_llf2_alru.vcd");
    $dumpvars();
	clk                = 1'b0;
	write_dst_in       =  'h0;
    write_op1_in       =  'h0;
    latch_alu_regs_in  =  'h0;
    forced_carry_in    =  'h0;
    op1_type_reg_in    =  'h0;
    op1_reg_in         =  'h0;
    dst_type_reg_in    =  'h0;
    dst_reg_in         =  'h0;
    alu_dest_mux_in    =  'h0;
    decimal_in         =  'h0;
    data_in            =  'h0;
    left_mask_in       =  'h0;
    right_mask_in      =  'h0;
    alu_op_in          =  'h0;
    addr_in            =  'h0;
    testeq_0_bit_a_in  =  'h0;
    testeq_0_bit_c_in  =  'h0;
    testeq_1_bit_a_in  =  'h0;
    testeq_1_bit_c_in  =  'h0;
    testeq_0_bit_st_in =  'h0;
    testeq_1_bit_st_in =  'h0;
    clr_bit_st_in      =  'h0;
    set_bit_st_in      =  'h0;
    inc_p_in           =  'h0;
    dec_p_in           =  'h0;
    tsteq_p_in         =  'h0;
    tstneq_p_in        =  'h0;
    write_p_in         =  'h0;
    add_pc_in          =  'h0;
    load_pc_in         =  'h0;
    push_pc_in         =  'h0;
    pop_pc_in          =  'h0;
    IN_in              =  'h0;
	write_d0_5_in      =  'h0;
	write_d1_5_in      =  'h0;
	write_d0_4_in      =  'h0;
	write_d1_4_in      =  'h0;
	dp_sel_in          =  'h0;
	#100
    clk                = 1'b1;
    #100
    clk                = 1'b0;
    
	// Load to A test
    data_in            =  64'h123456789ABCDEF1;
	left_mask_in       =   4'hf;
    right_mask_in      =   4'h0;
	dst_type_reg_in    =  2'b00;
    dst_reg_in          = 4'h0; // A
    latch_alu_regs_in   = 1'b1;
    alu_op_in           = 4'h3; // TFR
    #100
    clk                = 1'b1;
    #100
    clk                = 1'b0;
    latch_alu_regs_in  = 1'b0;
    write_dst_in       = 1'b1;
    #100
    clk                = 1'b1;
    #100
    clk                = 1'b0;
    write_dst_in       = 1'b0;
    
	#200 $finish; 
	end
	
	
endmodule
