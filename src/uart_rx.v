`timescale 1ns / 1ps

module uart_rx (
    input        clk,
    input        reset,
    input        rx,
    input        i_baud_tick,
    output [7:0] rx_data,
    output       rx_done
);
    // s    tate
    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] c_state, n_state;
    reg [3:0] tick_count_reg, tick_count_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    //for CL output
    //reg rx_done_reg;
    reg rx_done_reg, rx_done_next;

    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    // state SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state        <= IDLE;
            tick_count_reg <= 0;
            bit_count_reg  <= 0;
            data_reg       <= 0;
            rx_done_reg    <= 0;
        end else begin
            c_state        <= n_state;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;
        end
    end

    // next
    always @(*) begin
        n_state = c_state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        //for CL output
        //rx_done_reg = 0;
        rx_done_next = rx_done_reg;
        case (c_state)
            IDLE: begin
                //for CL output
                //rx_done_reg = 0;
                rx_done_next   = 0;
                bit_count_next = 0;
                if (i_baud_tick) begin
                    if (!rx) begin
                        if (tick_count_reg == 7) begin
                            n_state         = START;
                            tick_count_next = 0;
                        end else begin
                            tick_count_next = tick_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = 0;
                    end
                end
            end
            START: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        n_state = DATA;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if (i_baud_tick) begin
                    if (tick_count_reg == 0) begin
                        //data_next = data_reg[bit_count_reg]; //PIPO, bit.indexing
                        //SIPO 
                        data_next = {rx, data_reg[7:1]};
                    end
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if (i_baud_tick) begin
                    //rx_done_reg = 1;
                    rx_done_next = 1;
                    // if (tick_count_reg == 7) begin
                    //     //for CL output
                    //     //rx_done_reg = 0;
                    n_state = IDLE;
                    // end else begin
                    // rx_done_next = 0;
                    // tick_count_next = tick_count_reg + 1;
                end
            end
            // end
        endcase
    end
endmodule