/* Handles the display
 * DOGM132 132x32 graphic display

 */



module display_dogm132(
    input wire          clk_in,
    input wire          reset_in,
    input wire  [9:0]   addr_in,
    input wire  [15:0]  data_in,
    input wire          we_in,      // asserted when data for the display is to be written
    // display interface
    output wire         disp_cs_n_o,
    output wire         disp_res_n_o,
    output wire         disp_data_o,
    output wire         disp_addr_o,
    output wire         disp_sck_o
	);

reg [5:0] state = 5'h0;
reg [4:0] curr_bit = 5'h0;
reg ss = 1'b0;
reg dispon = 1'b0;
reg send_ready = 1'b0;
reg disp_sck = 1'b0;
reg clock_active = 1'b0;
reg [2:0] lcd_page = 3'h0;
reg [7:0] lcd_col = 8'h00;
reg [7:0] out_data = 8'h0;
reg [7:0] cmddata = 8'h0;
reg force_refresh = 1'h0;
reg [7:0] lcdrame [1023:0];
reg [7:0] lcdramo [1023:0];
wire [7:0] lcd_data;
`define ST_RESET            6'h00
`define ST_INIT_LAST        6'h0e
`define ST_RFSH_START       6'h0f
`define ST_RFSH_LINE        6'h12
`define ST_WAIT_FOR_TOGGLE  6'h13
`define ST_SLEEP_CMD        6'h14
`define ST_POWER_DOWN       6'h14
`define ST_WAKE_UP          6'h16

assign disp_sck_o = disp_sck;
assign disp_cs_n_o = ss;

