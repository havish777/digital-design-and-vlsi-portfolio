// Data memory model. NOTE: for this project dataOut simply echoes the address
// (a placeholder, since filling the whole memory is impractical), so LW results
// equal the computed effective address. Writes are supported but unused (no SW).
module RAM32 (
    input  [31:0] addr, dataIn,
    input         clk, writeEnable, enable,
    output [31:0] dataOut
);
    reg [31:0] memory [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 32'h00000000;
    end

    always @(posedge clk) begin
        if (writeEnable && enable && (addr < 256))
            memory[addr] <= dataIn;
    end

    assign dataOut = addr;
endmodule
