module frontend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,
    input   logic   [31:0]      backend_redirect_pc,

    frontend_fifo_itf.frontend  to_fifo,

    // I cache connected to arbiter
    cacheline_itf.master        icache_itf
);

    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;

    logic                   if1_valid;
    logic                   if1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]          pc_next;
    logic   [31:0]          pc;
    logic                   icache_read;
    logic   [31:0]          icache_rdata[IF_WIDTH];

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
        .insts                  (icache_rdata),

        .icache_itf             (icache_itf)
    );

    logic   [32*IF_WIDTH-1:0]   instr_queue_enq_data;

    assign if1_ready = to_fifo.ready;
    assign to_fifo.valid = if1_valid;
    assign to_fifo.data = instr_queue_enq_data;

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            instr_queue_enq_data[(32 * i) +: 32] = icache_rdata[i];
        end
    end

endmodule
