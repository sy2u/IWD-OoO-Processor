module rob
import cpu_params::*;
import rvfi_types::*;
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
        logic   [31:0]          rd_value;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } cdb_rob_t;

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

    cdb_rob_t               cdb_rob [CDB_WIDTH];

    rvfi_dbg_t              rvfi_itf;
    rvfi_dbg_t              rvfi_array [ROB_DEPTH];
    logic   [63:0]          rvfi_order;


    // same logic with fifo queue
    assign {head_ptr_flag, head_ptr} = head_ptr_reg;
    assign {tail_ptr_flag, tail_ptr} = tail_ptr_reg;

    // assign tail_ptr_next = tail_ptr_reg + ROB_IDX'(1);
    assign full = (tail_ptr == head_ptr) && (tail_ptr_flag != head_ptr_flag);
    assign empty = (tail_ptr == head_ptr) && (tail_ptr_flag == head_ptr_flag);
    assign pop = (empty) ? 1'b0 : ready_array[head_ptr];

    // create local CDB interface instances
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin : cdb_assign
        assign cdb_rob[k].rob_id = cdb[k].rob_id;
        assign cdb_rob[k].valid = cdb[k].valid;
        assign cdb_rob[k].rd_value = cdb[k].rd_value;
        assign cdb_rob[k].rs1_value_dbg = cdb[k].rs1_value_dbg;
        assign cdb_rob[k].rs2_value_dbg = cdb[k].rs2_value_dbg;
    end endgenerate


    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < ROB_DEPTH; i++) begin
                ready_array[i] <= '0;
                prf_idx_array[i] <= 'x;
                arf_idx_array[i] <= 'x;
                rvfi_array[i] <= '0;
            end
            head_ptr_reg <= '0;
            tail_ptr_reg <= '0;

            rvfi_order <= 64'h0;
        end else begin
            head_ptr_reg <= head_ptr_reg;
            tail_ptr_reg <= tail_ptr_reg;
            prf_idx_array <= prf_idx_array;
            arf_idx_array <= arf_idx_array;
            ready_array <= ready_array;

            rvfi_array <= rvfi_array;

            if (from_id.valid && ~full) begin           // push in
                tail_ptr_reg <= tail_ptr_reg + ROB_IDX'(1);
                ready_array[tail_ptr] <= '0;
                prf_idx_array[tail_ptr] <= from_id.rd_phy;
                arf_idx_array[tail_ptr] <= from_id.rd_arch;
                rvfi_array[tail_ptr] <= from_id.rvfi_dbg;       // for rvfi storage
            end

            if (pop) begin                              // pop out
                head_ptr_reg <= head_ptr_reg + ROB_IDX'(1);
                ready_array[head_ptr] <= '0;
                rvfi_order <= rvfi_order + 1;
            end

            for (int i = 0; i < CDB_WIDTH; i++) begin   // snoop CDB
                if (cdb_rob[i].valid) begin
                    ready_array[cdb_rob[i].rob_id] <= '1;
                    rvfi_array[cdb_rob[i].rob_id].rd_wdata <= cdb_rob[i].rd_value;
                    rvfi_array[cdb_rob[i].rob_id].rs1_rdata <= cdb_rob[i].rs1_value_dbg;
                    rvfi_array[cdb_rob[i].rob_id].rs2_rdata <= cdb_rob[i].rs2_value_dbg;
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

    //////////////////////////
    //          RVFI        //
    //////////////////////////

    rvfi_dbg_t rvfi_head;
    assign rvfi_head = rvfi_array[head_ptr];
    assign rvfi_itf.order = rvfi_order;
    assign rvfi_itf.inst = rvfi_head.inst;
    assign rvfi_itf.rs1_addr = rvfi_head.rs1_addr;
    assign rvfi_itf.rs2_addr = rvfi_head.rs2_addr;
    assign rvfi_itf.rs1_rdata = rvfi_head.rs1_rdata;
    assign rvfi_itf.rs2_rdata = rvfi_head.rs2_rdata;
    assign rvfi_itf.rd_addr = rvfi_head.rd_addr;
    assign rvfi_itf.rd_wdata = rvfi_head.rd_wdata;
    assign rvfi_itf.frd_addr = rvfi_head.frd_addr;
    assign rvfi_itf.frd_wdata = rvfi_head.frd_wdata;
    assign rvfi_itf.pc_rdata = rvfi_head.pc_rdata;
    assign rvfi_itf.pc_wdata = rvfi_head.pc_rdata + 4;
    assign rvfi_itf.mem_addr = rvfi_head.mem_addr;
    assign rvfi_itf.mem_rmask = rvfi_head.mem_rmask;
    assign rvfi_itf.mem_wmask = rvfi_head.mem_wmask;
    assign rvfi_itf.mem_rdata = rvfi_head.mem_rdata;
    assign rvfi_itf.mem_wdata = rvfi_head.mem_wdata;

endmodule
