// Instruction memory (32 words) preloaded with the test program
module ROM32 (
    input  [31:0] addr,
    input         ce,
    output [31:0] out
);
    reg [31:0] ROM_ [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) ROM_[i] = 32'h00000000;
        //            OP   rd   rs   rt   imm
        ROM_[0] = 32'h02340000; // 0000 0010 0011 0100 0000  NOR   r2, r3, r4
        ROM_[1] = 32'h45200000; // 0100 0101 0010 0000 0000  LW    r5, 0(r2)
        ROM_[2] = 32'h46200012; // 0100 0110 0010 0000 0012  LW    r6, 0x12(r2)
        ROM_[3] = 32'h27604433; // 0010 0111 0110 0000 4433  XNORI r7, r6, 0x4433
        ROM_[4] = 32'h45800000; // 0100 0101 1000 0000 0000  LW    r5, 0(r8)
    end
    assign out = (ce && addr < 32) ? ROM_[addr] : 32'h00000000;
endmodule
