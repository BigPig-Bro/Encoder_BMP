`timescale 1ns / 1ns
module encoder_bmp_tb();

reg         sys_clk_i = 0, sys_rst_n_i = 0;
reg [7:0 ]  src_data_i = 'd0;
reg         encoder_start_i = 0;

wire        encoder_ready_o, encoder_done_o, bmp_data_vaild_o;
wire [7:0 ] bmp_data_o;

parameter   BMP_WIDTH   = 16'd8;
parameter   BMP_HEIGHT  = 16'd8;

encoder_bmp#(
    .BMP_WIDTH          (BMP_WIDTH           ),
    .BMP_HEIGHT         (BMP_HEIGHT          )
) encoder_bmp_m0(
    .sys_clk_i          (sys_clk_i          ),
    .sys_rst_n_i        (sys_rst_n_i        ),

    .src_data_req_o     (src_data_req_o     ),
    .src_data_i         (src_data_i         ),

    .encoder_start_i    (encoder_start_i    ),
    .encoder_ready_o    (encoder_ready_o    ),
    .encoder_done_o     (encoder_done_o     ),
    .bmp_data_vaild_o   (bmp_data_vaild_o   ),
    .bmp_data_o         (bmp_data_o         )
);

//生成 50M时钟，并复位 1us
always #10 sys_clk_i = ~sys_clk_i;
initial   #1000 sys_rst_n_i = 1;

//生成 指定图片（应该用FIFO接口，这里仿真直接给数据
enum {IDLE, SEND_DATA} DATA_STATE;

// 8色彩条定义 (注意，BMP中的顺序)
parameter COLOR_BLACK  = 24'h000000;
parameter COLOR_BLUE   = 24'h0000FF;
parameter COLOR_GREEN  = 24'h00FF00;
parameter COLOR_CYAN   = 24'h00FFFF;
parameter COLOR_RED    = 24'hFF0000;
parameter COLOR_MAGENTA= 24'hFF00FF;
parameter COLOR_YELLOW = 24'hFFFF00;
parameter COLOR_WHITE  = 24'hFFFFFF;

parameter [24*8 - 1 : 0] COLOR_BAR = {COLOR_BLACK, COLOR_BLUE, COLOR_GREEN, COLOR_CYAN, COLOR_RED, COLOR_MAGENTA, COLOR_YELLOW, COLOR_WHITE};

reg [ 2:0] state = 0;
reg [23:0] rgb_data = 0;
reg [15:0] send_cnt = 0;

always@(posedge sys_clk_i)
    case(state)
        IDLE:begin
            if(encoder_ready_o)begin
                send_cnt        <= 16'd0;
                encoder_start_i <= 1'b1;

                state           <= SEND_DATA;
            end
        end

        SEND_DATA:begin
            encoder_start_i <= encoder_ready_o ? 'd1 : 'd0;

            if(encoder_done_o)
                $display("encoder done");
            else if(src_data_req_o)begin
                send_cnt        <= send_cnt + 16'd1;
                src_data_i      <= COLOR_BAR[(send_cnt % 24) * 8  +: 8];
            end 
        end
    endcase

//将编码后的数据写入hex文件
//将bmp_data输出到文件
integer test;
initial begin 
	test  = $fopen("bmp_data.bmp","wb");
	if(test) $display("open file success");
	else	 $display("open file fail");
end

always@(posedge sys_clk_i)begin
    if(bmp_data_vaild_o)
        $fwrite(test,"%c",bmp_data_o); 

    if(encoder_done_o)begin
        $fclose(test);
    	$display("close success");

    	$stop;
    end
end

endmodule