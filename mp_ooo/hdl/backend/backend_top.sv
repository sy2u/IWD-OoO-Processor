module backend_top
import cpu_params::*;
import uop_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // Instruction Queue
    fifo_backend_itf.backend    from_fifo,
    cacheline_itf.master        dcache_itf,

    // Flush signals
    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc,

    // control buffer to branch predictor
    cb_bp_itf.cb                to_bp

);
    id_rat_itf                  id_rat_itf_i();
    id_fl_itf                   id_fl_itf_i();
    id_rob_itf                  id_rob_itf_i();
    ds_rs_itf                   ds_int_rs_itf_i();
    ds_rs_itf                   ds_intm_rs_itf_i();
    ds_rs_mono_itf              ds_branch_itf_i();
    ds_rs_mono_itf              ds_lsu_itf_i();
    rob_rrf_itf                 rob_rrf_itf_i();
    rrf_fl_itf                  rrf_fl_itf_i();
    cdb_itf                     cdb_itfs[CDB_WIDTH]();
    cb_rob_itf                  cb_rob_itf_i();
    ldq_rob_itf                 ldq_rob_itf();
    stq_rob_itf                 stq_rob_itf();
    rs_prf_itf                  rs_prf_itfs[CDB_WIDTH]();

    logic                       dispatch_valid;
    logic                       dispatch_ready;
    logic                       uops_valid[ID_WIDTH];
    logic   [1:0]               rs_type[ID_WIDTH];
    uop_t                       uops[ID_WIDTH];

    logic   [PRF_IDX-1:0]       rrf_mem[ARF_DEPTH];

    id_stage id_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .nxt_valid              (dispatch_valid),
        .nxt_ready              (dispatch_ready),
        .uops_valid             (uops_valid),
        .rs_type                (rs_type),
        .uops                   (uops),

        .from_fifo              (from_fifo),
        .to_rat                 (id_rat_itf_i),
        .to_fl                  (id_fl_itf_i),
        .to_rob                 (id_rob_itf_i)
    );

    rat rat_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .rrf_mem                (rrf_mem),

        .from_id                (id_rat_itf_i),
        .cdb                    (cdb_itfs)
    );

    free_list free_list_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .from_id                (id_fl_itf_i),
        .from_rrf               (rrf_fl_itf_i)
    );

    rob rob_i(
        .clk                    (clk),
        .rst                    (rst),

        .backend_flush          (backend_flush),
        .backend_redirect_pc    (backend_redirect_pc),
        .from_id                (id_rob_itf_i),
        .to_rrf                 (rob_rrf_itf_i),
        .cdb                    (cdb_itfs),
        .from_cb                (cb_rob_itf_i),
        .from_stq               (stq_rob_itf),
        .from_ldq               (ldq_rob_itf)
    );

    rrf rrf_i(
        .clk                    (clk),
        .rst                    (rst),

        .rrf_mem                (rrf_mem),

        .from_rob               (rob_rrf_itf_i),
        .to_fl                  (rrf_fl_itf_i)
    );

    ds_stage ds_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .prv_valid              (dispatch_valid),
        .prv_ready              (dispatch_ready),
        .uops_valid             (uops_valid),
        .rs_type                (rs_type),
        .uops                   (uops),

        .to_int_rs              (ds_int_rs_itf_i),
        .to_intm_rs             (ds_intm_rs_itf_i),
        .to_br_rs               (ds_branch_itf_i),
        .to_mem_rs              (ds_lsu_itf_i)
    );

    // merge to_prf and cdb_out for dual issue
    parameter int subset_indices[INT_ISSUE_WIDTH] = '{0, 4};
    rs_prf_itf int_to_prf       [INT_ISSUE_WIDTH] ();
    cdb_itf int_fu_cdb_out      [INT_ISSUE_WIDTH] (); 
    generate
        for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin
            assign rs_prf_itfs[subset_indices[i]].rs1_phy   =   int_to_prf[i].rs1_phy;
            assign rs_prf_itfs[subset_indices[i]].rs2_phy   =   int_to_prf[i].rs2_phy;
            assign int_to_prf[i].rs1_value  =   rs_prf_itfs[subset_indices[i]].rs1_value;
            assign int_to_prf[i].rs2_value  =   rs_prf_itfs[subset_indices[i]].rs2_value;
            assign cdb_itfs[subset_indices[i]].rob_id        = int_fu_cdb_out[i].rob_id;
            assign cdb_itfs[subset_indices[i]].rd_phy        = int_fu_cdb_out[i].rd_phy;
            assign cdb_itfs[subset_indices[i]].rd_arch       = int_fu_cdb_out[i].rd_arch;
            assign cdb_itfs[subset_indices[i]].rd_value      = int_fu_cdb_out[i].rd_value;
            assign cdb_itfs[subset_indices[i]].valid         = int_fu_cdb_out[i].valid;
            assign cdb_itfs[subset_indices[i]].rs1_value_dbg = int_fu_cdb_out[i].rs1_value_dbg;
            assign cdb_itfs[subset_indices[i]].rs2_value_dbg = int_fu_cdb_out[i].rs2_value_dbg;
        end
    endgenerate

    generate
        if( INT_RS_TYPE == 1 ) begin
            int_rs_ordered int_rs_i(
                .clk                    (clk),
                .rst                    (rst || backend_flush),
                .from_ds                (ds_int_rs_itf_i),
                .to_prf                 (int_to_prf),
                .cdb                    (cdb_itfs),
                .fu_cdb_out             (int_fu_cdb_out)
            );
        end else begin
            int_rs_normal int_rs_i(
                .clk                    (clk),
                .rst                    (rst || backend_flush),
                .from_ds                (ds_int_rs_itf_i),
                .to_prf                 (rs_prf_itfs[0]),
                .cdb                    (cdb_itfs),
                .fu_cdb_out             (cdb_itfs[0])
            );
        end
    endgenerate

    generate
        if ( INTM_RS_TYPE == 1 ) begin
            intm_rs_ordered intm_rs_i(
                .clk                    (clk),
                .rst                    (rst || backend_flush),
                .from_ds                (ds_intm_rs_itf_i),
                .to_prf                 (rs_prf_itfs[1]),
                .cdb                    (cdb_itfs),
                .fu_cdb_out             (cdb_itfs[1])
            );
        end else begin
            intm_rs_normal intm_rs_i(
                .clk                    (clk),
                .rst                    (rst || backend_flush),
                .from_ds                (ds_intm_rs_itf_i),
                .to_prf                 (rs_prf_itfs[1]),
                .cdb                    (cdb_itfs),
                .fu_cdb_out             (cdb_itfs[1])
            );
        end
    endgenerate

    branch_top branch_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .from_ds                (ds_branch_itf_i),
        .to_prf                 (rs_prf_itfs[2]),
        .cdb                    (cdb_itfs),
        .fu_cdb_out             (cdb_itfs[2]),
        .to_rob                 (cb_rob_itf_i),
        .to_bp                  (to_bp)
    );

    lsu_top lsu_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_ds                (ds_lsu_itf_i),
        .to_prf                 (rs_prf_itfs[3]),
        .cdb                    (cdb_itfs),
        .fu_cdb_out             (cdb_itfs[3]),
        .ld_to_rob              (ldq_rob_itf),
        .st_to_rob              (stq_rob_itf),
        .dcache_itf             (dcache_itf),

        .backend_flush          (backend_flush)
    );

    prf prf_i(
        .clk                    (clk),

        .from_rs                (rs_prf_itfs),
        .cdb                    (cdb_itfs)
    );

endmodule
