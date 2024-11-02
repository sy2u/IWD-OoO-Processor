module free_list
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_fl_itf.fl                from_id,
    rrf_fl_itf.fl               from_rrf
);

    localparam  unsigned        FREELIST_DEPTH = PRF_DEPTH - ARF_DEPTH;
    localparam  unsigned        FREELIST_IDX = $clog2(FREELIST_DEPTH);

    logic   [PRF_IDX-1:0]       free_list[FREELIST_DEPTH];
    logic   [FREELIST_IDX-1:0]  wr_ptr;
    logic   [FREELIST_IDX-1:0]  rd_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= (FREELIST_IDX)'(unsigned'(PRF_DEPTH - 1));
            rd_ptr <= '0;
            for (int i = 0; i < FREELIST_DEPTH; i++) begin
                free_list[i] <= (PRF_IDX)'(ARF_DEPTH + i);
            end
        end else begin
            if (from_rrf.valid) begin
                free_list[wr_ptr] <= from_rrf.stale_idx;
                wr_ptr <= (FREELIST_IDX)'(wr_ptr + 1);
            end
            if (from_id.ready && from_id.valid) begin
                rd_ptr <= (FREELIST_IDX)'(rd_ptr + 1);
            end
        end
    end

    assign from_id.free_idx = (from_id.ready) ? free_list[rd_ptr] : 'x;
    assign from_id.ready = ~(wr_ptr == rd_ptr);

endmodule
