// Forwarding unit: 10 = from EX/MEM, 01 = from MEM/WB, 00 = register file value
module fu (
    input  [3:0] idex_rs, idex_rt,
    input  [3:0] exmem_destReg,
    input        exmem_writeEnable,
    input  [3:0] memwb_destReg,
    input        memwb_writeEnable,
    output reg [1:0] forwardA, forwardB
);
    always @(*) begin
        forwardA = 2'b00;
        forwardB = 2'b00;

        if (exmem_writeEnable && (exmem_destReg != 4'b0000)) begin
            if (exmem_destReg == idex_rs) forwardA = 2'b10;
            if (exmem_destReg == idex_rt) forwardB = 2'b10;
        end

        if (memwb_writeEnable && (memwb_destReg != 4'b0000)) begin
            if ((memwb_destReg == idex_rs) && (forwardA != 2'b10)) forwardA = 2'b01;
            if ((memwb_destReg == idex_rt) && (forwardB != 2'b10)) forwardB = 2'b01;
        end
    end
endmodule
