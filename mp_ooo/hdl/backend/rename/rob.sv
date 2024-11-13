module rob
import cpu_params::*;
import rvfi_types::*;
(
    input   logic               clk,
    input   logic               rst,

    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH],
    ls_cdb_itf.rob              ls_cdb_dbg
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

    rvfi_dbg_t              rvfi_itf    [ID_WIDTH];
    rvfi_dbg_t              rvfi_array  [ROB_DEPTH] [ID_WIDTH];
    logic   [63:0]          rvfi_order;
    logic   [63:0]          valid_instrs;

    // same logic with fifo queue
    assign {head_ptr_flag, head_ptr} = head_ptr_reg;
    assign {tail_ptr_flag, tail_ptr} = tail_ptr_reg;

    // assign tail_ptr_next = tail_ptr_reg + ROB_IDX'(1);
    assign full = (tail_ptr == head_ptr) && (tail_ptr_flag != head_ptr_flag);
    assign empty = (tail_ptr == head_ptr) && (tail_ptr_flag == head_ptr_flag);

    always_comb begin
        if (empty) begin
            pop = 1'b0;
        end else begin
            pop = 1'b1;
            for (int i = 0; i < ID_WIDTH; i++) begin
                pop = pop && (rob_arr[head_ptr][i].ready || ~rob_arr[head_ptr][i].valid);
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
        if (rst) begin
            for (int i = 0; i < ROB_DEPTH; i++) begin
                for (int j = 0; j < ID_WIDTH; j++) begin
                    rob_arr[i][j].ready <= 1'b0;
                end
            end
            head_ptr_reg <= '0;
            tail_ptr_reg <= '0;
            rvfi_order <= 64'h0;
        end else begin
            if (from_id.valid && from_id.ready) begin           // push in
                tail_ptr_reg <= (ROB_IDX+1)'(tail_ptr_reg + 1);
                for (int i = 0; i< ID_WIDTH; i++) begin
                    rob_arr[tail_ptr][i].valid <= from_id.inst_valid[i];
                    rob_arr[tail_ptr][i].ready <= 1'b0;
                    rob_arr[tail_ptr][i].rd_phy <= from_id.rd_phy[i];
                    rob_arr[tail_ptr][i].rd_arch <= from_id.rd_arch[i];
                    rvfi_array[tail_ptr][i] <= from_id.rvfi_dbg[i];       // for rvfi storage
                end
            end

            if (pop) begin                              // pop out
                head_ptr_reg <= (ROB_IDX+1)'(head_ptr_reg +1);
                rvfi_order <= rvfi_order + valid_instrs;
            end

            for (int i = 0; i < CDB_WIDTH; i++) begin   // snoop CDB
                if (cdb_rob[i].valid) begin
                    rob_arr[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].ready <= 1'b1;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rd_wdata <= cdb_rob[i].rd_value;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rs1_rdata <= cdb_rob[i].rs1_value_dbg;
                    rvfi_array[cdb_rob[i].rob_id / ID_WIDTH][cdb_rob[i].rob_id % ID_WIDTH].rs2_rdata <= cdb_rob[i].rs2_value_dbg;
                end
            end

            if (ls_cdb_dbg.valid) begin
                rvfi_array[ls_cdb_dbg.rob_id / ID_WIDTH][ls_cdb_dbg.rob_id % ID_WIDTH].mem_addr <= ls_cdb_dbg.addr_dbg;
                rvfi_array[ls_cdb_dbg.rob_id / ID_WIDTH][ls_cdb_dbg.rob_id % ID_WIDTH].mem_rmask <= ls_cdb_dbg.rmask_dbg;
                rvfi_array[ls_cdb_dbg.rob_id / ID_WIDTH][ls_cdb_dbg.rob_id % ID_WIDTH].mem_wmask <= ls_cdb_dbg.wmask_dbg;
                rvfi_array[ls_cdb_dbg.rob_id / ID_WIDTH][ls_cdb_dbg.rob_id % ID_WIDTH].mem_rdata <= ls_cdb_dbg.rdata_dbg;
                rvfi_array[ls_cdb_dbg.rob_id / ID_WIDTH][ls_cdb_dbg.rob_id % ID_WIDTH].mem_wdata <= ls_cdb_dbg.wdata_dbg;
            end
        end
    end

    // interface with dispatch:: input: phys_reg, arch_reg; output: rob_id
    assign from_id.ready = ~full;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_id.rob_id[i] = (ROB_IDX)'(tail_ptr * ID_WIDTH + i);
    end endgenerate

    // interface with rrf:: output: phys_reg, arch_reg
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rrf.valid[i] = pop && rob_arr[head_ptr][i].valid;
        assign to_rrf.rd_phy[i] = rob_arr[head_ptr][i].rd_phy;
        assign to_rrf.rd_arch[i] = rob_arr[head_ptr][i].rd_arch;
    end endgenerate

    //////////////////////////
    //          RVFI        //
    //////////////////////////

    rvfi_dbg_t rvfi_head[ID_WIDTH];
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign rvfi_head[i] = rvfi_array[head_ptr][i];
        assign rvfi_itf[i].commit = pop && rob_arr[head_ptr][i].valid;
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
        assign rvfi_itf[i].pc_wdata = rvfi_head[i].pc_rdata + 4;
        assign rvfi_itf[i].mem_addr = rvfi_head[i].mem_addr;
        assign rvfi_itf[i].mem_rmask = rvfi_head[i].mem_rmask;
        assign rvfi_itf[i].mem_wmask = rvfi_head[i].mem_wmask;
        assign rvfi_itf[i].mem_rdata = rvfi_head[i].mem_rdata;
        assign rvfi_itf[i].mem_wdata = rvfi_head[i].mem_wdata;
    end endgenerate

    always_comb begin
        valid_instrs = '0;
        for (int i = 0; i < ID_WIDTH; i++) begin
            rvfi_itf[i].order = rvfi_order + valid_instrs;
            if (rob_arr[head_ptr][i].valid) begin
                valid_instrs = valid_instrs + 1;
            end
        end
    end

endmodule
