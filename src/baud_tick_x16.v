`timescale 1ns / 1ps

module baud_tick_x16 (
    input  clk,
    input  reset,
    output o_baud_tick
);
    //9600hz
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg  [$clog2(F_COUNT)-1:0] count_reg;
    wire [$clog2(F_COUNT)-1:0] count_next;

    //SL
    // count_reg SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 1'b0;
        end else begin
            count_reg <= count_next;
        end
    end

    // next CL
    assign count_next  = (count_reg == (F_COUNT - 1)) ? 0 : count_reg + 1;


    // output CL
    assign o_baud_tick = (count_reg == (F_COUNT - 1)) ? 1 : 0;

endmodule