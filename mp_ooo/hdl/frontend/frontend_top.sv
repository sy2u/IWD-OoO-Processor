module frontend_top
(
    input   logic           clk,
    input   logic           rst,

    input   logic           backend_flush,
    input   logic   [31:0]  backend_redirect_pc,

    input   logic           inst_queue_deq,

    // I cache connected to arbiter (later)
    cacheline_itf.master    icache_itf
);

    localparam              IF_WIDTH = 1;

    logic                   if1_valid;
    logic                   if1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]          pc_next;
    logic   [31:0]          pc;
    logic                   icache_read;
    logic   [31:0]          icache_rdata[IF_WIDTH];

    logic                   prev_rst;
    logic                   rst_done;

    always_ff @(posedge clk) begin
        prev_rst <= rst;
    end

    assign rst_done = prev_rst && ~rst;

    always_comb begin
        if (rst_done) begin
            pc_next = 32'h1eceb000;
        end else if (backend_flush) begin
            pc_next = backend_redirect_pc;
        end else begin
            pc_next = pc + unsigned'(IF_WIDTH * 4);
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

    logic                       instr_queue_full;
    logic   [32*IF_WIDTH-1:0]   instr_queue_enq_data;

    assign if1_ready = ~instr_queue_full;

    sync_fifo #(
        .DEPTH          (16),
        .WIDTH          (32 * IF_WIDTH)
    ) instr_queue(
        .clk            (clk),
        .rst            (rst || backend_flush),

        .enq_en         (if1_valid),
        .full           (instr_queue_full),
        .enq_data       (instr_queue_enq_data),

        .deq_en         (inst_queue_deq)
    );

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            instr_queue_enq_data[(32 * i) +: 32] = icache_rdata[i];
        end
    end

endmodule
