 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */


// 串口模块(默认: 115200, 8 N 1)
module uart(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,
	output wire tx_pin,
    input wire rx_pin,
    output wire SID_done

    );


    // 50MHz时钟，波特率115200bps对应的分频系�?
    localparam BAUD_115200 = 32'h1B8;

    localparam S_IDLE       = 4'b0001;
    localparam S_START      = 4'b0010;
    localparam S_SEND_BYTE  = 4'b0100;
    localparam S_STOP       = 4'b1000;

    reg tx_data_valid;
    reg tx_data_ready;

    reg[3:0] state;
    reg[15:0] cycle_cnt;
    reg[3:0] bit_cnt;
    reg[7:0] tx_data;
    reg tx_reg;

    reg rx_q0;
    reg rx_q1;
    wire rx_negedge;
    reg rx_start;                      // RX使能
    reg[3:0] rx_clk_edge_cnt;          // clk时钟沿的个数
    reg rx_clk_edge_level;             // clk沿电�?
    reg rx_done;
    reg[15:0] rx_clk_cnt;
    reg[15:0] rx_div_cnt;
    reg[7:0] rx_data;
    reg rx_over;

    localparam UART_CTRL = 8'h0;
    localparam UART_STATUS = 8'h4;
    localparam UART_BAUD = 8'h8;
    localparam UART_TXDATA = 8'hc;
    localparam UART_RXDATA = 8'h10;
    localparam UART_SID = 8'h14;

    // addr: 0x00
    // rw. bit[0]: tx enable, 1 = enable, 0 = disable
    // rw. bit[1]: rx enable, 1 = enable, 0 = disable
    reg[31:0] uart_ctrl;

    // addr: 0x04
    // ro. bit[0]: tx busy, 1 = busy, 0 = idle
    // rw. bit[1]: rx over, 1 = over, 0 = receiving
    // must check this bit before tx data
    reg[31:0] uart_status;

    // addr: 0x08
    // rw. clk div
    reg[31:0] uart_baud;

    // addr: 0x10
    // ro. rx data
    reg[31:0] uart_rx;

    assign tx_pin = tx_reg;

    //SID
    reg [3:0]   sid_state;
    reg [3:0]   sid_state_next;
    wire [7:0] data_SID;

    always @(*) begin
        case (sid_state)
            4'b0000: sid_state_next = sid_state;
            4'b0001: sid_state_next = tx_data_ready?4'b0010:sid_state;
            4'b0010: sid_state_next = tx_data_ready?4'b0011:sid_state;
            4'b0011: sid_state_next = tx_data_ready?4'b0100:sid_state;
            4'b0100: sid_state_next = tx_data_ready?4'b0101:sid_state;
            4'b0101: sid_state_next = tx_data_ready?4'b0110:sid_state;
            4'b0110: sid_state_next = tx_data_ready?4'b0111:sid_state;
            4'b0111: sid_state_next = tx_data_ready?4'b1000:sid_state;
            4'b1000: sid_state_next = tx_data_ready?4'b1001:sid_state;
            4'b1001: sid_state_next = tx_data_ready?4'b1010:sid_state;
            4'b1010: sid_state_next = tx_data_ready?4'b0000:sid_state;
            default: sid_state_next = sid_state;
        endcase 
    end

    assign data_SID = {8{sid_state==4'b0000}} & 8'h0 |
                      {8{sid_state==4'b0001}} & 8'h32 |
                      {8{sid_state==4'b0010}} & 8'h30 |
                      {8{sid_state==4'b0011}} & 8'h32 |
                      {8{sid_state==4'b0100}} & 8'h34 |
                      {8{sid_state==4'b0101}} & 8'h32 |
                      {8{sid_state==4'b0110}} & 8'h31 |
                      {8{sid_state==4'b0111}} & 8'h31 |
                      {8{sid_state==4'b1000}} & 8'h30 |
                      {8{sid_state==4'b1001}} & 8'h35 |
                      {8{sid_state==4'b1010}} & 8'h33;

    assign SID_done = (sid_state==4'b1010)& tx_data_ready? 1'b1 : 1'b0;

    // 写寄存器
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            uart_ctrl <= 32'h0;
            uart_status <= 32'h0;
            uart_rx <= 32'h0;
            uart_baud <= BAUD_115200;
            tx_data_valid <= 1'b0;
            sid_state <= 4'b0000;
        end 
        else begin
            if (we_i == 1'b1) begin
                case (addr_i[7:0])
                    UART_CTRL: begin
                        uart_ctrl <= data_i;
                    end
                    UART_BAUD: begin
                        uart_baud <= data_i;
                    end
                    UART_STATUS: begin
                        uart_status[1] <= data_i[1];
                    end
                    UART_TXDATA: begin
                        if (uart_ctrl[0] == 1'b1 && uart_status[0] == 1'b0) begin
                            tx_data <= data_i[7:0];
                            uart_status[0] <= 1'b1;
                            tx_data_valid <= 1'b1;
                        end
                    end
                    UART_SID: begin
                        if (sid_state == 4'b0000) begin
                            sid_state <= 4'b0001;
                        end
                    end
                endcase
            end 
            else begin
                sid_state <= sid_state_next;
                if (uart_ctrl[1] == 1'b1) begin
                        if (rx_over == 1'b1) begin
                            uart_status[1] <= 1'b1;
                            uart_rx <= {24'h0, rx_data};
                        end
                    end
                if(sid_state==4'b0000)  begin
                    tx_data_valid <= 1'b0;
                    if (tx_data_ready == 1'b1) begin
                        uart_status[0] <= 1'b0;
                    end
                end
                else    begin
                    if (tx_data_ready == 1'b1) begin
                        uart_status[0] <= 1'b0;
                        tx_data_valid <= 1'b0;
                    end
                    else if (uart_status[0] == 1'b0) begin
                        tx_data_valid <= 1'b1;
                        uart_status[0] <= 1'b1;
                        tx_data <= data_SID;
                    end  
                end    
            end
        end
    end

    // 读寄存器
    always @ (*) begin
        if (rst == 1'b0) begin
            data_o = 32'h0;
        end else begin
            case (addr_i[7:0])
                UART_CTRL: begin
                    data_o = uart_ctrl;
                end
                UART_STATUS: begin
                    data_o = uart_status;
                end
                UART_BAUD: begin
                    data_o = uart_baud;
                end
                UART_RXDATA: begin
                    data_o = uart_rx;
                end
                default: begin
                    data_o = 32'h0;
                end
            endcase
        end
    end

    // *************************** TX发�?? ****************************

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            state <= S_IDLE;
            cycle_cnt <= 16'd0;
            tx_reg <= 1'b0;
            bit_cnt <= 4'd0;
            tx_data_ready <= 1'b0;
        end else begin
            if (state == S_IDLE) begin
                tx_reg <= 1'b1;
                tx_data_ready <= 1'b0;
                if (tx_data_valid == 1'b1) begin
                    state <= S_START;
                    cycle_cnt <= 16'd0;
                    bit_cnt <= 4'd0;
                    tx_reg <= 1'b0;
                end
            end else begin
                cycle_cnt <= cycle_cnt + 16'd1;
                if (cycle_cnt == uart_baud[15:0]) begin
                    cycle_cnt <= 16'd0;
                    case (state)
                        S_START: begin
                            tx_reg <= tx_data[bit_cnt];
                            state <= S_SEND_BYTE;
                            bit_cnt <= bit_cnt + 4'd1;
                        end
                        S_SEND_BYTE: begin
                            bit_cnt <= bit_cnt + 4'd1;
                            if (bit_cnt == 4'd8) begin
                                state <= S_STOP;
                                tx_reg <= 1'b1;
                            end else begin                
                                tx_reg <= tx_data[bit_cnt];
                            end
                        end
                        S_STOP: begin
                            tx_reg <= 1'b1;
                            state <= S_IDLE;
                            tx_data_ready <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

    // *************************** RX接收 ****************************

    // 下降沿检�?(�?测起始信�?)
    assign rx_negedge = rx_q1 && ~rx_q0;


    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_q0 <= 1'b0;
            rx_q1 <= 1'b0;	
        end else begin
            rx_q0 <= rx_pin;
            rx_q1 <= rx_q0;
        end
    end

    // �?始接收数据信号，接收期间�?直有�?
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_start <= 1'b0;
        end else begin
            if (uart_ctrl[1]) begin
                if (rx_negedge) begin
                    rx_start <= 1'b1;
                end else if (rx_clk_edge_cnt == 4'd9) begin
                    rx_start <= 1'b0;
                end
            end else begin
                rx_start <= 1'b0;
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_div_cnt <= 16'h0;
        end else begin
            // 第一个时钟沿只需波特率分频系数的�?�?
            if (rx_start == 1'b1 && rx_clk_edge_cnt == 4'h0) begin
                rx_div_cnt <= {1'b0, uart_baud[15:1]};
            end else begin
                rx_div_cnt <= uart_baud[15:0];
            end
        end
    end

    // 对时钟进行计�?
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_clk_cnt <= 16'h0;
        end else if (rx_start == 1'b1) begin
            // 计数达到分频�?
            if (rx_clk_cnt == rx_div_cnt) begin
                rx_clk_cnt <= 16'h0;
            end else begin
                rx_clk_cnt <= rx_clk_cnt + 1'b1;
            end
        end else begin
            rx_clk_cnt <= 16'h0;
        end
    end

    // 每当时钟计数达到分频值时产生�?个上升沿脉冲
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end else if (rx_start == 1'b1) begin
            // 计数达到分频�?
            if (rx_clk_cnt == rx_div_cnt) begin
                // 时钟沿个数达到最大�??
                if (rx_clk_edge_cnt == 4'd9) begin
                    rx_clk_edge_cnt <= 4'h0;
                    rx_clk_edge_level <= 1'b0;
                end else begin
                    // 时钟沿个数加1
                    rx_clk_edge_cnt <= rx_clk_edge_cnt + 1'b1;
                    // 产生上升沿脉�?
                    rx_clk_edge_level <= 1'b1;
                end
            end else begin
                rx_clk_edge_level <= 1'b0;
            end
        end else begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end
    end

    // bit序列
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            rx_data <= 8'h0;
            rx_over <= 1'b0;
        end else begin
            if (rx_start == 1'b1) begin
                // 上升�?
                if (rx_clk_edge_level == 1'b1) begin
                    case (rx_clk_edge_cnt)
                        // 起始�?
                        1: begin

                        end
                        // 数据�?
                        2, 3, 4, 5, 6, 7, 8, 9: begin
                            rx_data <= rx_data | (rx_pin << (rx_clk_edge_cnt - 2));
                            // �?后一位接收完成，置位接收完成标志
                            if (rx_clk_edge_cnt == 4'h9) begin
                                rx_over <= 1'b1;
                            end
                        end
                    endcase
                end
            end else begin
                rx_data <= 8'h0;
                rx_over <= 1'b0;
            end
        end
    end

endmodule
