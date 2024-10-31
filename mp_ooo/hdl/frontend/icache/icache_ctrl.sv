module icache_ctrl 
import icache_types::*; #(
            parameter               TAG_IDX     = 23,
            parameter               NUM_WAYS    = 4,
            parameter               WAY_BITS    = 2,
            parameter               OFFSET_IDX  = 5,
            parameter               SET_IDX     = 5
)
(
    input   logic                   clk,
    input   logic                   rst,

    input   logic                   kill,
    input   logic                   read,
    input   logic   [TAG_IDX-1:0]   tag,
    input   logic   [SET_IDX-1:0]   set,
    input   logic   [TAG_IDX:0]     tag_arr_out[NUM_WAYS],
    input   logic                   valid_arr_out[NUM_WAYS],

    // Output control signals
    output  logic                   stall,
    output  logic                   allocate_done,
    output  logic   [WAY_BITS-1:0]  hit_way,

    // dfp control
    output  logic   [31:0]          dfp_addr,
    output  logic                   dfp_read,
    output  logic                   dfp_write,
    input   logic                   dfp_ready,
    input   logic   [31:0]          dfp_raddr,
    input   logic                   dfp_rvalid
);

    icache_ctrl_fsm_state_t     state, next_state;
    logic                       hit;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= PASS_THRU;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        dfp_read = 1'b0;
        allocate_done = 1'b0;

        unique case (state)
            PASS_THRU: begin
                if (read) begin
                    if (~hit) begin
                        dfp_read = 1'b1;
                        if (dfp_ready) begin
                            next_state = ALLOCATE;
                        end
                    end
                end
                if (kill) begin
                    next_state = PASS_THRU;
                end
            end
            ALLOCATE: begin
                if (dfp_rvalid && dfp_addr == dfp_raddr) begin
                    next_state = ALLOCATE_STALL;
                    allocate_done = 1'b1;
                end
                if (kill) begin
                    next_state = PASS_THRU;
                end
            end
            ALLOCATE_STALL: begin
                next_state = PASS_THRU;
            end
            default: begin
                // do nothing
            end
        endcase
    end

    assign stall = read && ~hit;

    // Hit detection logic
    always_comb begin
        hit = 1'b0;
        hit_way = 'x;

        for (int i = 0; i < NUM_WAYS; i++) begin
            if (tag_arr_out[i][22:0] == tag && valid_arr_out[i]) begin
                hit = 1'b1;
                hit_way = WAY_BITS'(unsigned'(i));
            end
        end
    end

    assign dfp_write = 1'b0;
    assign dfp_addr = {tag, set, {OFFSET_IDX{1'b0}}};

endmodule
