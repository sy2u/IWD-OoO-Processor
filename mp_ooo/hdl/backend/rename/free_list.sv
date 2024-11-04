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
    logic   [FREELIST_IDX:0]    wr_ptr;
    logic   [FREELIST_IDX-1:0]  wr_ptr_actual;
    logic                       wr_ptr_flag;
    logic   [FREELIST_IDX:0]    rd_ptr;
    logic   [FREELIST_IDX-1:0]  rd_ptr_actual;
    logic                       rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= (FREELIST_IDX+1)'(unsigned'(FREELIST_DEPTH));
            rd_ptr <= '0;
            for (int i = 0; i < FREELIST_DEPTH; i++) begin
                free_list[i] <= (PRF_IDX)'(ARF_DEPTH + unsigned'(i));
            end
        end else begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rrf.valid[i]) begin
                    free_list[wr_ptr_actual] <= from_rrf.stale_idx[i];
                    wr_ptr <= (FREELIST_IDX+1)'(wr_ptr + 1);
                end
            end
            if (from_id.ready && from_id.valid) begin
                rd_ptr <= (FREELIST_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    assign from_id.free_idx = free_list[rd_ptr_actual];
    assign from_id.ready = ~(wr_ptr == rd_ptr);

endmodule
