module rob
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH]
);

    logic                   ready_array [ROB_DEPTH];
    logic   [PRF_IDX-1:0]   prf_idx_array [ROB_DEPTH];
    logic   [ARF_IDX-1:0]   arf_idx_array [ROB_DEPTH];

    logic   [PRF_IDX-1:0]   prf_idx;
    logic   [ARF_IDX-1:0]   arf_idx;

    logic   [ROB_IDX-1:0]   head_ptr_reg;
    logic   [ROB_IDX-1:0]   tail_ptr_reg;

    logic   [ROB_IDX-1:0]   head_ptr;
    logic   [ROB_IDX-1:0]   tail_ptr;
    logic   [ROB_IDX-1:0]   tail_ptr_next;
    logic                   full;
    logic                   empty;
    logic                   pop;

    assign tail_ptr_next = (tail_ptr < ROB_DEPTH - 1) ? tail_ptr + 1 : 0;   // circular successor of tail pointer
    assign full = (tail_ptr_next == head_ptr) ? 1 : 0;
    assign empty = (tail_ptr == head_ptr) ? 1 : 0;
    assign pop = (empty) ? 0 : ready_array[head_ptr];

    assign head_ptr = head_ptr_reg;     // TODO: could simplify


    always_ff @(posedge clk) begin
        if (rst) begin
            head_ptr_reg <= '0;
            tail_ptr_reg <= '0;
            ready_array <= '0;
            prf_idx_array <= 'x;
            arf_idx_array <= 'x;
        end else begin
            head_ptr_reg <= head_ptr;
            tail_ptr_reg <= tail_ptr;
            prf_idx_array <= prf_idx_array;
            arf_idx_array <= arf_idx_array;
            ready_array <= ready_array;

            if (from_id.valid) begin
                ready_array[tail_ptr] <= '0;
                prf_idx_array[tail_ptr] <= prf_idx;
                arf_idx_array[tail_ptr] <= arf_idx;
            end
            if (pop) begin
                head_ptr_reg <= (head_ptr < ROB_DEPTH - 1) ? head_ptr + 1 : 0;  // circular increment head
                ready_array[head_ptr] <= '0;    // pop out previous head
            end
            for (int i = 0; i < CDB_WIDTH; i++) begin
                if (cdb[i].valid) begin
                    ready_array[cdb[i].rob_id] <= 1;
                end
            end
        end
    end

    // interface with dispatch:: input: phys_reg, arch_reg; output: rob_id
    always_comb begin
        tail_ptr = tail_ptr_reg;
        from_id.rob_id = 'x;
        from_id.ready = ~full;
        if (from_id.valid) begin
            prf_idx = from_id.rd_phy;
            arf_idx = from_id.rd_arch;
            tail_ptr = (tail_ptr < ROB_DEPTH - 1) ? tail_ptr + 1 : 0;    // circular increment tail
            from_id.rob_id = tail_ptr;
        end
    end

    // interface with rrf:: output: phys_reg, arch_reg
    always_comb begin
        to_rrf.valid = 0;
        to_rrf.rd_phy = 'x;
        to_rrf.rd_arch = 'x;
        if (~empty) begin
            to_rrf.valid = ready_array[head_ptr];
            to_rrf.rd_phy = prf_idx_array[head_ptr];
            to_rrf.rd_arch = arf_idx_array[head_ptr];
        end
    end


endmodule
