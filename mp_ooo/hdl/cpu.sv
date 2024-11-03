module cpu
import cpu_params::*;
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // output  logic   [31:0]      bmem_addr,
    // output  logic               bmem_read,
    // output  logic               bmem_write,
    // output  logic   [63:0]      bmem_wdata,
    // input   logic               bmem_ready,

    // input   logic   [31:0]      bmem_raddr,
    // input   logic   [63:0]      bmem_rdata,
    // input   logic               bmem_rvalid

    output  logic   [31:0]      imem_addr,
    output  logic   [3:0]       imem_rmask,
    input   logic   [31:0]      imem_rdata,
    input   logic               imem_resp
);

    cacheline_itf               cacheline_itf_i();
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

        // .icache_itf             (cacheline_itf_i)

        .imem_addr              (imem_addr),
        .imem_rmask             (imem_rmask),
        .imem_rdata             (imem_rdata),
        .imem_resp              (imem_resp)
    );

    // cache_adapter cache_adapter_i(
    //     .clk            (clk),
    //     .rst            (rst),

    //     .ufp            (cacheline_itf_i),

    //     .dfp_addr       (bmem_addr),
    //     .dfp_read       (bmem_read),
    //     .dfp_write      (bmem_write),
    //     .dfp_wdata      (bmem_wdata),
    //     .dfp_ready      (bmem_ready),
    //     .dfp_raddr      (bmem_raddr),
    //     .dfp_rdata      (bmem_rdata),
    //     .dfp_rvalid     (bmem_rvalid)
    // );

    inst_queue #(
        .DEPTH          (16),
        .WIDTH          (32 * IF_WIDTH)
    ) inst_queue_i(
        .clk            (clk),
        .rst            (rst || backend_flush),

        .in_valid       (frontend_fifo_itf_i.valid),
        .in_ready       (frontend_fifo_itf_i.ready),
        .in_packet      (frontend_fifo_itf_i.data),

        .out_valid      (fifo_backend_itf_i.valid),
        .out_ready      (fifo_backend_itf_i.ready),
        .out_packet     (fifo_backend_itf_i.data)
    );

    backend_top backend_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_fifo              (fifo_backend_itf_i),

        .backend_flush          (backend_flush),
        .backend_redirect_pc    (backend_redirect_pc)
    );

endmodule : cpu
