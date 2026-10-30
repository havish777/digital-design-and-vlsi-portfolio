`timescale 1ns/1ps
// Self-checking testbench for vipt_cache.
// - Backing memory returns mem_data(PA) (a function of the physical word address).
// - A scoreboard checks every returned word against mem_data(PA) of the request.
// - Directed tests: cold miss, 4-way fill in one set, LRU eviction, set independence,
//   back-to-back hit throughput.
module tb_vipt_cache;
    localparam PA_W = 45;
    localparam MISS_LAT = 4;            // cycles the "memory" takes to answer a miss

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg                 fetch_valid_i = 0;
    reg  [31:2]         fetch_va_i    = 0;
    reg  [PA_W-1:12]    fetch_pa_i    = 0;
    wire                fetch_ready_o;
    wire                cache_data_valid_o;
    wire [31:0]         cache_data_o;
    wire                cache_miss_req_o;
    wire [PA_W-1:2]     cache_miss_pa_o;
    reg                 cache_miss_resp_i = 0;
    reg  [31:0]         cache_miss_resp_data_i = 0;

    vipt_cache #(.PA_W(PA_W)) dut (
        .clk(clk), .rst_n(rst_n),
        .fetch_valid_i(fetch_valid_i), .fetch_va_i(fetch_va_i), .fetch_pa_i(fetch_pa_i),
        .fetch_ready_o(fetch_ready_o),
        .cache_data_valid_o(cache_data_valid_o), .cache_data_o(cache_data_o),
        .cache_miss_req_o(cache_miss_req_o), .cache_miss_pa_o(cache_miss_pa_o),
        .cache_miss_resp_i(cache_miss_resp_i), .cache_miss_resp_data_i(cache_miss_resp_data_i)
    );

    // ---------------- backing memory model ----------------
    function [31:0] mem_data(input [PA_W-1:2] pa);
        mem_data = pa[33:2] * 32'h9E3779B1 ^ 32'hC0DE0000;
    endfunction

    always @(posedge cache_miss_req_o) begin
        repeat (MISS_LAT) @(negedge clk);
        cache_miss_resp_data_i = mem_data(cache_miss_pa_o);
        cache_miss_resp_i = 1;
        @(negedge clk);
        cache_miss_resp_i = 0;
    end

    // ---------------- scoreboard / counters ----------------
    reg [31:0] exp_q [0:255];
    integer head = 0, tail = 0, hits = 0, misses = 0, errors = 0, checks = 0;

    always @(posedge clk) if (rst_n) begin
        if (fetch_valid_i && fetch_ready_o) begin
            exp_q[tail % 256] = mem_data({fetch_pa_i, fetch_va_i[11:2]});
            tail = tail + 1;
        end
        if (cache_data_valid_o) begin
            hits = hits + 1;
            if (cache_data_o !== exp_q[head % 256]) begin
                errors = errors + 1;
                $display("[%0t] DATA MISMATCH got %h expected %h", $time, cache_data_o, exp_q[head % 256]);
            end
            head = head + 1;
        end
        if (cache_miss_req_o) begin
            misses = misses + 1;
            head = head + 1;      // the missing request returns no data
        end
    end

    task chk(input cond, input [255:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin errors = errors + 1; $display("[%0t] CHECK FAILED: %0s", $time, msg); end
        end
    endtask

    // ---------------- stimulus helpers ----------------
    // Physical address = {tag, va[11:0]}: VA and PA share the 4 KB page offset.
    task issue(input [31:0] va, input [PA_W-1:12] tag);
        begin
            @(negedge clk);
            while (!fetch_ready_o) @(negedge clk);
            fetch_va_i = va[31:2]; fetch_pa_i = tag; fetch_valid_i = 1;
            @(negedge clk);
            fetch_valid_i = 0;
        end
    endtask

    // one access; waits for hit return or for miss + refill to complete
    integer h0, m0;
    task access(input [31:0] va, input [PA_W-1:12] tag, input expect_hit, input [255:0] name);
        begin
            h0 = hits; m0 = misses;
            issue(va, tag);
            repeat (3) @(negedge clk);
            while (!fetch_ready_o) @(negedge clk);
            repeat (2) @(negedge clk);
            if (expect_hit) begin
                chk(hits == h0 + 1 && misses == m0, name);
            end else begin
                chk(misses == m0 + 1 && hits == h0, name);
            end
        end
    endtask

    // miss, then replay and check the replay hits
    task miss_then_hit(input [31:0] va, input [PA_W-1:12] tag, input [255:0] name);
        begin
            access(va, tag, 1'b0, name);
            access(va, tag, 1'b1, name);
        end
    endtask

    localparam [PA_W-1:12] TA = 33'h0_0001_0001, TB = 33'h0_0002_0002, TC = 33'h0_0003_0003,
                           TD = 33'h0_0004_0004, TE = 33'h0_0005_0005;
    localparam [31:0] SET_A = 32'h0000_0204;      // index = VA[9:2] = 0x81
    integer n;

    initial begin
        $dumpfile("vipt_cache.vcd");
        $dumpvars(0, tb_vipt_cache);
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);

        $display("== Test 1: cold miss, refill, replay hit ==");
        miss_then_hit(32'h0000_0100, 33'h1_0000_00AB, "cold miss + replay");

        $display("== Test 2: 4 different physical tags in ONE set (same virtual index) ==");
        miss_then_hit(SET_A, TA, "fill way A");
        miss_then_hit(SET_A, TB, "fill way B");
        miss_then_hit(SET_A, TC, "fill way C");
        miss_then_hit(SET_A, TD, "fill way D");
        access(SET_A, TA, 1'b1, "A still resident");
        access(SET_A, TB, 1'b1, "B still resident");
        access(SET_A, TC, 1'b1, "C still resident");
        access(SET_A, TD, 1'b1, "D still resident");

        $display("== Test 3: LRU eviction (order A,B,C,D -> touch A -> LRU is B) ==");
        access(SET_A, TA, 1'b1, "touch A");
        miss_then_hit(SET_A, TE, "E evicts LRU (B)");
        access(SET_A, TA, 1'b1, "A kept");
        access(SET_A, TC, 1'b1, "C kept");
        access(SET_A, TD, 1'b1, "D kept");
        access(SET_A, TE, 1'b1, "E present");
        access(SET_A, TB, 1'b0, "B was evicted -> miss");
        // recency order is now A,C,D,E,B -> A is LRU, so reloading B evicted A
        access(SET_A, TA, 1'b0, "A (now LRU) was evicted by B reload");

        $display("== Test 4: different set (index) with same tag is independent ==");
        miss_then_hit(32'h0000_0304, TA, "other set cold miss");
        access(SET_A, TE, 1'b1, "set 0x81 unaffected");

        $display("== Test 5: back-to-back hits, 1 request per cycle ==");
        miss_then_hit(32'h0000_0400, TA, "pre-load X0");
        miss_then_hit(32'h0000_0404, TB, "pre-load X1");
        miss_then_hit(32'h0000_0408, TC, "pre-load X2");
        miss_then_hit(32'h0000_040C, TD, "pre-load X3");
        h0 = hits; m0 = misses;
        @(negedge clk);
        for (n = 0; n < 8; n = n + 1) begin
            fetch_va_i = (32'h0000_0400 + 4*(n%4)) >> 2;
            fetch_pa_i = (n%4==0) ? TA : (n%4==1) ? TB : (n%4==2) ? TC : TD;
            fetch_valid_i = 1;
            @(negedge clk);
        end
        fetch_valid_i = 0;
        repeat (6) @(negedge clk);
        chk(hits == h0 + 8 && misses == m0, "8 back-to-back hits, no stalls");

        $display("");
        $display("Summary: %0d hits, %0d misses, %0d checks, %0d errors", hits, misses, checks, errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: %0d FAILURE(S)", errors);
        $finish;
    end

    initial begin #200000; $display("WATCHDOG TIMEOUT"); $finish; end
endmodule
