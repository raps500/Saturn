/*
 * Test bench for DOGM240
 *
 *
 *
 */
`timescale 1ns/1ns

module tb_dogm240();

reg clk;

reg [ 9: 0] addr        ;
reg [15: 0] data        ;
reg [ 0: 0] write       ;
reg [ 0: 0] reset       ;



display_dogm240 alru(
	.clk_in                 (clk        ),
    .reset_in               (reset      ),
    .addr_in                (addr       ),
    .data_in                (data       ),
    .we_in                  (write      ),
    .disp_cs_n_o            (           ),
    .disp_res_n_o           (           ),
    .disp_data_o            (           ),
    .disp_addr_o            (           ),
    .disp_sck_o             (           )
    );

always
	#100 clk = ~clk;   //  5 MHz clock

initial
	begin
	$dumpfile("tb_dogm240.vcd");
    $dumpvars();
	clk             = 1'b0;
	reset           = 1'b0;
    addr            = 10'h0;
    data            = 16'h0;
    write           = 1'b0;
    #500
	reset           = 1'b1;
    
	
	#5000000 $finish;
	end


endmodule
