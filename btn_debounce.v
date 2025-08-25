`timescale 1ns / 1ps

module btn_debounce(
    input clk,
    input rst,
    input i_btnU,
    input i_btnD,
    input i_btnL,
    input i_btnR,
    output o_btnU,
    output o_btnD,
    output o_btnL,
    output o_btnR
);

    btn_device U_BTN_UP(
        .clk(clk),
        .rst(rst),
        .i_btn(i_btnU),
        .o_btn(o_btnU)
    );

    btn_device U_BTN_DOWN(
        .clk(clk),
        .rst(rst),
        .i_btn(i_btnD),
        .o_btn(o_btnD)
    );

    btn_device U_BTN_LEFT(
        .clk(clk),
        .rst(rst),
        .i_btn(i_btnL),
        .o_btn(o_btnL)
    );

    btn_device U_BTN_RIGHT(
        .clk(clk),
        .rst(rst),
        .i_btn(i_btnR),
        .o_btn(o_btnR)
    );
endmodule

module btn_device (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);
    parameter F_COUNT = 1000;
    // 100khz
    reg [$clog2(F_COUNT)-1:0] r_counter;
    reg r_clk;
    reg [7:0] q_reg, q_next;
    wire w_debounce;
    reg r_edge_q;

    // clk div
    always @(posedge clk, posedge rst) begin
        if(rst)begin
            r_counter <= 0;
            r_clk <= 1'b0;
        end else begin
            if(r_counter == F_COUNT - 1) begin
                r_counter <= 0;
                r_clk <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_clk <= 1'b0;
            end
        end
    end

    // debounce
    always @(posedge r_clk, posedge rst) begin
        if(rst)begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end
    
    // f/f shift 구조
    always @(i_btn, q_reg, r_clk) begin   
        q_next = {i_btn, q_reg[7:1]};
    end

    // 8 input and gate
    assign w_debounce = &q_reg;

    // edge detector
    always @(posedge clk, posedge rst) begin
        if(rst)begin
            r_edge_q <= 0;
        end else begin
            r_edge_q <= w_debounce;
        end
    end

    // rising edge
    assign o_btn = w_debounce & (~r_edge_q);

endmodule
