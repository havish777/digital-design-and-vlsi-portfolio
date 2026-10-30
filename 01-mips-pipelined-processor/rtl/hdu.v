// Hazard detection unit: stall one cycle on a load-use dependency
module hdu (
    input        idex_memRead,
    input  [3:0] idex_destReg,
    input  [3:0] ifid_rs, ifid_rt,
    output       stall
);
    assign stall = idex_memRead &&
                   ((idex_destReg == ifid_rs) || (idex_destReg == ifid_rt)) &&
                   (idex_destReg != 4'b0000);
endmodule
