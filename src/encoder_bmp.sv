module encoder_bmp#(
    parameter  BMP_WIDTH = 32'D640,
    parameter  BMP_HEIGHT = 32'D480
)(
    input               sys_clk_i,
    input               sys_rst_n_i,

    output reg          src_data_req_o,  //建议对接到FIFO RD_EN
    input  [7:0]        src_data_i,

    input               encoder_start_i,
    output              encoder_ready_o,
    output              encoder_done_o,
    output reg          bmp_data_vaild_o,
    output reg [7:0]    bmp_data_o
);

parameter           BMP_HEAD_LENGTH = 32'd54;
parameter [ 31 : 0] BMP_LENGTH = BMP_WIDTH * BMP_HEIGHT * 3 + 54;
parameter [ 54 * 8 - 1 : 0] BMP_HEADER = {
    16'h424d, // BMP文件头 BM
    {BMP_LENGTH[7:0],BMP_LENGTH[15:8],BMP_LENGTH[23:16],BMP_LENGTH[31:24]}, // 文件大小
    32'h00000000, // 保留
    32'h36000000, // 从文件头到位图数据的偏移量
    32'h28000000, // 信息头大小
    {BMP_WIDTH[7:0],BMP_WIDTH[15:8],BMP_WIDTH[23:16],BMP_WIDTH[31:24]}, // 图像宽度
    {BMP_HEIGHT[7:0],BMP_HEIGHT[15:8],BMP_HEIGHT[23:16],BMP_HEIGHT[31:24]}, // 图像高度
    16'h0100, // 颜色平面数
    16'h1800, // 每个像素所需的位数
    32'h00000000, // 压缩方式
    32'h00000000, // 图像大小
    32'hC40E0000, // 水平分辨率
    32'hC40E0000, // 垂直分辨率
    32'h00000000, // 使用的颜色数
    32'h00000000  // 重要颜色数
};
enum {IDLE,ENC_HEAD,ENC_DATA,ENC_BYTE,ENC_END} MAIN_STATE;

reg [ 2:0] state;
reg [31:0] enc_cnt; // 编码字节计数器
reg [16:0] line_cnt; //行编码计数器，用于补齐行字节到8的整数倍

assign encoder_ready_o = (sys_rst_n_i &  state == IDLE);
assign encoder_done_o = (state == ENC_END);
always@(posedge sys_clk_i)
    if(!sys_rst_n_i)begin
        bmp_data_vaild_o   <= 1'b0;
        src_data_req_o  <= 1'b0;
        bmp_data_o      <= 8'h00;
        enc_cnt         <= 'd0;
        line_cnt        <= 'd0;

        state           <= IDLE;
    end else 
        case(state)
            IDLE:begin
                if(encoder_start_i)begin
                    enc_cnt         <= 'd0;
                    line_cnt        <= 'd0;
                    src_data_req_o  <= 1'b0;

                    state           <= ENC_HEAD;
                end
            end

            ENC_HEAD:begin
                enc_cnt         <= enc_cnt + 'd1;

                bmp_data_vaild_o   <= 1'b1;
                bmp_data_o      <= BMP_HEADER[(BMP_HEAD_LENGTH - 1 - enc_cnt) * 8 +: 8];
                src_data_req_o  <= (enc_cnt == BMP_HEAD_LENGTH - 2) ? 1'b1 : src_data_req_o; //数据返回需要2个时钟

                state           <= (enc_cnt == BMP_HEAD_LENGTH - 1) ? ENC_DATA : ENC_HEAD;
            end

            ENC_DATA:begin
                enc_cnt         <= enc_cnt + 'd1;

                bmp_data_vaild_o   <= 1'b1;
                bmp_data_o      <= src_data_i;

                if(line_cnt == BMP_WIDTH * 3 - 1 &&  line_cnt[2:0] != 3'd7 )begin //需要补齐字节
                    line_cnt        <= line_cnt + 'd1;

                    src_data_req_o  <= 'd0;

                    state           <= ENC_BYTE;
                end else begin //不需要补齐字节
                    line_cnt        <= line_cnt == BMP_WIDTH * 3 - 1 ? 'd0 : line_cnt + 1;

                    src_data_req_o  <= (enc_cnt == BMP_LENGTH - 'd1) ? 1'b0 : 1'b1;

                    state           <= (enc_cnt == BMP_LENGTH - 'd1) ? ENC_END : ENC_DATA;
                end
            end

            ENC_BYTE:begin
                line_cnt        <= line_cnt[2:0] == 3'd7 ? 'd0 : line_cnt + 1;

                src_data_req_o  <= (line_cnt[2:0] == 3'd6 & (enc_cnt != BMP_LENGTH) ) ? 1'b1 : src_data_req_o;
                bmp_data_o      <= 8'h00;

                state           <= (line_cnt[2:0] == 3'd7 ) ? (enc_cnt == BMP_LENGTH) ? ENC_END :  ENC_DATA : ENC_BYTE;//最后一行
            end

            ENC_END:begin
                bmp_data_vaild_o   <= 1'b0;
                state           <= IDLE;
            end
        endcase

endmodule 