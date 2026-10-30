// =============================================================
//  tb_uart_loopback_states.sv - UART loopback testbench with
//  FSM state-transition logging (8-N-1, BAUD_DIV=16, 100 MHz clk)
// =============================================================
module tb_uart_loopback_states;

    reg        clk, rst, tx_start;
    reg  [7:0] data_in;
    wire [7:0] data_out;
    wire       rx_done, tx_busy, serial, baud_tick;

    always #5 clk = ~clk;   // 100 MHz

    uart_loopback_top #(.BAUD_DIV(16)) dut (
        .clk       (clk),
        .rst       (rst),
        .data_in   (data_in),
        .tx_start  (tx_start),
        .tx_busy   (tx_busy),
        .data_out  (data_out),
        .rx_done   (rx_done),
        .serial    (serial),
        .baud_tick (baud_tick)
    );

    // Hierarchical probes into internal FSM signals
    wire [1:0] tx_state = dut.u_tx.state;
    wire [1:0] rx_state = dut.u_rx.state;
    wire [2:0] tx_bit   = dut.u_tx.bit_cnt;
    wire [2:0] rx_bit   = dut.u_rx.bit_cnt;
    wire [7:0] tx_shift = dut.u_tx.shift_reg;
    wire [7:0] rx_shift = dut.u_rx.shift_reg;

    function [47:0] state_name;
        input [1:0] s;
        case (s)
            2'd0: state_name = "IDLE  ";
            2'd1: state_name = "START ";
            2'd2: state_name = "DATA  ";
            2'd3: state_name = "STOP  ";
        endcase
    endfunction

    integer baud_num;
    always @(posedge clk or posedge rst)
        if (rst)           baud_num <= 0;
        else if (baud_tick) baud_num <= baud_num + 1;

    reg [1:0] prev_tx, prev_rx;

    // LOGGER 1 - fires on every baud_tick
    always @(posedge clk) begin
        if (!rst && baud_tick) begin
            $display("+-----------------------------------------------------------------+");
            $display("| BAUD TICK #%-3d   time=%-8t                                  |",
                      baud_num, $time);
            $display("+-----------------------------+-----------------------------------+");
            if (tx_state !== prev_tx)
                $display("| TX : %s -> %s  [CHG] | serial=%b  tx_busy=%b  bit=%0d          |",
                          state_name(prev_tx), state_name(tx_state),
                          serial, tx_busy, tx_bit);
            else
                $display("| TX : %s (same)       | serial=%b  tx_busy=%b  bit=%0d          |",
                          state_name(tx_state), serial, tx_busy, tx_bit);
            if (tx_state == 2'd2)
                $display("|   TX shift_reg = %08b  (next bit out = %b)             |",
                          tx_shift, tx_shift[0]);
            if (rx_state !== prev_rx)
                $display("| RX : %s -> %s  [CHG] | rx_done=%b  data=0x%02h  bit=%0d       |",
                          state_name(prev_rx), state_name(rx_state),
                          rx_done, data_out, rx_bit);
            else
                $display("| RX : %s (same)       | rx_done=%b  data=0x%02h  bit=%0d       |",
                          state_name(rx_state), rx_done, data_out, rx_bit);
            if (rx_state == 2'd2)
                $display("|   RX shift_reg = %08b  (building byte LSB first)       |",
                          rx_shift);
            $display("+-----------------------------------------------------------------+");
            $display("");
            prev_tx <= tx_state;
            prev_rx <= rx_state;
        end
    end

    // LOGGER 2 - serial line edge monitor
    reg prev_serial;
    always @(serial) begin
        if (!rst) begin
            $display("  >> LINE CHANGE at time=%-8t : %b -> %b   tx_state=%s",
                     $time, prev_serial, serial, state_name(tx_state));
        end
        prev_serial = serial;
    end

    // LOGGER 3 - rx_done capture
    always @(posedge rx_done) begin
        #1;
        $display("");
        $display("  +======================================+");
        $display("  |  BYTE RECEIVED                       |");
        $display("  |  sent     = 0x%02h  [ %08b ]     |", data_in,  data_in);
        $display("  |  received = 0x%02h  [ %08b ]     |", data_out, data_out);
        $display("  |  result   = %-4s                      |",
                  (data_out === data_in) ? "PASS" : "FAIL");
        $display("  +======================================+");
        $display("");
    end

    // STIMULUS
    integer pass_cnt, fail_cnt, i;
    reg [7:0] test_bytes [0:4];

    task send_byte;
        input [7:0] b;
        begin
            @(negedge clk);
            while (tx_busy) @(negedge clk);

            $display("");
            $display("==================================================");
            $display("  SENDING  0x%02h  [ %08b ]", b, b);
            $display("  Frame: START(0) D0=%b D1=%b D2=%b D3=%b D4=%b D5=%b D6=%b D7=%b STOP(1)",
                      b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7]);
            $display("  Total baud ticks expected: 10  (1 START + 8 DATA + 1 STOP)");
            $display("==================================================");
            $display("");

            data_in  = b;
            tx_start = 1;
            @(negedge clk);
            tx_start = 0;

            @(posedge rx_done);
            @(negedge clk);

            if (data_out === b) pass_cnt = pass_cnt + 1;
            else                fail_cnt = fail_cnt + 1;

            repeat(4) @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart_states.vcd");
        $dumpvars(0, tb_uart_loopback_states);

        clk=0; rst=1; tx_start=0; data_in=0;
        pass_cnt=0; fail_cnt=0;
        prev_serial=1; baud_num=0;
        prev_tx=0; prev_rx=0;

        test_bytes[0] = 8'hA5;
        test_bytes[1] = 8'hFF;
        test_bytes[2] = 8'h00;
        test_bytes[3] = 8'h55;
        test_bytes[4] = 8'h3C;

        repeat(4) @(negedge clk);
        rst = 0;
        repeat(2) @(negedge clk);

        $display("");
        $display("##################################################");
        $display("##  UART LOOPBACK - FSM STATE TRANSITION LOG    ##");
        $display("##  BAUD_DIV=16  |  CLK=100MHz  |  8-N-1        ##");
        $display("##  [CHG] = state changed on this baud tick     ##");
        $display("##################################################");
        $display("");

        for (i=0; i<5; i=i+1)
            send_byte(test_bytes[i]);

        $display("##################################################");
        $display("##  FINAL:  %0d PASS   %0d FAIL                   ##",
                  pass_cnt, fail_cnt);
        $display("##################################################");
        #100;
        $finish;
    end

    initial begin #2000000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
