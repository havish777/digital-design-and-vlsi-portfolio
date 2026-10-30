// Original waveform testbench
module Proctb ();
    reg reset;
    Proc uut (.reset(reset));

    initial begin
        $dumpfile("build/Proctb.vcd");
        $dumpvars(0, Proctb);
        reset = 0;   // reset active
        #2;
        reset = 1;   // release reset
        #100;
        $finish;
    end
endmodule
