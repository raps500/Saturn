/* Parallel Saturn - Top file
 *
 * 16-bit async memory interface
 *
 * (c) 2013-2017 Alejandro Paz S.
 */

module saturn_top(
    input wire          clk_in,     // 50 MHz clock

    input wire          key_h18,    // noraml '1'. '0' when pressed

    output wire [19:0]  addr_o,
    output wire         oe_o,
    output wire         we_o,

    inout wire [15:0]   data_io,
    // keyboard matrix
    input wire [13:0]   columns_in,
    output wire [3:0]   rows_o,

    // UC1611s based LCD display
    output wire         disp_sck_o,
    output wire         disp_sdi_o,
    output wire         disp_a0_o,
    output wire         disp_ss_o,
    output wire         disp_reset_o

    );

wire [19:0] addr;
wire [15:0] cpu_to_bus, data_from_rom, data_from_ram, data_from_ram2k, bus_to_cpu;
wire [3:0] data_from_ti1, data_from_ti2, data_from_ti3;
wire we, we_ti1, we_ti2, we_ti3, oe_ti1, oe_ti2, oe_ti3;
wire we_lcd;
wire [9:0] lcd_addr;
wire [15:0] data_to_lcd;

assign addr_o = addr;
assign data_io = we == 1'b0 ? cpu_to_bus:16'hz;
assign disp_sck_o   = 1'b0;
assign disp_sdi_o   = 1'b0;
assign disp_a0_o    = 1'b0;
assign disp_ss_o    = 1'b0;
assign disp_reset_o = 1'b0;
assign we_o = we;
assign oe_o = ~we;

