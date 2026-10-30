// UART TRANSMITTER (8-N-1, LSB first, baud_tick driven)
module uart_tx_baud (
    input  wire       clk, rst, baud_tick,
    input  wire [7:0] data_in,
    input  wire       tx_start,
    output reg        tx,
    output reg        tx_busy
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE; tx <= 1; tx_busy <= 0;
            bit_cnt <= 0; shift_reg <= 0;
        end else case (state)
            S_IDLE:  begin
                         tx <= 1; tx_busy <= 0;
                         if (tx_start) begin
                             shift_reg <= data_in;
                             tx_busy   <= 1;
                             state     <= S_START;
                         end
                     end
            S_START: if (baud_tick) begin tx <= 0; bit_cnt <= 0; state <= S_DATA;  end
            S_DATA:  if (baud_tick) begin
                         tx        <= shift_reg[0];
                         shift_reg <= {1'b0, shift_reg[7:1]};
                         bit_cnt   <= bit_cnt + 1;
                         if (bit_cnt == 7) state <= S_STOP;
                     end
            S_STOP:  if (baud_tick) begin tx <= 1; state <= S_IDLE; end
        endcase
    end
endmodule
