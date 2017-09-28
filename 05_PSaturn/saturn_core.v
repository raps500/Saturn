/* 1LF2 - core
 *
 * 1LF2 (Saturn) serial core
 *
 * Uses 4 bit internal & external buses
 *
 */
`include "saturn_defs.v"


module saturn_core(
    input wire          clk_in,
	input wire          reset_in,
    input wire          irq_in,
    output wire         irq_ack_o,
    output wire         irq_en_o,
    output wire [19:0]  addr_o,
    output wire         oe_o,
    output wire         we_o,

    output wire [15:0]  data_o,
    input wire [15:0]   data_in,
    input wire          mem_ack_in,

    output wire [11:0]  oport_o,            // output port
    input wire [15:0]   iport_in            // input port
`ifdef HAS_TRACE_UNIT
    ,
    output wire         txd_o
`endif

    );


// External memory interface
wire [19:0] bus_addr;
wire bus_rd_n;
wire bus_we_n;
wire [15:0] bus_data_from_mem;
wire [15:0] bus_data_to_mem;
// Internal fetch bus

wire ibus_flush_queue;  // asserted to indicate that the pre-fetch queue must be flush and a new address should be used
wire ibus_fetch;        // asserted to indicate that a fetch is needed
wire ibus_fetch_ack;    // fetch acknowledged
wire [19:0] ibus_addr;  // address used when the queue has been flushed due to jump
wire [83:0] ibus_pre_opcode; // pre-fetched opcode, can be decoded directly
wire [4:0] ibus_pre_opcode_length; // length of opcode in the pre-fetched buffer
wire [19:0] ibus_pre_fetched_opcode_addr;
wire ibus_ready;        // the current pre-fetch buffer has a valid opcode

// Internal Data interface
wire [19:0] data_addr;  // address of the current transfer
wire [3:0] data_size;   // size in nibbles of the current transfer
wire [63:0] data_to_mem;// data register to write or read
wire [63:0] data_from_mem;  // read data from memory, register aligned
wire data_read;         // read data from memory strobe
wire data_write;        // write data to memory strobe
wire data_read_ready;   // read data from memory completed
wire data_write_ready;  // write data to memory completed

assign data_read = 1'b0;
assign data_write = 1'b0;

wire [ 0: 0] seq_write_dst         ;
wire [ 0: 0] seq_write_op1         ;
wire [ 0: 0] seq_latch_alu_regs    ;
wire [ 0: 0] seq_forced_carry      ;
wire [ 0: 0] seq_forced_hex        ;
wire [ 5: 0] seq_op1_reg           ;
wire [ 5: 0] seq_op2_reg           ;
wire [ 5: 0] seq_dst_reg           ;
wire [63: 0] seq_op_literal        ;
wire [ 0: 0] seq_set_decimal       ;
wire [ 0: 0] seq_set_hex           ;
wire [63: 0] bus_data_from_memory  ;
wire [63: 0] alru_data_to_memory   ;
wire [ 3: 0] seq_field_left        ;
wire [ 3: 0] seq_field_right       ;
wire [ 4: 0] seq_alu_op            ;
wire [19: 0] seq_addr              ;
wire [ 0: 0] seq_write_carry       ;
wire [ 0: 0] seq_write_sticky_bit  ;
wire [ 0: 0] seq_clr_carry         ;
wire [ 0: 0] seq_set_carry         ;
wire [ 0: 0] alru_carry            ;
wire [ 3: 0] alru_P                ;
wire [ 0: 0] seq_shift_alu_q       ;
wire [ 0: 0] seq_add_pc            ;
wire [ 0: 0] seq_load_pc           ;
wire [ 0: 0] seq_push_rstk         ;
wire [ 0: 0] seq_pull_rstk         ;
wire [19: 0] alru_PC               ;
wire [15: 0] bus_IN                ;
wire [11: 0] alru_OUT              ;
wire [ 0: 0] seq_dp_sel_in         ;
wire [19: 0] alru_Dn               ;

saturn_bus_controller bus_ctrl(
    .clk_in                             (clk_in),           // BUS and cpu c

    .bus_addr_o                         (addr_o),           // address bus,
    .bus_rd_o                           (oe_o),             // read strobe
    .bus_we_o                           (we_o),             // write strobe

    .bus_data_in                        (data_in),          // read data bus
    .bus_data_o                         (data_o),           // write data bus

    .bus_data_io                        (),    // bidirectional

    .ibus_addr_in                       (ibus_addr),        // new fetch address
    .ibus_flush_q_in                    (ibus_flush_queue), // force flush t
    .ibus_fetch_in                      (ibus_fetch),       // fetch strobe,
    .ibus_fetch_ack_in                  (ibus_fetch_ack),   // fetch acknowledge

    .ibus_pre_fetched_opcode_o          (ibus_pre_opcode),  // pre fetched opcode
    .ibus_pre_fetched_opcode_length_o   (ibus_pre_opcode_length), // length
    .ibus_pre_fetched_opcode_addr_o     (ibus_pre_fetched_opcode_addr), // address
    .ibus_ready_o                       (ibus_ready),       // asserted when opcode is fully loaded

    .data_addr_in                       (data_addr),        // data address
    .data_size_in                       (data_size),        // size of data
    .data_data_in                       (data_to_mem),      // data to be written
    .data_field_left_in                 (seq_field_left),  // data mask
    .data_field_right_in                (seq_field_right), // data mask

    .data_data_o                        (data_from_mem),    // read data
    .data_read_in                       (data_read),
    .data_write_in                      (data_write),
    .data_read_ready_o                  (data_read_ready),
    .data_write_ready_o                 (data_write_ready)
);

saturn_decoder_sequencer dec_seq(
    .clk_in                 (clk_in),
    .reset_in               (reset_in),
    .irq_in                 (),
    .irqen_in               (),
    .irq_ack_o              (),

    .ibus_addr_o            (ibus_addr),
    .ibus_flush_q_o         (ibus_flush_queue),
    .ibus_fetch_o           (ibus_fetch),
    .ibus_fetch_ack_o       (ibus_fetch_ack),
    .ibus_pre_fetched_opcode_in         (ibus_pre_opcode),
    .ibus_pre_fetched_opcode_length_in  (ibus_pre_opcode_length),
    .ibus_pre_fetched_opcode_addr_in    (ibus_pre_fetched_opcode_addr),
    .ibus_ready_in          (ibus_ready),

    .write_dst_o            (seq_write_dst),
    .write_op1_o            (seq_write_op1),
    .latch_alu_regs_o       (seq_latch_alu_regs),
    .forced_carry_o         (seq_forced_carry),
    .forced_hex_o           (seq_forced_hex        ),
    .op1_reg_o              (seq_op1_reg),
    .op2_reg_o              (seq_op2_reg),
    .dst_reg_o              (seq_dst_reg),
    .op_literal_o           (seq_op_literal),
    .set_decimal_o          (seq_set_decimal),
    .set_hexadecimal_o      (seq_set_hex),
    .left_mask_o            (seq_field_left ),
    .right_mask_o           (seq_field_right),
    .alu_op_o               (seq_alu_op),
    .addr_o                 (seq_addr),
    .write_sticky_bit_o     (seq_write_sticky_bit),
    .write_carry_o          (seq_write_carry),
    .clr_carry_o            (seq_clr_carry),
    .set_carry_o            (seq_set_carry),
    .carry_in               (alru_carry),
    .shift_alu_q_o          (seq_shift_alu_q       ),
    .reg_P_in               (alru_P                ),
    .add_pc_o               (seq_add_pc),
    .load_pc_o              (seq_load_pc),
    .push_rstk_o            (seq_push_rstk         ),
    .pull_rstk_o            (seq_pull_rstk         ),
    .PC_in                  (alru_PC),
    .dp_sel_o               (seq_dp_sel_in),
    .Dn_in                  (alru_Dn)
);

saturn_alru alru(
	.clk_in                 (clk_in                ),
    .write_dst_in           (seq_write_dst         ),
    .write_op1_in           (seq_write_op1         ),
    .latch_alu_regs_in      (seq_latch_alu_regs    ),
    .forced_carry_in        (seq_forced_carry      ),
    .forced_hex_in          (seq_forced_hex        ),
    .op1_reg_in             (seq_op1_reg           ),
    .op2_reg_in             (seq_op2_reg           ),
    .dst_reg_in             (seq_dst_reg           ),
    .set_decimal_in         (seq_set_decimal       ),
    .set_hexadecimal_in     (seq_set_hex           ),
    .data_in                (bus_data_from_memory  ),
    .data_o                 (alru_data_to_memory   ),
    .left_mask_in           (seq_field_left        ),
    .right_mask_in          (seq_field_right       ),
    .alu_op_in              (seq_alu_op            ),
    .op_literal_in          (seq_op_literal        ),
    .write_sticky_bit_in    (seq_write_sticky_bit),
    .write_carry_in         (seq_write_carry),
    .clr_carry_in           (seq_clr_carry         ),
    .set_carry_in           (seq_set_carry         ),
    .carry_o                (alru_carry            ),
    .shift_alu_q_in         (seq_shift_alu_q       ),
    .P_o                    (alru_P                ),
    .add_pc_in              (seq_add_pc            ),
    .push_rstk_in           (seq_push_rstk         ),
    .pull_rstk_in           (seq_pull_rstk         ),
    .bwrite_fetched_pc_in   (ibus_ready            ), // write back fetched PC
    .fetched_PC_in          (ibus_pre_fetched_opcode_addr),
    .PC_o                   (alru_PC               ),
    .IN_in                  (bus_IN                ),
    .OUT_o                  (alru_OUT              ),
    .dp_sel_in              (seq_dp_sel_in         ),
    .Dn_o                   (alru_Dn               )
    );


/*
llf2_flags_unit flags_unit(
    .clk_in(clk_in),
    .exe_in(execute),

    .sethex_in(sethex),
    .setdec_in(setdec),
    .setxm_in(setxm),
    .setmp_in(setmp),
    .setsb_in(setsb | set_stickybit_from_alu),
    .setsr_in(setsr),
    .setint_in(setint),
    .clrxm_in(clrxm),
    .clrmp_in(clrmp),
    .clrsb_in(clrsb),
    .clrsr_in(clrsr),
    .tstxm_in(tstxm),
    .tstmp_in(tstmp),
    .tstsb_in(tstsb),
    .tstsr_in(tstsr),
    .clrint_in(clrint),
    .clrhst_in(clrhst),
    .set_carry_in(set_carry | set_carry_from_alu | test_cond_true_st | test_cond_true_hst),
    .clr_carry_in(clr_carry | clr_carry_from_alu | test_cond_false_st),
    .irqen_o(irqen),
    .dec_o(decimal),
    .carry_o(carry),
    .test_cond_true_o(test_cond_true_hst)
    );

`ifdef HAS_TRACE_UNIT
llf2_trace_unit tu(
    .clk_in(clk_in),
    .reset_in(reset_in),       // asserted high reset

    .data_in(alu_op1),        // register data at current address
    .op1_nib_in(op1_nib),     // nibble address of register 1 from decoder unit
    .reg_op1_in(reg_op1),    // alu operand, register 1 from decoder unit
    .pc_in(pc),          // alu operand, register 1 from decoder unit

    .op1_nib_o(trace_op1_nib),      // address of operand 1 nibble to register unit
    .reg_op1_o(trace_reg_op1),     // alu operand, register 1 to register unit

    .trace_start_in(trace_start), // assert to start trace
    .trace_end_o(trace_end),    // wait for this signal to proceed with next intsruction

    .txd_o(txd_o)    // serial data
    );
