/**
 * Parallel Saturn
 * Bus controller
 *
 * 
 * One external BUS with a width of 16 bits, 4 nibbles
 *
 * Unaligned data accesses are splitted in 16 bits chunks with read-modify-write
 * for unaligned writes
 * One internal instruction bus with a 32 nibbles prefetch buffer 
 * * a LA(F) opcode should fit the prefetch buffer 8082F 0123456789ABCDEF = 21 nibbles, 12 bytes
 * 
 *
 */
 
 
module saturn_bus_controller(
    input wire          clk_in,         // BUS and cpu clock
    input wire          reset_in,       // Master reset asserted low
    
    output wire [19:0]  bus_addr_o,     // address bus, for 16 bits memory use [19:2]
    output wire         bus_rd_o,       // read strobe
    output wire         bus_we_o,       // write strobe
    
    input wire [15:0]   bus_data_in,    // read data bus
    output wire [15:0]  bus_data_o,     // write data bus
    
    inout wire [15:0]   bus_data_io,    // bidirectional data bus
    
    // CPU Instruction bus
    input wire [19:0]   ibus_addr_in,   // fetch address
    input wire          ibus_flush_q_in,// force flush the queue
    input wire          ibus_fetch_in,  // fetch strobe, asserted for every new requested fetch
    input wire          ibus_fetch_ack_in,// fetch acknowledged
    //input wire [4:0]    ibus_size_in, // size of last instruction in nibbles
    output wire [83:0]  ibus_pre_fetched_opcode_o,// pre-fetch buffer 21 nibbles long
    output wire [ 4:0]  ibus_pre_fetched_opcode_length_o,    // valid nibbles
    output wire [19:0]  ibus_pre_fetched_opcode_addr_o,    // address of the prefetched bytes
    output wire         ibus_ready_o,   // asserted when the pre-fetch buffer has a whole opcode
    
    // CPU data bus
    input wire [19:0]   data_addr_in,   // data address
    input wire [3:0]    data_size_in,   // size of data transfer
    input wire [63:0]   data_data_in,   // data to be written, address & size have alignment information
    input wire [3:0]    data_field_left_in,   // data left field mask
    input wire [3:0]    data_field_right_in,  // data right field mask
    
    output wire [63:0]  data_data_o,    // read data 
    input wire          data_read_in,   // read data strobe
    input wire          data_write_in,  // write data strobe
    output wire         data_read_ready_o,   // asserted when the read transfer is complete
    output wire         data_write_ready_o   // asserted when the write transfer is complete
);

reg [3:0] bus_state = 4'h0;

reg [95:0] pre_fetch_buffer = 96'h0; // pre-fetch buffer up to 12 bytes
reg [83:0] pre_fetched_opcode = 84'h0;
reg [4:0] nibbles_in_queue = 5'h0;
wire [4:0] no_of_needed_nibbles;
reg [4:0] pre_fetched_opcode_length = 5'h0;   // length of the opcode in the  pre_fetched_opcode
reg ibus_ready = 1'b0;

reg [19:0] bus_addr = 20'h0; // full address of the current transfer
reg [19:0] pre_fetched_opcode_addr = 20'h0; // latched address of the current pre-fetch opcode
reg [19:0] next_prefetch_addr = 20'h0; // address of the opcode being fetched now
reg bus_rd = 1'b0, bus_we = 1'b0; // in positive logic

reg [63:0] read_data = 64'h0;       // read data from memory correctly aligned accoring to data mask
reg [15:0] write_data = 16'h0;      // data to write to memory already aligned and 
reg [4:0] nibbles_in_transfer = 5'h0;    // read or written nibbles
wire [3:0] dst_total_nibs;  // number of nibbles in the field area
reg data_read_ready = 1'b0, data_write_ready = 1'b0;
reg skip_size_check = 1'b0; // skip size check when prefetching during execution
wire inhibit_fetch; // the instruction in the queue is a got or conditional, inhib further fetch
reg flush_pending = 1'b0;
reg fetch_pending = 1'b0;
assign ibus_pre_fetched_opcode_o = pre_fetched_opcode;
assign ibus_pre_fetched_opcode_length_o = pre_fetched_opcode_length;
assign ibus_pre_fetched_opcode_addr_o = pre_fetched_opcode_addr;
assign ibus_ready_o = ibus_ready;
assign bus_addr_o = bus_addr;
assign bus_rd_o = ~bus_rd;
assign bus_we_o = ~bus_we;
assign data_read_ready_o = data_read_ready;
assign data_write_ready_o = data_write_ready;


