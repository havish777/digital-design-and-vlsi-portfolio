// 16 x 32-bit register file, async read, sync write, r0 is read-only (never written)
module regfile32 (
    input  [ 3:0] readAddr1, readAddr2, writeAddr,
    input  [31:0] writeData,
    input         writeEnable, resetb, clk,
    output [31:0] readData1, readData2
);
    reg [31:0] registers [0:15];
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) registers[i] = 32'h00000000;
        registers[3] = 32'h00010101;   // reg3 = 0x10101
        registers[4] = 32'h0001015F;   // reg4 = 0x1015F
        registers[8] = 32'h00000008;   // reg8 = 0x8
    end

    always @(posedge clk) begin
        if (writeEnable && (writeAddr != 4'b0000))
            registers[writeAddr] <= writeData;
    end

    integer j;
    always @(negedge resetb) begin
        for (j = 0; j < 16; j = j + 1) registers[j] <= 32'h00000000;
    end

    assign readData1 = registers[readAddr1];
    assign readData2 = registers[readAddr2];
endmodule
