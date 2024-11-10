module mem_rs
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
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
    // rs array, store uop+available
    uop_t rs_array      [INTRS_DEPTH];
    logic rs_valid      [INTRS_DEPTH];

    // push logic
    logic                 int_rs_push_en;
    logic [INTRS_IDX-1:0] int_rs_push_idx;

    // issue logic
    logic                 int_rs_issue_en;
    logic [INTRS_IDX-1:0] int_rs_issue_idx;
    logic                 src2_valid;

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                rs_valid[i] <= 1'b1;
            end
        end else begin 
            // issue > snoop cdb > push
            // push renamed instruction
            if (int_rs_push_en) begin 
                // set rs to unavailable
                rs_valid[int_rs_push_idx]   <= 1'b0;
                rs_array[int_rs_push_idx]   <= from_ds.uop;
            end

            // snoop CDB to update rs1 valid
            for (int i = 0; i < INTRS_DEPTH; i++) begin
                for (int k = 0; k < CDB_WIDTH; k++) begin
                    if (cdb_rs[k].valid && rs_valid[i]) begin 
                        if (rs_array[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                            rs_array[i].rs1_valid <= 1'b1;
                        end
                    end
                end 
            end

            // pop issued instruction
            if (int_rs_issue_en) begin 
                // set rs to available
                rs_valid[int_rs_issue_idx] <= 1'b1;
            end
        end
    end

    // push logic, push instruction to rs if id is valid and rs is ready
    // loop from top until the first available station
    always_comb begin
        int_rs_push_en  = '0;
        int_rs_push_idx = '0;
        if (from_ds.valid && from_ds.ready) begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                if (!rs_valid[(INTRS_IDX)'(unsigned'(i))]) begin 
                    int_rs_push_idx = (INTRS_IDX)'(unsigned'(i));
                    int_rs_push_en = 1'b1;
                    break;
                end
            end
        end
    end

    // issue enable logic
    // loop from top until src all valid
    logic                 src_valid;

    always_comb begin
        int_rs_issue_en  = '0;
        int_rs_issue_idx = '0; 
        src_valid       = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (rs_valid[(INTRS_IDX)'(unsigned'(i))]) begin 
                src_valid = rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_valid;
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                        src_valid = 1'b1;
                    end
                end

                if (src_valid) begin 
                    int_rs_issue_en = '1;
                    int_rs_issue_idx = (INTRS_IDX)'(unsigned'(i));
                    break;
                end
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    always_comb begin 
        from_ds.ready = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (!rs_valid[i]) begin 
                from_ds.ready = '1;
                break;
            end
        end
    end

    // communicate with prf
    assign to_prf.rs1_phy = rs_array[int_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = rs_array[int_rs_issue_idx].rs2_phy;

    ///////////////////////
    // INT_MEM to FU_AGU //
    ///////////////////////
    logic           fu_agu_valid;
    agu_reg_t       agu_reg_in;
    agu_lsq_t       agu_lsq;

    fu_agu fu_agu_i(
        .clk(clk),
        .rst(rst),

        .prv_valid  (int_rs_issue_en),
        .prv_ready  (),
        .agu_reg_in (agu_reg_in),

        .nxt_valid  (fu_agu_valid),
        .to_lsq     (agu_lsq)
    );

    pipeline_reg #(
        .DATA_T    (agu_lsq_t)
    ) agu_lsq_reg_i (
        .clk        (clk),
        .rst        (rst),
        .flush      ('0),

        .prv_valid  (fu_agu_valid),
        .prv_ready  (),
        .prv_data   (agu_lsq),

        .nxt_valid  (to_lsq.valid),
        .nxt_ready  ('1),
        .nxt_data   (to_lsq.data)
    );

endmodule
