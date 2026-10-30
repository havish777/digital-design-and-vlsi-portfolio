// 5-stage pipelined RISC processor top level (IF / ID / EX / MEM / WB)
// with hazard detection (load-use stall) and EX/MEM + MEM/WB forwarding.
// NOTE: simulation top - the clock is generated inside this module.
module Proc (
    input reset          // active-low reset
);
    reg clk;
    initial clk = 0;
    always #1 clk = ~clk;

    // Stall and forwarding control wires
    wire stall, pcWrite, ifidWrite;
    wire [1:0] forwardA, forwardB;
    assign pcWrite   = ~stall;
    assign ifidWrite = ~stall;

    // Writeback wires (declared early so regfile can connect)
    wire [31:0] wb_writeData;
    wire [ 3:0] wb_writeAddr;
    wire        wb_writeEnable;

    // EX/MEM and MEM/WB registers
    reg [31:0] exmem_aluResult;
    reg [ 3:0] exmem_destReg;
    reg        exmem_writeEnable, exmem_memRead, exmem_wbSelect;

    reg [31:0] memwb_memData, memwb_aluResult;
    reg [ 3:0] memwb_destReg;
    reg        memwb_writeEnable, memwb_wbSelect;

    // ---------------- IF stage ----------------
    reg  [31:0] pc;
    wire [31:0] pcPlus4;
    wire        pcCout;
    initial pc = 32'h00000000;

    add32 pcAdder (.A(pc), .B(32'h00000004), .Cin(1'b0), .Sum(pcPlus4), .Cout(pcCout));

    always @(posedge clk) begin
        if (!reset)       pc <= 32'h00000000;
        else if (pcWrite) pc <= pcPlus4;
    end

    wire [31:0] if_instr;
    ROM32 instrMem (.addr(pc >> 2), .ce(1'b1), .out(if_instr));

    // IF/ID register
    reg [31:0] ifid_instr;
    initial ifid_instr = 32'h00000000;
    always @(posedge clk) begin
        if (!reset)         ifid_instr <= 32'h00000000;
        else if (ifidWrite) ifid_instr <= if_instr;
    end

    // ---------------- ID stage ----------------
    wire [1:0] id_aluCtrl;
    wire [3:0] id_readAddr1, id_readAddr2, id_writeAddr;
    wire       id_writeEnable, id_aluSrc, id_wbSelect, id_memRead;
    wire [31:0] id_readData1, id_readData2, id_immediate;

    cu CU (
        .instr(ifid_instr),
        .aluCtrl(id_aluCtrl),
        .regFileWriteAddr(id_writeAddr),
        .regFileWriteEnable(id_writeEnable),
        .regFileReadAddr1(id_readAddr1),
        .regFileReadAddr2(id_readAddr2),
        .aluSrc(id_aluSrc),
        .aluOut_dataMemOut_select(id_wbSelect),
        .memRead(id_memRead)
    );

    regfile32 REGFILE (
        .readAddr1(id_readAddr1), .readAddr2(id_readAddr2),
        .writeAddr(wb_writeAddr), .writeData(wb_writeData),
        .writeEnable(wb_writeEnable), .resetb(1'b1),
        .readData1(id_readData1), .readData2(id_readData2), .clk(clk)
    );

    signextender16_32 SIGNEXT (.inp(ifid_instr[15:0]), .op(id_immediate));

    // Hazard detection unit
    reg        idex_memRead;
    reg [3:0]  idex_destReg;
    hdu HDU (
        .idex_memRead(idex_memRead), .idex_destReg(idex_destReg),
        .ifid_rs(id_readAddr1), .ifid_rt(id_readAddr2), .stall(stall)
    );

    // ID/EX register
    reg [31:0] idex_readData1, idex_readData2, idex_immediate;
    reg [3:0]  idex_rs, idex_rt;
    reg [1:0]  idex_aluCtrl;
    reg        idex_aluSrc, idex_writeEnable, idex_wbSelect;
    initial begin
        idex_readData1 = 32'h0; idex_readData2 = 32'h0; idex_immediate = 32'h0;
        idex_rs = 4'h0; idex_rt = 4'h0; idex_destReg = 4'h0;
        idex_aluCtrl = 2'b00; idex_aluSrc = 1'b0; idex_writeEnable = 1'b0;
        idex_memRead = 1'b0; idex_wbSelect = 1'b0;
    end

    always @(posedge clk) begin
        if (!reset || stall) begin          // bubble on reset or load-use stall
            idex_readData1 <= 32'h0; idex_readData2 <= 32'h0; idex_immediate <= 32'h0;
            idex_rs <= 4'h0; idex_rt <= 4'h0; idex_destReg <= 4'h0;
            idex_aluCtrl <= 2'b00; idex_aluSrc <= 1'b0; idex_writeEnable <= 1'b0;
            idex_memRead <= 1'b0; idex_wbSelect <= 1'b0;
        end else begin
            idex_readData1 <= id_readData1; idex_readData2 <= id_readData2;
            idex_immediate <= id_immediate;
            idex_rs <= id_readAddr1; idex_rt <= id_readAddr2;
            idex_destReg <= id_writeAddr;
            idex_aluCtrl <= id_aluCtrl; idex_aluSrc <= id_aluSrc;
            idex_writeEnable <= id_writeEnable;
            idex_memRead <= id_memRead; idex_wbSelect <= id_wbSelect;
        end
    end

    // ---------------- EX stage ----------------
    wire [31:0] ex_aluA, ex_forwardB, ex_aluB, ex_aluOut;
    wire ex_zflg, ex_ovflg, ex_brwflg, ex_negflg;

    fu FWD (
        .idex_rs(idex_rs), .idex_rt(idex_rt),
        .exmem_destReg(exmem_destReg), .exmem_writeEnable(exmem_writeEnable),
        .memwb_destReg(memwb_destReg), .memwb_writeEnable(memwb_writeEnable),
        .forwardA(forwardA), .forwardB(forwardB)
    );

    // 00 = ID/EX value, 01 = MEM/WB result, 10 = EX/MEM result
    mux3x1_32 fwdMuxA (.select(forwardA), .inp0(idex_readData1), .inp1(wb_writeData),
                       .inp2(exmem_aluResult), .out(ex_aluA));
    mux3x1_32 fwdMuxB (.select(forwardB), .inp0(idex_readData2), .inp1(wb_writeData),
                       .inp2(exmem_aluResult), .out(ex_forwardB));
    mux2x1_32 aluSrcMux (.select(idex_aluSrc), .inp0(ex_forwardB),
                         .inp1(idex_immediate), .out(ex_aluB));

    alu32 ALU (.A(ex_aluA), .B(ex_aluB), .Ctrl(idex_aluCtrl), .Out(ex_aluOut),
               .zflg(ex_zflg), .ovflg(ex_ovflg), .brwflg(ex_brwflg), .negflg(ex_negflg));

    // EX/MEM register
    initial begin
        exmem_aluResult = 32'h0; exmem_destReg = 4'h0; exmem_writeEnable = 1'b0;
        exmem_memRead = 1'b0; exmem_wbSelect = 1'b0;
    end
    always @(posedge clk) begin
        if (!reset) begin
            exmem_aluResult <= 32'h0; exmem_destReg <= 4'h0; exmem_writeEnable <= 1'b0;
            exmem_memRead <= 1'b0; exmem_wbSelect <= 1'b0;
        end else begin
            exmem_aluResult <= ex_aluOut; exmem_destReg <= idex_destReg;
            exmem_writeEnable <= idex_writeEnable;
            exmem_memRead <= idex_memRead; exmem_wbSelect <= idex_wbSelect;
        end
    end

    // ---------------- MEM stage ----------------
    wire [31:0] mem_readData;
    RAM32 DataMem (
        .addr(exmem_aluResult),
        .dataIn(32'h00000000),   // no SW in this ISA subset
        .clk(clk),
        .writeEnable(1'b0),
        .enable(1'b1),
        .dataOut(mem_readData)
    );

    // MEM/WB register
    initial begin
        memwb_memData = 32'h0; memwb_aluResult = 32'h0; memwb_destReg = 4'h0;
        memwb_writeEnable = 1'b0; memwb_wbSelect = 1'b0;
    end
    always @(posedge clk) begin
        if (!reset) begin
            memwb_memData <= 32'h0; memwb_aluResult <= 32'h0; memwb_destReg <= 4'h0;
            memwb_writeEnable <= 1'b0; memwb_wbSelect <= 1'b0;
        end else begin
            memwb_memData <= mem_readData; memwb_aluResult <= exmem_aluResult;
            memwb_destReg <= exmem_destReg; memwb_writeEnable <= exmem_writeEnable;
            memwb_wbSelect <= exmem_wbSelect;
        end
    end

    // ---------------- WB stage ----------------
    assign wb_writeAddr   = memwb_destReg;
    assign wb_writeEnable = memwb_writeEnable;
    mux2x1_32 wbMux (.select(memwb_wbSelect), .inp0(memwb_memData),
                     .inp1(memwb_aluResult), .out(wb_writeData));
endmodule