// first access mask
reg [15:0] left_mask, right_mask;
wire [15:0] data_mask;
always @(*)
    begin
        case (data_field_left_in)
            4'h0: left_mask = 16'b0000000000000001;
            4'h1: left_mask = 16'b0000000000000011;
            4'h2: left_mask = 16'b0000000000000111;
            4'h3: left_mask = 16'b0000000000001111;
            4'h4: left_mask = 16'b0000000000011111;
            4'h5: left_mask = 16'b0000000000111111;
            4'h6: left_mask = 16'b0000000001111111;
            4'h7: left_mask = 16'b0000000011111111;
            4'h8: left_mask = 16'b0000000111111111;
            4'h9: left_mask = 16'b0000001111111111;
            4'ha: left_mask = 16'b0000011111111111;
            4'hb: left_mask = 16'b0000111111111111;
            4'hc: left_mask = 16'b0001111111111111;
            4'hd: left_mask = 16'b0011111111111111;
            4'he: left_mask = 16'b0111111111111111;
            4'hf: left_mask = 16'b1111111111111111;
        endcase
    end

always @(*)
    begin
        case (data_field_right_in)
            4'h0: right_mask = 16'b1111111111111111;
            4'h1: right_mask = 16'b1111111111111110;
            4'h2: right_mask = 16'b1111111111111100;
            4'h3: right_mask = 16'b1111111111111000;
            4'h4: right_mask = 16'b1111111111110000;
            4'h5: right_mask = 16'b1111111111100000;
            4'h6: right_mask = 16'b1111111111000000;
            4'h7: right_mask = 16'b1111111110000000;
            4'h8: right_mask = 16'b1111111100000000;
            4'h9: right_mask = 16'b1111111000000000;
            4'ha: right_mask = 16'b1111110000000000;
            4'hb: right_mask = 16'b1111100000000000;
            4'hc: right_mask = 16'b1111000000000000;
            4'hd: right_mask = 16'b1110000000000000;
            4'he: right_mask = 16'b1100000000000000;
            4'hf: right_mask = 16'b1000000000000000;
        endcase
    end

assign data_mask = left_mask & right_mask; 
assign dst_total_nibs = data_field_left_in - data_field_right_in;



saturn_predecoder predec(
    .opcode_in(pre_fetch_buffer[19:0]),
    .nibbles_in_queue_in(nibbles_in_queue),
    .size_o(no_of_needed_nibbles),
    .inhibit_fetch_o(inhibit_fetch)
);
`define BUS_ST_FLUSH        4'h0
`define BUS_ST_FETCH_WORD   4'h1
`define BUS_ST_CHECK_SIZE   4'h2
`define BUS_ST_WAIT         4'h3
`define BUS_ST_READ         4'h4
`define BUS_ST_READ_CHECK   4'h5    
`define BUS_ST_WRITE        4'h6
`define BUS_ST_WRITE1       4'h7

