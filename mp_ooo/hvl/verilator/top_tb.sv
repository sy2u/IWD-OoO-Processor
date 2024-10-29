module top_tb
(
    input   logic   clk,
    input   logic   rst,
    output  logic   halt,
    output  logic   error
);

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

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
    );

    `include "rvfi_reference.svh"

    always_comb begin
        halt = 1'b0;
        for (int unsigned i=0; i < 8; ++i) begin
            halt = halt | mon_itf.halt[i];
        end
        error = (mem_itf.error != 0) || (mon_itf.error != 0);
    end

endmodule
