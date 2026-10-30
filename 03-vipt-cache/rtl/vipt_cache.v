// =====================================================================
//  VIPT L1 cache : 4 KB, 4 ways, 4-byte lines, 4 KB pages, LRU, 3-stage pipeline
//
//  Address use (page offset = VA[11:0] = PA[11:0], so index+offset fit in the page offset):
//     index  = VA[9:2]   (256 sets)     byte offset = VA[1:0]
//     tag    = PA[PA_W-1:12]            (from the TLB, in parallel with the SRAM read)
//
//  T0 : accept fetch, start tag+data SRAM reads with the VIRTUAL index; register PA tag
//  T1 : SRAM data returns; compare 4 stored tags with the PHYSICAL tag; select data; LRU lookup
//  T2 : registered outputs: data_valid/data on hit, miss_req/miss_pa on miss
//
//  Miss: one outstanding miss. fetch_ready_o drops; victim = first invalid way, else LRU way.
//  When cache_miss_resp_i arrives the line is written (tag+data+valid) and LRU updated;
//  the requester then replays the access (it will hit).
// =====================================================================
module vipt_cache #(
    parameter PA_W = 45
)(
    input                    clk, rst_n,

    // fetch request (T0)
    input                    fetch_valid_i,
    input  [31:2]            fetch_va_i,
    input  [PA_W-1:12]       fetch_pa_i,     // physical page number from the TLB
    output                   fetch_ready_o,

    // response (T2)
    output reg               cache_data_valid_o,
    output reg [31:0]        cache_data_o,

    // miss request / refill
    output reg               cache_miss_req_o,
    output reg [PA_W-1:2]    cache_miss_pa_o,
    input                    cache_miss_resp_i,
    input  [31:0]            cache_miss_resp_data_i
);
    localparam TAG_W = PA_W - 12;
    localparam IW    = 8;

    // ---------------- control state ----------------
    reg                miss_pending;
    reg [11:2]         pend_va;
    reg [TAG_W-1:0]    pend_tag;
    reg [1:0]          pend_way;
    wire               refill   = cache_miss_resp_i & miss_pending;
    wire [IW-1:0]      pend_idx = pend_va[9:2];

    // ---------------- T0 ----------------
    wire               t1_miss;                          // from T1 below
    assign fetch_ready_o = rst_n & ~miss_pending & ~t1_miss;
    wire               accept  = fetch_valid_i & fetch_ready_o;
    wire [IW-1:0]      t0_idx  = fetch_va_i[9:2];

    reg                s1_valid;
    reg [11:2]         s1_va;
    reg [TAG_W-1:0]    s1_tag;
    always @(posedge clk) begin
        if (!rst_n) s1_valid <= 1'b0;
        else begin
            s1_valid <= accept;
            if (accept) begin s1_va <= fetch_va_i[11:2]; s1_tag <= fetch_pa_i; end
        end
    end
    wire [IW-1:0] s1_idx = s1_va[9:2];

    // ---------------- SRAM arrays (4 ways x {tag, data}) ----------------
    wire [4*TAG_W-1:0] tag_rd_flat;
    wire [4*32-1:0]    data_rd_flat;
    genvar w;
    generate
        for (w = 0; w < 4; w = w + 1) begin : g_way
            wire we = refill & (pend_way == w);
            sram_1rw1r_model #(.W(TAG_W)) u_tag (
                .clk0(clk), .csb0(~we), .web0(1'b0), .addr0(pend_idx), .din0(pend_tag),
                .clk1(clk), .csb1(~accept), .addr1(t0_idx),
                .dout1(tag_rd_flat[w*TAG_W +: TAG_W]));
            sram_1rw1r_model #(.W(32)) u_data (
                .clk0(clk), .csb0(~we), .web0(1'b0), .addr0(pend_idx), .din0(cache_miss_resp_data_i),
                .clk1(clk), .csb1(~accept), .addr1(t0_idx),
                .dout1(data_rd_flat[w*32 +: 32]));
        end
    endgenerate

    // valid bits in flops (one bit per way per set)
    reg [3:0] valid_mem [0:(1<<IW)-1];
    reg [3:0] vtmp;
    integer   k;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (k = 0; k < (1<<IW); k = k + 1) valid_mem[k] <= 4'b0000;
        end else if (refill) begin
            vtmp = valid_mem[pend_idx];
            vtmp[pend_way] = 1'b1;
            valid_mem[pend_idx] <= vtmp;
        end
    end

    // ---------------- T1: tag compare, data mux, LRU ----------------
    wire [3:0] vbits = valid_mem[s1_idx];
    wire [3:0] hit_vec;
    generate
        for (w = 0; w < 4; w = w + 1) begin : g_cmp
            assign hit_vec[w] = vbits[w] && (tag_rd_flat[w*TAG_W +: TAG_W] == s1_tag);
        end
    endgenerate
    wire t1_hit = s1_valid &  (|hit_vec);
    assign t1_miss = s1_valid & ~(|hit_vec);

    wire [1:0] hit_way = hit_vec[0] ? 2'd0 : hit_vec[1] ? 2'd1 : hit_vec[2] ? 2'd2 : 2'd3;
    wire [31:0] hit_data = ({32{hit_vec[0]}} & data_rd_flat[ 31: 0]) |
                           ({32{hit_vec[1]}} & data_rd_flat[ 63:32]) |
                           ({32{hit_vec[2]}} & data_rd_flat[ 95:64]) |
                           ({32{hit_vec[3]}} & data_rd_flat[127:96]);

    wire [7:0] ranks;
    lru_4way u_lru (
        .clk(clk), .rst_n(rst_n),
        .rd_idx(s1_idx), .rd_ranks(ranks),
        .upd_en(t1_hit | refill),
        .upd_idx(refill ? pend_idx : s1_idx),
        .upd_way(refill ? pend_way : hit_way)
    );

    wire [1:0] lru_way = (ranks[1:0] == 2'd3) ? 2'd0 :
                         (ranks[3:2] == 2'd3) ? 2'd1 :
                         (ranks[5:4] == 2'd3) ? 2'd2 : 2'd3;
    wire [1:0] inv_way = !vbits[0] ? 2'd0 : !vbits[1] ? 2'd1 : !vbits[2] ? 2'd2 : 2'd3;
    wire [1:0] victim_way = (vbits != 4'hF) ? inv_way : lru_way;

    // ---------------- T2: output registers / miss bookkeeping ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            cache_data_valid_o <= 1'b0; cache_data_o <= 32'h0;
            cache_miss_req_o   <= 1'b0; cache_miss_pa_o <= {(PA_W-2){1'b0}};
            miss_pending <= 1'b0;
        end else begin
            cache_data_valid_o <= t1_hit;
            cache_data_o       <= t1_hit ? hit_data : 32'h0;
            cache_miss_req_o   <= t1_miss;
            if (t1_miss) begin
                cache_miss_pa_o <= {s1_tag, s1_va};
                miss_pending    <= 1'b1;
                pend_va         <= s1_va;
                pend_tag        <= s1_tag;
                pend_way        <= victim_way;
            end
            if (refill) miss_pending <= 1'b0;
        end
    end
endmodule
