// UART RECEIVER (8-N-1, LSB first, baud_tick driven)
module uart_rx_baud (
    input  wire       clk, rst, baud_tick, rx,
    output reg  [7:0] data_out,
    output reg        rx_done
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE; data_out <= 0; rx_done <= 0;
            bit_cnt <= 0; shift_reg <= 0;
        end else begin
            rx_done <= 0;
            case (state)
                S_IDLE:  if (rx == 0) state <= S_START;
                S_START: if (baud_tick) begin bit_cnt <= 0; state <= S_DATA; end
                S_DATA:  if (baud_tick) begin
                             shift_reg <= {rx, shift_reg[7:1]};
                             bit_cnt   <= bit_cnt + 1;
                             if (bit_cnt == 7) state <= S_STOP;
                         end
                S_STOP:  if (baud_tick) begin
                             if (rx) begin data_out <= shift_reg; rx_done <= 1; end
                             state <= S_IDLE;
                         end
            endcase
        end
    end
endmodule
