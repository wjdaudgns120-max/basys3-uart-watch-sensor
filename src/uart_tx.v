`timescale 1ns / 1ps

module uart_tx (
    input        clk,
    input        reset,
    input        tx_start,
    input  [7:0] tx_data,
    input        i_baud_tick,
    output       tx,
    output       tx_busy,
    output       tx_done
);
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA = 2'b10;
    localparam [1:0] STOP = 2'b11;

    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg tx_reg, tx_next;
    reg [7:0] data_reg, data_next;  //tx_data save
    reg tx_busy_reg, tx_busy_next;
    reg tx_done_reg, tx_done_next;

    assign tx      = tx_reg;
    assign tx_busy = tx_busy_reg;
    assign tx_done = tx_done_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state        <= IDLE;
            tx_reg         <= 1'b1;
            bit_count_reg  <= 3'b000;
            data_reg       <= 8'b0000_0000;
            tx_busy_reg    <= 1'b0;
            tx_done_reg    <= 1'b0;
            tick_count_reg <= 4'b0000;
        end else begin
            c_state        <= n_state;
            bit_count_reg  <= bit_count_next;
            tx_reg         <= tx_next;
            data_reg       <= data_next;
            tx_busy_reg    <= tx_busy_next;
            tx_done_reg    <= tx_done_next;
            tick_count_reg <= tick_count_next;
        end
    end
    //next, output CL
    always @(*) begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        tx_next         = tx_reg;
        data_next       = data_reg;
        tx_busy_next    = tx_busy_reg;
        tx_done_next    = tx_done_reg;
        tick_count_next = tick_count_reg;

        case (c_state)
            IDLE: begin
                tx_next         = 1'b1;
                tx_busy_next    = 1'b0;
                tx_done_next    = 1'b0;
                tick_count_next = 0;
                if (tx_start) begin
                    data_next    = tx_data;
                    tx_busy_next = 1'b1;
                    n_state      = START;
                end
            end

            START: begin
                tx_next = 1'b0;
                bit_count_next = 3'd0;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state = DATA;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end

            DATA: begin
                tx_next = data_reg[0];
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        data_next       = {1'b0, data_reg[7:1]};
                        tick_count_next = 0;
                        //data_next = data_reg >> 1;
                        if (bit_count_reg == 7) n_state = STOP;
                        else begin
                            n_state        = DATA;
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tx_busy_next = 1'b0;
                        tx_done_next = 1'b1;
                        n_state = IDLE;
                    end else tick_count_next = tick_count_reg + 1;
                end
            end
        endcase
    end
endmodule