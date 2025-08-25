`timescale 1ns / 1ps

module UART_CTRL_sensor(
    input        clk,
    input        rst,
    input        push_tx,       
    input  [7:0] tx_din,        

    output       tx,            
    output       tx_busy,       
    output       tx_done       
);
    wire w_bd_tick;
    wire w_tx_full, w_tx_empty;
    wire [7:0] w_tx_data;
    wire w_tx_start;
    wire w_tx_busy, w_tx_done;

    assign tx_busy   = w_tx_busy;
    assign tx_done   = w_tx_done;

    fifo U_FIFO_TX (
        .clk       (clk),
        .rst       (rst),
        .push      (push_tx),
        .pop       (~w_tx_busy),       
        .push_data (tx_din),
        .full      (w_tx_full),
        .empty     (w_tx_empty),
        .pop_data  (w_tx_data)
    );

    assign w_tx_start = ~w_tx_empty;

    uart_tx U_UART_TX (
        .clk         (clk),
        .rst         (rst),
        .baud_tick   (w_bd_tick),
        .start       (w_tx_start),
        .din         (w_tx_data),
        .o_tx_done   (w_tx_done),
        .o_tx_busy   (w_tx_busy),
        .o_tx        (tx)
    );

    baudrate U_BR (
        .clk       (clk),
        .rst       (rst),
        .baud_tick (w_bd_tick)
    );
endmodule

module fifo (
    input        clk,
    input        rst,
    input        push,
    input        pop,
    input  [7:0] push_data,
    output       full,
    output       empty,
    output [7:0] pop_data
);

    wire [3:0] w_w_ptr, w_r_ptr;

    fifo_cu U_FIFO_CU (
        .clk  (clk),
        .rst  (rst),
        .push (push),
        .pop  (pop),
        .w_ptr(w_w_ptr),
        .r_ptr(w_r_ptr),
        .full (full),
        .empty(empty)
    );

    register_file U_Reg_File (
        .clk(clk),
        .wr_en(push & (~full)),  
        .wdata(push_data),
        .w_ptr(w_w_ptr),  
        .r_ptr(w_r_ptr), 
        .rdata(pop_data)
    );

endmodule

module uart_tx (
    input clk,
    input rst,
    input baud_tick,
    input start,
    input [7:0] din,
    output o_tx_done,
    output o_tx_busy,
    output o_tx
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3, WAIT = 4;

    reg [2:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [2:0] data_cnt_reg, data_cnt_next;  
    reg [3:0]
        b_cnt_reg,
        b_cnt_next; 
    reg tx_done_reg, tx_done_next;
    reg tx_busy_reg, tx_busy_next;
    // tx data buffer
    reg [7:0] tx_din_reg, tx_din_next;

    assign o_tx = tx_reg;
    assign o_tx_done = tx_done_reg;
    assign o_tx_busy = tx_busy_reg;
    // assign o_tx_done = ((c_state == STOP) & (b_cnt_reg == 7)) ? 1'b1 : 1'b0;

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state      <= 0;
            tx_reg       <= 1'b1;
            data_cnt_reg <= 0; 
            b_cnt_reg    <= 0; 
            tx_done_reg  <= 0;
            tx_busy_reg  <= 0;
            tx_din_reg   <= 0;
        end else begin
            c_state      <= n_state;
            tx_reg       <= tx_next;
            data_cnt_reg <= data_cnt_next;
            b_cnt_reg    <= b_cnt_next;
            tx_done_reg  <= tx_done_next;
            tx_busy_reg  <= tx_busy_next;
            tx_din_reg   <= tx_din_next;
        end
    end

    // next state CL
    always @(*) begin
        n_state       = c_state;
        tx_next       = tx_reg;
        data_cnt_next = data_cnt_reg;
        b_cnt_next    = b_cnt_reg;
        tx_done_next  = 0;
        tx_busy_next  = tx_busy_reg;
        tx_din_next   = tx_din_reg;
        case (c_state)
            IDLE: begin
                b_cnt_next = 0;
                data_cnt_next = 0;
                tx_next = 1'b1;
                tx_done_next = 1'b0;
                tx_busy_next = 1'b0;
                if (start == 1'b1) begin
                    n_state = START;
                    tx_busy_next = 1'b1;
                    tx_din_next = din;
                end
            end
            START: begin
                if (baud_tick == 1'b1) begin
                    tx_next = 1'b0;
                    if (b_cnt_reg == 8) begin
                        n_state = DATA;
                        data_cnt_next = 0;
                        b_cnt_next = 0;
                    end else begin
                        b_cnt_next = b_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = tx_din_reg[data_cnt_reg];
                if (baud_tick == 1'b1) begin
                    if (b_cnt_reg == 3'b111) begin
                        if (data_cnt_reg == 3'b111) begin
                            n_state = STOP;
                        end
                        b_cnt_next = 0;
                        data_cnt_next = data_cnt_reg + 1;
                    end else begin
                        b_cnt_next = b_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (baud_tick == 1'b1) begin
                    if (b_cnt_reg == 3'b111) begin
                        n_state = IDLE;
                        tx_busy_next = 1'b0;
                        tx_done_next = 1'b1;
                    end
                    b_cnt_next = b_cnt_reg + 1;
                end
            end
        endcase
    end
endmodule

module baudrate (
    input clk,
    input rst,
    output baud_tick
);
    //clk 100Mhz
    parameter BAUD = 9600;
    parameter BAUD_COUNT = 100_000_000 / (BAUD * 8);
    reg [$clog2(BAUD_COUNT)-1:0] count_reg, count_next;
    reg baud_tick_reg, baud_tick_next;

    assign baud_tick = baud_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            baud_tick_reg <= 0;
        end else begin
            count_reg <= count_next;
            baud_tick_reg <= baud_tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        baud_tick_next = 0; 
        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            baud_tick_next = 1'b1;
        end else begin
            count_next = count_reg + 1;
            baud_tick_next = 1'b0;
        end
    end
endmodule

module fifo_cu (
    input clk,
    input rst,
    input push,
    input pop,
    output [3:0] w_ptr,
    output [3:0] r_ptr,
    output full,
    output empty
);

    reg [3:0] w_ptr_reg, w_ptr_next, r_ptr_reg, r_ptr_next;
    reg full_reg, full_next, empty_reg, empty_next;

    assign w_ptr = w_ptr_reg;
    assign r_ptr = r_ptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            w_ptr_reg <= 0;
            r_ptr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        w_ptr_next = w_ptr_reg;
        r_ptr_next = r_ptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            pop, push
        })
            2'b01: begin  // push
                if (full_reg == 1'b0) begin
                    w_ptr_next = w_ptr_reg + 1;
                    empty_next = 0;
                    if (w_ptr_next == r_ptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // pop
                if (empty_reg == 1'b0) begin
                    r_ptr_next = r_ptr_reg + 1;
                    full_next  = 1'b0;
                    if (w_ptr_reg == r_ptr_next) begin
                        empty_next = 1;
                    end
                end
            end
            2'b11: begin  // push, pop
                if (empty_reg == 1'b1) begin
                    w_ptr_next = w_ptr_reg + 1;
                    empty_next = 1'b0;
                end else if (full_reg == 1'b1) begin
                    r_ptr_next = r_ptr_reg + 1;
                    full_next  = 1'b0;
                end else begin
                    w_ptr_next = w_ptr_reg + 1;
                    r_ptr_next = r_ptr_reg + 1;
                end
            end
        endcase
    end
endmodule