`endif
*/

endmodule


/* A hw/sw flags unit
 * with 3 functions
 * set, clear, test
 */
module llf2_flags_unit(
    input wire          clk_in,
    input wire          exe_in,

    input wire          sethex_in,
    input wire          setdec_in,
    input wire          setxm_in,
    input wire          setmp_in,
    input wire          setsb_in,
    input wire          setsr_in,
    input wire          setint_in,
    input wire          clrxm_in,
    input wire          clrmp_in,
    input wire          clrsb_in,
    input wire          clrsr_in,
    input wire          tstxm_in,
    input wire          tstmp_in,
    input wire          tstsb_in,
    input wire          tstsr_in,
    input wire          clrint_in,
    input wire          clrhst_in,
    input wire          set_carry_in,
    input wire          clr_carry_in,
    output wire         irqen_o,        // interrupts enabled
    output wire         dec_o,
    output wire         carry_o,
    output wire         test_cond_true_o

    );

reg dec;
reg carry;
reg xm; // external module missing
reg mp; // module pulled
reg sb; // sticky bit
reg sr; // Service request
reg irqen;

assign dec_o = dec;
assign carry_o = carry;
assign irqen_o = irqen;

assign test_cond_true_o = (tstxm_in && (~xm)) || (tstmp_in && (~mp)) || (tstsb_in && (~sb)) || (tstsr_in && (~sr));

always @(posedge clk_in)
    begin
        if (sethex_in & exe_in) dec <= 1'b0;
        if (setdec_in & exe_in) dec <= 1'b1;
        if (setxm_in) xm <= 1'b1;
        if (clrxm_in | clrhst_in) xm <= 1'b0;
        if (setmp_in) mp <= 1'b1;
        if (clrmp_in | clrhst_in) mp <= 1'b0;
        if (setsb_in) sb <= 1'b1;
        if (clrsb_in | clrhst_in) sb <= 1'b0;
        if (setsr_in) sr <= 1'b1;
        if (clrsr_in | clrhst_in) sr <= 1'b0;
        if (set_carry_in & exe_in) carry <= 1'b1;
        if (clr_carry_in & exe_in) carry <= 1'b0;
        if (setint_in & exe_in) irqen <= 1'b1;
        if (clrint_in & exe_in) irqen <= 1'b0;
    end
initial
    begin
        xm = 1'b0;
        sb = 1'b0;
        sr = 1'b0;
        mp = 1'b0;
        dec = 1'b0; // starts in hex mode
        carry = 1'b0;
        irqen = 1'b0;
    end
endmodule

/* 6 nibbles 1LG3 Timer
 *
 */

module llg3_Timer #(parameter TimerNum = 0)
(
    input wire          clk_in,     // processor clock

    input wire          clk_512Hz_in,   // 512 Hz clock
    input wire          irq_enabled_in,
    input wire          irq_ack_in,
    input wire          read_in,
    input wire          write_in,
    input wire [3:0]    addr_in,

    output reg [3:0]    data_o,
    input wire [3:0]    data_in,
    output wire         irq_o
    );

reg [3:0] timer[6:0];

reg irq_pending, ozero;
reg oclk_512;
wire zero = { timer[5], timer[4], timer[3], timer[2], timer[1], timer[0] } == 24'h0;

assign irq_o = irq_pending;

always @(posedge clk_in)
    begin
        if (irq_ack_in)
            irq_pending <= 1'b0;
        oclk_512 <= clk_512Hz_in;

        if (read_in)
            begin
                data_o <= timer[addr_in];
                $display("RT%d: [%x]=%x", TimerNum, addr_in, timer[addr_in]);
            end
        if (write_in)
            begin
               timer[addr_in] <= data_in;
               $display("WT%d: [%x]:%x", TimerNum, addr_in, data_in);
            end


        if ((oclk_512 == 1'b0) && (clk_512Hz_in == 1'b1))
            begin
                ozero <= zero;
                if (~zero) // decrement timer if not zero
                    { timer[5], timer[4], timer[3], timer[2], timer[1], timer[0] } <= { timer[5], timer[4], timer[3], timer[2], timer[1], timer[0] } - 24'h1;
                if ((ozero == 1'b0) && (zero == 1'b1))
                    if (irq_enabled_in == 1'b1)
                        irq_pending <= 1'b1;
            end
    end

initial
    begin
        irq_pending = 1'b0;
        timer[0] = 4'h0;
        timer[1] = 4'h0;
        timer[2] = 4'h0;
        timer[3] = 4'h0;
        timer[4] = 4'h0;
        timer[5] = 4'h0;
    end
endmodule
/* 800x600 60 Hz with 40 MHz clock */
module vga_out(
	input wire			clk_in,

	input wire [9:0] 	addr_in,
	input wire 			we_in,
	input wire [3:0]	data_in,

	output wire			vsync_o,
	output wire			hsync_o,

	output wire			white_o
	);

reg vsync, hsync, white;
reg [10:0] vsync_cnt, hsync_cnt;

reg [3:0] lcdram1[127:0];
reg [3:0] lcdram2[127:0];
reg [3:0] lcdram3[127:0];
wire visible;
assign visible = ((vsync_cnt < 11'd600) && (hsync_cnt < 11'd800));

wire [6:0] addr;

assign addr = { hsync_cnt[7:2], vsync_cnt[3] };
wire [3:0] datas1, datas2, datam;

assign datas1 = lcdram1[addr];
assign datas2 = lcdram2[addr];
assign datam  = lcdram3[addr];

assign vsync_o = vsync;
assign hsync_o = hsync;
assign white_o  = white;

always @(posedge clk_in)
	begin
		if (we_in)
			case (addr_in[9:8])
				2'b01:lcdram1[addr_in[6:0]] <= data_in; // slave1 left most 48 columns
				2'b10:lcdram2[addr_in[6:0]] <= data_in; // slave2 center columns
				2'b11:lcdram3[addr_in[6:0]] <= data_in; // master rightmost columns
			endcase

		if (hsync_cnt == 11'd1055)
			begin
				if (vsync_cnt == 11'd627)
					vsync_cnt <= 11'd0;
				else
					vsync_cnt <= vsync_cnt + 11'd1;
				hsync_cnt <= 11'd0;
			end
		else
			hsync_cnt <= hsync_cnt + 11'd1;


		if (hsync_cnt == 11'd839)
			hsync <= 1'b1; // positive pulse
		if (hsync_cnt == 11'd968)
			hsync <= 1'b0;

		if (vsync_cnt == 11'd600)
			vsync <= 1'b1; // positive pulse
		if (vsync_cnt == 11'd604)
			vsync <= 1'b0;

		// manage visible
		white <= 1'b0;
		// 136 x 8 48 +
		if (visible)
			begin

				// border
				if ((vsync_cnt == 11'd0) || (vsync_cnt == 11'd599))
					white <= 1'b1;
				if ((hsync_cnt == 11'd0) || (hsync_cnt == 11'd799))
					white <= 1'b1;
				if (vsync_cnt < 11'd16)
					begin
						if (hsync_cnt < 11'd192)
							begin
								case (vsync_cnt[2:1])
									2'd0:	white <= datas1[0];
									2'd1:	white <= datas1[1];
									2'd2:	white <= datas1[2];
									2'd3:	white <= datas1[3];
								endcase
							end
						else
							if (hsync_cnt < 11'd384)
								begin
									case (vsync_cnt[2:1])
										2'd0:	white <= datas2[0];
										2'd1:	white <= datas2[1];
										2'd2:	white <= datas2[2];
										2'd3:	white <= datas2[3];
									endcase
								end
							else
								if (hsync_cnt < 11'd576)
									begin
										case (vsync_cnt[2:1])
											2'd0:	white <= datam[0];
											2'd1:	white <= datam[1];
											2'd2:	white <= datam[2];
											2'd3:	white <= datam[3];
										endcase
									end
					end

			end

	end

initial
    begin
        hsync_cnt = 0;
        vsync_cnt = 0;
        vsync = 0;
        hsync = 0;
    end

endmodule
/**
 *
 *
 *
 *
 *
 */

module llf2_trace_unit(
    input wire          clk_in,
    input wire          reset_in,       // asserted high reset

    input wire [3:0]    data_in,        // register data at current address
    input wire [3:0]    op1_nib_in,     // nibble address of register 1 from decoder unit
    input wire [3:0]    reg_op1_in,     // alu operand, register 1 from decoder unit
    input wire [19:0]   pc_in,          // current PC

    output wire [3:0]   op1_nib_o,      // address of operand 1 nibble to register unit
    output wire [3:0]   reg_op1_o,     // alu operand, register 1 to register unit

    input wire          trace_start_in, // assert to start trace
    output reg          trace_end_o,    // wait for this signal to proceed with next intsruction

    output  wire        txd_o           // serial data
    );

wire [7:0] tx_data;
wire [7:0] hex_data;
reg [6:0] state, next_state;
reg [4:0] name_addr;
reg [7:0] name;
reg [3:0] reg_size, size;
reg [3:0] reg_nummer;
reg [3:0] reg_nibble;
reg is_hex, is_space, is_lf, is_colon, is_name, is_pc, is_reg;
wire tx_busy;
reg tx_start;
wire [3:0] pc_data;

assign op1_nib_o = is_reg ? reg_nibble:op1_nib_in;
assign reg_op1_o = is_reg ? reg_nummer:reg_op1_in;

assign pc_data = reg_nibble == 4'h0 ? pc_in[ 3: 0]:
                 reg_nibble == 4'h1 ? pc_in[ 7: 4]:
                 reg_nibble == 4'h2 ? pc_in[11: 8]:
                 reg_nibble == 4'h3 ? pc_in[15:12]:pc_in[19:16];



assign hex_data = is_pc ? ((pc_data > 4'h9) ? (8'd55 + pc_data):(8'h30 + pc_data)):
                          ((data_in > 4'h9) ? (8'd55 + data_in):(8'h30 + data_in));

assign tx_data = is_hex     ? hex_data:
                 is_space   ? 8'h20:
                 is_lf      ? 8'h0a:
                 is_colon   ? ":":
                 is_name    ? name:8'h20;

async_transmitter txer(
    .clk(clk_in),
    .TxD_start(tx_start),
    .TxD_data(tx_data),
    .TxD(txd_o),
    .TxD_busy(tx_busy)
);
always @(*)
    case (name_addr)
        5'h00: name = "A";
        5'h01: name = " ";
        5'h02: name = "B";
        5'h03: name = " ";
        5'h04: name = "C";
        5'h05: name = " ";
        5'h06: name = "D";
        5'h07: name = " ";
        5'h08: name = "R";
        5'h09: name = "0";
        5'h0a: name = "R";
        5'h0b: name = "1";
        5'h0c: name = "R";
        5'h0d: name = "2";
        5'h0e: name = "R";
        5'h0f: name = "3";
        5'h10: name = "R";
        5'h11: name = "4";
        5'h12: name = "D";
        5'h13: name = "0";
        5'h14: name = "D";
        5'h15: name = "1";
        5'h16: name = "S";
        5'h17: name = "T";
        5'h18: name = "S";
        5'h19: name = "K";
        5'h1a: name = "I";
        5'h1b: name = "N";
        5'h1c: name = "P";
        5'h1d: name = "C";
        5'h1e: name = "P";
        5'h1f: name = " ";
    endcase
always @(*)
    case (name_addr[4:1])
        4'h0: size = 4'hf;
        4'h1: size = 4'hf;
        4'h2: size = 4'hf;
        4'h3: size = 4'hf;
        4'h4: size = 4'hf;
        4'h5: size = 4'hf;
        4'h6: size = 4'hf;
        4'h7: size = 4'hf;
        4'h8: size = 4'hf;
        4'h9: size = 4'h4;
        4'ha: size = 4'h4; // D0
        4'hb: size = 4'h3;
        4'hc: size = 4'h4; // STK
        4'hd: size = 4'h3; // Input register 16 bits
        4'he: size = 4'h4; // PC
        4'hf: size = 4'h0; // P
    endcase


always @(posedge clk_in)
    begin
        trace_end_o <= 1'b0;
        if (tx_busy)
            tx_start <= 1'b0;
        if (reset_in)
            state <= 'h0;
        else
            begin
                case (state)
                    6'h00:
                        begin
                            if (trace_start_in)
                                state <= 6'h01;
                        end
                    6'h01:
                        begin
                            next_state <= 6'h02;
                            name_addr <= 5'h1c; // start with PC
                            state <= 6'h10;
                        end
                    6'h02:
                        begin
                            next_state <= 6'h02;
                            if (name_addr == 5'h1b)
                                state <= 6'h03;
                            else
                                state <= 6'h10;
                            name_addr <= name_addr + 5'h01;
                        end
                    6'h03:
                        begin
                            is_lf <= 1'b1;
                            tx_start <= 1'b1;
                            state <= 6'h04;
                        end
                    6'h04:
                        if (tx_busy)
                            begin
                                state <= 6'h05;
                            end
                    6'h05:
                        if (!tx_busy)
                            begin
                                is_lf <= 1'b0;
                                state <= 6'h00;
                                trace_end_o <= 1'b1; // signal end of tracing
                            end
                    // outputs the content of a register
                    6'h10:  begin // first letter of name
                                is_name <= 1'b1;
                                tx_start <= 1'b1;
                                state <= 6'h11;
                            end
                    6'h11:
                        if (tx_busy)
                            begin
                                state <= 6'h12;
                            end
                    6'h12:// second letter of name
                        if (!tx_busy)
                            begin
                                tx_start <= 1'b1;
                                name_addr <= name_addr + 5'h1;
                                state <= 6'h13;
                            end
                    6'h13:
                        if (tx_busy)
                            begin
                                state <= 6'h14;
                            end
                    6'h14:// colon
                        if (!tx_busy)
                            begin
                                tx_start <= 1'b1;
                                state <= 6'h15;
                                is_name <= 1'b0;
                                is_colon <= 1'b1;
                            end
                    6'h15:
                        if (tx_busy)
                            begin
                                state <= 6'h16;
                            end
                    6'h16: // white space
                        if (!tx_busy)
                            begin
                                tx_start <= 1'b1;
                                state <= 6'h17;
                                is_space <= 1'b1;
                                is_colon <= 1'b0;
                            end
                    6'h17:
                        if (tx_busy)
                            begin
                                state <= 6'h18;
                                is_reg <= 1'b1;
                                is_space <= 1'b0;
                                reg_nummer <= name_addr[4:1];
                                //reg_size <= size;
                                reg_nibble <= size; // first nibble to display
                                is_hex <= 1'b1;
                                if (name_addr[4:1] == 4'he)
                                    is_pc <= 1'b1;
                                else
                                    is_pc <= 1'b0;
                            end
                    6'h18: // register value
                        if (!tx_busy)
                            begin
                                tx_start <= 1'b1;
                                state <= 6'h19;
                            end
                    6'h19:
                        if (tx_busy)
                            begin
                                state <= 6'h1a;
                            end
                    6'h1a:
                        if (reg_nibble != 4'h0)
                            begin
                                reg_nibble <= reg_nibble - 4'h1;
                                state <= 6'h18;
                            end
                        else
                            state <= 6'h1b;
                    6'h1b: // white space
                        if (!tx_busy)
                            begin
                                tx_start <= 1'b1;
                                state <= 6'h1c;
                                is_space <= 1'b1;
                                is_reg <= 1'b0;
                                is_hex <= 1'b0;
                            end
                    6'h1c:
                        if (tx_busy)
                            begin
                                is_space <= 1'b0;
                                state <= 6'h1d;
                            end
                    6'h1d: // wait for it to finish
                        if (!tx_busy)
                            begin
                                state <= next_state;
                            end
                endcase
            end

    end

initial
    begin
        is_colon = 1'b0;
        is_lf = 1'b0;
        is_space = 1'b0;
        is_hex = 1'b0;
        is_pc = 1'b0;
        is_reg = 1'b0;
        state = 'h0;
        tx_start = 1'b0;
    end

endmodule
/**
 *
 * Asynchronous transmitter, the clock should be the bit clock
 *
 */
module async_transmitter(
	input wire clk,
	input wire TxD_start,
	input wire [7:0] TxD_data,
	output wire TxD,
	output wire TxD_busy
);

////////////////////////////////

wire BitTick = 1'b1;  // output one bit per clock cycle

reg [3:0] TxD_state = 0;
wire TxD_ready = (TxD_state==0);
assign TxD_busy = ~TxD_ready;

reg [7:0] TxD_shift = 0;
always @(posedge clk)
begin
	if(TxD_ready & TxD_start)
		TxD_shift <= TxD_data;
	else
	if(TxD_state[3] & BitTick)
		TxD_shift <= (TxD_shift >> 1);

	case(TxD_state)
		4'b0000: if(TxD_start) TxD_state <= 4'b0100;
		4'b0100: if(BitTick) TxD_state <= 4'b1000;  // start bit
		4'b1000: if(BitTick) TxD_state <= 4'b1001;  // bit 0
		4'b1001: if(BitTick) TxD_state <= 4'b1010;  // bit 1
		4'b1010: if(BitTick) TxD_state <= 4'b1011;  // bit 2
		4'b1011: if(BitTick) TxD_state <= 4'b1100;  // bit 3
		4'b1100: if(BitTick) TxD_state <= 4'b1101;  // bit 4
		4'b1101: if(BitTick) TxD_state <= 4'b1110;  // bit 5
		4'b1110: if(BitTick) TxD_state <= 4'b1111;  // bit 6
		4'b1111: if(BitTick) TxD_state <= 4'b0010;  // bit 7
		4'b0010: if(BitTick) TxD_state <= 4'b0011;  // stop1
		4'b0011: if(BitTick) TxD_state <= 4'b0000;  // stop2
		default: if(BitTick) TxD_state <= 4'b0000;
	endcase
end

assign TxD = (TxD_state<4) | (TxD_state[3] & TxD_shift[0]);  // put together the start, data and stop bits
initial
    TxD_state = 0;
endmodule
