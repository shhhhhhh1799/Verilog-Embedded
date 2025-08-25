`timescale 1ns / 1ps

module TOP_SR04(
    input        clk,
    input        rst,
    input        btn_start,
    input        echo,
    output       trig,
    output       tx,
    output [7:0] fnd_data,
    output [3:0] fnd_com
);

    wire [9:0] dist;
    wire dist_done, ascii_valid, push_tx, tx_busy, tx_done, rx_valid, pop_rx;
    wire [7:0] ascii_0, ascii_1, ascii_2, ascii_3, tx_din;

    sr04_controller U_SR04 (
        .clk(clk),
        .rst(rst),
        .start(btn_start),
        .echo(echo),
        .trig(trig),
        .dist(dist),
        .dist_done(dist_done)
    );

    hex_to_ascii U_HEX_ASCII (
        .clk(clk),
        .rst(rst),
        .valid_in(dist_done),
        .distance(dist),
        .ascii_valid(ascii_valid),
        .ascii_0(ascii_0),
        .ascii_1(ascii_1),
        .ascii_2(ascii_2),
        .ascii_3(ascii_3)
    );

    FND_CTRL U_FND (
        .clk(clk),
        .reset(rst),
        .count_data({4'b0000, dist}),
        .fnd_data(fnd_data),
        .fnd_com(fnd_com)
    );

    dist_uart_sender U_DIST_SENDER (
        .clk(clk),
        .rst(rst),
        .ascii_valid(ascii_valid),
        .ascii_0(ascii_0),
        .ascii_1(ascii_1),
        .ascii_2(ascii_2),
        .ascii_3(ascii_3),
        .tx_busy(tx_busy),
        .tx_din(tx_din),
        .push_tx(push_tx)
    );

    UART_CTRL_sensor U_UART_CTRL (
        .clk(clk),
        .rst(rst),
        .push_tx(push_tx),
        .tx_din(tx_din),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );
endmodule

module dist_uart_sender (
    input clk,
    input rst,
    input ascii_valid,
    input [7:0] ascii_0,
    input [7:0] ascii_1,
    input [7:0] ascii_2,
    input [7:0] ascii_3,
    input tx_busy,

    output reg [7:0] tx_din,
    output reg push_tx
);

    reg [4:0] state;
    reg [7:0] msg[0:16];

    initial begin
        msg[0]  = "D";
        msg[1]  = "i";
        msg[2]  = "s";
        msg[3]  = "t";
        msg[4]  = "a";
        msg[5]  = "n";
        msg[6]  = "c";
        msg[7]  = "e";
        msg[8]  = " ";
        // msg[9~12] = ascii_3~0
        msg[13] = "c";
        msg[14] = "m";
        msg[15] = 8'h0D;  // '\r'
        msg[16] = 8'h0A;  // '\n'
    end

    reg [4:0] index;
    reg sending;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= 0;
            index   <= 0;
            tx_din  <= 0;
            push_tx <= 0;
            sending <= 0;
        end else begin
            push_tx <= 0;

            if (ascii_valid && !sending) begin
                if (ascii_3 == 8'h30) begin
                    msg[9] = 8'h20;
                end else begin
                    msg[9] = ascii_3;
                end
                if (ascii_2 == 8'h30 && ascii_3 == 8'h30) begin
                    msg[10] = 8'h20;
                end else begin
                    msg[10] = ascii_2;
                end
                if (ascii_1 == 8'h30 && ascii_3 == 8'h30 && ascii_2 == 8'h30) begin
                    msg[11] = 8'h20;
                end else begin
                    msg[11] = ascii_1;
                end
                msg[12] <= ascii_0;
                sending <= 1;
                index   <= 0;
            end else if (sending && !tx_busy) begin
                tx_din  <= msg[index];
                push_tx <= 1;
                index   <= index + 1;

                if (index == 16) begin 
                    sending <= 0;
                end
            end
        end
    end

endmodule

module sr04_controller (
    input clk,
    input rst,
    input start, // Btn_start
    input echo,
    output trig,
    output [9:0] dist,
    output dist_done
);

    wire w_tick;
    wire echo_flag, echo_done;

    high_level_detector U_Echo_detect (
        .clk(w_tick),
        .rst(rst),
        .echo(echo),
        .high_level_flag(echo_flag),
        .done(echo_done)
    );

    calculator U_Calc (
        .clk(w_tick),
        .rst(rst),
        .high_level_flag(echo_flag),
        .done(echo_done),
        .distance(dist),
        .dist_done(dist_done)
    );

    start_trigger U_Start_trigg (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick),
        .start(start),
        .o_sr04_trigger(trig)
    );

    tick_gen_sr04 U_Tick_Gen (
        .clk(clk),
        .rst(rst),
        .o_tick_1mhz(w_tick)
    );
endmodule

module high_level_detector (
    input clk,
    input rst,
    input echo,
    output reg high_level_flag,
    output reg done
);
    reg echo_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            high_level_flag <= 0;
            done <= 0;
            echo_d <= 0;
        end else begin
            echo_d <= echo;
            if (echo && !echo_d) begin
                high_level_flag <= 1;
                done <= 0;
            end
            else if (!echo && echo_d) begin
                high_level_flag <= 0;
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end
endmodule

module calculator (
    input clk,
    input rst,
    input high_level_flag,
    input done,
    output reg [9:0] distance,
    output reg dist_done
);
    reg [15:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            distance <= 0;
            dist_done <= 0;
        end else begin
            if (high_level_flag) begin
                count <= count + 1;
                dist_done <= 0;
            end else if (done) begin
                distance <= count / 58;
                dist_done <= 1;
                count <= 0;
            end else begin
                dist_done <= 0;
            end
        end
    end
endmodule

module start_trigger (
    input  clk,
    input  rst,
    input  i_tick,
    input  start,
    output o_sr04_trigger
);
    reg start_reg, start_next;
    reg [3:0] count_reg, count_next;
    reg sr04_trigg_reg, sr04_trigg_next;

    assign o_sr04_trigger = sr04_trigg_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            start_reg <= 0;
            sr04_trigg_reg <= 0;
            count_reg <= 0;
        end else begin
            start_reg <= start_next;
            sr04_trigg_reg <= sr04_trigg_next;
            count_reg <= count_next;
        end
    end

    always @(*) begin
        start_next = start_reg;
        sr04_trigg_next = sr04_trigg_reg;
        count_next = count_reg;
        case (start_reg)
            0: begin
                count_next = 0;
                sr04_trigg_next = 1'b0;
                if (start) begin
                    start_next = 1;
                end
            end
            1: begin
                if (i_tick) begin
                    sr04_trigg_next = 1'b1;
                    if (count_reg == 10) begin
                        start_next = 0;
                    end
                    count_next = count_reg + 1;
                end
            end
        endcase
    end

endmodule

module tick_gen_sr04 (
    input  clk,
    input  rst,
    output o_tick_1mhz
);

    parameter F_COUNT = 100 - 1;

    reg [6:0] count;
    reg tick;

    assign o_tick_1mhz = tick;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count <= 0;
            tick  <= 0;
        end else begin
            if (count == F_COUNT) begin
                count <= 0;
                tick  <= 1'b1;
            end else begin
                count <= count + 1;
                tick  <= 1'b0;
            end
        end
    end

endmodule


module hex_to_ascii (
    input        clk,
    input        rst,
    input        valid_in,         
    input  [9:0] distance,         

    output reg        ascii_valid,
    output reg [7:0]  ascii_0,     // ASCII of 1's digit
    output reg [7:0]  ascii_1,     // ASCII of 10's digit
    output reg [7:0]  ascii_2,     // ASCII of 100's digit
    output reg [7:0]  ascii_3      // ASCII of 1000's digit (optional)
);

    reg [3:0] d0, d1, d2, d3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ascii_valid <= 0;
            ascii_0 <= 0;
            ascii_1 <= 0;
            ascii_2 <= 0;
            ascii_3 <= 0;
        end else begin
            if (valid_in) begin
                // BCD 분리
                d0 <= distance % 10;
                d1 <= (distance / 10) % 10;
                d2 <= (distance / 100) % 10;
                d3 <= (distance / 1000) % 10;

                ascii_0 <= 8'h30 + (distance % 10);
                ascii_1 <= 8'h30 + ((distance / 10) % 10);
                ascii_2 <= 8'h30 + ((distance / 100) % 10);
                ascii_3 <= 8'h30 + ((distance / 1000) % 10);

                ascii_valid <= 1;
            end else begin
                ascii_valid <= 0;
            end
        end
    end

endmodule

module register_file #(
    parameter DEPTH = 16,
    WIDTH = 4
) (
    input              clk,
    input              wr_en, 
    input  [      7:0] wdata,
    input  [WIDTH-1:0] w_ptr,  
    input  [WIDTH-1:0] r_ptr,  
    output [      7:0] rdata
);

    reg [7:0] mem[0:DEPTH - 1]; 
    assign rdata = mem[r_ptr];

    always @(posedge clk) begin
        if (wr_en) begin
            mem[w_ptr] <= wdata;
        end
        // rdata <= mem[r_ptr];
    end

endmodule
