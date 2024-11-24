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
    logic   [FREELIST_IDX-1:0]  wr_ptrs [ID_WIDTH];
    logic   [FREELIST_IDX-1:0]  rd_ptrs [ID_WIDTH];
    logic   [FREELIST_IDX:0]    counter;
    logic   [FREELIST_IDX:0]    counter_nxt;

    logic   [ID_WIDTH_IDX:0]    n_valids_id;
    logic   [ID_WIDTH_IDX:0]    n_valids_rrf;

    ////////////////////
    // Pointer Update //
    ////////////////////

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            counter <= (FREELIST_IDX+1)'(unsigned'(FREELIST_DEPTH));
        end else if (backend_flush) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            counter <= (FREELIST_IDX+1)'(unsigned'(FREELIST_DEPTH));
        end else begin
            wr_ptr <= FREELIST_IDX'(wr_ptr + n_valids_rrf);
            if (from_id.ready) begin
                rd_ptr <= FREELIST_IDX'(rd_ptr + n_valids_id);
            end
            counter <= counter_nxt;
        end
    end

    assign counter_nxt = (from_id.ready) ? 
                        counter + (FREELIST_IDX+1)'(n_valids_rrf) - (FREELIST_IDX+1)'(n_valids_id) : 
                        counter + (FREELIST_IDX+1)'(n_valids_rrf);

    /////////////////
    // FIFO Update //
    /////////////////

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < FREELIST_DEPTH; i++) begin
                free_list[i] <= PRF_IDX'(ARF_DEPTH + unsigned'(i));
            end
        end else if (backend_flush) begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rrf.valid[i]) begin
                    free_list[wr_ptr] <= from_rrf.stale_idx[i];
                end
            end
        end else begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rrf.valid[i]) begin
                    free_list[(FREELIST_IDX)'(wr_ptrs[i])] <= from_rrf.stale_idx[i];
                end
            end
        end
    end

    always_comb begin
        n_valids_id = '0;
        for (int i = 0; i < ID_WIDTH; i++) begin
            rd_ptrs[i] = rd_ptr + FREELIST_IDX'(n_valids_id);
            if (from_id.valid[i]) begin
                n_valids_id = (ID_WIDTH_IDX+1)'(n_valids_id + 1);
            end
        end
    end

    always_comb begin
        n_valids_rrf = '0;
        for (int i = 0; i < ID_WIDTH; i++) begin
            wr_ptrs[i] = wr_ptr + FREELIST_IDX'(n_valids_rrf);
            if (from_rrf.valid[i]) begin
                n_valids_rrf = (ID_WIDTH_IDX+1)'(n_valids_rrf + 1);
            end
        end
    end

    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_id.free_idx[i] = free_list[FREELIST_IDX'(rd_ptrs[i])];
    end endgenerate

    assign from_id.ready = (counter >= (FREELIST_IDX+1)'(ID_WIDTH));

endmodule
