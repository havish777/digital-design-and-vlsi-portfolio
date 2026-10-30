// LOOPBACK TOP: TX serial output wired to RX input
module uart_loopback_top #(parameter BAUD_DIV = 16)(
    input  wire       clk, rst,
    input  wire [7:0] data_in,
    input  wire       tx_start,
    output wire       tx_busy,
    output wire [7:0] data_out,
    output wire       rx_done,
    output wire       serial,
    output wire       baud_tick
);
    baud_gen     #(.BAUD_DIV(BAUD_DIV)) u_bg (.clk(clk),.rst(rst),.baud_tick(baud_tick));
    uart_tx_baud                         u_tx (.clk(clk),.rst(rst),.baud_tick(baud_tick),
                                               .data_in(data_in),.tx_start(tx_start),
                                               .tx(serial),.tx_busy(tx_busy));
    uart_rx_baud                         u_rx (.clk(clk),.rst(rst),.baud_tick(baud_tick),
                                               .rx(serial),
                                               .data_out(data_out),.rx_done(rx_done));
endmodule
