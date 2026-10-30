// 32-bit register (not used by Proc.v; kept from the original design)
module register32 (
    input  [31:0] ip,
    input         wen, resb,
    output [31:0] op
);
    reg [31:0] register;
    initial register = 32'b0;
    always @(posedge wen or negedge resb) begin
        if (!resb) register <= 32'b0;
        else       register <= ip;
    end
    assign op = register;
endmodule
