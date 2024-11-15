module if1_stage #(
            parameter       IF_WIDTH    = 2
)
(
    input   logic           clk,
    input   logic           rst,

    input   logic           flush,

    // Prev stage handshake
    input   logic           prv_valid,
    output  logic           prv_ready,

    // Next stage handshake
    output  logic           nxt_valid,
    input   logic           nxt_ready,

    // Datapath input
    input   logic   [31:0]  pc_next,

    // Datapath output
    output  logic   [31:0]                  pc,
    output  logic   [IF_WIDTH-1:0]  [31:0]  insts,

    // memory side signals, dfp -> downward facing port
    cacheline_itf.master    icache_itf
);

    logic                           icache_valid;
    logic                           icache_resp;
    logic                           icache_pending;
    logic   [IF_WIDTH-1:0]  [31:0]  icache_rdata;
    logic                           icache_unresponsive;

    assign prv_ready = ~icache_valid || (nxt_valid && nxt_ready) || flush;

    // PC update
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= '0;
        end else if (prv_ready && prv_valid) begin
            pc <= pc_next;
        end
    end

    // Cache state update
    always_ff @(posedge clk) begin
        if (rst) begin
            icache_pending <= '0;
        end else if (prv_ready && prv_valid) begin
            icache_pending <= '1;
        end else if (icache_resp) begin
            icache_pending <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            icache_valid <= '0;
        end else if (prv_ready) begin
            icache_valid <= prv_valid;
        end
    end

    assign icache_unresponsive = icache_pending && ~icache_resp;

    // I-Cache

    icache #(
        .IF_WIDTH(IF_WIDTH)
    ) icache_i (
        .clk            (clk),
        .rst            (rst),

        .ufp_addr       (pc_next),
        .ufp_read       (prv_ready && prv_valid),
        .ufp_rdata      (icache_rdata),
        .ufp_resp       (icache_resp),
        .kill           (flush),

        .dfp            (icache_itf)
    );

    // Temporary buffer for output
    logic   [IF_WIDTH-1:0]  [31:0]  temp_icache_rdata;

    always_ff @(posedge clk) begin
        if (icache_resp) begin
            temp_icache_rdata <= icache_rdata;
        end
    end

    assign insts = (icache_resp) ? icache_rdata : temp_icache_rdata;

    assign nxt_valid = icache_valid && ~icache_unresponsive;

endmodule
