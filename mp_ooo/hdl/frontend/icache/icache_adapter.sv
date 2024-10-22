module icache_adapter
(
    input   logic           clk,
    input   logic           rst,

    // cache side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic           ufp_read,
    input   logic           ufp_write,
    input   logic   [255:0] ufp_wdata,
    output  logic           ufp_ready,
    output  logic   [31:0]  ufp_raddr,
    output  logic   [255:0] ufp_rdata,
    output  logic           ufp_rvalid,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    output  logic   [63:0]  dfp_wdata,
    input   logic           dfp_ready,
    input   logic   [31:0]  dfp_raddr,
    input   logic   [63:0]  dfp_rdata,
    input   logic           dfp_rvalid
);

    logic   [255:0] garbage;
    assign garbage = ufp_wdata;

    assign ufp_raddr = dfp_raddr;
    assign ufp_ready = dfp_ready;
    assign dfp_wdata = 'x;

    assign dfp_addr = ufp_addr;
    assign dfp_read = ufp_read;
    assign dfp_write = ufp_write;

    // rdata collection logic
    typedef enum logic [1:0] {
        Idle, 
        Collect_1, 
        Collect_2, 
        Collect_3
    } rdata_state_t;
    rdata_state_t rdata_state, next_rdata_state;

    logic   [63:0]  cached_rdata[3];
    logic           cache_rdata[3];

    always_ff @(posedge clk) begin
        if (rst) begin
            rdata_state <= Idle;
        end else begin
            rdata_state <= next_rdata_state;
        end
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 3; i++) begin
            if (cache_rdata[i]) begin
                cached_rdata[i] <= dfp_rdata;
            end
        end
    end

    always_comb begin
        next_rdata_state = rdata_state;
        ufp_rdata = 'x;
        ufp_rvalid = 1'b0;
        for (int i = 0; i < 3; i++) begin
            cache_rdata[i] = 1'b0;
        end

        unique case (rdata_state)
            Idle: begin
                if (dfp_rvalid) begin
                    next_rdata_state = Collect_1;
                end
                cache_rdata[0] = 1'b1;
            end
            Collect_1: begin
                next_rdata_state = Collect_2;
                cache_rdata[1] = 1'b1;
            end
            Collect_2: begin
                next_rdata_state = Collect_3;
                cache_rdata[2] = 1'b1;
            end
            Collect_3: begin
                next_rdata_state = Idle;
                ufp_rvalid = 1'b1;
                ufp_rdata = {dfp_rdata, cached_rdata[2], cached_rdata[1], cached_rdata[0]};
            end
            default: begin
                // nothing
            end
        endcase
    end

endmodule
