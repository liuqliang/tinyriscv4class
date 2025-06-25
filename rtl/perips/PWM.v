//PWM模块
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
        if (~rst) begin
            A0 <= 32'b0;
            A1 <= 32'b0;
            A2 <= 32'b0;
            A3 <= 32'b0;
            B0 <= 32'b0;
            B1 <= 32'b0;
            B2 <= 32'b0;
            B3 <= 32'b0;
            C <= 32'b0;
        end 
        else if (we_i) begin
            A0 <= (write_addr == 32'h00000000)?write_data:A0;
            A1 <= (write_addr == 32'h00010000)?write_data:A1;
            A2 <= (write_addr == 32'h00020000)?write_data:A2;
            A3 <= (write_addr == 32'h00030000)?write_data:A3;
            B0 <= (write_addr == 32'h00100000)?write_data:B0;
            B1 <= (write_addr == 32'h00110000)?write_data:B1;
            B2 <= (write_addr == 32'h00120000)?write_data:B2;
            B3 <= (write_addr == 32'h00130000)?write_data:B3;
            C <=  (write_addr == 32'h00040000)?write_data:C;
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
            counter0 <= counter0_next;
            counter1 <= counter1_next;
            counter2 <= counter2_next;
            counter3 <= counter3_next;
            
        end
    end
    assign  counter0_next = counter0==A0 ?32'b0:counter0 + 32'b1;
    assign  counter1_next = counter1==A1 ?32'b0:counter1 + 32'b1;
    assign  counter2_next = counter2==A2 ?32'b0:counter2 + 32'b1;
    assign  counter3_next = counter3==A3 ?32'b0:counter3 + 32'b1;

    assign pwm_out[0] = C[0] & (counter0 < B0) ? 1'b1 : 1'b0;
    assign pwm_out[1] = C[1] & (counter1 < B1) ? 1'b1 : 1'b0;
    assign pwm_out[2] = C[2] & (counter2 < B2) ? 1'b1 : 1'b0;
    assign pwm_out[3] = C[3] & (counter3 < B3) ? 1'b1 : 1'b0;   
endmodule