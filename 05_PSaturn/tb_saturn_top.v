/*
 * Test bench for Parallel Saturn top entity
 *
 *
 *
 */
`timescale 1ns/1ns

module tb_saturn_top();

reg clk = 1'b0;
wire [15:0] data_io;

saturn_top top(
    .clk_in(clk),     // 50 MHz clock
    
    .key_h18(1'b0),    // noraml '1'. '0' when pressed
    
    .addr_o(),
    .oe_o(),
    .we_o(),
    .data_io(data_io),
    // keyboard matrix
    .columns_in(14'h0),
    .rows_o(),
    
    // UC1611s based LCD display
    .disp_sck_o(),
    .disp_sdi_o(),
    .disp_a0_o(),
    .disp_ss_o(),
    .disp_reset_o()
    
    );

always
	#100 clk = ~clk;   //  5 MHz clock

initial
	begin
	$dumpfile("tb_saturn_top.vcd");
    $dumpvars();
    #0
	#200000 $finish;
	end


endmodule
