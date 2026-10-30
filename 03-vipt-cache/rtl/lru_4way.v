// True LRU for a 4-way set-associative cache.
// Each set stores a 2-bit rank per way: 0 = most recently used ... 3 = least recently used.
// Update on use of way U: ranks lower than rank[U] are incremented, rank[U] becomes 0.
module lru_4way #(
    parameter SETS = 256,
    parameter IW   = 8
)(
    input               clk, rst_n,
    input  [IW-1:0]     rd_idx,
    output [7:0]        rd_ranks,      // {rank3, rank2, rank1, rank0}
    input               upd_en,
    input  [IW-1:0]     upd_idx,
    input  [1:0]        upd_way
);
    reg [7:0] rank_mem [0:SETS-1];
    assign rd_ranks = rank_mem[rd_idx];

    integer i, w;
    reg [7:0] cur, nxt;
    reg [1:0] r_used;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < SETS; i = i + 1) rank_mem[i] <= {2'd3, 2'd2, 2'd1, 2'd0};
        end else if (upd_en) begin
            cur    = rank_mem[upd_idx];
            r_used = cur[2*upd_way +: 2];
            for (w = 0; w < 4; w = w + 1) begin
                if (w == upd_way)                    nxt[2*w +: 2] = 2'd0;
                else if (cur[2*w +: 2] < r_used)     nxt[2*w +: 2] = cur[2*w +: 2] + 2'd1;
                else                                 nxt[2*w +: 2] = cur[2*w +: 2];
            end
            rank_mem[upd_idx] <= nxt;
        end
    end
endmodule
