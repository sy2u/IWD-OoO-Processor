module cpu
import cpu_params::*;
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

    cacheline_itf               icache_itf_i();
    cacheline_itf               dcache_itf_i();
    cacheline_itf               adapter_itf_i();
    frontend_fifo_itf           frontend_fifo_itf_i();
    fifo_backend_itf            fifo_backend_itf_i();
    logic                       backend_flush;
    logic   [31:0]              backend_redirect_pc;

    frontend_top frontend_i(
        .clk                    (clk),
        .rst                    (rst),

        .backend_flush          (backend_flush),
        .backend_redirect_pc    (backend_redirect_pc),

        .to_fifo                (frontend_fifo_itf_i),

        .icache_itf             (icache_itf_i)
    );

    arbiter arbiter_i(
        .clk            (clk),
        .rst            (rst),
        
        .icache         (icache_itf_i),
        .dcache         (dcache_itf_i),
        .adapter        (adapter_itf_i)
    );

    cache_adapter cache_adapter_i(
        .clk            (clk),
        .rst            (rst),

        .ufp            (adapter_itf_i),

        .dfp_addr       (bmem_addr),
        .dfp_read       (bmem_read),
        .dfp_write      (bmem_write),
        .dfp_wdata      (bmem_wdata),
        .dfp_ready      (bmem_ready),
        .dfp_raddr      (bmem_raddr),
        .dfp_rdata      (bmem_rdata),
        .dfp_rvalid     (bmem_rvalid)
    );

    inst_queue #(
        .DEPTH          (8)
    ) inst_queue_i(
        .clk            (clk),
        .rst            (rst || backend_flush),

        .in             (frontend_fifo_itf_i),

        .out            (fifo_backend_itf_i)
    );

    backend_top backend_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_fifo              (fifo_backend_itf_i),
        .dcache_itf             (dcache_itf_i),

        .backend_flush          (backend_flush),
        .backend_redirect_pc    (backend_redirect_pc)
    );

endmodule : cpu
