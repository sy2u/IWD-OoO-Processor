module frontend_top
(
    input   logic           clk,
    input   logic           rst,

    // I cache connected to arbiter (later)
    cacheline_itf.master    icache_itf
);

    localparam              IF_WIDTH = 2;

    logic           if1_valid;
    logic           if1_stall;

    // Stage IF0 = Access ICache

    logic   [31:0]  pc_next;
    logic   [31:0]  pc;
    logic           icache_read;
    logic   [31:0]  icache_rdata[IF_WIDTH];
    logic           icache_unresponsive;

    logic           prev_rst;
    logic           rst_done;

    always_ff @(posedge clk) begin
        prev_rst <= rst;
    end

    assign rst_done = prev_rst && ~rst;

    always_comb begin
        if (rst_done) begin
            pc_next = 32'h1eceb000;
        end else begin
            pc_next = pc + 8;
        end
    end

    // Stage IF1 = Read ICache and send to FIFO

    if1_stage #(
        .IF_WIDTH(IF_WIDTH)
    ) if1_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .pc_next                (pc_next),
        .stall                  (if1_stall),
        .icache_unresponsive    (icache_unresponsive),
        .pc                     (pc),
        .icache_rdata           (icache_rdata),
        .valid                  (if1_valid),

        .icache_itf             (icache_itf)
    );

    logic                       instr_queue_full;
    logic   [32*IF_WIDTH-1:0]   instr_queue_enq_data;

    sync_fifo #(
        .DEPTH          (8),
        .WIDTH          (32 * IF_WIDTH)
    ) instr_queue(
        .clk            (clk),
        .rst            (rst),

        .enq_en         (if1_valid && ~if1_stall),
        .full           (instr_queue_full),
        .enq_data       (instr_queue_enq_data),

        .deq_en         ('0)
    );

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            instr_queue_enq_data[(32 * i) +: 32] = icache_rdata[i];
        end
    end

    logic           frontend_stall;
    assign frontend_stall = icache_unresponsive || instr_queue_full;

    // Simple solution: stall the entire pipeline
    assign if1_stall = frontend_stall;

endmodule
