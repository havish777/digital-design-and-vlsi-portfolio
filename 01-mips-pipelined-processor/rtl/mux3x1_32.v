module mux3x1_32 (
    input [ 1:0] select,
    input [31:0] inp0, inp1, inp2,
    output reg [31:0] out
);
    always @(*) begin
        case (select)
            2'b00:   out = inp0;
            2'b01:   out = inp1;
            2'b10:   out = inp2;
            default: out = 32'bx;
        endcase
    end
endmodule
