module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);

    cacheline_itf               cacheline_itf_i();
    logic                       inst_queue_deq;
    logic                       backend_flush;
    logic   [31:0]              backend_redirect_pc;

    assign inst_queue_deq = '0;
    assign backend_flush = '0;
    assign backend_redirect_pc = 'x;

    frontend_top frontend_i(
        .clk            (clk),
        .rst            (rst),

        .backend_flush  (backend_flush),
        .backend_redirect_pc    (backend_redirect_pc),

        .inst_queue_deq (inst_queue_deq),

        .icache_itf     (cacheline_itf_i)
    );

    cache_adapter cache_adapter_i(
        .clk            (clk),
        .rst            (rst),

        .ufp            (cacheline_itf_i),

        .dfp_addr       (bmem_addr),
        .dfp_read       (bmem_read),
        .dfp_write      (bmem_write),
        .dfp_wdata      (bmem_wdata),
        .dfp_ready      (bmem_ready),
        .dfp_raddr      (bmem_raddr),
        .dfp_rdata      (bmem_rdata),
        .dfp_rvalid     (bmem_rvalid)
    );

endmodule : cpu
