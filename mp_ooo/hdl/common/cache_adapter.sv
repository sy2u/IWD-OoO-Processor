module cache_adapter
(
    input   logic           clk,
    input   logic           rst,

    // cache side signals, ufp -> upward facing port
    cacheline_itf.slave     ufp,

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

    // wdata issue logic
    typedef enum logic [1:0] {
        W_Idle,
        Issue_1,
        Issue_2,
        Issue_3
    } wdata_state_t;
    wdata_state_t wdata_state, next_wdata_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            wdata_state <= W_Idle;
        end else begin
            wdata_state <= next_wdata_state;
        end
    end

    always_comb begin
        next_wdata_state = wdata_state;
        dfp_wdata = 'x;
        ufp.ready = 1'b0;

        unique case (wdata_state)
            W_Idle: begin
                ufp.ready = dfp_ready;
                if (ufp.write) begin
                    ufp.ready = 1'b0;
                    dfp_wdata = ufp.wdata[0 +: 64];
                    if (dfp_ready) begin
                        next_wdata_state = Issue_1;
                    end
                end
            end
            Issue_1: begin
                ufp.ready = 1'b0;
                dfp_wdata = ufp.wdata[64 +: 64];
                if (dfp_ready) begin
                    next_wdata_state = Issue_2;
                end
            end
            Issue_2: begin
                ufp.ready = 1'b0;
                dfp_wdata = ufp.wdata[128 +: 64];
                if (dfp_ready) begin
                    next_wdata_state = Issue_3;
                end
            end
            Issue_3: begin
                ufp.ready = 1'b0;
                dfp_wdata = ufp.wdata[192 +: 64];
                if (dfp_ready) begin
                    ufp.ready = 1'b1;
                    next_wdata_state = W_Idle;
                end
            end
            default: begin
                // nothing
            end
        endcase
    end

    // rdata collection logic
    typedef enum logic [1:0] {
        R_Idle, 
        Collect_1, 
        Collect_2, 
        Collect_3
    } rdata_state_t;
    rdata_state_t rdata_state, next_rdata_state;

    logic   [63:0]  cached_rdata[3];
    logic           cache_rdata[3];

    always_ff @(posedge clk) begin
        if (rst) begin
            rdata_state <= R_Idle;
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
        ufp.rdata = 'x;
        ufp.rvalid = 1'b0;
        for (int i = 0; i < 3; i++) begin
            cache_rdata[i] = 1'b0;
        end

        unique case (rdata_state)
            R_Idle: begin
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
                next_rdata_state = R_Idle;
                ufp.rvalid = 1'b1;
                ufp.rdata = {dfp_rdata, cached_rdata[2], cached_rdata[1], cached_rdata[0]};
            end
            default: begin
                // nothing
            end
        endcase
    end

    assign dfp_addr = ufp.addr;
    assign dfp_read = ufp.read;
    assign dfp_write = ufp.write;
    assign ufp.raddr = dfp_raddr;

endmodule
