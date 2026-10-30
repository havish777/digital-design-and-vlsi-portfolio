module add32 (
    input  [31:0] A, B,
    input         Cin,
    output [31:0] Sum,
    output        Cout
);
    reg [31:0] _Sum_;
    reg        _Cout_;
    always @(*) { _Cout_, _Sum_ } = A + B + Cin;
    assign Sum  = _Sum_;
    assign Cout = _Cout_;
endmodule