`define S_ASSERTED       1'b1
`define S_NEGATED        1'b0
reg shift_now = 1'b0;
always @(posedge clk_in)
    begin
        if (reset_in == 1'b0)
            begin
                fetch_pending <= 1'b0;
                flush_pending <= 1'b0;
            end
        else
            begin
                if (ibus_flush_q_in)
                    flush_pending <= 1'b1;
                if (ibus_fetch_in)
                    fetch_pending <= 1'b1;
                // shift as needed
                if (shift_now)
                    begin // discard last opcode from pre-fetch buffer
                        pre_fetch_buffer <=  pre_fetch_buffer >> (pre_fetched_opcode_length << 2);
                        /* 
                        case (pre_fetched_opcode_length) // discard used opcode from pre-fetch buffer
                            5'h2:  pre_fetch_buffer[87: 0] <= pre_fetch_buffer[95: 8];
                            5'h3:  pre_fetch_buffer[83: 0] <= pre_fetch_buffer[95:12];
                            5'h4:  pre_fetch_buffer[79: 0] <= pre_fetch_buffer[95:16];
                            5'h5:  pre_fetch_buffer[75: 0] <= pre_fetch_buffer[95:20];
                            5'h6:  pre_fetch_buffer[71: 0] <= pre_fetch_buffer[95:24];
                            5'h7:  pre_fetch_buffer[67: 0] <= pre_fetch_buffer[95:28];
                            5'h8:  pre_fetch_buffer[63: 0] <= pre_fetch_buffer[95:32];
                            5'h9:  pre_fetch_buffer[59: 0] <= pre_fetch_buffer[95:36];
                            5'ha:  pre_fetch_buffer[55: 0] <= pre_fetch_buffer[95:40];
                            5'hb:  pre_fetch_buffer[51: 0] <= pre_fetch_buffer[95:44];
                            5'hc:  pre_fetch_buffer[47: 0] <= pre_fetch_buffer[95:48];
                            5'hd:  pre_fetch_buffer[43: 0] <= pre_fetch_buffer[95:52];
                            5'he:  pre_fetch_buffer[39: 0] <= pre_fetch_buffer[95:56];
                            5'hf:  pre_fetch_buffer[35: 0] <= pre_fetch_buffer[95:60];
                            5'h10: pre_fetch_buffer[31: 0] <= pre_fetch_buffer[95:64];
                            5'h11: pre_fetch_buffer[27: 0] <= pre_fetch_buffer[95:68];
                            5'h12: pre_fetch_buffer[23: 0] <= pre_fetch_buffer[95:72];
                            5'h13: pre_fetch_buffer[19: 0] <= pre_fetch_buffer[95:76];
                            5'h14: pre_fetch_buffer[15: 0] <= pre_fetch_buffer[95:80];                                
                        endcase
                        */
                    end
                case (bus_state)
                    `BUS_ST_FLUSH: // reset state or flushed
                        begin
                            shift_now <= `S_NEGATED;
                            bus_state <= `BUS_ST_FETCH_WORD;
                            nibbles_in_queue <= 5'h0;
                            ibus_ready <= `S_NEGATED;
                            bus_addr <= ibus_addr_in;
                            next_prefetch_addr <= ibus_addr_in;
                            bus_rd <= `S_ASSERTED;
                            skip_size_check <= 1'b0;
                        end
                    `BUS_ST_FETCH_WORD: // fetch first word aligned or not
                        begin
                            shift_now <= `S_NEGATED;
                            if (nibbles_in_queue == 5'h00)
                                next_prefetch_addr <= bus_addr;
                            case (bus_addr[1:0])
                                2'b00: // aligned access
                                    begin
                                        case (nibbles_in_queue)
                                            5'h0:  pre_fetch_buffer[15: 0] <= bus_data_in;
                                            5'h1:  pre_fetch_buffer[19: 4] <= bus_data_in;
                                            5'h2:  pre_fetch_buffer[23: 8] <= bus_data_in;
                                            5'h3:  pre_fetch_buffer[27:12] <= bus_data_in;
                                            5'h4:  pre_fetch_buffer[31:16] <= bus_data_in;
                                            5'h5:  pre_fetch_buffer[35:20] <= bus_data_in;
                                            5'h6:  pre_fetch_buffer[39:24] <= bus_data_in;
                                            5'h7:  pre_fetch_buffer[43:28] <= bus_data_in;
                                            5'h8:  pre_fetch_buffer[47:32] <= bus_data_in;
                                            5'h9:  pre_fetch_buffer[51:36] <= bus_data_in;
                                            5'ha:  pre_fetch_buffer[55:40] <= bus_data_in;
                                            5'hb:  pre_fetch_buffer[59:44] <= bus_data_in;
                                            5'hc:  pre_fetch_buffer[63:48] <= bus_data_in;
                                            5'hd:  pre_fetch_buffer[67:52] <= bus_data_in;
                                            5'he:  pre_fetch_buffer[71:56] <= bus_data_in;
                                            5'hf:  pre_fetch_buffer[75:60] <= bus_data_in;
                                            5'h10: pre_fetch_buffer[79:64] <= bus_data_in;
                                            5'h11: pre_fetch_buffer[83:68] <= bus_data_in;
                                            5'h12: pre_fetch_buffer[87:72] <= bus_data_in;
                                            5'h13: pre_fetch_buffer[91:76] <= bus_data_in;
                                            5'h14: pre_fetch_buffer[95:80] <= bus_data_in;
                                        endcase
                                        nibbles_in_queue <= nibbles_in_queue + 5'h4;
                                        bus_addr <= bus_addr + 20'h4;
                                    end
                                2'b01: // fetch only 3 nibbles, happens only after flush
                                    begin
                                        pre_fetch_buffer[12: 0] <= bus_data_in[15: 4];
                                        nibbles_in_queue <= nibbles_in_queue + 5'h3;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                                2'b10: // fetch only 3 nibbles, happens only after flush
                                    begin
                                        pre_fetch_buffer[ 7: 0] <= bus_data_in[15: 8];
                                        nibbles_in_queue <= nibbles_in_queue + 5'h2;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                                2'b11: // fetch only 1 nibble, happens only after flush
                                    begin
                                        pre_fetch_buffer[ 3: 0] <= bus_data_in[15:12];
                                        nibbles_in_queue <= nibbles_in_queue + 5'h1;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                            endcase
                            bus_rd <= `S_NEGATED;
                            if (skip_size_check)
                                begin
                                    bus_state <= `BUS_ST_WAIT;
                                    skip_size_check <= 1'b0;
                                end
                            else
                                bus_state <= `BUS_ST_CHECK_SIZE;
                        end
                    `BUS_ST_CHECK_SIZE:
                        begin
                            shift_now <= `S_NEGATED;
                            if ((nibbles_in_queue < 5'h2) ||
                                (no_of_needed_nibbles > nibbles_in_queue))
                                begin // not enough nibbles, read 4 nibbles at once
                                    bus_rd <= `S_ASSERTED;
                                    bus_state <= `BUS_ST_FETCH_WORD;
                                end
                            else
                                begin // full opcode fetched
                                    pre_fetched_opcode <= pre_fetch_buffer[83: 0];
                                    pre_fetched_opcode_length <= no_of_needed_nibbles;
                                    nibbles_in_queue <= nibbles_in_queue - no_of_needed_nibbles;
                                    pre_fetched_opcode_addr <= next_prefetch_addr;
                                    next_prefetch_addr <= next_prefetch_addr + { 15'h0, no_of_needed_nibbles };
                                    ibus_ready <= `S_ASSERTED;
                                    bus_state <= `BUS_ST_WAIT;
                                    shift_now <= 1'b1;
                                    /*
                                    case (no_of_needed_nibbles) // discard used opcode from pre-fetch buffer
                                        5'h2:  pre_fetch_buffer[87: 0] <= pre_fetch_buffer[95: 8];
                                        5'h3:  pre_fetch_buffer[83: 0] <= pre_fetch_buffer[95:12];
                                        5'h4:  pre_fetch_buffer[79: 0] <= pre_fetch_buffer[95:16];
                                        5'h5:  pre_fetch_buffer[75: 0] <= pre_fetch_buffer[95:20];
                                        5'h6:  pre_fetch_buffer[71: 0] <= pre_fetch_buffer[95:24];
                                        5'h7:  pre_fetch_buffer[67: 0] <= pre_fetch_buffer[95:28];
                                        5'h8:  pre_fetch_buffer[63: 0] <= pre_fetch_buffer[95:32];
                                        5'h9:  pre_fetch_buffer[59: 0] <= pre_fetch_buffer[95:36];
                                        5'ha:  pre_fetch_buffer[55: 0] <= pre_fetch_buffer[95:40];
                                        5'hb:  pre_fetch_buffer[51: 0] <= pre_fetch_buffer[95:44];
                                        5'hc:  pre_fetch_buffer[47: 0] <= pre_fetch_buffer[95:48];
                                        5'hd:  pre_fetch_buffer[43: 0] <= pre_fetch_buffer[95:52];
                                        5'he:  pre_fetch_buffer[39: 0] <= pre_fetch_buffer[95:56];
                                        5'hf:  pre_fetch_buffer[35: 0] <= pre_fetch_buffer[95:60];
                                        5'h10: pre_fetch_buffer[31: 0] <= pre_fetch_buffer[95:64];
                                        5'h11: pre_fetch_buffer[27: 0] <= pre_fetch_buffer[95:68];
                                        5'h12: pre_fetch_buffer[23: 0] <= pre_fetch_buffer[95:72];
                                        5'h13: pre_fetch_buffer[19: 0] <= pre_fetch_buffer[95:76];
                                        5'h14: pre_fetch_buffer[15: 0] <= pre_fetch_buffer[95:80];                                
                                    endcase
                                    */
                                end
                        end
                    `BUS_ST_WAIT:
                        begin
                            shift_now <= `S_NEGATED;
                            ibus_ready <= `S_NEGATED;
                            if (data_read_in)
                                begin
                                    bus_state <= `BUS_ST_READ;
                                    bus_rd <= `S_ASSERTED;
                                    bus_addr <= data_addr_in;
                                    nibbles_in_transfer <= 5'h0;
                                end
                            if (flush_pending)
                                begin
                                    bus_state <= `BUS_ST_FLUSH;
                                    flush_pending <= `S_NEGATED;
                                end
                            else
                                if (fetch_pending)
                                    begin // check if the current pre fetch buffer has a whole opcode
                                        // it doesn't return here till a new request exists
                                        fetch_pending <= `S_NEGATED;
                                        if (no_of_needed_nibbles <= nibbles_in_queue)
                                            begin
                                                pre_fetched_opcode <= pre_fetch_buffer[83: 0];
                                                pre_fetched_opcode_length <= no_of_needed_nibbles;
                                                nibbles_in_queue <= nibbles_in_queue - no_of_needed_nibbles;
                                                pre_fetched_opcode_addr <= next_prefetch_addr;
                                                next_prefetch_addr <= next_prefetch_addr + { 15'h0, no_of_needed_nibbles };
                                                ibus_ready <= `S_ASSERTED;
                                                shift_now <= 1'b1;
                                                /*
                                                case (no_of_needed_nibbles) // discard used opcode from pre-fetch buffer
                                                    5'h2:  pre_fetch_buffer[87: 0] <= pre_fetch_buffer[95: 8];
                                                    5'h3:  pre_fetch_buffer[83: 0] <= pre_fetch_buffer[95:12];
                                                    5'h4:  pre_fetch_buffer[79: 0] <= pre_fetch_buffer[95:16];
                                                    5'h5:  pre_fetch_buffer[75: 0] <= pre_fetch_buffer[95:20];
                                                    5'h6:  pre_fetch_buffer[71: 0] <= pre_fetch_buffer[95:24];
                                                    5'h7:  pre_fetch_buffer[67: 0] <= pre_fetch_buffer[95:28];
                                                    5'h8:  pre_fetch_buffer[63: 0] <= pre_fetch_buffer[95:32];
                                                    5'h9:  pre_fetch_buffer[59: 0] <= pre_fetch_buffer[95:36];
                                                    5'ha:  pre_fetch_buffer[55: 0] <= pre_fetch_buffer[95:40];
                                                    5'hb:  pre_fetch_buffer[51: 0] <= pre_fetch_buffer[95:44];
                                                    5'hc:  pre_fetch_buffer[47: 0] <= pre_fetch_buffer[95:48];
                                                    5'hd:  pre_fetch_buffer[43: 0] <= pre_fetch_buffer[95:52];
                                                    5'he:  pre_fetch_buffer[39: 0] <= pre_fetch_buffer[95:56];
                                                    5'hf:  pre_fetch_buffer[35: 0] <= pre_fetch_buffer[95:60];
                                                    5'h10: pre_fetch_buffer[31: 0] <= pre_fetch_buffer[95:64];
                                                    5'h11: pre_fetch_buffer[27: 0] <= pre_fetch_buffer[95:68];
                                                    5'h12: pre_fetch_buffer[23: 0] <= pre_fetch_buffer[95:72];
                                                    5'h13: pre_fetch_buffer[19: 0] <= pre_fetch_buffer[95:76];
                                                    5'h14: pre_fetch_buffer[15: 0] <= pre_fetch_buffer[95:80];                                
                                                endcase
                                                */
                                            end
                                        else
                                            begin
                                                bus_state <= `BUS_ST_FETCH_WORD; // incomplete
                                                bus_rd <= `S_ASSERTED;
                                            end
                                    end
                                else
                                    begin
                                        if ((nibbles_in_queue <= 5'd18) && (!inhibit_fetch)) // keep fetching
                                            begin
                                                bus_state <= `BUS_ST_FETCH_WORD; // incomplete
                                                bus_rd <= `S_ASSERTED;
                                                skip_size_check <= 1'b1;
                                            end
                                    end
                        end
                    `BUS_ST_READ:
                        begin
                            // load up to 4 nibbles
                            shift_now <= `S_NEGATED;
                            case (bus_addr[1:0])
                                2'b00: // aligned access
                                    begin
                                        case (nibbles_in_transfer)
                                            5'h0:  read_data[15: 0] <= bus_data_in;
                                            5'h1:  read_data[19: 4] <= bus_data_in;
                                            5'h2:  read_data[23: 8] <= bus_data_in;
                                            5'h3:  read_data[27:12] <= bus_data_in;
                                            5'h4:  read_data[31:16] <= bus_data_in;
                                            5'h5:  read_data[35:20] <= bus_data_in;
                                            5'h6:  read_data[39:24] <= bus_data_in;
                                            5'h7:  read_data[43:28] <= bus_data_in;
                                            5'h8:  read_data[47:32] <= bus_data_in;
                                            5'h9:  read_data[51:36] <= bus_data_in;
                                            5'ha:  read_data[55:40] <= bus_data_in;
                                            5'hb:  read_data[59:44] <= bus_data_in;
                                            5'hc:  read_data[63:48] <= bus_data_in;
                                            5'hd:  read_data[63:52] <= bus_data_in[11: 0];
                                            5'he:  read_data[63:56] <= bus_data_in[ 7: 0];
                                            5'hf:  read_data[63:60] <= bus_data_in[ 3: 0];
                                        endcase
                                        nibbles_in_transfer <= nibbles_in_transfer + 5'h4;
                                        bus_addr <= bus_addr + 20'h4;
                                    end
                                2'b01: // fetch only 3 nibbles, happens only after flush
                                    begin
                                        read_data[12: 0] <= bus_data_in[15: 4];
                                        nibbles_in_transfer <= nibbles_in_transfer + 5'h3;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                                2'b10: // fetch only 3 nibbles, happens only after flush
                                    begin
                                        read_data[ 7: 0] <= bus_data_in[15: 8];
                                        nibbles_in_transfer <= nibbles_in_transfer + 5'h2;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                                2'b11: // fetch only 1 nibble, happens only after flush
                                    begin
                                        read_data[ 3: 0] <= bus_data_in[15:12];
                                        nibbles_in_transfer <= nibbles_in_transfer + 5'h1;
                                        bus_addr <= { bus_addr[19:2] + 18'h1, 2'b00 }; // next access will be aligned
                                    end
                            endcase
                            bus_rd <= `S_NEGATED;
                            bus_state <= `BUS_ST_READ_CHECK;
                        end
                    `BUS_ST_READ_CHECK:
                        begin
                            bus_rd <= `S_NEGATED;
                            if (nibbles_in_transfer >= dst_total_nibs)
                                begin
                                    read_data <= read_data << { data_field_right_in, 2'b00 };
                                    data_read_ready <= 1'b1;
                                    bus_state <= `BUS_ST_WAIT;
                                end
                            else
                                begin
                                    bus_state <= `BUS_ST_READ;
                                    bus_rd <= `S_ASSERTED;
                                end
                        end
                    `BUS_ST_WRITE:
                        begin
                        end
                    `BUS_ST_WRITE1:
                        begin
                        end
                endcase
            end
    end

endmodule

/**
 * Predecode an opcode to extract the size
 *
 *
 */
module saturn_predecoder(
    input wire [19:0] opcode_in,
    input wire [4:0] nibbles_in_queue_in,
    output wire [4:0] size_o,
    output wire     inhibit_fetch_o     // asserted when a jump is in the queue

);

wire [3:0] op0, op1, op2, op3, op4;

wire op_is_size_2;
wire op_is_size_3, op_is_size_3b;
wire op_is_size_4, op_is_size_4b;
wire op_is_size_5, op_is_size_5b;
wire op_is_size_6, op_is_size_6b;
wire op_is_size_7, op_is_size_7b;

wire op0_0, op0_1, op0_2, op0_3, op0_4, op0_5, op0_6, op0_7, op0_8, op0_9, op0_A, op0_B, op0_C, op0_D, op0_E, op0_F;
wire op1_0, op1_1, op1_2, op1_3, op1_4, op1_5, op1_6, op1_7, op1_8, op1_9, op1_A, op1_B, op1_C, op1_D, op1_E, op1_F;
wire op2_0, op2_1, op2_2, op2_3, op2_4, op2_5, op2_6, op2_7, op2_8, op2_9, op2_A, op2_B, op2_C, op2_D, op2_E, op2_F;
wire op3_0, op3_1, op3_2, op3_3, op3_4, op3_5, op3_6, op3_7, op3_8, op3_9, op3_A, op3_B, op3_C, op3_D, op3_E, op3_F;
wire op_is_la, op_goto;
reg [4:0] size = 5'h00;

assign op0 = opcode_in[3:0];
assign op1 = opcode_in[7:4];
assign op2 = opcode_in[11:8];
assign op3 = opcode_in[15:12];
assign op4 = opcode_in[19:16];

	
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

assign op3_0 = op3 == 4'h0;
assign op3_1 = op3 == 4'h1;
assign op3_2 = op3 == 4'h2;
assign op3_3 = op3 == 4'h3;
assign op3_4 = op3 == 4'h4;
assign op3_5 = op3 == 4'h5;
assign op3_6 = op3 == 4'h6;
assign op3_7 = op3 == 4'h7;
assign op3_8 = op3 == 4'h8;
assign op3_9 = op3 == 4'h9;
assign op3_A = op3 == 4'hA;
assign op3_B = op3 == 4'hB;
assign op3_C = op3 == 4'hC;
assign op3_D = op3 == 4'hD;
assign op3_E = op3 == 4'hE;
assign op3_F = op3 == 4'hF;

/* Pre-decode to extract size */

assign op_is_size_2 = ((op0_0) && (op1 != 4'hE)) || 
                      (op0_2) ||
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

assign op_is_size_4 = ((op0_0) && (op1_E)) ||
                      ((op0_1) && ((op1_5) || (op1_9) || (op1_D))) || // Dx=(2)
                      (op0_6) ||
                      (op0_7);

assign op_is_size_5 = (op0_9);
                      
assign op_is_size_6 = ((op0_1) && ((op1_A) || (op1_E))) || // Dx=(4)
                      ((op0_8) && ((op1_C) || (op1_E)));
                      
assign op_is_size_7 = ((op0_1) && ((op1_B) || (op1_F))) || // Dx=(5)
                      ((op0_8) && ((op1_D) || (op1_F))); 
                      
// these needs a third or fourth nibble before its size is known
assign op_is_size_3b = (op0_8) && (((op1_0) && (~((op2_8) || (op2_C) || 
                                                  (op2_D) || (op2_F)))) ||
                                   ((op1_1) && (~( (op2_8) || (op2_9) || (op2_A) || (op2_B)))));
                      
assign op_is_size_4b= (op0_8) && (((op1_0) && (((op2_8) && ((op3_0) || (op3_F))) || 
                                               (op2_C) || (op2_D) || (op2_F))) ||
                                 (((op1_1) && (op2_B) )));

assign op_is_size_5b= ((op0_8) && ((op1_0) && (((op2_8) && ((op3_4) || (op3_5) || (op3_8) || (op3_9))) ||
                                   (op1_3) || (op1_6) || (op1_7) || 
                                   (op1_8) || (op1_9) || (op1_A) ||
                                   (op1_B))) ||
                                 (((op1_1) && (op2_9) )));

assign op_is_size_6b= (op0_8) && (op1_1) && ((op2_8) || (op2_A));  // Rn=C.f

assign op_is_size_7b= (op0_8) && (((op1_0) && (((op2_8) && ((op3_6) || (op3_7) || (op3_A) || (op3_B)))))); 

assign op_is_la = ((op0_8) && (op1_0) && (op2_8) && (op3 == 4'h2));

assign op_goto = (op0_0 & (op1_0 | op1_1 | op1_2 | op1_3 | op1_F)) | // RTNs RTI
                 op0_4 | op0_5 | op0_6 | op0_7 | // GOC GONC GOTO GOSUB
                 (op0_8 & op1_0 & op2_8 & (op3_6 | op3_7 | op3_A | op3_B)) |// ?xBIT
                 (op0_8 & op1_0 & op2_8 & (op3_C | op3_D)) |// PC=(A) PC=(C)
                 (op0_8 & op1_1 & op2_B & (op3_2 | op3_3 | op3_6 | op3_7)) |// PC=A PC=C APCEX CPCEX
                 (op0_8 & (op1_3 | op1_6 | op1_7 | op1_8 | op1_9 | op1_A | op1_B)) | // ?HS ?ST ?P ?A
                 (op0_8 & (op1_C | op1_D | op1_E | op1_F)) | // GOL GOVL GOSBL GOSBVL
                 op0_9;
assign inhibit_fetch_o = op_goto;

always @(*)
    begin
        size = 5'h05; // with 5 nibbles all opcodes can be decoded safely
        if ((nibbles_in_queue_in == 5'h2) || (nibbles_in_queue_in == 5'h3))
            begin
                if (op_is_size_2 == 1'b1) size = 5'h02;
                else
                if (op_is_size_3 == 1'b1) size = 5'h03;
                else
                if (op_is_size_4 == 1'b1) size = 5'h04;
                else
                if (op_is_size_5 == 1'b1) size = 5'h05;
                else
                if (op_is_size_6 == 1'b1) size = 5'h06;
                else
                if (op_is_size_7 == 1'b1) size = 5'h07;
                else
                if (op0_3) size = 5'h03 + { 1'b0, op1 }; // LC
            end
        else
            if (nibbles_in_queue_in >= 5'h4)
                begin
                    if (op_is_size_2 == 1'b1) size = 5'h02;
                    else
                    if ((op_is_size_3 == 1'b1) || (op_is_size_3b == 1'b1)) size = 5'h03;
                    else
                    if ((op_is_size_4 == 1'b1) || (op_is_size_4b == 1'b1)) size = 5'h04;
                    else
                    if ((op_is_size_5 == 1'b1) || (op_is_size_5b == 1'b1)) size = 5'h05;
                    else
                    if ((op_is_size_6 == 1'b1) || (op_is_size_6b == 1'b1)) size = 5'h06;
                    else
                    if ((op_is_size_7 == 1'b1) || (op_is_size_7b == 1'b1)) size = 5'h07;
                    else
                    if (op0_3) size = 5'h03 + { 1'b0, op1 }; // LCelse
                    else
                    if (op_is_la) size = 5'h05 + { 1'b0, op4 }; // LA
                end
    end

assign size_o = size;
    
endmodule