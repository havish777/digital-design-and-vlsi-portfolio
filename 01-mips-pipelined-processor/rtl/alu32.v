// ALU: 00 = ADD (LW address), 01 = XNOR (XNORI), 10 = NOR
module alu32 (
    input  [31:0] A, B,
    input  [ 1:0] Ctrl,
    output [31:0] Out,
    output        zflg, ovflg, brwflg, negflg
);
    reg [31:0] Out_;
    reg zflg_, ovflg_, brwflg_, negflg_;

    always @(*) begin
        case (Ctrl)
            2'b00:   Out_ = A + B;
            2'b01:   Out_ = ~(A ^ B);
            2'b10:   Out_ = ~(A | B);
            default: Out_ = 32'h0;
        endcase
        zflg_   = (Out_ == 0);
        negflg_ = Out_[31];
        brwflg_ = (A < B);
        ovflg_  = 1'b0;
    end

    assign Out = Out_;
    assign zflg = zflg_;
    assign ovflg = ovflg_;
    assign negflg = negflg_;
    assign brwflg = brwflg_;
endmodule
