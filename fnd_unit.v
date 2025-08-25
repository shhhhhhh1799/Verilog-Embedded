`timescale 1ns / 1ps

module fnd_unit(
    input [7:0] fnd_data_c, 
    input [7:0] fnd_data_u, 
    input [7:0] fnd_data_t,
    input [3:0] fnd_com_c,
    input [3:0] fnd_com_u,
    input [3:0] fnd_com_t,
    input sw5,
    input w_sensor_clock_c,
    input tx_u,
    input tx_t,
    output [7:0] fnd_data, 
    output [3:0] fnd_com,
    output tx
);
    assign fnd_data = (w_sensor_clock_c) ? ((sw5) ? fnd_data_u : fnd_data_t) : fnd_data_c; 
    assign fnd_com = (w_sensor_clock_c) ? ((sw5) ? fnd_com_u : fnd_com_t) : fnd_com_c; 
    assign tx = (sw5) ? tx_u : tx_t; 
endmodule
