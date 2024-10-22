module icache 
import icache_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    output  logic   [31:0]  ufp_rdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    cacheline_itf.master    dfp
);
            localparam      OFFSET_IDX  = 5;
            localparam      SET_IDX     = 4;
            localparam      TAG_IDX     = 23;
            localparam      NUM_WAYS    = 4;
            localparam      PLRU_BITS   = NUM_WAYS - 1;
            localparam      WAY_BITS    = $clog2(NUM_WAYS);

    logic                   data_csb0[NUM_WAYS];
    logic                   tag_csb0[NUM_WAYS];
    logic                   valid_csb0[NUM_WAYS];
    logic                   plru_csb0;
    logic                   plru_csb1;

    logic                   data_web0[NUM_WAYS];
    logic                   tag_web0[NUM_WAYS];
    logic                   valid_web0[NUM_WAYS];
    logic                   plru_web1;

    logic   [31:0]          data_wmask0;
    logic   [255:0]         data_din0;
    logic   [TAG_IDX:0]     tag_din0;
    logic                   valid_din0;
    logic   [PLRU_BITS-1:0] plru_din1;

    logic   [255:0]         data_dout0[NUM_WAYS];
    logic   [TAG_IDX:0]     tag_dout0[NUM_WAYS];
    logic                   valid_dout0[NUM_WAYS];
    logic   [PLRU_BITS-1:0] plru_dout0;

    logic   [OFFSET_IDX-1:0] ufp_offset;
    logic   [SET_IDX-1:0]   ufp_set;
    logic   [TAG_IDX-1:0]   ufp_tag;

    logic   [SET_IDX-1:0]   next_set;
    logic   [SET_IDX-1:0]   sram_operating_set;

    icache_stage_reg_t       stage_reg;

    logic                   hit;
    logic   [WAY_BITS-1:0]  hit_way;
    logic   [WAY_BITS-1:0]  replace_way;

    logic                   stall;
    logic                   allocate_done;

    assign ufp_offset = ufp_addr[OFFSET_IDX-1:0];
    assign ufp_set = ufp_addr[SET_IDX+OFFSET_IDX-1:OFFSET_IDX];
    assign ufp_tag = ufp_addr[TAG_IDX+SET_IDX+OFFSET_IDX-1:SET_IDX+OFFSET_IDX];

    assign sram_operating_set = (stall) ? stage_reg.set : ufp_set;

    generate for (genvar i = 0; i < NUM_WAYS; i++) begin : arrays
        icache_data_array data_array (
            .clk0       (clk),
            .csb0       (data_csb0[i]),
            .web0       (data_web0[i]),
            .wmask0     (data_wmask0),
            .addr0      (sram_operating_set),
            .din0       (data_din0),
            .dout0      (data_dout0[i])
        );
        icache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (tag_csb0[i]),
            .web0       (tag_web0[i]),
            .addr0      (sram_operating_set),
            .din0       (tag_din0),
            .dout0      (tag_dout0[i])
        );
        valid_array #(
            .S_INDEX (SET_IDX),
            .WIDTH   (1)
        ) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (valid_csb0[i]),
            .web0       (valid_web0[i]),
            .addr0      (sram_operating_set),
            .din0       (valid_din0),
            .dout0      (valid_dout0[i])
        );
    end endgenerate

    lru_array #(
        .S_INDEX (SET_IDX),
        .WIDTH   (PLRU_BITS)
    ) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (plru_csb0),
        .addr0      (ufp_set),
        .din0       ('x),
        .dout0      (plru_dout0),
        .csb1       (plru_csb1),
        .web1       (plru_web1),
        .addr1      (stage_reg.set),
        .din1       (plru_din1)
    );


    // ========================================================================
    // FETCH stage
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            stage_reg.rmask <= '0;
        end else if (~stall) begin
            stage_reg.rmask <= ufp_rmask;
            stage_reg.offset <= ufp_offset;
            stage_reg.set <= ufp_set;
            stage_reg.tag <= ufp_tag;
        end
    end

    // Chip-Select signals
    always_comb begin
        for (int i = 0; i < NUM_WAYS; i++) begin
            data_csb0[i] = 1'b1;
            tag_csb0[i] = 1'b1;
            valid_csb0[i] = 1'b1;
        end

        if (~stall) begin
            for (int i = 0; i < NUM_WAYS; i++) begin
                data_csb0[i] = 1'b0;
                tag_csb0[i] = 1'b0;
                valid_csb0[i] = 1'b0;
            end
        end

        if (allocate_done) begin
            data_csb0[replace_way] = 1'b0;
            tag_csb0[replace_way] = 1'b0;
            valid_csb0[replace_way] = 1'b0;
        end
    end

    assign plru_csb0 = stall;
    assign plru_csb1 = ~ufp_resp;

    // Write-Enable signals
    always_comb begin
        for (int i = 0; i < NUM_WAYS; i++) begin
            data_web0[i] = 1'b1;
            tag_web0[i] = 1'b1;
            valid_web0[i] = 1'b1;
        end

        if (allocate_done) begin
            data_web0[replace_way] = 1'b0;
            tag_web0[replace_way] = 1'b0;
            valid_web0[replace_way] = 1'b0;
        end
    end

    assign plru_web1 = plru_csb1;

    // SRAM wmask and din
    always_comb begin
        if (allocate_done) begin
            data_wmask0 = '1;
            data_din0 = dfp.rdata;
        end else begin
            // Leave don't care for EDA optimization
            data_wmask0 = 'x;
            data_din0 = 'x;
        end
    end

    assign tag_din0 = {1'b0, stage_reg.tag};
    assign valid_din0 = 1'b1;

    // ========================================================================
    // PROCESS stage
    // ========================================================================

    assign dfp.wdata = 'x;

    assign ufp_rdata = data_dout0[hit_way][8 * stage_reg.offset +: 32];
    assign ufp_resp = |stage_reg.rmask && ~stall;

    icache_ctrl #(
        .TAG_IDX    (TAG_IDX),
        .NUM_WAYS   (NUM_WAYS),
        .WAY_BITS   (WAY_BITS),
        .OFFSET_IDX (OFFSET_IDX),
        .SET_IDX    (SET_IDX)
    ) ppl_ctrl_i (
        .clk            (clk),
        .rst            (rst),

        .rmask          (stage_reg.rmask),
        .tag            (stage_reg.tag),
        .set            (stage_reg.set),
        .tag_arr_out    (tag_dout0),
        .valid_arr_out  (valid_dout0),

        .stall          (stall),
        .allocate_done  (allocate_done),
        .hit_way        (hit_way),

        .dfp_addr       (dfp.addr),
        .dfp_read       (dfp.read),
        .dfp_write      (dfp.write),
        .dfp_ready      (dfp.ready),
        .dfp_raddr      (dfp.raddr),
        .dfp_rvalid     (dfp.rvalid)
    );

    plru_update #(
        .NUM_WAYS    (NUM_WAYS),
        .PLRU_BITS   (PLRU_BITS),
        .WAY_BITS    (WAY_BITS)
    ) plru_update_i (
        .current_plru   (plru_dout0),
        .next_plru      (plru_din1),
        .hit_way        (hit_way),
        .replace_way    (replace_way)
    );


endmodule
