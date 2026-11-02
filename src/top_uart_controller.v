`timescale 1ns / 1ps

module top_uart_controller (
    input         clk,
    input         reset,
    input         rx,
    input         rx_pop,
    input         tx_trigger,
    input  [13:0] selected_data,
    output        tx,
    output [ 7:0] rx_data,
    output        rx_empty
);
    // push state
    localparam P_IDLE = 0, P_1000 = 1, P_100 = 2, P_10 = 3, P_1 = 4, P_CARRY = 5;
    reg [2:0] p_nstate, p_cstate;

    // tx state
    localparam TX_IDLE = 0, TX_START = 1, TX_POP = 2, TX_WAIT = 3;
    reg [1:0] tx_cstate, tx_nstate;

    wire w_baud_tick_x16;
    // wire rx
    wire w_rx_done;
    wire [7:0] w_rx_data;
    // wire fifo_tx
    wire [7:0] w_fifo_tx_rdata;
    wire w_fifo_tx_empty, w_fifo_tx_full;
    //wire tx
    wire w_tx_busy, w_tx_done;

    // wire [3:0] d1000 = (selected_data / 1000) % 10; 
    // wire [3:0] d100 = (selected_data / 100) % 10;
    // wire [3:0] d10 = (selected_data / 10) % 10;
    // wire [3:0] d1 = selected_data % 10;
    reg [3:0] d1000, d100, d10, d1;

    reg r_fifo_tx_push, r_fifo_tx_pop, r_tx_start;
    reg [7:0] r_fifo_tx_wdata;

    reg r_tx_trigger_ed;
    wire w_tx_trigger_pulse = tx_trigger && !r_tx_trigger_ed;


    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .i_baud_tick(w_baud_tick_x16),
        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done)
    );

    fifo U_FIFO_RX (
        .clk  (clk),
        .reset(reset),
        .push (w_rx_done),
        .pop  (rx_pop),
        .wdata(w_rx_data),  // push data
        .rdata(rx_data),    // pop data
        .full (),
        .empty(rx_empty)
    );

    fifo U_FIFO_TX (
        .clk  (clk),
        .reset(reset),
        .push (r_fifo_tx_push),
        .pop  (r_fifo_tx_pop),
        .wdata(r_fifo_tx_wdata),  // push data
        .rdata(w_fifo_tx_rdata),  // pop data
        .full (w_fifo_tx_full),
        .empty(w_fifo_tx_empty)
    );

    uart_tx U_UART_TX (
        .clk        (clk),
        .reset      (reset),
        .tx_start   (r_tx_start),
        .tx_data    (w_fifo_tx_rdata),
        .i_baud_tick(w_baud_tick_x16),
        .tx         (tx),
        .tx_busy    (w_tx_busy),
        .tx_done    (w_tx_done)
    );

    baud_tick_x16 U_BAUD_TICK_x16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_x16)
    );
    
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            d1000 <= 0;
            d100  <= 0;
            d10   <= 0;
            d1    <= 0;
        end else if (w_tx_trigger_pulse) begin
            d1000 <= (selected_data / 1000) % 10;
            d100  <= (selected_data / 100) % 10;
            d10   <= (selected_data / 10) % 10;
            d1    <= selected_data % 10;
        end
    end

    // push state
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            p_cstate <= P_IDLE;
        end else begin
            p_cstate <= p_nstate;
        end
    end

    always @(*) begin
        p_nstate        = p_cstate;
        r_fifo_tx_wdata = 8'h00;
        r_fifo_tx_push  = 0;
        case (p_cstate)
            P_IDLE: begin
                if (w_tx_trigger_pulse) p_nstate = P_1000;
            end
            P_1000: begin
                r_fifo_tx_wdata = 8'h30 + d1000;
                if (!w_fifo_tx_full) begin
                    r_fifo_tx_push = 1;
                    p_nstate = P_100;
                end
            end
            P_100: begin
                r_fifo_tx_wdata = 8'h30 + d100;
                if (!w_fifo_tx_full) begin
                    r_fifo_tx_push = 1;
                    p_nstate = P_10;
                end
            end
            P_10: begin
                r_fifo_tx_wdata = 8'h30 + d10;
                if (!w_fifo_tx_full) begin
                    r_fifo_tx_push = 1;
                    p_nstate = P_1;
                end
            end
            P_1: begin
                r_fifo_tx_wdata = 8'h30 + d1;
                if (!w_fifo_tx_full) begin
                    r_fifo_tx_push = 1;
                    p_nstate = P_CARRY;
                end
            end
            P_CARRY: begin
                r_fifo_tx_wdata = 8'h0A;
                if (!w_fifo_tx_full) begin
                    r_fifo_tx_push = 1;
                    p_nstate = P_IDLE;
                end
            end
        endcase
    end

    // tx state
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tx_cstate <= TX_IDLE;
            r_tx_trigger_ed <= 0;
        end else begin
            tx_cstate <= tx_nstate;
            r_tx_trigger_ed <= tx_trigger;
        end
    end

    always @(*) begin
        tx_nstate     = tx_cstate;
        r_fifo_tx_pop = 0;
        r_tx_start    = 0;
        case (tx_cstate)
            TX_IDLE: begin
                if (!w_fifo_tx_empty & !w_tx_busy) tx_nstate = TX_START;
            end
            TX_START: begin
                r_tx_start = 1;
                tx_nstate  = TX_POP;
            end
            TX_POP: begin
                r_fifo_tx_pop = 1;
                tx_nstate = TX_WAIT;
            end

            TX_WAIT: begin
                if (w_tx_done) tx_nstate = TX_IDLE;
            end
        endcase
    end


endmodule
