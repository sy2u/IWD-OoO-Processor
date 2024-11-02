module rob
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH]
);

    typedef struct packed {
        
        logic   [ROB_IDX-1:0]   rob_id;
        logic                   valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [31 : 0]        rd_value;
        
    } cdb_rob_t;

    genvar k;

    logic                   ready_array [ROB_DEPTH];
    logic   [PRF_IDX-1:0]   prf_idx_array [ROB_DEPTH];
    logic   [ARF_IDX-1:0]   arf_idx_array [ROB_DEPTH];

    logic   [PRF_IDX-1:0]   prf_idx;
    logic   [ARF_IDX-1:0]   arf_idx;

    logic   [ROB_IDX:0]     head_ptr_reg;
    logic   [ROB_IDX:0]     tail_ptr_reg;

    logic   [ROB_IDX-1:0]   head_ptr;
    logic                   head_ptr_flag;
    logic   [ROB_IDX-1:0]   tail_ptr;
    logic                   tail_ptr_flag;

    logic                   full;
    logic                   empty;
    logic                   pop;

    cdb_rob_t               cdb_rob[CDB_WIDTH];

    assign {head_ptr_flag, head_ptr} = head_ptr_reg;
    assign {tail_ptr_flag, tail_ptr} = tail_ptr_reg;

    // assign tail_ptr_next = tail_ptr_reg + ROB_IDX'(1);
    assign full = (tail_ptr == head_ptr) && (tail_ptr_flag != head_ptr_flag);
    assign empty = (tail_ptr == head_ptr) && (tail_ptr_flag == head_ptr_flag);
    assign pop = (empty) ? 1'b0 : ready_array[head_ptr];

    assign prf_idx = from_id.rd_phy;
    assign arf_idx = from_id.rd_arch;

    generate for (k = 0; k < CDB_WIDTH; k++) begin : cdb_assign
        assign cdb_rob[k].rob_id = cdb[k].rob_id;
        assign cdb_rob[k].valid = cdb[k].valid;
    end endgenerate


    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < ROB_DEPTH; i++) begin
                ready_array[i] <= '0;
                prf_idx_array[i] <= 'x;
                arf_idx_array[i] <= 'x;
            end
            head_ptr_reg <= '0;
            tail_ptr_reg <= '0;
        end else begin
            head_ptr_reg <= head_ptr_reg;
            tail_ptr_reg <= tail_ptr_reg;
            prf_idx_array <= prf_idx_array;
            arf_idx_array <= arf_idx_array;
            ready_array <= ready_array;

            if (from_id.valid && ~full) begin
                tail_ptr_reg <= tail_ptr_reg + ROB_IDX'(1);
                ready_array[tail_ptr] <= '0;
                prf_idx_array[tail_ptr] <= prf_idx;
                arf_idx_array[tail_ptr] <= arf_idx;
            end

            if (pop) begin
                head_ptr_reg <= head_ptr_reg + ROB_IDX'(1);
                ready_array[head_ptr] <= '0;    // pop out previous head
            end
            
            
            for (int i = 0; i < CDB_WIDTH; i++) begin
                if (cdb_rob[i].valid) begin
                    ready_array[cdb_rob[i].rob_id] <= '1;
                end
            end
        end
    end

    // interface with dispatch:: input: phys_reg, arch_reg; output: rob_id
    always_comb begin
        from_id.rob_id = 'x;
        from_id.ready = ~full;
        if (from_id.valid) begin
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

