module mem_rs
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    agu_lsq_itf.agu             to_lsq
);
    ///////////////////////////
    // Reservation Stations  //
    ///////////////////////////

    // local copy of cdb
    cdb_rs_t cdb_rs[CDB_WIDTH];
    generate 
        for (genvar i = 0; i < CDB_WIDTH; i++) begin 
            assign cdb_rs[i].valid  = cdb[i].valid;
            assign cdb_rs[i].rd_phy = cdb[i].rd_phy;
        end
    endgenerate

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [31:0]          imm;
        logic   [3:0]           fu_opcode;
    } mem_rs_entry_t;

    // rs array, store uop+valid
    mem_rs_entry_t  mem_rs_arr    [MEMRS_DEPTH];
    logic           mem_rs_valid  [MEMRS_DEPTH];

    // push logic
    logic                 push_en;
    logic [MEMRS_IDX-1:0] push_idx;

    // issue logic
    logic                 issue_en;
    logic [MEMRS_IDX-1:0] issue_idx;

    // logic   push_or_issue_or_cdb;
    // logic   cdb_valid_exist;
    // assign push_or_issue_or_cdb = push_en || issue_en || cdb_valid_exist;
    // always_comb begin
    //     cdb_valid_exist = 1'b0;
    //     for (int i = 0; i < CDB_WIDTH; i++) begin
    //         if (cdb_rs[i].valid) begin
    //             cdb_valid_exist = 1'b1;
    //             break;
    //         end
    //     end
    // end

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            for (int i = 0; i < MEMRS_DEPTH; i++) begin 
                mem_rs_valid[i] <= 1'b0;
            end
        end else begin 
        // end else if (push_or_issue_or_cdb) begin 
            // issue > snoop cdb > push
            // push renamed instruction
            if (push_en) begin 
                // set rs to unavailable
                mem_rs_valid[push_idx]  <= 1'b1;
                mem_rs_arr[push_idx].rob_id    <= from_ds.uop.rob_id;
                mem_rs_arr[push_idx].rs1_phy   <= from_ds.uop.rs1_phy;
                mem_rs_arr[push_idx].rs1_valid <= from_ds.uop.rs1_valid;
                mem_rs_arr[push_idx].rs2_phy   <= from_ds.uop.rs2_phy;
                mem_rs_arr[push_idx].rs2_valid <= from_ds.uop.rs2_valid;
                mem_rs_arr[push_idx].imm       <= from_ds.uop.imm;
                mem_rs_arr[push_idx].fu_opcode <= from_ds.uop.fu_opcode;
            end

            // snoop CDB to update rs1 valid
            for (int i = 0; i < MEMRS_DEPTH; i++) begin
                for (int k = 0; k < CDB_WIDTH; k++) begin
                    if (cdb_rs[k].valid && mem_rs_valid[i]) begin 
                        if (mem_rs_arr[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                            mem_rs_arr[i].rs1_valid <= 1'b1;
                        end
                        if (mem_rs_arr[i].rs2_phy == cdb_rs[k].rd_phy) begin 
                            mem_rs_arr[i].rs2_valid <= 1'b1;
                        end
                    end
                end 
            end

            // pop issued instruction
            if (issue_en) begin 
                // set rs to available
                mem_rs_valid[issue_idx] <= 1'b0;
            end
        end
    end

    // push logic, push instruction to rs if id is valid and rs is ready
    // loop from top until the first available station
    always_comb begin
        push_en  = '0;
        push_idx = '0;
        if (from_ds.valid && from_ds.ready) begin 
            for (int i = 0; i < MEMRS_DEPTH; i++) begin 
                if (!mem_rs_valid[(MEMRS_IDX)'(unsigned'(i))]) begin 
                    push_idx = (MEMRS_IDX)'(unsigned'(i));
                    push_en = 1'b1;
                    break;
                end
            end
        end
    end

    // issue enable logic
    // loop from top until src all valid
    logic                 src1_valid;
    logic                 src2_valid;

    always_comb begin
        issue_en  = '0;
        issue_idx = '0;
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; i < MEMRS_DEPTH; i++) begin 
            if (mem_rs_valid[(MEMRS_IDX)'(unsigned'(i))]) begin
                src1_valid = mem_rs_arr[(MEMRS_IDX)'(unsigned'(i))].rs1_valid;
                src2_valid = mem_rs_arr[(MEMRS_IDX)'(unsigned'(i))].rs2_valid;
                for (int k = 0; k < CDB_WIDTH; k++) begin
                    // if (RS_CDB_BYPASS[3][k]) begin
                        if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == mem_rs_arr[(MEMRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                            src1_valid = 1'b1;
                        end
                        if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == mem_rs_arr[(MEMRS_IDX)'(unsigned'(i))].rs2_phy)) begin 
                            src2_valid = 1'b1;
                        end
                    // end
                end

                if (src1_valid && src2_valid) begin 
                    issue_en = '1;
                    issue_idx = (MEMRS_IDX)'(unsigned'(i));
                    break;
                end
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    always_comb begin 
        from_ds.ready = '0;
        for (int i = 0; i < MEMRS_DEPTH; i++) begin 
            if (!mem_rs_valid[i]) begin 
                from_ds.ready = '1;
                break;
            end
        end
    end

    // communicate with prf
    assign to_prf.rs1_phy = mem_rs_arr[issue_idx].rs1_phy;
    assign to_prf.rs2_phy = mem_rs_arr[issue_idx].rs2_phy;

    ///////////////////////
    // INT_MEM to FU_AGU //
    ///////////////////////
    logic           fu_agu_valid;
    agu_reg_t       agu_reg_in;
    agu_lsq_t       agu_lsq;

    assign agu_reg_in.rob_id = mem_rs_arr[issue_idx].rob_id;
    assign agu_reg_in.fu_opcode = mem_rs_arr[issue_idx].fu_opcode;
    assign agu_reg_in.imm = mem_rs_arr[issue_idx].imm;
    assign agu_reg_in.rs1_value = to_prf.rs1_value;
    assign agu_reg_in.rs2_value = to_prf.rs2_value;

    fu_agu fu_agu_i(
        .clk(clk),
        .rst(rst),

        .prv_valid  (issue_en),
        .prv_ready  (),
        .agu_reg_in (agu_reg_in),

        .nxt_valid  (to_lsq.valid),
        .to_lsq     (to_lsq.data)
    );

endmodule