assign we_ti1 = (we == 1'b0) && ((addr[19:0] >= 20'h2e3f8) && (addr[19:0] < 20'h2e3fe));
assign oe_ti1 = (we == 1'b1) && ((addr[19:0] >= 20'h2e3f8) && (addr[19:0] < 20'h2e3fe));
assign we_ti2 = (we == 1'b0) && ((addr[19:0] >= 20'h2e2f8) && (addr[19:0] < 20'h2e2fe));
assign oe_ti2 = (we == 1'b1) && ((addr[19:0] >= 20'h2e2f8) && (addr[19:0] < 20'h2e2fe));
assign we_ti3 = (we == 1'b0) && ((addr[19:0] >= 20'h2e1f8) && (addr[19:0] < 20'h2e1fe));
assign oe_ti3 = (we == 1'b1) && ((addr[19:0] >= 20'h2e1f8) && (addr[19:0] < 20'h2e1fe));
assign we_lcd = (we == 1'b0) && (((addr[19:0] >= 20'h2e100) && (addr[19:0] < 20'h2e160)) || // slave1
                                 ((addr[19:0] >= 20'h2e200) && (addr[19:0] < 20'h2e260)) || // slave2
                                 ((addr[19:0] >= 20'h2e300) && (addr[19:0] < 20'h2e360)));  // master

// data to cpu mux
assign bus_to_cpu = oe_ti1 ? data_from_ti1:
                    oe_ti2 ? data_from_ti2:
                    oe_ti3 ? data_from_ti3:
                    addr[19:17] == 3'b000 ? data_from_rom:
                    addr[19:13] == 7'b0010_111 ? data_from_ram2k: /// LCD and 1.5 k system RAM
                    addr[19:16] == 4'b0011 ? data_from_ram:data_io;

wire cpu_clk;

reg reset = 1'b0;
reg new_reset = 1'b0;
reg [11:0] div_cnt = 12'h000;
assign clk_512Hz = div_cnt == 12'd0;
assign cpu_clk = clk_in;
always @(posedge clk_in)
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


saturn_core core(
    .clk_in(cpu_clk),
    .reset_in(reset_in),
    .addr_o(addr),
    .oe_o(),
    .we_o(we),

    .data_o(cpu_to_bus),
    .data_in(bus_to_cpu),
    .mem_ack_in(1'b1)

    );
sync_mem ram(
    .clk_in(cpu_clk),

    .addr_in(addr[19:0]),
    .we_in(~we_n),

    .data_o(data_from_ram),
    .data_in(cpu_to_bus)

    );
sync_mem2k ram2k(
    .clk_in(cpu_clk),

    .addr_a_in(addr[11:0]),
    .we_a_in(~we_n),

    .data_a_o(data_from_ram2k),
    .data_a_in(cpu_to_bus),

    .addr_b_in( lcd_addr ),
    .data_b_o(data_to_lcd)

    );
async_rom rom(
    .clk_in(cpu_clk),

    .addr_in(addr[19:0]),

    .data_o(data_from_rom)

    );
/*
llg3_Timer ti1(

    .clk_in(cpu_clk),     // processor clock

    .clk_512Hz_in(clk_512Hz),   // 512 Hz clock
    .irq_enabled_in(1'b1),
    .read_in(oe_ti1),
    .write_in(we_ti1),
    .addr_in(addr[3:0]),

    .data_o(data_from_ti1),
    .data_in(data_to_mem),
    .irq_o()
    );


llg3_Timer ti2(

    .clk_in(cpu_clk),     // processor clock

    .clk_512Hz_in(clk_512Hz),   // 512 Hz clock
    .irq_enabled_in(1'b1),
    .read_in(oe_ti2),
    .write_in(we_ti2),
    .addr_in(addr[3:0]),

    .data_o(data_from_ti2),
    .data_in(data_to_mem),
    .irq_o()
    );


llg3_Timer ti3(

    .clk_in(cpu_clk),     // processor clock

    .clk_512Hz_in(clk_512Hz),   // 512 Hz clock
    .irq_enabled_in(1'b1),
    .read_in(oe_ti3),
    .write_in(we_ti3),
    .addr_in(addr[3:0]),

    .data_o(data_from_ti3),
    .data_in(data_to_mem),
    .irq_o()
    );

    */

endmodule

// 32 k RAM as 16kx16, no byte acceses possible, read-before write will be used
// for write accesses when unaligned data is to bewritten
module sync_mem(
    input wire          clk_in,
    input wire          we_in,

    input wire [19:0]   addr_in,
    output reg [15:0]    data_o,
    input wire [15:0]    data_in
    );

reg [15:0] mem[16383:0];

always @(posedge clk_in)
    begin
        if (we_in)
            begin
                mem[addr_in[16:2]] <= data_in;
                $display("W: %05x:%x @%d", addr_in, data_in, $time);
            end
        data_o <= #5 mem[addr_in];
    end

integer i;
initial
    begin
        for (i = 32'h0; i <= 32'd16383; i = i+1)
          mem[i] = 16'h0000;
        //$readmemh("ram.hex", mem);
    end

endmodule

// 2 k RAM as 1kx16, no byte acceses possible, read-before write will be used
// for write accesses when unaligned data is to bewritten
module sync_mem2k(
    input wire          clk_in,
    input wire          we_a_in,

    input wire [11:0]   addr_a_in,
    output reg [15:0]   data_a_o,
    input wire [15:0]   data_a_in,
    // Only read on second port
    input wire [ 9:0]   addr_b_in, // word address
    output reg [15:0]   data_b_o

    );

reg [15:0] mem[16383:0];

always @(posedge clk_in)
    begin
        if (we_a_in)
            begin
                mem[addr_a_in[11:2]] <= data_a_in;
                $display("W: %05x:%x @%d", addr_a_in, data_a_in, $time);
            end
        data_a_o <= #55 mem[addr_a_in[11:2]];
        data_b_o <= #55 mem[addr_b_in];
    end

integer i;
initial
    begin
        for (i = 32'h0; i <= 32'd16383; i = i+1)
          mem[i] = 16'h0000;
        //$readmemh("ram.hex", mem);
    end

endmodule

// 64 k ROM as 16kx16, no byte acceses possible, read-before write will be used
// for write accesses when unaligned data is to bewritten
module async_rom(
    input wire          clk_in,

    input wire [19:0]   addr_in,
    output wire [15:0]    data_o
    );

reg [15:0] mem[32767:0];

assign #70 data_o = mem[addr_in[17:2]];

integer i;
initial
    begin
        //$readmemh("rom71_h16.hex", mem);
        $readmemh("cputest.hex", mem);
    end

endmodule