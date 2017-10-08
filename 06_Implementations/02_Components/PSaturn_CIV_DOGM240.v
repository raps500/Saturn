/*
 * Top Entity for
 *
 * Parallel Saturn with 16 bit external memory BUS
 * and DOGM240 LC Display
 */
`timescale 1ns/1ns

module PSaturn_CIV_DOGM240(
    input wire          clk_in,
    input wire          reset_in,
    output wire         clk_512Hz_o,
    output wire         nclk_o,
	//
    output wire [19:0]  addr_o,
    output wire         oe_o,
    output wire         we_o,

    inout wire [15:0]   data_io,
    // display interface
    output wire         disp_cs_n_o,
    output wire         disp_res_n_o,
    output wire         disp_data_o,
    output wire         disp_addr_o,
    output wire         disp_sck_o


);

wire clk_50MHz, clk_10MHz, clk_5MHz, pll_locked, cpu_clk;
wire [19:0] addr;
wire [15:0] cpu_to_bus, data_from_rom, data_from_ram, data_from_ram2k, bus_to_cpu;
wire [3:0] data_from_ti1, data_from_ti2, data_from_ti3;
wire we, we_ti1, we_ti2, we_ti3, oe_ti1, oe_ti2, oe_ti3;
wire we_lcd;
wire [9:0] lcd_addr;
wire [15:0] data_to_lcd;

assign nclk_o = clk_5MHz;
assign addr_o = addr;
assign data_io = (we == 1'b0) ? cpu_to_bus:16'hz;

pll plli(
    .inclk0(clk_in),
	.c0(clk_50MHz),
	.c1(clk_10MHz),
	.c2(clk_5MHz),
	.locked(pll_locked)
    );


wire clk_512Hz;

reg reset = 1'b0;
reg new_reset = 1'b0;
reg [11:0] div_cnt = 12'h000;
assign clk_512Hz = div_cnt == 12'd0;

assign nclk_o = clk_5MHz;
assign cpu_clk =clk_5MHz;

always @(posedge clk_5MHz)
    begin
        new_reset <= reset_in;
        if (div_cnt == 12'd3906)
            begin
                div_cnt <= 12'd0;
                if (new_reset == 1'b0)
                    reset <= 1'b0;
                else
                    reset <= 1'b1;
            end
        else
            div_cnt <= div_cnt + 12'd1;
    end

assign clk_512Hz_o = clk_512Hz;


assign we_lcd = (we == 1'b0) && (((addr[19:0] >= 20'h2e100) && (addr[19:0] < 20'h2e160)) || // slave1
                                 ((addr[19:0] >= 20'h2e200) && (addr[19:0] < 20'h2e260)) || // slave2
                                 ((addr[19:0] >= 20'h2e300) && (addr[19:0] < 20'h2e360)));  // master


// data to cpu mux
assign bus_to_cpu = //oe_ti1 ? data_from_ti1:
                    //oe_ti2 ? data_from_ti2:
                    //oe_ti3 ? data_from_ti3:
                    addr[19:17] == 3'b000 ? data_from_rom:
                    //addr[19:13] == 7'b0010_111 ? data_from_ram2k: /// LCD and 1.5 k system RAM
                    //addr[19:16] == 4'b0011 ? data_from_ram:
					data_io;


`ifdef DOGM240
display_dogm240 disp_ctrl(
    .clk_in(clk_5MHz),
    .reset_in(reset),
    .addr_in(),
    .data_in(),
    .we_in(),      // asserted when data for the display is to be written
    // display interface
    .disp_cs_n_o(disp_cs_n_o),
    .disp_res_n_o(disp_res_n_o),
    .disp_data_o(disp_data_o),
    .disp_addr_o(disp_addr_o),
    .disp_sck_o(disp_sck_o)
    );
`endif
display_dogm132 disp_ctrl(
    .clk_in(clk_5MHz),
    .reset_in(reset),
    .addr_in(),
    .data_in(),
    .we_in(),      // asserted when data for the display is to be written
    // display interface
    .disp_cs_n_o(disp_cs_n_o),
    .disp_res_n_o(disp_res_n_o),
    .disp_data_o(disp_data_o),
    .disp_addr_o(disp_addr_o),
    .disp_sck_o(disp_sck_o)
    );

saturn_core core(
    .clk_in(cpu_clk),
    .reset_in(reset),
    .addr_o(addr),
    .oe_o(),
    .we_o(we),

    .data_o(cpu_to_bus),
    .data_in(bus_to_cpu),
    .mem_ack_in(1'b1)
    );
	
async_rom rom(
    .clk_in(cpu_clk),

    .addr_in(addr[19:0]),

    .data_o(data_from_rom)

    );


endmodule

// 16 k ROM as 8kx16, no byte acceses possible, read-before write will be used
// for write accesses when unaligned data is to bewritten
module async_rom(
    input wire          clk_in,

    input wire [19:0]   addr_in,
    output wire [15:0]    data_o
    );

reg [15:0] mem[8191:0];

assign #70 data_o = mem[addr_in[17:2]];

integer i;
initial
    begin
        //$readmemh("rom71_h16.hex", mem);
        $readmemh("cputest.hex", mem);
    end

endmodule