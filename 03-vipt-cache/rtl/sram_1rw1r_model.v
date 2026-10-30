// Behavioural model of a 1RW1R synchronous SRAM (1-cycle read latency).
// Port structure mirrors sky130_sram_1kbyte_1rw1r_32x256_8 (active-low csb/web,
// port 0 = write, port 1 = read) so the real macro can be swapped in for W=32.
// W is a parameter so the same model can hold the 33-bit tag (see README).
module sram_1rw1r_model #(
    parameter W     = 32,
    parameter DEPTH = 256,
    parameter AW    = 8
)(
    input               clk0, csb0, web0,
    input  [AW-1:0]     addr0,
    input  [W-1:0]      din0,
    input               clk1, csb1,
    input  [AW-1:0]     addr1,
    output reg [W-1:0]  dout1
);
    reg [W-1:0] mem [0:DEPTH-1];
    always @(posedge clk0) if (!csb0 && !web0) mem[addr0] <= din0;
    always @(posedge clk1) if (!csb1)          dout1      <= mem[addr1];
endmodule
