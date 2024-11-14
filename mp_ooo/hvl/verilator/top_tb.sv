module top_tb
(
    input   logic   clk,
    input   logic   rst
);

    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    mem_itf_banked dbg_mem_itf(.*);
    dram_w_burst_frfcfs_controller dbg_mem(.itf(dbg_mem_itf));

    // For randomized testing
    // logic [31:0] regs_v[32];
    // assign regs_v = '{default: 32'h0};
    // mem_itf_w_mask #(.CHANNELS(2)) mem_itf(.*);
    // random_tb random_tb(.itf(mem_itf), .reg_data(regs_v));

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

        // For debugging
        ,
        .dbg_bmem_addr  (dbg_mem_itf.addr  ),
        .dbg_bmem_read  (dbg_mem_itf.read  ),
        .dbg_bmem_write (dbg_mem_itf.write ),
        .dbg_bmem_wdata (dbg_mem_itf.wdata ),
        .dbg_bmem_ready (dbg_mem_itf.ready ),
        .dbg_bmem_raddr (dbg_mem_itf.raddr ),
        .dbg_bmem_rdata (dbg_mem_itf.rdata ),
        .dbg_bmem_rvalid(dbg_mem_itf.rvalid)

        // For random testing
        // .imem_addr      (mem_itf.addr [0]),
        // .imem_rmask     (mem_itf.rmask[0]),
        // .imem_rdata     (mem_itf.rdata[0]),
        // .imem_resp      (mem_itf.resp [0])
    );

    // For random testing
    // assign mem_itf.wmask[0] = '0;
    // assign mem_itf.wdata[0] = 'x;
    // assign mem_itf.wmask[1] = '0;
    // assign mem_itf.addr[1] = 'x;
    // assign mem_itf.rmask[1] = '0;

    `include "rvfi_reference.svh"

    initial begin
        `ifdef ECE411_FST_DUMP
            $dumpfile("dump.fst");
        `endif
        `ifdef ECE411_VCD_DUMP
            $dumpfile("dump.vcd");
        `endif
        $dumpvars();
        if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
            $dumpoff();
        end
    end

    final begin
        $dumpflush;
    end

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mon_itf.error != 0) begin
            $fatal;
        end
        if (mem_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule
