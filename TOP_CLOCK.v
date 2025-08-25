`timescale 1ns / 1ps

module TOP_CLOCK(
    input        clk,
    input        btnU,
    input        btnL_RunStop,
    input        btnR_Clear,
    input        btnD,
    input        reset,
    input        sw0,
    input        sw1,
    input        sw2,
    input        sw3,
    input        sw4,
    output [3:0] LED,
    output [7:0] fnd_data,
    output [3:0] fnd_com,
    output       o_cuckoo
);
    wire [6:0] s_msec, w_msec, f_msec;
    wire [5:0] s_sec, w_sec, f_sec;
    wire [5:0] s_min, w_min, f_min;
    wire [4:0] s_hour, w_hour, f_hour;
    wire [13:0] w_count_data;

    assign f_msec = (sw1 == 0) ? w_msec : s_msec;
    assign f_sec  = (sw1 == 0) ? w_sec : s_sec;
    assign f_min  = (sw1 == 0) ? w_min : s_min;
    assign f_hour = (sw1 == 0) ? w_hour : s_hour;
    assign w_count_data = (sw0) ? (f_hour * 100 + f_min): (f_sec * 100 + f_msec);

    assign LED[0] = (~sw1 & ~sw0);
    assign LED[1] = (~sw1 & sw0);
    assign LED[2] = (sw1 & ~sw0);
    assign LED[3] = (sw1 & sw0);

    stopwatch U_STOPWATCH (
        .clk(clk),
        .reset(reset),
        .sw1(sw1),
        .btnR_Clear(btnR_Clear),
        .btnL_RunStop(btnL_RunStop), 
        .msec(s_msec),
        .sec(s_sec),
        .min(s_min),
        .hour(s_hour)
    );

    watch U_Watch (
        .clk(clk),
        .reset(reset),
        .btnU(btnU),
        .sw1(sw1),
        .sw2(sw2),  
        .sw3(sw3),  
        .sw4(sw4),  
        .btnD(btnD),
        .msec(w_msec),
        .sec(w_sec),
        .min(w_min),
        .hour(w_hour),
        .o_cuckoo(o_cuckoo)
    );

    fnd_controller U_FND_CTRL (
        .clk(clk),
        .rst(reset),
        .sw0(sw0),
        .msec(f_msec),
        .sec(f_sec),
        .min(f_min),
        .hour(f_hour),
        .fnd_data(fnd_data),
        .fnd_com(fnd_com)
    );
endmodule

module stopwatch (
    input        clk,
    input        reset,
    input        sw1,
    input        btnR_Clear,
    input        btnL_RunStop,
    output [$clog2(100)-1:0] msec,
    output [$clog2(60)-1:0] sec, 
    output [$clog2(60)-1:0] min,
    output [$clog2(24)-1:0] hour
);
    wire w_clear, w_runstop;

    stopwatch_cu U_StopWatch_CU(
        .clk(clk),
        .reset(reset),
        .i_clear(btnR_Clear&sw1),
        .i_runstop(btnL_RunStop&sw1),
        .o_clear(w_clear),
        .o_runstop(w_runstop)
    );

    stopwatch_dp U_Stopwatch_DP(
        .clk(clk),
        .reset(reset),
        .run_stop(w_runstop),
        .clear(w_clear),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour)
    );
endmodule

module stopwatch_dp (
    input        clk,
    input        reset,
    input        run_stop,
    input        clear,
    output  [6:0] msec,
    output  [5:0] sec,
    output  [5:0] min,
    output  [4:0] hour
);
    wire w_tick_100hz, w_msec_tick, w_sec_tick, w_min_tick, w_hour_tick;

    tick_gen U_tick_gen_10ms( 
        .clk(clk & run_stop),
        .reset(reset|clear),
        .o_tick(w_msec_tick)
    );

    time_counter #(.TICK_COUNT(100)) U_MSEC (
        .clk(clk),
        .rst(reset|clear),
        .i_tick(w_msec_tick),
        .o_time(msec),
        .o_tick(w_sec_tick)
    );

    time_counter #(.TICK_COUNT(60)) U_SEC (
        .clk(clk),
        .rst(reset|clear),
        .i_tick(w_sec_tick),
        .o_time(sec),
        .o_tick(w_min_tick)
    );

    time_counter #(.TICK_COUNT(60)) U_MIN (
        .clk(clk),
        .rst(reset|clear),
        .i_tick(w_min_tick),
        .o_time(min),
        .o_tick(w_hour_tick)
    );

    time_counter #(.TICK_COUNT(24)) U_HOUR (
        .clk(clk),
        .rst(reset|clear),
        .i_tick(w_hour_tick),
        .o_time(hour),
        .o_tick()
    );
endmodule

module tick_gen #(parameter FCOUNT = 1_000_000)(
    input  clk,
    input  reset,
    output o_tick
);
    reg r_o_tick;
    reg [$clog2(FCOUNT)-1:0] r_counter;

    assign o_tick = r_o_tick;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_counter <= 0;
            r_o_tick <= 0;
        end else if(reset==0)begin   
            if(r_counter == FCOUNT - 1) begin
                r_counter <= 0;
                r_o_tick <= 1;
            end else begin
                r_counter <= r_counter + 1;
                r_o_tick <= 0;
            end      
        end
    end
endmodule

module time_counter #(
    parameter TICK_COUNT = 100
) (
    input                               clk,
    input                               rst,
    input                               i_tick,
    output     [$clog2(TICK_COUNT)-1:0] o_time,
    output                              o_tick
);

    reg [$clog2(TICK_COUNT)-1:0] count_reg, count_next;
    reg o_tick_reg, o_tick_next;

    assign o_time = count_reg;
    assign o_tick = o_tick_reg;
    
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count_reg <= 0;
            o_tick_reg <= 1'b0;
        end else begin
            count_reg <= count_next; 
            o_tick_reg <= o_tick_next;
        end
    end

    always @(*) begin 
        count_next = count_reg; 
        o_tick_next = 1'b0;
        if(i_tick == 1'b1) begin
            if (count_reg == (TICK_COUNT - 1)) begin
                count_next = 1'b0;
                o_tick_next = 1'b1;
            end else begin
               count_next = count_reg + 1; 
               o_tick_next = 1'b0;
            end
        end
    end
endmodule

module stopwatch_cu(
    input  clk,
    input  reset,
    input  i_clear,//BtnR
    input  i_runstop,//BtnL
    output o_clear,
    output o_runstop
);
    reg[1:0] state_reg, next_state;

    parameter STOP = 1;
    parameter RUN = 2;
    parameter CLEAR = 3;

    assign o_clear = (state_reg == CLEAR)?1:0;
    assign o_runstop = (state_reg == RUN)?1:0;
    
    always @(posedge clk, posedge reset) begin
        if(reset) begin state_reg <= STOP; end
        else begin state_reg <= next_state; end
    end

    always @(*) begin
        next_state = state_reg;
        case (state_reg)
            STOP:
                if (i_clear) begin
                    next_state = CLEAR;
                end else if (i_runstop) begin
                    next_state = RUN;
                end else begin
                    next_state = state_reg;
                end
            RUN:
                if (i_runstop) begin
                    next_state = STOP;
                end else begin
                    next_state = state_reg;
                end
            CLEAR:
                if (i_clear) begin
                    next_state = STOP;
                end else begin
                    next_state = state_reg;
                end
        endcase
    end
endmodule

module watch (
    input clk,
    input reset,
    input btnU,
    input sw1,  //sw1이 0인 경우 시계 모드
    input sw2,  //초바꾸기
    input sw3,  //분바꾸기
    input sw4,  //시바꾸기
    input btnD,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour,
    output o_cuckoo
);
    wire [$clog2(100)-1:0] w_msec;
    wire [$clog2(60)-1:0] w_sec, w_min;
    wire [$clog2(24)-1:0] w_hour;
    wire [1:0] w_op, w_mode;
    wire w_tick_sec_up, w_tick_min_up, w_tick_hour_up;
    wire w_tick_sec_down, w_tick_min_down, w_tick_hour_down;

    watch_cu U_UP_WATCH (
        .clk(clk),
        .reset(reset),
        .button(btnU),
        .sw1 (sw1),
        .sw2 (sw2),
        .sw3 (sw3),
        .sw4 (sw4),
        .tick_sec(w_tick_sec_up),
        .tick_min(w_tick_min_up),
        .tick_hour(w_tick_hour_up)
    );

    watch_cu U_DOWN_WATCH (
        .clk(clk),
        .reset(reset),
        .button(btnD),
        .sw1 (sw1),
        .sw2 (sw2),
        .sw3 (sw3),
        .sw4 (sw4),
        .tick_sec(w_tick_sec_down),
        .tick_min(w_tick_min_down),
        .tick_hour(w_tick_hour_down)
    );

    watch_dp U_Watch_DP (
        .clk  (clk),
        .reset(reset),
        .tick_sec_up(w_tick_sec_up),
        .tick_min_up(w_tick_min_up),
        .tick_hour_up(w_tick_hour_up),
        .tick_sec_down(w_tick_sec_down),
        .tick_min_down(w_tick_min_down),
        .tick_hour_down(w_tick_hour_down),
        .msec (msec),
        .sec  (sec),
        .min  (min),
        .hour (hour)
    );

    cuckoo U_Cuckoo (
        .hour(hour),
        .min(min),
        .o_cuckoo(o_cuckoo)
    );
endmodule

module watch_cu(
    input clk,
    input reset,
    input button,
    input sw1,  //sw1이 0인 경우 시계 모드
    input sw2,  //초바꾸기
    input sw3,  //분바꾸기
    input sw4,  //시바꾸기
    output reg tick_sec,  
    output reg tick_min,
    output reg tick_hour
);
    reg button_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            button_prev <= 0;
            tick_sec <= 0;
            tick_min <= 0;
            tick_hour <= 0;
        end else if((sw1 == 0) && (sw2 == 1)) begin
            button_prev <= button;
            tick_sec <= (~button_prev & button);
        end else if((sw1 == 0) && (sw3 == 1)) begin
            button_prev <= button;
            tick_min <= (~button_prev & button);
        end else if((sw1 == 0) && (sw4 == 1)) begin
            button_prev <= button;
            tick_hour <= (~button_prev & button);
        end else begin
            button_prev <= 0;
            tick_sec <= 0;
            tick_min <= 0;
            tick_hour <= 0;
        end
    end
endmodule

module watch_dp(
    input        clk,
    input        reset,
    input        tick_sec_up,
    input        tick_min_up,
    input        tick_hour_up,
    input        tick_sec_down,
    input        tick_min_down,
    input        tick_hour_down,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);
    wire w_tick_100hz, w_msec_tick, w_sec_tick, w_min_tick, w_hour_tick;

    tick_gen_watch U_tick_gen_10ms_watch(
        .clk(clk),
        .reset(reset),
        .o_tick(w_msec_tick)
    );

    time_counter_10ms_watch #(.TICK_COUNT(100)) U_MSEC_watch (
        .clk(clk),
        .rst(reset),
        .i_tick(w_msec_tick),
        .o_time(msec),
        .o_tick(w_sec_tick)
    );

    time_counter_watch #(.TICK_COUNT(60)) U_SEC_watch (
        .clk(clk),
        .rst(reset),
        .i_tick(w_sec_tick | tick_sec_up),
        .i_down_tick(tick_sec_down),
        .o_time(sec),
        .o_tick(w_min_tick)
    );

    time_counter_watch #(.TICK_COUNT(60)) U_MIN_watch (
        .clk(clk),
        .rst(reset),
        .i_tick(w_min_tick | tick_min_up),
        .i_down_tick(tick_min_down),
        .o_time(min),
        .o_tick(w_hour_tick)
    );

    time_counter_hour_watch #(.TICK_COUNT(24)) U_HOUR_watch (
        .clk(clk),
        .rst(reset),
        .i_tick(w_hour_tick | tick_hour_up),
        .i_down_tick(tick_hour_down),
        .o_time(hour),
        .o_tick()
    );
endmodule

// 10ms 생성 => FCOUNT = 1_000_000
module tick_gen_watch #(parameter FCOUNT = 1_000_000)(
    input  clk,
    input  reset,
    output o_tick
);
    reg r_o_tick;
    reg [$clog2(FCOUNT)-1:0] r_counter;

    assign o_tick = r_o_tick;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_counter <= 0;
            r_o_tick <= 0;
        end else begin   
            if(r_counter == FCOUNT - 1) begin
                r_counter <= 0;
                r_o_tick <= 1;
            end else begin
                r_counter <= r_counter + 1;
                r_o_tick <= 0;
            end      
        end
    end
endmodule

module time_counter_10ms_watch #(
    parameter TICK_COUNT = 100
) (
    input                               clk,
    input                               rst,
    input                               i_tick,
    output     [$clog2(TICK_COUNT)-1:0] o_time,
    output                              o_tick
);

    reg [$clog2(TICK_COUNT)-1:0] count_reg, count_next;
    reg o_tick_reg, o_tick_next;

    assign o_time = count_reg;
    assign o_tick = o_tick_reg;
    
    // state register
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count_reg <= 0;
            o_tick_reg <= 1'b0;
        end else begin
            count_reg <= count_next; 
            o_tick_reg <= o_tick_next;
        end
    end

    // next state
    always @(*) begin
        count_next = count_reg; 
        o_tick_next = 1'b0;
        if(i_tick == 1'b1) begin
            if (count_reg == (TICK_COUNT - 1)) begin
                count_next = 1'b0;
                o_tick_next = 1'b1;
            end else begin
               count_next = count_reg + 1; 
               o_tick_next = 1'b0;
            end
        end
    end
endmodule

module time_counter_watch #(
    parameter TICK_COUNT = 100
) (
    input                           clk,
    input                           rst,
    input                           i_tick,
    input                           i_down_tick,
    output [$clog2(TICK_COUNT)-1:0] o_time,
    output                          o_tick
);

    reg [$clog2(TICK_COUNT)-1:0] count_reg, count_next;
    reg o_tick_reg, o_tick_next;

    assign o_time = count_reg;
    assign o_tick = o_tick_reg;
    
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count_reg <= 0;
            o_tick_reg <= 1'b0;
        end else begin
            count_reg <= count_next; 
            o_tick_reg <= o_tick_next;
        end
    end

    // next state
    always @(*) begin
        count_next = count_reg; 
        o_tick_next = 1'b0;
    
        if(i_tick == 1'b1) begin
            if (count_reg == (TICK_COUNT - 1)) begin
                count_next = 0;
                o_tick_next = 1'b1;
            end else begin
               count_next = count_reg + 1; 
               o_tick_next = 1'b0;
            end
        end 
        if(i_down_tick == 1'b1) begin
            count_next = (count_reg == 0) ? 59 : count_reg - 1;
        end
    end
endmodule

module time_counter_hour_watch #(//시
    parameter TICK_COUNT = 100
) (
    input                           clk,
    input                           rst,
    input                           i_tick,
    input                           i_down_tick,
    output [$clog2(TICK_COUNT)-1:0] o_time,
    output                          o_tick
);

    reg [$clog2(TICK_COUNT)-1:0] count_reg, count_next;
    reg o_tick_reg, o_tick_next;

    assign o_time = count_reg;
    assign o_tick = o_tick_reg;
    
    // state register
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count_reg <= 12;
            o_tick_reg <= 1'b0;
        end else begin
            count_reg <= count_next; 
            o_tick_reg <= o_tick_next;
        end
    end

    // next state
    always @(*) begin
        count_next = count_reg; 
        o_tick_next = 1'b0;
        if(i_tick == 1'b1) begin
            if (count_reg == (TICK_COUNT - 1)) begin
                count_next = 0;
                o_tick_next = 1'b1;
            end else begin
               count_next = count_reg + 1; 
               o_tick_next = 1'b0;
            end
        end 
        if(i_down_tick == 1'b1) begin
            count_next = (count_reg == 0) ? 23 : count_reg - 1;
        end
    end
endmodule

module cuckoo (
    input  [4:0] hour,
    input  [5:0] min,
    output       o_cuckoo
);
    assign o_cuckoo = (min == 6'd0) & (hour>=7);

endmodule

module fnd_controller (
    input clk,
    input rst,
    input sw0,
    input [6:0] msec,
    input [5:0] sec,
    input [5:0] min,
    input [4:0] hour,
    output [7:0] fnd_data,
    output [3:0] fnd_com
);

    wire [3:0] w_bcd, w_msec_1, w_msec_10, w_sec_1, w_sec_10;
    wire [3:0] w_min_1, w_min_10, w_hour_1, w_hour_10;
    wire [3:0] w_min_hour, w_msec_sec;
    wire w_oclk;
    wire [3:0] w_dp;
    wire [2:0] fnd_sel;

    comparator_500ms U_Comparator_500ms(
        .msec(msec),
        .reset(rst),
        .dp(w_dp)
    );
   
    clk_divider_C U_CLK_Div (
        .clk(clk),
        .rst(rst),
        .o_clk(w_oclk)
    );

    counter_8_C U_Counter_8 (
        .clk(w_oclk),
        .rst(rst),
        .fnd_sel(fnd_sel)//3bit
    );

    decoder_2x4 U_Decoder_2x4 (
        .fnd_sel(fnd_sel[1:0]),
        .fnd_com(fnd_com)
    );

    digit_splitter_C #(
        .BIT_WIDTH(7)
    ) U_DS_MSEC (
        .time_data(msec),
        .digit_1  (w_msec_1),
        .digit_10 (w_msec_10)
    );

    digit_splitter_C #(
        .BIT_WIDTH(6)
    ) U_DS_SEC (
        .time_data(sec),
        .digit_1  (w_sec_1),
        .digit_10 (w_sec_10)
    );

    digit_splitter_C #(
        .BIT_WIDTH(6)
    ) U_DS_MIN (
        .time_data(min),
        .digit_1  (w_min_1),
        .digit_10 (w_min_10)
    );

    digit_splitter_C #(
        .BIT_WIDTH(5)
    ) U_DS_HOUR (
        .time_data(hour),
        .digit_1  (w_hour_1),
        .digit_10 (w_hour_10)
    );

    mux_2x1_C U_MUX_2x1 (
        .msec_sec(w_msec_sec),
        .min_hour(w_min_hour),
        .sel(sw0),
        .bcd(w_bcd)
    );

    mux_8x1_C U_MUX_8x1_MIN_HOUR (
        .sel(fnd_sel),
        .dp(w_dp),
        .digit_1(w_min_1),
        .digit_10(w_min_10),
        .digit_100(w_hour_1),
        .digit_1000(w_hour_10),
        .bcd(w_min_hour)
    );
    mux_8x1_C U_MUX_8x1_MSEC_SEC (
        .sel(fnd_sel),
        .dp(w_dp),
        .digit_1(w_msec_1),
        .digit_10(w_msec_10),
        .digit_100(w_sec_1),
        .digit_1000(w_sec_10),
        .bcd(w_msec_sec)
    );

    bcd_C U_BCD (
        .bcd(w_bcd),
        .fnd_data(fnd_data)
    );

endmodule

module comparator_500ms (
    input [6:0] msec,
    input reset,
    output reg [3:0] dp
);
    always @(*) begin
        if(reset) begin
            dp <= 4'h0; 
        end else begin
            if(msec>49) begin
                dp <= 4'hf;    
            end else begin
                dp <= 4'he;
            end
        end
    end
endmodule

module mux_2x1_C (
    input [3:0] msec_sec,
    input [3:0] min_hour,
    input sel,
    output [3:0] bcd
);
    assign bcd = (sel) ? min_hour : msec_sec;
    
endmodule

//clk divider
// ->1kHz
module clk_divider_C (
    input  clk,
    input  rst,
    output o_clk
);
    // clk 100_000_000, r_count 100_000 (1KHZ)
    //reg [16:0] r_counter;  
    reg [$clog2(100_000)-1:0] r_counter;
    reg r_clk;

    assign o_clk = r_clk; 
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            r_clk <= 1'b0; 
        end else begin
            if (r_counter == 100_000 - 1) begin  // 1KHz preiod
                r_counter <= 0;
                r_clk <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_clk <= 1'b0;
            end
        end
    end
endmodule

//8진 카운터
module counter_8_C (  
    input clk,
    input rst,
    output [2:0] fnd_sel
);
    reg [2:0] r_counter;
    assign fnd_sel = r_counter;
    //
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end
endmodule

module mux_8x1_C (
    input  [2:0] sel,
    input  [3:0] dp,
    input  [3:0] digit_1,
    input  [3:0] digit_10,
    input  [3:0] digit_100,
    input  [3:0] digit_1000,
    output reg [3:0] bcd
);

    // 4:1 mux, always
    always @(*) begin
        case (sel)
            3'b000: bcd = digit_1;
            3'b001: bcd = digit_10;
            3'b010: bcd = digit_100;
            3'b011: bcd = digit_1000;
            3'b110: bcd = dp;
            default: bcd = 4'hf;
        endcase
    end
endmodule

module digit_splitter_C #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] time_data,
    output [3:0] digit_1,
    output [3:0] digit_10
);
    assign digit_1  = time_data % 10;
    assign digit_10 = (time_data / 10) % 10;

endmodule


module bcd_C (
    input  [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'h00:   fnd_data = 8'hc0;
            4'h01:   fnd_data = 8'hf9;
            4'h02:   fnd_data = 8'ha4;
            4'h03:   fnd_data = 8'hb0;
            4'h04:   fnd_data = 8'h99;
            4'h05:   fnd_data = 8'h92;
            4'h06:   fnd_data = 8'h82;
            4'h07:   fnd_data = 8'hf8;
            4'h08:   fnd_data = 8'h80;
            4'h09:   fnd_data = 8'h90;
            4'h0E:   fnd_data = 8'h7f;
            default: fnd_data = 8'hff;
        endcase
    end

endmodule
