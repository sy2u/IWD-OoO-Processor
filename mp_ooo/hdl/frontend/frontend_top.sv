module frontend_top
(
    input   logic           clk,
    input   logic           rst,

    // I cache connected to arbiter (later)
    cacheline_itf.master    icache_itf
);

    localparam              IF_WIDTH = 2;

    logic           frontend_stall;
    logic           f0_valid;
    logic           f0_ready;
    logic           f1_valid;
    logic           f1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]  pc_next;
    logic   [31:0]  pc;
    logic           icache_read;
    logic           icache_resp;
    logic   [31:0]  icache_rdata[IF_WIDTH];
    logic           icache_pending;
    logic           icache_stall;
    logic           icache_valid;

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

    always_ff @(posedge clk) begin
        if (~frontend_stall) begin
            pc <= pc_next;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            icache_pending <= '0;
        end else if (icache_read) begin
            icache_pending <= '1;
        end else if (icache_resp) begin
            icache_pending <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            icache_valid <= '0;
        end else if (f0_valid && f0_ready) begin
            icache_valid <= '1;
        end else if (f1_valid && f1_ready) begin
            icache_valid <= '0;
        end
    end

    assign f0_valid = ~rst && ~frontend_stall;
    assign f0_ready = ~(icache_pending && ~icache_resp);

    assign icache_read = f0_valid;

    icache #(
        .IF_WIDTH(IF_WIDTH)
    ) icache_i (
        .clk            (clk),
        .rst            (rst),

        .ufp_addr       (pc_next),
        .ufp_read       (icache_read),
        .ufp_rdata      (icache_rdata),
        .ufp_resp       (icache_resp),

        .dfp            (icache_itf)
    );

    assign f1_valid = (icache_valid && icache_resp) && ~frontend_stall;

    // Stage IF1 = Read ICache and send into queue

    logic                       instr_queue_full;
    logic   [32*IF_WIDTH-1:0]   instr_queue_enq_data;

    assign f1_ready = ~instr_queue_full;

    sync_fifo #(
        .DEPTH          (8),
        .WIDTH          (32 * IF_WIDTH)
    ) instr_queue(
        .clk            (clk),
        .rst            (rst),

        .enq_en         (f1_valid),
        .full           (instr_queue_full),
        .enq_data       (instr_queue_enq_data),

        .deq_en         ('0)
    );

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            instr_queue_enq_data[(32 * i) +: 32] = icache_rdata[i];
        end
    end

    assign frontend_stall = ~f0_ready || ~f1_ready;

endmodule
