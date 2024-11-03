module frontend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,
    input   logic   [31:0]      backend_redirect_pc,

    frontend_fifo_itf.frontend  to_fifo,

    // I cache connected to arbiter
    // cacheline_itf.master        icache_itf

    // Randomized testing
    output  logic   [31:0]      imem_addr,
    output  logic   [3:0]       imem_rmask,
    input   logic   [31:0]      imem_rdata,
    input   logic               imem_resp
);

    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;

    logic                   if1_valid;
    logic                   if1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]          pc_next;
    logic   [31:0]          pc;
    logic   [31:0]          insts[IF_WIDTH];

    logic                   prev_rst;

    always_ff @(posedge clk) begin
        prev_rst <= rst;
    end

    always_comb begin
        if (prev_rst) begin
            pc_next = 32'h1eceb000;
        end else if (backend_flush) begin
            pc_next = backend_redirect_pc;
        end else begin
            pc_next = (pc + IF_BLK_SIZE) & ~(unsigned'(IF_BLK_SIZE - 1));
        end
    end

    // Stage IF1 = Read ICache and send to FIFO

    if1_stage #(
        .IF_WIDTH(IF_WIDTH)
    ) if1_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .flush                  (backend_flush),

        .prv_valid              ('1), // pc_next is always generating the next request
        .prv_ready              (),   // not used

        .nxt_valid              (if1_valid),
        .nxt_ready              (if1_ready),

        .pc_next                (pc_next),
        .pc                     (pc),
        .insts                  (insts),

        // .icache_itf             (icache_itf)

        .imem_addr              (imem_addr),
        .imem_rmask             (imem_rmask),
        .imem_rdata             (imem_rdata),
        .imem_resp              (imem_resp)
    );

    assign if1_ready = to_fifo.ready;
    assign to_fifo.valid = if1_valid;
    assign to_fifo.data.inst[0] = insts[0];
    assign to_fifo.data.pc[0] = pc;
    assign to_fifo.data.valid[0] = 1'b1;

endmodule
