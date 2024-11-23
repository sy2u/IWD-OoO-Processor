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

    logic   [31:0]                  pc_next;
    logic   [31:0]                  pc;
    logic   [31:0]                  blk_pc;
    logic   [IF_WIDTH-1:0]  [31:0]  insts;

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

    if1_stage if1_stage_i(
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

        .icache_itf             (icache_itf)
    );

    assign if1_ready = to_fifo.ready;
    assign to_fifo.valid = if1_valid;
    assign to_fifo.packet.inst = insts;
    assign to_fifo.packet.predict_taken = '0;
    assign blk_pc = pc & ~(unsigned'(IF_BLK_SIZE - 1));
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign to_fifo.packet.predict_target[i] = blk_pc + unsigned'(i) * 4 + 4;
    end endgenerate
    assign to_fifo.packet.pc = blk_pc;

    generate if (ID_WIDTH == 1) begin
        assign to_fifo.packet.valid[0] = 1'b1;
    end endgenerate

    generate if (ID_WIDTH > 1) begin
        always_comb begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                to_fifo.packet.valid[i] = (i >= ((pc % IF_BLK_SIZE) / 4));
            end
        end
    end endgenerate

endmodule
