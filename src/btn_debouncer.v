`timescale 1ns / 1ps

module btn_debouncer (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);


    reg  [7:0] q_reg;  // 8tap shift register SIPO(Serial input Parallel Output)
    reg        edge_reg;
    wire       debounce;  // output of 8 input AND gate

    reg[$clog2(50)-1:0] counter_reg;
    reg o_1mhz;

    // clock div : 100MHz -> 1MHz
    always @ (posedge clk, posedge reset)begin
        if(reset) begin
            counter_reg <= 0;
            o_1mhz <= 0;
        end
        else begin
            counter_reg <= counter_reg + 1;
            if(counter_reg == (50-1)) begin
                counter_reg <= 0;
                o_1mhz <= ~o_1mhz;
            end
        end
    end

    always @(posedge o_1mhz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            // q_reg <= {q_reg[6:0], i_btn}; // shift left
            q_reg <= {i_btn, q_reg[7:1]}; // shift right
        end
    end

    // 8bit input AND gate
    assign debounce = &q_reg;

    // 1clock delay by debounce
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    // edge detection
    assign o_btn = debounce & ~edge_reg;

    

endmodule
