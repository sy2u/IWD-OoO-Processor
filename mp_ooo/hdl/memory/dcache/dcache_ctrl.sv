module dcache_ctrl
import mp_cache_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           hit,
    input   logic           dirty,
    input   logic   [3:0]   rmask,
    input   logic   [3:0]   wmask,

    // Output control signals
    output  logic           stall,
    output  logic           allocate_done,
    output  logic           write_hit,
    output  logic           write_hit_rec,

    input   logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic           dfp_ready,
    input   logic   [31:0]  dfp_raddr,
    input   logic           dfp_rvalid
);

    ppl_ctrl_fsm_state_t    state, next_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= PASS_THRU;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        allocate_done = 1'b0;
        write_hit = 1'b0;
        dfp_read = 1'b0;
        dfp_write = 1'b0;

        unique case (state)
            PASS_THRU: begin
                if ((|rmask || |wmask) && ~write_hit_rec) begin
                    if (~hit) begin
                        if (dirty) begin
                            dfp_write = 1'b1;
                            if (dfp_ready) begin
                                next_state = WB;
                            end
                        end else begin
                            dfp_read = 1'b1;
                            if (dfp_ready) begin
                                next_state = ALLOCATE;
                            end
                        end
                    end
                    write_hit = |wmask && hit;
                end
            end
            ALLOCATE: begin
                if (dfp_rvalid && dfp_addr == dfp_raddr) begin
                    next_state = ALLOCATE_STALL;
                    allocate_done = 1'b1;
                end
            end
            ALLOCATE_STALL: begin
                next_state = PASS_THRU;
            end
            WB: begin
                dfp_read = 1'b1;
                if (dfp_ready) begin
                    next_state = ALLOCATE;
                end
            end
            default: begin
                // do nothing
            end
        endcase
    end

    assign stall = (|rmask || |wmask) && (write_hit_rec || ~hit);

    always_ff @(posedge clk) begin
        if (rst) begin
            write_hit_rec <= 1'b0;
        end else if (write_hit_rec) begin
            write_hit_rec <= 1'b0;
        end else if (write_hit) begin
            write_hit_rec <= 1'b1;
        end
    end

endmodule