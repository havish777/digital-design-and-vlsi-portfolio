// BAUD RATE GENERATOR: one-clock-wide baud_tick every BAUD_DIV clocks
module baud_gen #(parameter BAUD_DIV = 16)(
    input  wire clk, rst,
    output reg  baud_tick
);
    reg [$clog2(BAUD_DIV)-1:0] cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin cnt <= 0; baud_tick <= 0; end
        else begin
            baud_tick <= 0;
            if (cnt == BAUD_DIV-1) begin cnt <= 0; baud_tick <= 1; end
            else cnt <= cnt + 1;
        end
    end
endmodule
