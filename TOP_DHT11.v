`timescale 1ns / 1ps

module TOP_DHT11(
    input clk,
    input reset,
    input btnU,
    output tx,
    output [7:0] fnd_data,
    output [3:0] fnd_com,
    output [3:0] state_led_dht11,
    output LED_dht11,
    inout dht11_io
);
    wire [7:0] w_t_data, w_rh_data;
    wire w_dht11_valid;

    assign LED_dht11 = w_dht11_valid;

    dht11_controller U_DHT11 (
        .clk(clk),
        .rst(reset),
        .start(btnU),
        .rh_data(w_rh_data),
        .t_data(w_t_data),
        .dht11_done(),
        .dht11_valid(w_dht11_valid),
        .state_led(state_led_dht11),
        .dht11_io(dht11_io)
    );

    fnd_controller_dht11 U_FND(
        .clk(clk),
        .rst(reset),
        .rh_data(w_rh_data),
        .t_data(w_t_data),
        .fnd_data(fnd_data),
        .fnd_com(fnd_com)
    );

    wire [7:0] ascii_T0, ascii_T1, ascii_RH0, ascii_RH1;
    wire ascii_valid;

    dht11_hex_to_ascii U_HEX_ASCII (
        .clk(clk),
        .rst(reset),
        .valid_in(w_dht11_valid),
        .t_data(w_t_data),
        .rh_data(w_rh_data),
        .ascii_valid(ascii_valid),
        .ascii_T0(ascii_T0),
        .ascii_T1(ascii_T1),
        .ascii_RH0(ascii_RH0),
        .ascii_RH1(ascii_RH1)
    );

    wire [7:0] tx_din;
    wire push_tx;
    wire tx_busy;

    dht11_uart_sender U_UART_SEND (
        .clk(clk),
        .rst(reset),
        .ascii_valid(ascii_valid),
        .ascii_T0(ascii_T0),
        .ascii_T1(ascii_T1),
        .ascii_RH0(ascii_RH0),
        .ascii_RH1(ascii_RH1),
        .tx_busy(tx_busy),
        .tx_din(tx_din),
        .push_tx(push_tx)
    );

    wire tx_done;

    UART_CTRL_sensor U_UART (
        .clk(clk),
        .rst(reset),
        .push_tx(push_tx),
        .tx_din(tx_din),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );
endmodule

module dht11_controller (
    input clk,
    input rst,
    input start,
    output [7:0] rh_data,
    output [7:0] t_data,
    output dht11_done,
    output dht11_valid, // checksum에 대한 신호
    output [3:0] state_led,
    inout dht11_io
);
    wire w_tick;

    tick_gen_10us_dht11 U_Tick (
        .clk(clk),
        .rst(rst),
        .o_tick(w_tick)
    );

    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4, DATA_SYNC = 5, DATA_DETECT = 6, VALID = 7, DATA_DETECT_f = 8, STOP = 9;

    reg [3:0] c_state, n_state;
    reg [$clog2(1900)-1:0] tick_cnt_reg, tick_cnt_next;
    reg dht11_reg, dht11_next;
    reg io_en_reg, io_en_next;
    reg [39:0] data_reg, data_next;
    reg [$clog2(40)-1:0] data_cnt_reg, data_cnt_next;

    reg dht11_done_reg, dht11_done_next;
    reg dht11_valid_reg, dht11_valid_next;
    reg w_tick_d, dht11_io_d, tick_edge_r, dht11_io_r, dht11_io_f;// rising edge

    assign dht11_io = (io_en_reg) ? dht11_reg : 1'bz;  //출력인 경우
    assign state_led = c_state;
    assign dht11_valid = dht11_valid_reg;
    assign dht11_done = dht11_done_reg;
    
    assign rh_data = data_reg[23:16];//습도 => dht11_done 신호 나올때 받으면 됨.
    assign t_data = data_reg[39:32];//온도 => dht11_done 신호 나올때 받으면 됨.

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tick_cnt_reg    <= 0;
            dht11_reg       <= 1;  // 초기값 항상 high로
            io_en_reg       <= 1;  // idle에서 항상 출력 모드
            data_reg        <= 0;
            data_cnt_reg    <= 39;
            dht11_valid_reg <= 0;
            w_tick_d        <= 0;
            dht11_io_d      <= 0;
            dht11_done_reg  <= 0;
            dht11_valid_reg <= 0;

        end else begin
            c_state         <= n_state;
            tick_cnt_reg    <= tick_cnt_next;
            dht11_reg       <= dht11_next;
            io_en_reg       <= io_en_next;
            data_reg        <= data_next;
            data_cnt_reg    <= data_cnt_next;

            dht11_valid_reg <= dht11_valid_next;
            dht11_done_reg  <= (dht11_done_reg)?0:dht11_done_next;

            w_tick_d        <= w_tick;
            tick_edge_r     <= (tick_edge_r)? 0: (~w_tick_d & w_tick);// tick rising edge

            dht11_io_d      <= dht11_io;
            dht11_io_r      <= (dht11_io_r)? 0: (~dht11_io_d & dht11_io);// io rising edge
            dht11_io_f      <= (dht11_io_f)? 0: (dht11_io_d & ~dht11_io);// io falling edge
        end
    end

    always @(*) begin
        n_state          = c_state;
        tick_cnt_next    = tick_cnt_reg;
        dht11_next       = dht11_reg;
        io_en_next       = io_en_reg;
        data_next        = data_reg;
        dht11_valid_next = dht11_valid_reg;
        dht11_done_next  = dht11_done_reg;
        data_cnt_next    = data_cnt_reg;

        case (c_state)
            IDLE: begin // 0
                dht11_next = 1;
                io_en_next = 1;//출력모드
                if (start) begin
                    n_state = START;
                    dht11_valid_next = 0;//valid
                end
            end
            START: begin // 1
                if (w_tick) begin
                    // 카운트
                    dht11_next = 0;
                    if (tick_cnt_reg == 1900) begin
                        n_state       = WAIT;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin // 2
                dht11_next = 1;
                if (w_tick) begin
                    if (tick_cnt_reg == 2) begin
                        n_state       = SYNC_L;
                        tick_cnt_next = 0;
                        io_en_next    = 0; // input 모드
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            SYNC_L: begin // 3
                if (w_tick & dht11_io) begin
                    n_state = SYNC_H;
                end
            end
            SYNC_H: begin // 4
                if (w_tick & !dht11_io) begin
                    n_state = DATA_SYNC;
                    tick_cnt_next = 0;
                end
            end
            DATA_SYNC: begin // 5 
                if (w_tick) begin
                    if (dht11_io) begin
                        n_state       = DATA_DETECT;
                        dht11_next    = 0;
                        tick_cnt_next = 0;
                    end
                end
            end
            DATA_DETECT: begin  // 6
                if (dht11_io & tick_edge_r) begin  // tick이 rising edge일 때
                    tick_cnt_next = tick_cnt_reg + 1;  // 증가
                end
                if (dht11_io_f) begin  // input: falling edge일 때
                    n_state = DATA_DETECT_f;
                end
            end
            VALID: begin
                if(data_reg[39:32] + data_reg[31:24] + data_reg[23:16] + data_reg[15:8] == data_reg[7:0]) begin
                    dht11_valid_next = 1;
                end else begin
                    dht11_valid_next = 0;
                end
                n_state = STOP;
            end
            DATA_DETECT_f: begin
                if (tick_cnt_reg >= 5) begin  // 1인 경우
                    data_next[data_cnt_reg] = 1;
                end else begin  // 0인 경우
                    data_next[data_cnt_reg] = 0;
                end
                
                if (data_cnt_reg == 0) begin
                    tick_cnt_next = 0;
                    data_cnt_next = 39;
                    dht11_done_next = 1;  //done
                    n_state = VALID;
                end else begin
                    n_state = DATA_SYNC; // data_sync로 
                    data_cnt_next = data_cnt_reg - 1;
                end
            end
            STOP: begin
                if (tick_edge_r) begin // rising edge
                    tick_cnt_next = tick_cnt_reg + 1;
                end
                if(tick_cnt_reg == 4) begin
                    n_state = IDLE;
                end
            end
        endcase
    end
endmodule

//10us 틱 발생기
module tick_gen_10us_dht11 (
    input  clk,
    input  rst,
    output o_tick
);
    parameter F_CNT = 1000;
    reg [$clog2(F_CNT) - 1:0] counter_reg;
    reg tick_reg;

    assign o_tick = tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_reg    <= 0;
        end else begin
            if (counter_reg == F_CNT - 1) begin
                counter_reg <= 0;
                tick_reg    <= 1;
            end else begin
                counter_reg <= counter_reg + 1;
                tick_reg    <= 0;
            end
        end
    end
endmodule

module dht11_hex_to_ascii (
    input        clk,
    input        rst,
    input        valid_in,         
    input  [7:0] t_data,           // 온도
    input  [7:0] rh_data,          // 습도
    output reg        ascii_valid,
    output reg [7:0]  ascii_T0,    // 온도 일의 자리
    output reg [7:0]  ascii_T1,    // 온도 십의 자리
    output reg [7:0]  ascii_RH0,   // 습도 일의 자리
    output reg [7:0]  ascii_RH1    // 습도 십의 자리
);
    reg [3:0] t1, t0, h1, h0;
    reg prev_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ascii_valid <= 0;
            ascii_T0 <= 0;
            ascii_T1 <= 0;
            ascii_RH0 <= 0;
            ascii_RH1 <= 0;
            prev_valid <= 0;
        end else begin
            prev_valid <= valid_in;
            if (valid_in && !prev_valid) begin
                t0 <= t_data % 10;
                t1 <= (t_data / 10) % 10;
                h0 <= rh_data % 10;
                h1 <= (rh_data / 10) % 10;

                ascii_T0 <= 8'h30 + (t_data % 10);
                ascii_T1 <= 8'h30 + ((t_data / 10) % 10);
                ascii_RH0 <= 8'h30 + (rh_data % 10);
                ascii_RH1 <= 8'h30 + ((rh_data / 10) % 10);

                ascii_valid <= 1;
            end else begin
                ascii_valid <= 0; 
            end
        end
    end
endmodule

module fnd_controller_dht11 (
    input clk,
    input rst,
    input [7:0] rh_data,
    input [7:0] t_data,
    output [7:0] fnd_data,
    output [3:0] fnd_com
);
    wire [3:0] rh_10, rh_1, t_10, t_1;
    wire [1:0] fnd_sel;
    wire [3:0] bcd;
    wire clk_div;

    digit_splitter_dht11 #(.BIT_WIDTH(8)) U_DS_RH (
        .time_data(rh_data),
        .disit_1(rh_1),
        .disit_10(rh_10)
    );

    digit_splitter_dht11 #(.BIT_WIDTH(8)) U_DS_T (
        .time_data(t_data),
        .disit_1(t_1),
        .disit_10(t_10)
    );

    clk_div_1 U_CLK_DIV (
        .clk(clk),
        .rst(rst),
        .o_clk(clk_div)
    );

    counter_4 U_CNT (
        .clk(clk_div),
        .reset(rst),
        .fnd_sel(fnd_sel)
    );

    decoder_2x4 U_DEC (
        .fnd_sel(fnd_sel),
        .fnd_com(fnd_com)
    );

    mux_4x1 U_MUX (
        .sel(fnd_sel),
        .digit_1(t_1),
        .digit_10(t_10),
        .digit_100(rh_1),
        .digit_1000(rh_10),
        .bcd(bcd)
    );

    bcd U_BCD (
        .bcd(bcd),
        .fnd_data(fnd_data)
    );
endmodule

module clk_div_1 (
    input clk,
    input rst,
    output o_clk
);
    reg [$clog2(100_000) - 1:0] r_counter;
    reg r_clk;
    assign o_clk = r_clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            r_clk <= 1'b0;
        end else begin
            if (r_counter == 100_000 - 1) begin
                r_counter <= 0;
                r_clk <= ~r_clk;
            end else begin
                r_counter <= r_counter + 1;
            end
        end
    end
endmodule

module digit_splitter_dht11 #(
    parameter BIT_WIDTH = 8
) (
    input [BIT_WIDTH - 1:0] time_data,
    output [3:0] disit_1,
    output [3:0] disit_10
);
    assign disit_1 = time_data % 10;
    assign disit_10 = (time_data / 10) % 10;
endmodule

module dht11_uart_sender (
    input clk,
    input rst,
    input ascii_valid,
    input [7:0] ascii_T0,
    input [7:0] ascii_T1,
    input [7:0] ascii_RH0,
    input [7:0] ascii_RH1,
    input tx_busy,

    output reg [7:0] tx_din,
    output reg push_tx
);

    reg [4:0] index;
    reg sending;
    reg [7:0] msg[0:23];  // "Temp = XXC\r\nHumi = XX%\r\n"

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            index   <= 0;
            tx_din  <= 0;
            push_tx <= 0;
            sending <= 0;
        end else begin
            push_tx <= 0;

            if (ascii_valid && !sending) begin
                // 메시지 구성
                msg[0]  <= "T";
                msg[1]  <= "e";
                msg[2]  <= "m";
                msg[3]  <= "p";
                msg[4]  <= " ";
                msg[5]  <= "=";
                msg[6]  <= " ";
                msg[7]  <= ascii_RH1;
                msg[8]  <= ascii_RH0;
                msg[9]  <= "C";
                msg[10] <= 8'h0D;
                msg[11] <= 8'h0A;
                msg[12] <= "H";
                msg[13] <= "u";
                msg[14] <= "m";
                msg[15] <= "i";
                msg[16] <= " ";
                msg[17] <= "=";
                msg[18] <= " ";
                msg[19] <= ascii_T1;
                msg[20] <= ascii_T0;
                msg[21] <= "%";
                msg[22] <= 8'h0D;
                msg[23] <= 8'h0A;
                sending <= 1;
                index   <= 0;
            end else if (sending && !tx_busy) begin
                tx_din  <= msg[index];
                push_tx <= 1;
                index   <= index + 1;

                if (index == 23) begin
                    sending <= 0;
                end
            end
        end
    end
endmodule
