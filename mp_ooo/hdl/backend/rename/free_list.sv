module free_list
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,

    id_fl_itf.fl                from_id,
    rrf_fl_itf.fl               from_rrf
);

    localparam  unsigned        FREELIST_DEPTH = PRF_DEPTH - ARF_DEPTH;
    localparam  unsigned        FREELIST_IDX = $clog2(FREELIST_DEPTH);

    logic   [PRF_IDX-1:0]       free_list[FREELIST_DEPTH];
    logic   [FREELIST_IDX-1:0]  wr_ptr;
    logic   [FREELIST_IDX-1:0]  rd_ptr;
    logic   [FREELIST_IDX:0]    counter;
    logic   [FREELIST_IDX:0]    counter_nxt;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            counter <= (FREELIST_IDX+1)'(FREELIST_DEPTH);
            for (int i = 0; i < FREELIST_DEPTH; i++) begin
                free_list[i] <= (PRF_IDX)'(ARF_DEPTH + unsigned'(i));
            end
        end else if (backend_flush) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            counter <= (FREELIST_IDX+1)'(FREELIST_DEPTH);
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rrf.valid[i]) begin
                    free_list[wr_ptr] <= from_rrf.stale_idx[i];
                end
            end
        end else begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rrf.valid[i]) begin
                    free_list[wr_ptr] <= from_rrf.stale_idx[i];
                    wr_ptr <= (FREELIST_IDX)'(wr_ptr + 1);
                end
            end
            if (from_id.ready && from_id.valid) begin
                rd_ptr <= (FREELIST_IDX)'(rd_ptr + 1);
            end
            counter <= counter_nxt;
        end
    end

    always_comb begin
        counter_nxt = counter;
        for (int i = 0; i < ID_WIDTH; i++) begin
            if (from_rrf.valid[i]) begin
                counter_nxt = (FREELIST_IDX+1)'(counter_nxt + 1);
            end
        end
        if (from_id.ready && from_id.valid) begin
            counter_nxt = (FREELIST_IDX+1)'(counter_nxt - 1);
        end
    end

    assign from_id.free_idx = free_list[rd_ptr];
    assign from_id.ready = (counter >= 1);

endmodule
