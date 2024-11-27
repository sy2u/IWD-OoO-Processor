module load_queue
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,

    ds_rs_mono_itf.rs           from_ds,
    agu_lsq_itf.lsq             from_agu,
    cdb_itf.fu                  cdb_out,
    ldq_rob_itf.ldq             to_rob,
    ldq_dmem_itf.ldq            dmem,
    ldq_stq_itf.ldq             from_stq
);
    ldq_entry_t             ldq_arr     [LDQ_DEPTH];
    ldq_entry_t             ldq_arr_nxt [LDQ_DEPTH];

    logic                   push_en;
    logic   [LDQ_IDX-1:0]   push_idx;

    logic                   issue_en;
    logic   [LDQ_IDX-1:0]   issue_idx;

    always_ff @(posedge clk) begin
        if (rst || backend_flush) begin
            for (int i = 0; i < LDQ_DEPTH; i++) begin 
                ldq_arr[i].valid <= 1'b0;
            end
        end else begin
            for (int i = 0; i < LDQ_DEPTH; i++) begin
                ldq_arr[i] <= ldq_arr_nxt[i];
            end
        end
    end

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            ldq_arr_nxt[i] = ldq_arr[i];
        end

        if (from_stq.stq_deq) begin
            for (int i = 0; i < LDQ_DEPTH; i++) begin
                ldq_arr_nxt[push_idx].track_stq_ptr = (ldq_arr[push_idx].track_stq_ptr == '0) ? '0 :
                                                      (ldq_arr[push_idx].track_stq_ptr - 1);
            end
        end

        if (push_en) begin
            ldq_arr_nxt[push_idx].valid         = 1'b1;
            ldq_arr_nxt[push_idx].addr_valid    = 1'b0;
            ldq_arr_nxt[push_idx].track_stq_ptr = (from_stq.stq_deq) ? (from_stq.stq_tail - 1) : from_stq.stq_tail;
            ldq_arr_nxt[push_idx].rob_id        = from_ds.uop.rob_id;
            ldq_arr_nxt[push_idx].fu_opcode     = from_ds.uop.fu_opcode;
            ldq_arr_nxt[push_idx].rd_arch       = from_ds.uop.rd_arch;
            ldq_arr_nxt[push_idx].rd_phy        = from_ds.uop.rd_phy;
        end

        if (from_agu.valid) begin
            for (int i = 0; i < LDQ_DEPTH; i++) begin
                if (ldq_arr[i].rob_id == from_agu.data.rob_id) begin
                    ldq_arr_nxt[i].addr_valid    = 1'b1;
                    ldq_arr_nxt[i].addr          = from_agu.data.addr;
                    ldq_arr_nxt[i].mask          = from_agu.data.mask;
                    ldq_arr_nxt[i].rs1_value_dbg = from_agu.data.rs1_value_dbg;
                    ldq_arr_nxt[i].rs2_value_dbg = from_agu.data.rs2_value_dbg;
                end
            end
        end

        if (issue_en && dmem.ready) begin
            ldq_arr_nxt[issue_idx].valid = 1'b0;
        end
    end

    ////////////////
    // Push Logic //
    ////////////////

    always_comb begin
        push_en  = '0;
        push_idx = '0;
        if (from_ds.valid && from_ds.ready && ~from_ds.uop.fu_opcode[3]) begin
            for (int i = 0; i < LDQ_DEPTH; i++) begin
                if (~ldq_arr[(LDQ_IDX)'(unsigned'(i))].valid) begin
                    push_en = 1'b1;
                    push_idx = (LDQ_IDX)'(unsigned'(i));
                    break;
                end
            end
        end
    end

    always_comb begin
        from_ds.ready = '0;
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            if (~ldq_arr[i].valid) begin 
                from_ds.ready = '1;
                break;
            end
        end
    end

    /////////////////
    // Issue Logic //
    /////////////////

    always_comb begin
        issue_en  = '0;
        issue_idx = '0;
        for (int unsigned i = 0; i < LDQ_DEPTH; i++) begin
            if (ldq_arr[i].valid && ldq_arr[i].addr_valid && ldq_arr[push_idx].track_stq_ptr == '0) begin
                issue_en = 1'b1;
                issue_idx = (LDQ_IDX)'(i);
                break;
            end
        end
    end

    /////////////////////////
    // DCache Access Logic //
    /////////////////////////

    assign dmem.valid = issue_en && ~backend_flush;

    load_stage_reg_t        load_stage_reg;

    always_ff @(posedge clk) begin
        if (dmem.valid && dmem.ready) begin
            load_stage_reg.rob_id        <= ldq_arr[issue_idx].rob_id;
            load_stage_reg.addr_2        <= ldq_arr[issue_idx].addr[1:0];
            load_stage_reg.rd_arch       <= ldq_arr[issue_idx].rd_arch;
            load_stage_reg.rd_phy        <= ldq_arr[issue_idx].rd_phy;
            load_stage_reg.addr_dbg      <= dmem.addr;
            load_stage_reg.mask_dbg      <= ldq_arr[issue_idx].mask;
            load_stage_reg.rs1_value_dbg <= ldq_arr[issue_idx].rs1_value_dbg;
            load_stage_reg.rs2_value_dbg <= ldq_arr[issue_idx].rs2_value_dbg;
        end
    end

    assign dmem.rmask = ldq_arr[issue_idx].mask;
    assign dmem.addr =  {ldq_arr[issue_idx].addr[31:2], 2'b00};

    logic   [1:0]           addr_2;
    assign addr_2 = load_stage_reg.addr_2;

    logic   [31:0]  dmem_rdata_wb;
    always_comb begin
        unique case (ldq_arr[issue_idx].fu_opcode)
            MEM_LB : dmem_rdata_wb = {{24{dmem.rdata[7 +8 *addr_2[1:0]]}}, dmem.rdata[8 *addr_2[1:0] +: 8 ]};
            MEM_LBU: dmem_rdata_wb = {{24{1'b0}}                         , dmem.rdata[8 *addr_2[1:0] +: 8 ]};
            MEM_LH : dmem_rdata_wb = {{16{dmem.rdata[15+16*addr_2[1]  ]}}, dmem.rdata[16*addr_2[1]   +: 16]};
            MEM_LHU: dmem_rdata_wb = {{16{1'b0}}                         , dmem.rdata[16*addr_2[1]   +: 16]};
            MEM_LW : dmem_rdata_wb = dmem.rdata;
            default: dmem_rdata_wb = 'x;
        endcase
    end

    ////////////////
    // CDB Output //
    ////////////////

    assign cdb_out.valid         = dmem.resp;
    assign cdb_out.rob_id        = load_stage_reg.rob_id;
    assign cdb_out.rd_phy        = load_stage_reg.rd_phy;
    assign cdb_out.rd_arch       = load_stage_reg.rd_arch;
    assign cdb_out.rd_value      = dmem_rdata_wb;
    assign cdb_out.rs1_value_dbg = load_stage_reg.rs1_value_dbg;
    assign cdb_out.rs2_value_dbg = load_stage_reg.rs2_value_dbg;

    assign to_rob.valid     = dmem.resp;
    assign to_rob.rob_id    = load_stage_reg.rob_id;
    assign to_rob.addr_dbg  = load_stage_reg.addr_dbg;
    assign to_rob.rmask_dbg = load_stage_reg.mask_dbg;
    assign to_rob.rdata_dbg = dmem.rdata;

endmodule
