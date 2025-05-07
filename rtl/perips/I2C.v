module I2C (
    input   clk,
    input   rst,
    input   we_i,
    input   [31:0]      write_addr,
    input   [31:0]      write_data,
    output  [31:0]      read_data,
    output              i2c_compl,

    input               i2c_sda_i,
    output              i2c_scl_o,
    output  reg         i2c_sda_o
);
    localparam  clock_freq = 50000000; // 50MHz
    localparam  i2c_freq = 400000; // 400KHz
    //localparam  i2c_div = clock_freq / i2c_freq; // 125
    localparam  i2c_div = 8'd125; // 124
    localparam  i2c_idle = 3'd0,
                i2c_start = 3'd1,
                i2c_addr_compare = 3'd2,
                i2c_addr_ack = 3'd3,
                i2c_write = 3'd4,
                i2c_write_ack = 3'd5,
                i2c_read = 3'd6,
                i2c_read_ack = 3'd7,
                i2c_stop = 3'd8;

    reg [6:0]   i2c_addr;
    reg [2:0]   i2c_byte_cnt;
    reg [31:0]  i2c_data;
    reg [3:0]   i2c_state;
    reg [7:0]   i2c_div_cnt;
    reg [3:0]   i2c_transfer_cnt;
    reg         i2c_operation;//0:write, 1:read
    reg         i2c_sda_in_temp;
    reg [31:0]  i2c_read_data;

    wire    [7:0]   i2c_sda_o_next;
    reg [3:0]   i2c_state_next;
    reg [3:0]   i2c_transfer_cnt_next;

    assign  read_data = {32{write_addr==32'h070030000}} & i2c_read_data;
    assign  i2c_compl = (i2c_state == i2c_stop & i2c_state_next == i2c_idle);

    always @(posedge clk) begin
        if (~rst) begin
            i2c_state <= i2c_idle;
            i2c_addr <= 7'b0;
            i2c_byte_cnt <= 3'b0;
            i2c_data <= 32'b0;
            i2c_div_cnt <= 8'd128;
            i2c_transfer_cnt <= 4'b0;
            i2c_operation <= 1'b0;
            i2c_sda_in_temp <= 1'b1;
            i2c_read_data <= 32'b0;
        end 
        else begin
            i2c_state <= i2c_state_next;
            i2c_div_cnt <= (i2c_state != i2c_idle)? (i2c_div_cnt == 8'd252 ? 8'b0 : 
                                                     i2c_div_cnt == 8'd124 ? 8'd128 :
                                                     i2c_div_cnt + 1) : 8'd128;
            i2c_transfer_cnt <= i2c_transfer_cnt_next;
            i2c_sda_in_temp <= (i2c_div_cnt==8'd168)?i2c_sda_i:i2c_sda_in_temp;
            i2c_read_data[31] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[31];
            i2c_read_data[30] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[30];
            i2c_read_data[29] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[29];
            i2c_read_data[28] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[28];
            i2c_read_data[27] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[27];
            i2c_read_data[26] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[26];
            i2c_read_data[25] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[25];
            i2c_read_data[24] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt==3'd4)?i2c_sda_i:i2c_read_data[24];
            i2c_read_data[23] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[23];
            i2c_read_data[22] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[22];
            i2c_read_data[21] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[21];
            i2c_read_data[20] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[20];
            i2c_read_data[19] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[19];
            i2c_read_data[18] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[18];
            i2c_read_data[17] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[17];
            i2c_read_data[16] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt==3'd3)?i2c_sda_i:i2c_read_data[16];
            i2c_read_data[15] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[15];
            i2c_read_data[14] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[14];
            i2c_read_data[13] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[13];
            i2c_read_data[12] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[12];
            i2c_read_data[11] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[11];
            i2c_read_data[10] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[10];
            i2c_read_data[9] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[9];
            i2c_read_data[8] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt==3'd2)?i2c_sda_i:i2c_read_data[8];
            i2c_read_data[7] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[7];
            i2c_read_data[6] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[6];
            i2c_read_data[5] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[5];
            i2c_read_data[4] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[4];
            i2c_read_data[3] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[3];
            i2c_read_data[2] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[2];
            i2c_read_data[1] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[1];
            i2c_read_data[0] <= (i2c_state == i2c_read & i2c_div_cnt == 8'd192 & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt==3'd1)?i2c_sda_i:i2c_read_data[0];
            if (we_i & write_addr==32'h70010000) begin
                i2c_addr <= write_data[6:0];
                i2c_byte_cnt <= write_data[9:7];
                i2c_operation <= write_data[10];
            end
            else begin
                i2c_addr <= i2c_addr;
                i2c_byte_cnt <= (i2c_state==i2c_write & i2c_state_next==i2c_write_ack | i2c_state==i2c_read & i2c_state_next==i2c_read_ack)?i2c_byte_cnt-1:i2c_byte_cnt;
                i2c_operation <= i2c_operation;
            end
            if (we_i & write_addr==32'h70020000) begin
                i2c_data <= write_data;
            end
            else begin
                i2c_data <= i2c_data;
            end
        end
    end
    assign  i2c_scl_o = i2c_div_cnt[7]; 

    always @(*) begin
        case (i2c_state)
            i2c_idle: begin
                    i2c_sda_o = 1'b1;
                    i2c_state_next = we_i?i2c_start:i2c_idle;
                    i2c_transfer_cnt_next = 4'b0;
            end
            i2c_start: begin
                if (i2c_div_cnt >= 8'd138 & i2c_div_cnt < 8'd252) begin
                    i2c_sda_o = 1'b0;
                    i2c_state_next = i2c_start;
                    i2c_transfer_cnt_next = 4'd0;
                end
                else if (i2c_div_cnt == 8'd252) begin
                    i2c_sda_o = 1'b0;
                    i2c_state_next = i2c_addr_compare;
                    i2c_transfer_cnt_next = 4'd9;
                end
                else begin
                    i2c_sda_o = 1'b1;
                    i2c_state_next = i2c_start;
                    i2c_transfer_cnt_next = 4'b0;
                end
            end
            i2c_addr_compare: begin
                if(i2c_transfer_cnt != 4'b0) begin
                    i2c_sda_o = i2c_addr[6] & i2c_transfer_cnt == 4'd8 |
                                i2c_addr[5] & i2c_transfer_cnt == 4'd7 |
                                i2c_addr[4] & i2c_transfer_cnt == 4'd6 |
                                i2c_addr[3] & i2c_transfer_cnt == 4'd5 |
                                i2c_addr[2] & i2c_transfer_cnt == 4'd4 |
                                i2c_addr[1] & i2c_transfer_cnt == 4'd3 |
                                i2c_addr[0] & i2c_transfer_cnt == 4'd2 |
                                i2c_operation & i2c_transfer_cnt == 4'd1;
                end
                if (i2c_div_cnt == 8'd10) begin
                    i2c_transfer_cnt_next= (i2c_transfer_cnt==4'b0)?i2c_transfer_cnt - 1:4'b0;
                    i2c_state_next =( i2c_transfer_cnt==4'd0)?i2c_addr_ack:i2c_addr_compare;
                end
                else begin
                    i2c_transfer_cnt_next = i2c_transfer_cnt;
                    i2c_state_next = i2c_addr_compare;
                end
            end
            i2c_addr_ack: begin
                i2c_sda_o = 1'bz;
                if (i2c_div_cnt == 8'd208 & i2c_sda_in_temp == 1'b0 &i2c_sda_i==1'b0) begin
                    i2c_state_next = i2c_operation? i2c_read :i2c_write;
                    i2c_transfer_cnt_next = 4'd9;
                end
                else begin
                    i2c_state_next = i2c_addr_ack;
                    i2c_transfer_cnt_next = 4'd0;
                end
            end
            i2c_write: begin
                if (i2c_transfer_cnt != 4'b0 & i2c_byte_cnt != 3'd0) begin
                    i2c_sda_o = i2c_data[31] & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt == 3'd4|
                                i2c_data[30] & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt == 3'd4|
                                i2c_data[29] & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt == 3'd4|
                                i2c_data[28] & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt == 3'd4|
                                i2c_data[27] & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt == 3'd4|
                                i2c_data[26] & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt == 3'd4|
                                i2c_data[25] & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt == 3'd4|
                                i2c_data[24] & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt == 3'd4|
                                i2c_data[23] & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt == 3'd3|
                                i2c_data[22] & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt == 3'd3|
                                i2c_data[21] & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt == 3'd3|
                                i2c_data[20] & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt == 3'd3|
                                i2c_data[19] & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt == 3'd3|
                                i2c_data[18] & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt == 3'd3|
                                i2c_data[17] & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt == 3'd3|
                                i2c_data[16] & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt == 3'd3|
                                i2c_data[15] & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt == 3'd2|
                                i2c_data[14] & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt == 3'd2|
                                i2c_data[13] & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt == 3'd2|
                                i2c_data[12] & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt == 3'd2|
                                i2c_data[11] & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt == 3'd2|
                                i2c_data[10] & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt == 3'd2|
                                i2c_data[9] & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt == 3'd2|
                                i2c_data[8] & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt == 3'd2|
                                i2c_data[7] & i2c_transfer_cnt == 4'd8 & i2c_byte_cnt == 3'd1|
                                i2c_data[6] & i2c_transfer_cnt == 4'd7 & i2c_byte_cnt == 3'd1|
                                i2c_data[5] & i2c_transfer_cnt == 4'd6 & i2c_byte_cnt == 3'd1|
                                i2c_data[4] & i2c_transfer_cnt == 4'd5 & i2c_byte_cnt == 3'd1|
                                i2c_data[3] & i2c_transfer_cnt == 4'd4 & i2c_byte_cnt == 3'd1|
                                i2c_data[2] & i2c_transfer_cnt == 4'd3 & i2c_byte_cnt == 3'd1|
                                i2c_data[1] & i2c_transfer_cnt == 4'd2 & i2c_byte_cnt == 3'd1|
                                i2c_data[0] & i2c_transfer_cnt == 4'd1 & i2c_byte_cnt == 3'd1;
                end
                else begin
                    i2c_sda_o = 1'bz;
                end
                if (i2c_div_cnt == 8'd10) begin
                    i2c_transfer_cnt_next= (i2c_transfer_cnt==4'b0)?i2c_transfer_cnt - 1:4'b0;
                    i2c_state_next =(i2c_transfer_cnt==4'b0)?i2c_write_ack:i2c_write;
                end
                else begin
                    i2c_transfer_cnt_next = i2c_transfer_cnt;
                    i2c_state_next = i2c_write;
                end
            end
            i2c_write_ack: begin
                i2c_sda_o = 1'bz;
                if (i2c_div_cnt == 8'd208 & i2c_sda_in_temp == 1'b0 & i2c_sda_i==1'b0) begin
                    i2c_state_next = (i2c_byte_cnt==3'b0)? i2c_stop : i2c_write;
                    i2c_transfer_cnt_next = 4'd9;
                end
                else begin
                    i2c_state_next = i2c_write_ack;
                    i2c_transfer_cnt_next = 4'd0;
                end
            end
            i2c_read: begin
                i2c_sda_o = 1'bz;
                if (i2c_div_cnt == 8'd10) begin
                    i2c_transfer_cnt_next= (i2c_transfer_cnt==4'b0)?i2c_transfer_cnt - 1:4'b0;
                    i2c_state_next =(i2c_transfer_cnt==4'b0)?i2c_read_ack:i2c_read;
                end
                else begin
                    i2c_transfer_cnt_next = i2c_transfer_cnt;
                    i2c_state_next = i2c_read;
                end
            end
            i2c_read_ack: begin
                i2c_sda_o = 1'b0;
                if (i2c_div_cnt == 8'd10) begin
                        i2c_state_next = (i2c_byte_cnt==3'b0)? i2c_stop : i2c_read;
                        i2c_transfer_cnt_next = 4'd9;  
                end
                else begin
                    i2c_state_next = i2c_read_ack;
                    i2c_transfer_cnt_next = 4'd0;
                end
            end
            i2c_stop: begin
                    i2c_transfer_cnt_next = 4'd0;
                if (i2c_div_cnt >= 8'd138 & i2c_div_cnt < 8'd252) begin
                    i2c_sda_o = 1'b1;
                    i2c_state_next = i2c_stop;
                end
                else if (i2c_div_cnt == 8'd252) begin
                    i2c_sda_o = 1'bz;
                    i2c_state_next = i2c_idle;
                end
                else begin
                    i2c_sda_o = 1'b0;
                    i2c_state_next = i2c_stop;
                end
            end
            default: begin // other states.
                i2c_sda_o = 1'b1;
                i2c_state_next = i2c_idle; // reset to idle state.
            end
        endcase
    end
endmodule