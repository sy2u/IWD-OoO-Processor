module top_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps;
    longint timeout;
    initial begin
        $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
        clock_half_period_ps = clock_half_period_ps / 2;
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    // mem_itf_w_mask random_mem_itf(.*);
    // random_tb random_tb(.itf(random_mem_itf), .reg_data(regs_v)); // For randomized testing

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)

        // For random testing
        // .imem_addr      (random_mem_itf.addr [0]),
        // .imem_rmask     (random_mem_itf.rmask[0]),
        // .imem_rdata     (random_mem_itf.rdata[0]),
        // .imem_resp      (random_mem_itf.resp [0]),
    );

    // assign random_mem_itf.wmask[0] = '0;
    // assign random_mem_itf.wdata[0] = 'x;

    `include "rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        for (int unsigned i=0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        if (mon_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        if (mem_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
