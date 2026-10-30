// Self-checking testbench: runs the 5-instruction program and checks final
// register values, the load-use stall count and the forwarding events.
module Proctb_check ();
    reg reset;
    Proc uut (.reset(reset));

    integer errors = 0, stall_cycles = 0, fwdA_ex = 0, fwdA_wb = 0;

    always @(posedge uut.clk) if (reset) begin
        if (uut.stall)           stall_cycles = stall_cycles + 1;
        if (uut.forwardA == 2'b10) fwdA_ex = fwdA_ex + 1;   // EX/MEM -> EX
        if (uut.forwardA == 2'b01) fwdA_wb = fwdA_wb + 1;   // MEM/WB -> EX
    end

    task check(input [3:0] r, input [31:0] expected);
        begin
            if (uut.REGFILE.registers[r] === expected)
                $display("PASS  r%0d = 0x%08h", r, expected);
            else begin
                $display("FAIL  r%0d = 0x%08h (expected 0x%08h)", r, uut.REGFILE.registers[r], expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        reset = 0; #2; reset = 1;
        #60;   // plenty of cycles for 5 instructions + 1 stall
        $display("---- Final register check ----");
        check(2, 32'hFFFEFEA0);  // NOR  r2 = ~(0x10101 | 0x1015F)
        check(5, 32'h00000008);  // LW   r5 (last write: LW r5,0(r8) -> addr 8)
        check(6, 32'hFFFEFEB2);  // LW   r6 = addr 0xFFFEFEA0 + 0x12
        check(7, 32'h0001457E);  // XNORI r7 = ~(r6 ^ 0x4433)
        $display("---- Hazard events ----");
        $display("Load-use stall cycles       : %0d (expected 1)", stall_cycles);
        $display("EX/MEM -> EX forwards (A)   : %0d", fwdA_ex);
        $display("MEM/WB -> EX forwards (A)   : %0d", fwdA_wb);
        if (stall_cycles != 1) errors = errors + 1;
        if (errors == 0) $display("RESULT: ALL CHECKS PASSED");
        else             $display("RESULT: %0d CHECK(S) FAILED", errors);
        $finish;
    end
endmodule
