//PWM模块
`include "defines.v"
module PWM (
    input   clk,
    input   rst,
    input   we_i,
    input   [31:0]      write_addr,
    input   [31:0]      write_data,
    output  [3:0]       pwm_out
);
    reg [31:0] A0, A1, A2, A3;
    reg [31:0] B0, B1, B2, B3;
    reg [31:0] C;

    reg [31:0] counter0, counter1, counter2, counter3;
    wire    [31:0]  counter0_next, counter1_next, counter2_next, counter3_next; 
    
    always @(posedge clk) begin
        if (rst == `RstEnable ) begin
            A0 <= `ZeroWord;
            A1 <= `ZeroWord;
            A2 <= `ZeroWord;
            A3 <= `ZeroWord;
            B0 <= `ZeroWord;
            B1 <= `ZeroWord;
            B2 <= `ZeroWord;
            B3 <= `ZeroWord;
            C <= `ZeroWord;
        end 
        else if (we_i) begin
            A0 <= write_data & {32{write_addr == 32'h60000000}};
            A1 <= write_data & {32{write_addr == 32'h60010000}};
            A2 <= write_data & {32{write_addr == 32'h60020000}};
            A3 <= write_data & {32{write_addr == 32'h60030000}};
            B0 <= write_data & {32{write_addr == 32'h60100000}};
            B1 <= write_data & {32{write_addr == 32'h60110000}};
            B2 <= write_data & {32{write_addr == 32'h60120000}};
            B3 <= write_data & {32{write_addr == 32'h60130000}};
            C <=  write_data & {32{write_addr == 32'h60040000}};
        end
    end

    always @(posedge clk) begin
        if(rst == `RstEnable) begin
            counter0 <= 32'b0;
            counter1 <= 32'b0;
            counter2 <= 32'b0;
            counter3 <= 32'b0;
        end 
        else begin
            counter0 <= C[0] | counter0_next==A0 ? counter0_next:32'b0;
            counter1 <= C[1] | counter1_next==A1 ? counter1_next:32'b0;
            counter2 <= C[2] | counter2_next==A2 ? counter2_next:32'b0;
            counter3 <= C[3] | counter3_next==A3 ? counter3_next:32'b0;
            
        end
    end
    assign  counter0_next = counter0 + 32'b1;
    assign  counter1_next = counter1 + 32'b1;
    assign  counter2_next = counter2 + 32'b1;
    assign  counter3_next = counter3 + 32'b1;
    
    assign pwm_out[0] = C[0] & (counter0 < B0) ? 1'b1 : 1'b0;
    assign pwm_out[1] = C[1] & (counter1 < B1) ? 1'b1 : 1'b0;
    assign pwm_out[2] = C[2] & (counter2 < B2) ? 1'b1 : 1'b0;
    assign pwm_out[3] = C[3] & (counter3 < B3) ? 1'b1 : 1'b0;   
endmodule