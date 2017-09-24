/*
 * Test bench for Parallel 1LF2 top entity
 *
 *
 *
 */
`timescale 1ns/1ns
 
module tb_llf2_alru();

reg clk;

reg [ 0: 0] clk_in;    
wire [19:0] bus_addr_o;
wire [15: 0] bus_data_in;
wire[15: 0] bus_data_io;
reg [19: 0] ibus_addr_in;
reg [ 0: 0] ibus_flush_q_in;
reg [ 0: 0] ibus_fetch_in;
reg [ 0: 0] ibus_fetch_ack_in;
reg [ 4: 0] ibus_size_in;
reg [19: 0] data_addr_in;
reg [ 3: 0] data_size_in;
reg [63: 0] data_data_in;
reg [15: 0] data_mask_in;
              
reg [15:0] rom [32767:0];
saturn_bus_controller bus_ctrl(
    .clk_in            (clk               ),
	.bus_addr_o        (bus_addr_o        ),
    .bus_rd_o          (                  ),       
    .bus_we_o          (                  ),       
    .bus_data_in       (bus_data_in       ),
    .bus_data_o        (                  ),    
    .bus_data_io       (                  ),    
    .ibus_addr_in      (ibus_addr_in      ), 
    .ibus_flush_q_in   (ibus_flush_q_in   ),
    .ibus_fetch_in     (ibus_fetch_in     ),
    .ibus_fetch_ack_in (ibus_fetch_ack_in ),       
    .ibus_size_in      (ibus_size_in      ),
    .ibus_pre_fetched_opcode_o          (                  ),
    .ibus_pre_fetched_opcode_length_o   (                  ),
    .ibus_addr_o       (                  ), 
    .ibus_ready_o      (                  ),  
    .data_addr_in      (data_addr_in      ),
    .data_size_in      (data_size_in      ), 
    .data_data_in      (data_data_in      ),
    .data_mask_in      (data_mask_in      )     
    );
    
always 
    #100 clk = ~clk;   //  5 MHz clock
    
assign bus_data_in = rom[bus_addr_o[14:2]];
    
initial
	begin
    $readmemh("rom71_h16.hex", rom);
	$dumpfile("tb_saturn_bus_ctrl.vcd");
    $dumpvars();
	clk                = 1'b0;


    ibus_addr_in = 'h0;
    ibus_flush_q_in = 'h0;
    ibus_fetch_in = 'h1;
    ibus_fetch_ack_in = 'h1;
    ibus_size_in = 'h0;
    data_addr_in = 'h0;
    data_size_in = 'h0;
    data_data_in = 'h0;
    data_mask_in = 'h0;
	#20000 $finish; 
	end
	
	
endmodule
