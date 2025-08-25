`timescale 1ns / 1ps

module FND_CTRL(
    input         clk,
    input         reset,
    input  [13:0] count_data,
    output [ 7:0] fnd_data,
    output [ 3:0] fnd_com
);
    wire [3:0] w_bcd, w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire w_oclk;
    wire [1:0] fnd_sel;

    clk_div U_CLK_Div (
        .clk  (clk),
        .reset(reset),
        .o_clk(w_oclk)
    );

    counter_4 U_Counter_4 (
        .clk(w_oclk),
        .reset(reset),
        .fnd_sel(fnd_sel)
    );

    decoder_2x4 U_Decoder_2x4 (
        .fnd_sel(fnd_sel),
        .fnd_com(fnd_com)
    );

    digit_splitter U_DS (
        .count_data(count_data),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_4x1 U_MUX_4x1 (
        .sel(fnd_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .bcd(w_bcd)
    );

    bcd U_BCD (
        .bcd(w_bcd),
        .fnd_data(fnd_data)
    );

endmodule

// clk divider
module clk_div (
    input  clk,
    input  reset,
    output o_clk
);
    // clk 100_000_000, r_count 100_000
    // reg [16:0] r_counter;
    reg [$clog2(100_100)-1:0] r_counter;
    reg r_clk;
    assign o_clk = r_clk;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            r_clk     <= 1'b0;
        end else begin
            if (r_counter == 100_000 - 1) begin  // 1khz period
                r_counter <= 0;
                r_clk <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_clk <= 1'b0;
            end
        end
    end

endmodule

// 4진 카운터
module counter_4 (
    input        clk,
    input        reset,
    output [1:0] fnd_sel
);

    reg [1:0] r_counter;
    assign fnd_sel = r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end

endmodule

module decoder_2x4 (
    input      [1:0] fnd_sel,
    output reg [3:0] fnd_com
);
    always @(fnd_sel) begin
        case (fnd_sel)
            2'b00: begin
                fnd_com = 4'b1110;  // fnd 1의 자리 on
            end
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end
endmodule

module mux_4x1 (
    input  [1:0] sel,
    input  [3:0] digit_1,
    input  [3:0] digit_10,
    input  [3:0] digit_100,
    input  [3:0] digit_1000,
    output [3:0] bcd
);

    reg [3:0] r_bcd;
    assign bcd = r_bcd;

    // 4:1 mux, always
    always @(*) begin
        case (sel)
            2'b00: r_bcd = digit_1;
            2'b01: r_bcd = digit_10;
            2'b10: r_bcd = digit_100;
            2'b11: r_bcd = digit_1000;
        endcase
    end

endmodule

module digit_splitter (
    input  [13:0] count_data,
    output [ 3:0] digit_1,
    output [ 3:0] digit_10,
    output [ 3:0] digit_100,
    output [ 3:0] digit_1000
);

    assign digit_1    = count_data % 10;
    assign digit_10   = (count_data / 10) % 10;
    assign digit_100  = (count_data / 100) % 10;
    assign digit_1000 = (count_data / 1000) % 10;

endmodule

module bcd (
    input  [3:0] bcd,
    output [7:0] fnd_data
);

    reg [7:0] r_fnd_data;
    assign fnd_data = r_fnd_data;

    always @(bcd) begin
        case (bcd)
            4'h00:   r_fnd_data = 8'hc0;
            4'h01:   r_fnd_data = 8'hf9;
            4'h02:   r_fnd_data = 8'ha4;
            4'h03:   r_fnd_data = 8'hb0;
            4'h04:   r_fnd_data = 8'h99;
            4'h05:   r_fnd_data = 8'h92;
            4'h06:   r_fnd_data = 8'h82;
            4'h07:   r_fnd_data = 8'hf8;
            4'h08:   r_fnd_data = 8'h80;
            4'h09:   r_fnd_data = 8'h90;
            default: r_fnd_data = 8'h00;
        endcase
    end
endmodule
