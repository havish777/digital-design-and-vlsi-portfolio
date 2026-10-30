module mux2x1_32 (
    input        select,
    input [31:0] inp0, inp1,
    output reg [31:0] out
);
    always @(*) begin
        case (select)
            1'b0:    out = inp0;
            1'b1:    out = inp1;
            default: out = 32'bx;
        endcase
    end
endmodule
