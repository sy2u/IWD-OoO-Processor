module frontend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,
    input   logic   [31:0]      backend_redirect_pc,

    frontend_fifo_itf.frontend  to_fifo,

    // I cache connected to arbiter
    cacheline_itf.master        icache_itf,

    cb_bp_itf.bp                from_cb
);

    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    localparam  unsigned    IF_WIDTH_IDX= $clog2(IF_WIDTH);

    logic                   if1_valid;
    logic                   if1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]                  pc_next;
    logic   [31:0]                  pc;
    logic   [31:0]                  blk_pc;
    logic   [IF_WIDTH-1:0]  [31:0]  insts;

    logic                   prev_rst;

    logic   [IF_WIDTH-1:0]          predict_taken;
    logic   [IF_WIDTH-1:0]          predict_taken_gshare;
    logic   [IF_WIDTH-1:0]  [31:0]  predict_target;

    logic   predict_taken_en;
    logic   [IF_WIDTH_IDX-1:0]  predict_taken_idx;

    always_ff @(posedge clk) begin
        prev_rst <= rst;
    end

    always_comb begin
        if (prev_rst) begin
            pc_next = 32'h1eceb000;
        end else if (backend_flush) begin
            pc_next = backend_redirect_pc;
        end else if (predict_taken_en) begin
            pc_next = predict_target[predict_taken_idx];
        end else begin 
            pc_next = (pc + IF_BLK_SIZE) & ~(unsigned'(IF_BLK_SIZE - 1));
        end
    end

    always_comb begin 
        predict_taken_en = '0;
        predict_taken_idx = '0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            if ((unsigned'(i) >= ((pc % IF_BLK_SIZE) / 4)) & predict_taken[i]) begin 
                predict_taken_en = 1'b1;
                predict_taken_idx = (IF_WIDTH_IDX)'(unsigned'(i));
                break;
            end
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

    gshare gshare_i(
        .clk                    (clk),
        .rst                    (rst),
        .from_cb                (from_cb),
        .blk_pc                 (blk_pc), 
        .predict_taken          (predict_taken_gshare)              
    );

    ubtb ubtb_i(
        .clk                    (clk),
        .rst                    (rst),
        .from_cb                (from_cb),
        .predict_taken_gshare   (predict_taken_gshare),
        .blk_pc                 (blk_pc),
        .predict_target         (predict_target),
	    .predict_taken		    (predict_taken)
    );

    assign if1_ready = to_fifo.ready;
    assign to_fifo.valid = if1_valid;
    assign to_fifo.packet.inst = insts;
    // assign to_fifo.packet.predict_taken = predict_taken_en;
    assign blk_pc = pc & ~(unsigned'(IF_BLK_SIZE - 1));
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign to_fifo.packet.predict_taken[i] = predict_taken[i];
        assign to_fifo.packet.predict_target[i] = predict_target[i];
    end endgenerate
    assign to_fifo.packet.pc = blk_pc;

    generate if (ID_WIDTH == 1) begin
        assign to_fifo.packet.valid[0] = 1'b1;
    end endgenerate

    generate if (ID_WIDTH > 1) begin
        always_comb begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                to_fifo.packet.valid[i] = (~(predict_taken_en & ((IF_WIDTH_IDX)'(unsigned'(i)) > predict_taken_idx))) & (unsigned'(i) >= ((pc % IF_BLK_SIZE) / 4));
            end
        end
    end endgenerate

endmodule
