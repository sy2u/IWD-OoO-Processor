module rob
import cpu_params::*;
import rvfi_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc,
    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH],
    cb_rob_itf.rob              from_cb,
    stq_rob_itf.rob             from_stq,
    ldq_rob_itf.rob             from_ldq
);

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic                   valid;
        logic   [31:0]          rd_value;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } cdb_rob_t;

    typedef struct packed {
        logic                   valid;
        logic                   ready;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
    } rob_entry_t;

    rob_entry_t             rob_arr [ROB_DEPTH] [ID_WIDTH];

    logic   [ROB_PTR_IDX:0]     head_ptr_reg;
    logic   [ROB_PTR_IDX:0]     tail_ptr_reg;

    logic   [ROB_PTR_IDX-1:0]   head_ptr;
    logic                       head_ptr_flag;
    logic   [ROB_PTR_IDX-1:0]   tail_ptr;
    logic                       tail_ptr_flag;

    logic                   full;
    logic                   empty;
    logic                   pop;
    logic   [ID_WIDTH-1:0]  commit_instr;

    cdb_rob_t               cdb_rob [CDB_WIDTH];

    logic                   dequeue;
    rvfi_dbg_t              rvfi_itf    [ID_WIDTH];
    rvfi_dbg_t              rvfi_array  [ROB_DEPTH] [ID_WIDTH];
    logic   [63:0]          rvfi_order;
    logic   [63:0]          commit_instrs;

    // same logic with fifo queue
    assign {head_ptr_flag, head_ptr} = head_ptr_reg;
    assign {tail_ptr_flag, tail_ptr} = tail_ptr_reg;

    assign from_stq.rob_head = head_ptr;

    assign full = (tail_ptr == head_ptr) && (tail_ptr_flag != head_ptr_flag);
    assign empty = (tail_ptr == head_ptr) && (tail_ptr_flag == head_ptr_flag);

    always_comb begin
        if (empty) begin
            pop = 1'b0;
        end else begin
            pop = 1'b1;
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (rob_arr[head_ptr][i].valid && ~rob_arr[head_ptr][i].ready) begin
                    pop = 1'b0;
                end
            end
        end
    end

    // create local CDB interface instances
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin : cdb_assign
        assign cdb_rob[k].rob_id = cdb[k].rob_id;
        assign cdb_rob[k].valid = cdb[k].valid;
        assign cdb_rob[k].rd_value = cdb[k].rd_value;
        assign cdb_rob[k].rs1_value_dbg = cdb[k].rs1_value_dbg;
        assign cdb_rob[k].rs2_value_dbg = cdb[k].rs2_value_dbg;
    end endgenerate

    always_ff @(posedge clk) begin
        if (rst || backend_flush) begin
            for (int i = 0; i < ROB_DEPTH; i++) begin
                for (int j = 0; j < ID_WIDTH; j++) begin
                    rob_arr[i][j].valid <= 1'b0;
                    rob_arr[i][j].ready <= 1'b0;
                end
            end
            head_ptr_reg <= '0;
            tail_ptr_reg <= '0;
        end else begin
            if (from_id.valid && from_id.ready) begin           // push in
                tail_ptr_reg <= (ROB_PTR_IDX+1)'(tail_ptr_reg + 1);
                for (int i = 0; i< ID_WIDTH; i++) begin
                    rob_arr[tail_ptr][i].valid <= from_id.inst_valid[i];
                    rob_arr[tail_ptr][i].ready <= 1'b0;
                    rob_arr[tail_ptr][i].rd_phy <= from_id.rd_phy[i];
                    rob_arr[tail_ptr][i].rd_arch <= from_id.rd_arch[i];
                    rvfi_array[tail_ptr][i] <= from_id.rvfi_dbg[i];       // for rvfi storage
                end
            end

            if (pop) begin                              // pop out
                head_ptr_reg <= (ROB_PTR_IDX+1)'(head_ptr_reg +1);
            end

            for (int i = 0; i < CDB_WIDTH; i++) begin   // snoop CDB
                if (cdb_rob[i].valid) begin
                    rob_arr   [cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].ready <= 1'b1;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rd_wdata <= cdb_rob[i].rd_value;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rs1_rdata <= cdb_rob[i].rs1_value_dbg;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rs2_rdata <= cdb_rob[i].rs2_value_dbg;
                end
            end

            if (from_stq.valid) begin
                rob_arr   [from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].ready <= 1'b1;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].rs1_rdata <= from_stq.rs1_value_dbg;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].rs2_rdata <= from_stq.rs2_value_dbg;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].mem_addr <= from_stq.addr_dbg;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].mem_rmask <= '0;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].mem_wmask <= from_stq.wmask_dbg;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].mem_rdata <= '0;
                rvfi_array[from_stq.rob_id / ID_WIDTH][from_stq.rob_id % ID_WIDTH].mem_wdata <= from_stq.wdata_dbg;
            end

            if (from_ldq.valid) begin
                rvfi_array[from_ldq.rob_id / ID_WIDTH][from_ldq.rob_id % ID_WIDTH].mem_addr <= from_ldq.addr_dbg;
                rvfi_array[from_ldq.rob_id / ID_WIDTH][from_ldq.rob_id % ID_WIDTH].mem_rmask <= from_ldq.rmask_dbg;
                rvfi_array[from_ldq.rob_id / ID_WIDTH][from_ldq.rob_id % ID_WIDTH].mem_wmask <= '0;
                rvfi_array[from_ldq.rob_id / ID_WIDTH][from_ldq.rob_id % ID_WIDTH].mem_rdata <= from_ldq.rdata_dbg;
                rvfi_array[from_ldq.rob_id / ID_WIDTH][from_ldq.rob_id % ID_WIDTH].mem_wdata <= '0;
            end
        end
    end

    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            commit_instr[i] = pop && rob_arr[head_ptr][i].valid;
        end
    end

    // interface with dispatch:: input: phys_reg, arch_reg; output: rob_id
    assign from_id.ready = ~full;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_id.rob_id[i] = (ROB_IDX)'(tail_ptr * ID_WIDTH + i);
    end endgenerate

    // interface with rrf:: output: phys_reg, arch_reg
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rrf.valid[i] = commit_instr[i];
        assign to_rrf.rd_phy[i] = rob_arr[head_ptr][i].rd_phy;
        assign to_rrf.rd_arch[i] = rob_arr[head_ptr][i].rd_arch;
    end endgenerate

    // interface with control_buffer
    assign dequeue = from_cb.ready ? pop && ((ROB_PTR_IDX)'(from_cb.rob_id / ID_WIDTH) == head_ptr) : 1'b0;
    assign from_cb.dequeue = dequeue;
    assign backend_flush = dequeue && from_cb.miss_predict;
    assign backend_redirect_pc = from_cb.target_address;

    //////////////////////////
    //          RVFI        //
    //////////////////////////

    rvfi_dbg_t rvfi_head[ID_WIDTH];
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign rvfi_head[i] = rvfi_array[head_ptr][i];
        assign rvfi_itf[i].commit = commit_instr[i];
        assign rvfi_itf[i].inst = rvfi_head[i].inst;
        assign rvfi_itf[i].rs1_addr = rvfi_head[i].rs1_addr;
        assign rvfi_itf[i].rs2_addr = rvfi_head[i].rs2_addr;
        assign rvfi_itf[i].rs1_rdata = rvfi_head[i].rs1_rdata;
        assign rvfi_itf[i].rs2_rdata = rvfi_head[i].rs2_rdata;
        assign rvfi_itf[i].rd_addr = rvfi_head[i].rd_addr;
        assign rvfi_itf[i].rd_wdata = rvfi_head[i].rd_wdata;
        assign rvfi_itf[i].frd_addr = rvfi_head[i].frd_addr;
        assign rvfi_itf[i].frd_wdata = rvfi_head[i].frd_wdata;
        assign rvfi_itf[i].pc_rdata = rvfi_head[i].pc_rdata;
        assign rvfi_itf[i].pc_wdata = (backend_flush && 32'(from_cb.rob_id % ID_WIDTH) == i) ? backend_redirect_pc : rvfi_head[i].pc_wdata;
        assign rvfi_itf[i].mem_addr = rvfi_head[i].mem_addr;
        assign rvfi_itf[i].mem_rmask = rvfi_head[i].mem_rmask;
        assign rvfi_itf[i].mem_wmask = rvfi_head[i].mem_wmask;
        assign rvfi_itf[i].mem_rdata = rvfi_head[i].mem_rdata;
        assign rvfi_itf[i].mem_wdata = rvfi_head[i].mem_wdata;
    end endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin 
            rvfi_order <= 64'h0;
        end else if (pop) begin 
            rvfi_order <= rvfi_order + commit_instrs;
        end
    end

    always_comb begin
        commit_instrs = '0;
        for (int i = 0; i < ID_WIDTH; i++) begin
            rvfi_itf[i].order = rvfi_order + commit_instrs;
            if (commit_instr[i]) begin
                commit_instrs = commit_instrs + 1;
            end
        end
    end

endmodule