assign disp_data_o = out_data[7]; // MSB first
assign disp_addr_o = (state == `ST_RFSH_LINE);
                     
assign disp_res_n_o = reset_in;
assign lcd_data = lcd_col[0] ? lcdramo[{lcd_page, lcd_col[7:1]}]:lcdrame[{ lcd_page, lcd_col[7:1] }];


// command/data according to the state machine
always @(*)
    begin
        cmddata = 8'h00;
        case (state)
            6'h00: cmddata = 8'h00;
            6'h01: cmddata = 8'h40;
            6'h02: cmddata = 8'ha1; /* A1 for inverted display */
            6'h03: cmddata = 8'hc0; /* C0 for inverted display */
            6'h04: cmddata = 8'ha6;
            6'h05: cmddata = 8'ha2;
            6'h06: cmddata = 8'h2f;
            6'h07: cmddata = 8'hf8;
            6'h08: cmddata = 8'h00;
            6'h09: cmddata = 8'h23;
            6'h0a: cmddata = 8'h81;
            6'h0b: cmddata = 8'h1f;
            6'h0c: cmddata = 8'hac;
            6'h0d: cmddata = 8'h00;
            6'h0e: cmddata = 8'haf;
            6'h0f: cmddata = { 5'b10110, lcd_page }; // page address 
            6'h10: cmddata = 8'h10; // col address high 0
            6'h11: cmddata = 8'h00; // col address low 0
            6'h12: cmddata = lcd_data;
            6'h13: cmddata = 8'h00; // No command
            6'h14: cmddata = 8'hae; // power save
            6'h15: cmddata = 8'h00; // No command
            6'h16: cmddata = 8'haf; // wake up
            default:
                   cmddata = 8'h00;
        endcase
    end


always @(posedge clk_in)
    begin
        if (reset_in == 1'b0)
            begin
                state <= 5'h0;
                ss <= 1'b1;
                send_ready <= 1'b1;
                lcd_page <= 3'h0;
                lcd_col <= 8'h00;
                curr_bit <= 5'h0;
                force_refresh <= 1'b0;
            end
        else
            begin
                if (we_in)
                    begin
                        lcdrame[addr_in] <= data_in[ 7: 0];
                        lcdramo[addr_in] <= data_in[15: 8];
                        force_refresh <= 1'b1;
                    end/*
                if (op_disp_off_in)
                    begin
                        dispon <= 1'b0;
                    end
                if (op_disp_toggle_in)
                    begin
                        if (dispon)
                            dispon <= 1'b0;
                        else
                            begin
                                dispon <= 1'b1;
                                force_refresh <= 1'b1;
                            end
                    end */
                if (clock_active)
                    disp_sck <= ~disp_sck;
                else
                    disp_sck <= 1'b0;
                case (state)
                    /*`ST_RESET:
                        begin
                            if (lcd_col == 8'd127)
                                begin
                                    state <= state + 6'd1;
                                    lcd_col <= 8'h0;
                                end
                            else
                                lcd_col <= lcd_col + 8'h1;
                        end
                        */
                    `ST_WAIT_FOR_TOGGLE: 
                        begin 
                            if (force_refresh)
                                begin
                                    state <= `ST_RFSH_START;
                                    lcd_page <= 3'h0; // page to refresh
                                    lcd_col <= 8'h0;
                                    force_refresh <= 1'b0;
                                    curr_bit <= 5'h0;
                                end
                        end
                    `ST_RFSH_START: // 
                        if (send_ready == 1'b1)
                            begin
                                state <= state + 6'd1;
                                curr_bit <= 5'h0;
                                send_ready <= 1'b0;
                            end
                    `ST_RFSH_LINE:
                        if (send_ready == 1'b1)
                            begin
                                curr_bit <= 5'h0;
                                send_ready <= 1'b0;
                                if (lcd_col == 8'd131)
                                    begin
                                        if (lcd_page == 3'h3)
                                            state <= `ST_WAIT_FOR_TOGGLE;
                                        else
                                            begin
                                                lcd_page <= lcd_page + 3'h1;
                                                state <= `ST_RFSH_START; // next line
                                                lcd_col <= 8'h0;
                                            end
                                    end
                                else
                                    begin
                                        //state <= `ST_WAIT_FOR_DATA;
                                        lcd_col <= lcd_col + 8'h1; // next column
                                    end
                            end
                    default:
                        if (send_ready == 1'b1)
                            begin
                                state <= state + 6'd1;
                                curr_bit <= 5'h0;
                                send_ready <= 1'b0;
                            end
                endcase
                // only send when curr_bit is < 19
                if (~send_ready)
                    begin
                        case (curr_bit)
                            5'd0: out_data <= cmddata; // data to shift
                            5'd1: begin clock_active <= 1'b1; ss <= 1'b0; end
                            5'd3, 5'h5, 5'h7, 5'h9,
                            5'd11, 5'd13, 5'd15: out_data <= out_data << 1;
                            5'd16: begin clock_active <= 1'b0; end
                            5'd18: begin ss <= 1'b1; send_ready <= 1'b1; end
                        endcase
                        curr_bit <= curr_bit + 5'h1;
                    end

            end
    end
    
initial
    begin
        $readmemh("C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/02_Components/lcdrame.hex", lcdrame);
        $readmemh("C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/02_Components/lcdramo.hex", lcdramo);
    end


/* Graphic display State Machine */
/*
Befehl RS R/W DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0 Hex Bemerkung Function Set 
Command                     | A0 D7 D6 D5 D4 D3 D2 D1 D0 Hex Remark 
Display start line set      |  0  0  1  0  0  0  0  0  0 $40 Display start line 0 
ADC set                     |  0  1  0  1  0  0  0  0  1 $A1 ADC reverse *) 
Common output mode select   |  0  1  1  0  0  0  0  0  0 $C0 Normal COM0~COM31 
Display normal/reverse      |  0  1  0  1  0  0  1  1  0 $A6 Display normal 
LCD bias set                |  0  1  0  1  0  0  0  1  0 $A2 Set bias 1/9 (Duty 1/33) 
Power control set           |  0  0  0  1  0  1  1  1  1 $2F Booster, Regulator and Follower on
Booster ratio set           |  0  1  1  1  1  1  0  0  0 $F8 Set internal Booster to 3x / 4x
                            |     0  0  0  0  0  0  0  0 $00 
V0 voltage regulator set    |  0  0  0  1  0  0  0  1  1 $23 Contrast set
Electronic volume mode set  |  0  1  0  0  0  0  0  0  1 $81 
                            |     0  0  0  1  1  1  1  1 $1F
Static indicator set        |  0  1  0  1  0  1  1  0  0 $AC No indicator  
No indicator                |     0  0  0  0  0  0  0  0 $00 
Display ON/OFF              |  0  1  0  1  0  1  1  1  1 $AF Display on

 */   
    
initial
    begin
	end
	
endmodule