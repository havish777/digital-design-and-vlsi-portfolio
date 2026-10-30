// Control unit. Instruction format: [31:28] opcode, [27:24] dest, [23:20] rs, [19:16] rt, [15:0] imm
module cu (
    input  [31:0] instr,
    output [ 1:0] aluCtrl,
    output [ 3:0] regFileReadAddr1, regFileReadAddr2, regFileWriteAddr,
    output        aluSrc, regFileWriteEnable,
    output        aluOut_dataMemOut_select,   // 1 = ALU result, 0 = memory data
    output        memRead
);
    reg [1:0] aluCtrl_;
    reg       regFileWriteEnable_;
    reg [3:0] regFileWriteAddr_, regFileReadAddr1_, regFileReadAddr2_;
    reg       aluSrc_, aluOut_dataMemOut_select_, memRead_;

    always @(*) begin
        // defaults
        aluCtrl_ = 2'b11; regFileWriteAddr_ = 4'b0000; regFileWriteEnable_ = 1'b0;
        regFileReadAddr1_ = 4'b0000; regFileReadAddr2_ = 4'b0000;
        aluSrc_ = 1'b0; aluOut_dataMemOut_select_ = 1'b1; memRead_ = 1'b0;

        casez (instr[31:28])
            4'b0000: begin // NOR (R-type)
                aluCtrl_ = 2'b10;
                regFileWriteAddr_ = instr[27:24]; regFileWriteEnable_ = 1'b1;
                regFileReadAddr1_ = instr[23:20]; regFileReadAddr2_ = instr[19:16];
                aluSrc_ = 1'b0; aluOut_dataMemOut_select_ = 1'b1; memRead_ = 1'b0;
            end
            4'b0100: begin // LW (I-type)
                aluCtrl_ = 2'b00;
                regFileWriteAddr_ = instr[27:24]; regFileWriteEnable_ = 1'b1;
                regFileReadAddr1_ = instr[23:20]; regFileReadAddr2_ = 4'b0000;
                aluSrc_ = 1'b1; aluOut_dataMemOut_select_ = 1'b0; memRead_ = 1'b1;
            end
            4'b0010: begin // XNORI (I-type)
                aluCtrl_ = 2'b01;
                regFileWriteAddr_ = instr[27:24]; regFileWriteEnable_ = 1'b1;
                regFileReadAddr1_ = instr[23:20]; regFileReadAddr2_ = 4'b0000;
                aluSrc_ = 1'b1; aluOut_dataMemOut_select_ = 1'b1; memRead_ = 1'b0;
            end
            default: begin // NOP / unknown
                aluCtrl_ = 2'b11; regFileWriteAddr_ = 4'b0000; regFileWriteEnable_ = 1'b0;
                regFileReadAddr1_ = 4'b0000; regFileReadAddr2_ = 4'b0000;
                aluSrc_ = 1'b0; aluOut_dataMemOut_select_ = 1'b0; memRead_ = 1'b0;
            end
        endcase
    end

    assign aluCtrl = aluCtrl_;
    assign regFileWriteAddr = regFileWriteAddr_;
    assign regFileWriteEnable = regFileWriteEnable_;
    assign regFileReadAddr1 = regFileReadAddr1_;
    assign regFileReadAddr2 = regFileReadAddr2_;
    assign aluSrc = aluSrc_;
    assign aluOut_dataMemOut_select = aluOut_dataMemOut_select_;
    assign memRead = memRead_;
endmodule
