`timescale 1ns / 1ns

module uart_debug_tb;
  reg  clk = 0;
  reg  rst_n = 0;
  always #1 clk = ~clk;

  // DUT UART 接口
  wire tx;  // 可连接 DUT 输出
  reg  rx = 1;  // 传输线空闲为高
  reg uart_debug_en = 1;
  wire i2c_scl;
  wire i2c_sda;

  // 初始化 DUT 实例（请根据你的DUT命名调整端口）
  tinyriscv_soc_top tinyriscv_soc_top_0 (
      .clk(clk),
      .rst(rst_n),
      .uart_debug_pin(uart_debug_en),
      .uart_tx_pin(tx),  // UART发送引脚
      .uart_rx_pin(rx),  // UART接收引脚
      .i2c_scl(i2c_scl),
      .i2c_sda(i2c_sda)
  );

  pullup(i2c_scl);
  pullup(i2c_sda);

  // 待发送的数据
  reg [31:0] data_file[0:1023];
  reg [7:0] data_packet[0:34];
  reg [31:0] data_file_size;
  integer i;
  reg [4095:0] crc_input;
  reg [15:0] crc_result;
  reg [7:0] temp_8bit;

  // 计算每bit持续的时间（以50MHz为例，1 bit = 8680ns ≈ 434 cycles）
  localparam BIT_TIME = 16;

  integer idx;
  initial begin
    // 读取数据文件
    $readmemh("C:/Users/Humber/Projects/tinyriscv/CustomTest/Other_Example/PWM/PWM_inst.data", data_file);
    data_file_size = 0;
    for(idx = 0; idx < 1024; idx = idx + 1) begin 
      if(data_file[idx] !== 32'hxxxx_xxxx) begin 
        data_file_size = data_file_size + 4;
      end else begin 
        data_file[idx] = 32'hDEAD_BEEF; // 填充无效数据
      end
    end

    // 生成uart_debug packet 0
    for(idx = 0; idx < 29; idx = idx + 1) begin
      data_packet[idx] = 8'h00;
    end
    data_packet[29] = data_file_size[31:24];
    data_packet[30] = data_file_size[23:16];
    data_packet[31] = data_file_size[15:8];
    data_packet[32] = data_file_size[7:0];
    for(idx = 0; idx < 32; idx = idx + 1) begin
      crc_input[idx*8+:8] = data_packet[idx+1];
    end
    crc_result = crc16_modbus(crc_input, 32);
    data_packet[33] = crc_result[7:0];
    data_packet[34] = crc_result[15:8];

    // 复位
    rst_n = 0;
    #10;
    @(negedge clk) rst_n = 1; // 等待DUT准备好
    #10;
    @(negedge clk);

    // 发送所有字节
    for(idx = 0; idx < (data_file_size + 31) / 32 + 1; idx = idx + 1) begin
      for (i = 0; i < 35; i = i + 1) begin
        @(negedge clk);
        uart_send_byte(data_packet[i]);
        #(BIT_TIME * 2);  // 每字节后留点空余时间
      end
      uart_receive_byte(10000, temp_8bit);
      if (temp_8bit == 8'h6) begin
        $display("uart_debug: packet %d send OK", idx);
      end else if(temp_8bit == 8'h15) begin 
        $display("uart_debug: ERROR packet %d NACK", idx);
        $stop();
      end else begin 
        $display("uart_debug: ERROR packet %d get unknown ACK data %x", idx, temp_8bit);
        $stop();
      end
      data_packet[0] = idx + 1;
      for(i = 0; i < 32; i = i + 4) begin
        data_packet[i+1] = data_file[idx * 8 + i/4][7:0];
        data_packet[i+2] = data_file[idx * 8 + i/4][15:8];
        data_packet[i+3] = data_file[idx * 8 + i/4][23:16];
        data_packet[i+4] = data_file[idx * 8 + i/4][31:24];
        crc_input[(i+0)*8+:8] = data_file[idx * 8 + i/4][7:0];
        crc_input[(i+1)*8+:8] = data_file[idx * 8 + i/4][15:8];
        crc_input[(i+2)*8+:8] = data_file[idx * 8 + i/4][23:16];
        crc_input[(i+3)*8+:8] = data_file[idx * 8 + i/4][31:24];
      end
      crc_result = crc16_modbus(crc_input, 32);
      data_packet[33] = crc_result[7:0];
      data_packet[34] = crc_result[15:8];
    end

    #100;
    @(negedge clk) uart_debug_en = 0;

    fork
      // begin 
      //   for(idx = 0; idx < 10; idx = idx + 1) begin
      //     uart_receive_byte(10000, temp_8bit);
      //     $display("%d", temp_8bit);
      //   end
      // end
      #10000 $finish;
    join
  end

  // UART 发送任务：起始位 + 数据位 + 停止位
  task uart_send_byte(input [7:0] data);
    integer j;
    begin
      rx = 0; // 起始位（低电平）
      #(BIT_TIME);

      // 数据位（低位先传）
      for (j = 0; j < 8; j = j + 1) begin
        rx = data[j];
        #(BIT_TIME);
      end

      // 停止位（高电平）
      rx = 1;
      #(BIT_TIME);
    end
  endtask

  task uart_receive_byte(input [31:0] timeout, output [7:0] data);
    integer j;
    begin
      j = 0;
      while(tx && j < timeout) begin
        #1 j = j + 1;
      end
      if(tx) begin
        $display("uart_debug: ERROR: RX timeout");
        $stop(); // 等待起始位超时
      end

      #(BIT_TIME / 2); // 等待半个比特时间，确保数据稳定
      #(BIT_TIME);     // 跳过起始位
      for (j = 0; j < 8; j = j + 1) begin // 接收数据位（低位先接）
        data[j] = tx;
        #(BIT_TIME);
      end
      #(BIT_TIME/2); // 等待停止位结束
    end
  endtask

  initial begin
    $dumpfile("uart_debug_tb.fst");
    $dumpvars();
    // for (idx = 0; idx < 35; idx = idx + 1)
    // $dumpvars(0, tinyriscv_soc_top_0.u_uart_debug.rx_data[idx]);
  end

  function [15:0] crc16_modbus;
    input [4095:0] data;  // 最多 512 字节的数据（4096 位）
    input integer byte_count;  // 实际使用的数据字节数

    reg [15:0] crc;
    integer i, j;
    reg [7:0] curr_byte;
    begin
      crc = 16'hFFFF;
      for (i = 0; i < byte_count; i = i + 1) begin
        curr_byte = data[i*8+:8];  // 提取当前字节，低位在前
        crc = crc ^ curr_byte;
        for (j = 0; j < 8; j = j + 1) begin
          if (crc[0]) crc = (crc >> 1) ^ 16'hA001;  // 多项式反转形式（Modbus标准）
          else crc = crc >> 1;
        end
      end
      crc16_modbus = crc;
    end
  endfunction
endmodule
