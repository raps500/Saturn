/* Parallel Saturn - Top file
 *
 * 1LF2 (Saturn) serial core
 * 4-bit sync memory
 * Uses 4 bit external buses
 * 
 * (c) 2013-2017 Alejandro Paz S.
 */

module saturn_top(
    input wire          clk_in, // 50 MHz clock
    
    input wire          key_h18,    // noraml '1'. '0' when pressed
    
    output wire [19:0]  addr_o,
    output wire         oe_o,
    output wire         we_o,
    
    inout wire [3:0]    data_io,
    output wire         vsync_o,    // R22 - Conn J1 Pin 3
    output wire         hsync_o,    // T22 - Conn J1 Pin 1
    
    output wire         red_o,  // R16 - Conn J1 Pin 6
    output wire         green_o, // R15 - Conn J1 Pin 4
    output wire         blue_o   // T15 - Conn J1 Pin 2
    
    );

wire [19:0] addr;
wire [3:0] data_to_mem, data_from_mem, data_in, data_from_ti1, data_from_ti2, data_from_ti3;
wire we, we_ti1, we_ti2, we_ti3, oe_ti1, oe_ti2, oe_ti3;
wire we_lcd;
wire hsync, vsync, white;

assign addr_o = addr;
assign data_io = we == 1'b0 ? data_to_mem:4'hz;
assign vsync_o = vsync;
assign hsync_o = hsync;
assign green_o = white;
assign blue_o = white;
assign red_o = white;

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
assign data_in = oe_ti1 ? data_from_ti1:
                 oe_ti2 ? data_from_ti2:
                 oe_ti3 ? data_from_ti3:
                 addr[19:18] == 2'b00 ? data_from_mem:data_io;

reg [5:0] div_cnt_2Mhz;
reg clk_2MHz;
wire clk_512Hz;
always @(posedge clk_in)
    begin
        if (div_cnt_2Mhz == 6'd19)
            clk_2MHz <= 1'b1;
        else
            if (div_cnt_2Mhz == 6'd39)
                begin
                    clk_2MHz <= 1'b0;
                    div_cnt_2Mhz <= 6'd0;
                end
            else
                div_cnt_2Mhz <= div_cnt_2Mhz + 12'd1;
    end
                 
reg [11:0] div_cnt;
assign clk_512Hz = div_cnt == 12'd0;
always @(posedge clk_2MHz)
    begin
        if (div_cnt == 12'd3906)
            div_cnt <= 12'd0;
        else
            div_cnt <= div_cnt + 12'd1;
    end

saturn_core core(
    .clk_in(clk_2MHz),
    
    .addr_o(addr),
    .oe_o(),
    .we_o(we),
    
    .data_o(data_to_mem),
    .data_in(data_in),
    .mem_ack_in(1'b1)

    );  

sync_mem mem(
    .clk_in(clk_2MHz),
    
    .addr_in(addr[19:0]),
    .we_in(!we),
    
    .data_o(data_in),
    .data_in(data_from_mem)

    );  

    llg3_Timer ti1(

    .clk_in(clk_2MHz),     // processor clock
    
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

    .clk_in(clk_2MHz),     // processor clock
    
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

    .clk_in(clk_2MHz),     // processor clock
    
    .clk_512Hz_in(clk_512Hz),   // 512 Hz clock
    .irq_enabled_in(1'b1),
    .read_in(oe_ti3),
    .write_in(we_ti3),
    .addr_in(addr[3:0]),
    
    .data_o(data_from_ti3),
    .data_in(data_to_mem),
    .irq_o()
    );
     
vga_out vga(
    .clk_in(clk_in),
    
    .addr_in(addr[9:0]),
    .we_in(we_lcd),
    .data_in(data_to_mem),
    
    .vsync_o(vsync),
    .hsync_o(hsync),
    
    .white_o(white)
    );
    
initial
    begin   
        div_cnt_2Mhz = 0;
        div_cnt = 0;
        clk_2MHz = 0;
    end
    
endmodule


module sync_mem(
    input wire          clk_in,
    input wire          we_in,
    
    input wire [19:0]   addr_in,
    output reg [3:0]    data_o,
    input wire [3:0]    data_in
    );
    
reg [3:0] mem[1048575:0];

always @(posedge clk_in)
    begin
        if (we_in)
            begin
                mem[addr_in] <= data_in;
                $display("W: %05x:%x @%d", addr_in, data_in, $time);
            end
        data_o <= #5 mem[addr_in];
    end
    
integer i;
initial
    begin
        //for (i = 32'h0; i <= 32'd2048; i = i+1)
        //  mem[i] = 4'hA;
        $readmemh("../../04_ROMS/rom71.mif.hex", mem);
        /*
        mem[20'h20000] = 4'h9;
        mem[20'h20001] = 4'hD;
        mem[20'h20002] = 4'h1; // ?C<B M
        mem[20'h20003] = 4'h2;
        mem[20'h20004] = 4'h0; // GOYES +2
        mem[20'h20005] = 4'h9;
        mem[20'h20006] = 4'hD;
        mem[20'h20007] = 4'h5; // ?C>B M
        mem[20'h20008] = 4'h2;
        mem[20'h20009] = 4'h0; // GOYES +2
        mem[20'h20000] = 4'h9;
        mem[20'h20000] = 4'h9;
        */
    end
    
endmodule
    
    
    