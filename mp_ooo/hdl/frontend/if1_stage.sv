module if1_stage #(
            parameter       IF_WIDTH    = 2
)
(
    input   logic           clk,
    input   logic           rst,

    input   logic           stall,
    input   logic   [31:0]  pc_next,
    output  logic           icache_unresponsive,
    output  logic   [31:0]  pc,
    output  logic   [31:0]  icache_rdata[IF_WIDTH],
    output  logic           valid,

    // memory side signals, dfp -> downward facing port
    cacheline_itf.master    icache_itf
);

    // PC update
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= '0;
        end else if (~stall) begin
            pc <= pc_next;
        end
    end

    logic                   icache_read;
    logic                   icache_resp;
    logic                   icache_pending;
    logic                   icache_valid;

    assign icache_read = ~rst && ~stall;
    assign valid = icache_valid;

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
        end else if (~stall) begin
            icache_valid <= '1;
        end
    end

    assign icache_unresponsive = icache_pending && ~icache_resp;

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

endmodule
