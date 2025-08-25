`timescale 1ns / 1ps

module CU (
    input        clk,
    input        rst, 
    input        rx,
    input        btnU,
    input        btnL,
    input        btnR,
    input        btnD,
    input  [6:0] sw,
    output       reset_c,
    output       rs_c,         
    output       clear_c,
    output       sr_start_c,
    output       dht_start_c,
    output       up_c,
    output       down_c,
    output       sensor_clock_c
);
    wire w_reset_c;
    wire w_rs_c;         
    wire w_clear_c;
    wire w_sr_start_c;
    wire w_dht_start_c;
    wire w_up_c;
    wire w_down_c;
    wire w_sensor_clock_c;

    assign reset_c = w_reset_c | rst;
    assign rs_c = (sw[1]) ? (w_rs_c | btnL) : 0;
    assign clear_c = (sw[1]) ? (w_clear_c | btnR) : 0;
    assign sr_start_c = (sw[6]&&sw[5]) ? w_sr_start_c : 0;
    assign dht_start_c = (sw[6] && (~sw[5])) ? w_dht_start_c : 0;
    assign up_c = (~sw[1]) ? (w_up_c | btnU) : 0;
    assign down_c = (~sw[1]) ? (w_down_c | btnD) : 0;
    assign sensor_clock_c = w_sensor_clock_c | sw[6];

    uart_command_receiver U_CMD_RX(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .reset_cmd(w_reset_c),
        .rs_cmd(w_rs_c),
        .clear_cmd(w_clear_c),
        .sr_cmd(w_sr_start_c),
        .dht_cmd(w_dht_start_c),
        .up_cmd(w_up_c),
        .down_cmd(w_down_c),
        .led(w_sensor_clock_c)       
    );
endmodule

module uart_command_receiver #(
    parameter CMD_BUF_SIZE = 8
)(
    input        clk,
    input        rst,
    input        rx,       
    output reg   reset_cmd,
    output reg   rs_cmd,   
    output reg   clear_cmd,
    output reg   sr_cmd,   
    output reg   dht_cmd,  
    output reg   up_cmd,   
    output reg   down_cmd, 
    output reg   led       
);

    wire [7:0] data_out;
    wire       empty;
    wire       full;
    reg        pop;

    // 내부 명령어 버퍼
    reg [7:0] cmd_buf [0:7];
    reg [$clog2(CMD_BUF_SIZE):0] cmd_idx;

    // FSM 상태
    parameter IDLE = 0, RECV = 1, CHECK = 2;
    reg [1:0] state, next_state;

    // UART 수신 FIFO
    uart_with_fifo uart0 (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .pop(pop),
        .data_out(data_out),
        .empty(empty),
        .full(full)
    );
    reg pop_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            cmd_idx <= 0;
        end else begin
            state <= next_state;
            pop_d <= pop;

            if (state == RECV && pop) begin
                cmd_buf[cmd_idx] <= data_out;
                cmd_idx <= cmd_idx + 1;
                if(data_out == 8'h0A) begin
                    cmd_idx <= 0;
                end
            end
        end
    end

    always @(*) begin
        next_state = state;
        pop = 0;
        case (state)
            IDLE: begin
                if (!empty) begin
                    next_state = RECV;
                end
            end

            RECV: begin
                if (!empty) begin
                    pop = 1;
                    next_state = CHECK;
                end
            end

            CHECK: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rs_cmd <= 0;
            reset_cmd <= 0;
            led <= 0;
            clear_cmd <= 0;
            sr_cmd <= 0;
            dht_cmd <= 0;
            up_cmd <= 0;
            down_cmd <= 0;
        end else begin
            // 기본 비활성화
            rs_cmd <= 0;
            reset_cmd <= 0;
            clear_cmd <= 0;
            sr_cmd <= 0;
            dht_cmd <= 0;
            up_cmd <= 0;
            down_cmd <= 0;
            
            if ((state == CHECK) && pop_d) begin
                if ((cmd_idx == 4) &&
                    (cmd_buf[0] == "R") &&
                    (cmd_buf[1] == "/") &&
                    (cmd_buf[2] == "S")) begin
                    rs_cmd <= 1;
                end else if ((cmd_idx == 6) &&
                    (cmd_buf[0] == "R") &&
                    (cmd_buf[1] == "E") &&
                    (cmd_buf[2] == "S") &&
                    (cmd_buf[3] == "E") &&
                    (cmd_buf[4] == "T")) begin
                    reset_cmd <= 1;
                end else if ((cmd_idx == 6) &&
                    (cmd_buf[0] == "C") &&
                    (cmd_buf[1] == "L") &&
                    (cmd_buf[2] == "E") &&
                    (cmd_buf[3] == "A") &&
                    (cmd_buf[4] == "R")) begin
                    clear_cmd <= 1;
                end else if ((cmd_idx == 3) &&
                    (cmd_buf[0] == "S") &&
                    (cmd_buf[1] == "R")) begin
                    sr_cmd <= 1;
                end else if ((cmd_idx == 4) &&
                    (cmd_buf[0] == "D") &&
                    (cmd_buf[1] == "H") &&
                    (cmd_buf[2] == "T")) begin
                    dht_cmd <= 1;
                end else if ((cmd_idx == 3) &&
                    (cmd_buf[0] == "U") &&
                    (cmd_buf[1] == "P")) begin
                    up_cmd <= 1;
                end else if ((cmd_idx == 5) &&
                    (cmd_buf[0] == "D") &&
                    (cmd_buf[1] == "O") &&
                    (cmd_buf[2] == "W") &&
                    (cmd_buf[3] == "N")) begin
                    down_cmd <= 1;
                end else if ((cmd_idx == 4) &&
                    (cmd_buf[0] == "S") &&
                    (cmd_buf[1] == "/") &&
                    (cmd_buf[2] == "W")) begin
                    led <= led ? 0 : 1;
                end
            end
        end
    end
endmodule

module uart_with_fifo (
    input              clk,
    input              rst,
    input              rx,
    input              pop,             
    output [7:0]       data_out,        
    output             empty,
    output             full
);

    wire       w_bd_tick;
    wire       rx_done;
    wire [7:0] rx_data;

    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(rx_done),
        .pop(pop),
        .push_data(rx_data),
        .full(full), // 사용
        .empty(empty), // 사용
        .pop_data(data_out) // output 8bit
    );

    uart_rx U_RX(
        .clk(clk),
        .rst(rst),
        .bd_tick(w_bd_tick),
        .rx(rx),
        .o_dout(rx_data), // 8비트
        .o_rx_done(rx_done)
    );

    baudrate U_BR (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (w_bd_tick)
    );
endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        bd_tick,
    input        rx,
    output [7:0] o_dout,
    output       o_rx_done
);
    localparam IDLE = 0, START = 1, DATA = 2, DATA_READ = 3, STOP = 4;

    reg [2:0] c_state, n_state;
    reg [3:0] b_cnt_reg, b_cnt_next;
    reg [3:0] d_cnt_reg, d_cnt_next;
    reg [7:0] dout_reg, dout_next;
    reg rx_done_reg, rx_done_next;

    assign o_dout    = dout_reg;
    assign o_rx_done = rx_done_reg;

    // state
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state     <= IDLE;
            b_cnt_reg   <= 0;
            d_cnt_reg   <= 0;
            dout_reg    <= 0;
            rx_done_reg <= 0;
        end else begin
            c_state     <= n_state;
            b_cnt_reg   <= b_cnt_next;
            d_cnt_reg   <= d_cnt_next;
            dout_reg    <= dout_next;
            rx_done_reg <= rx_done_next;
        end
    end

    // next
    always @(*) begin
        n_state      = c_state;
        b_cnt_next   = b_cnt_reg;
        d_cnt_next   = d_cnt_reg;
        dout_next    = dout_reg;
        rx_done_next = rx_done_reg;
        case (c_state)
            IDLE: begin
                b_cnt_next = 0;
                d_cnt_next = 0;
                rx_done_next = 1'b0;
                if (bd_tick) begin
                    if (rx == 1'b0) begin
                        n_state = START;
                    end
                end
            end
            START: begin
                if (bd_tick) begin
                    if (b_cnt_reg == 11) begin
                        n_state = DATA_READ;
                        b_cnt_next = 0;
                    end else begin
                        b_cnt_next = b_cnt_reg + 1;
                    end
                end
            end
            DATA_READ: begin
                dout_next = {rx, dout_reg[7:1]};
                n_state   = DATA;
            end
            DATA: begin
                if (bd_tick) begin
                    if (b_cnt_reg == 7) begin
                        if (d_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            d_cnt_next = d_cnt_reg + 1;
                            b_cnt_next = 0;
                            n_state = DATA_READ;
                        end
                    end else begin
                        b_cnt_next = b_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (bd_tick) begin
                    n_state = IDLE;
                    rx_done_next = 1'b1;
                end
            end
        endcase
    end
endmodule
