module signextender16_32 (
    input  [15:0] inp,
    output [31:0] op
);
    assign op = {{16{inp[15]}}, inp};
endmodule
