module backend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    // Instruction Queue
    fifo_backend_itf.backend    from_fifo,

    // Flush signals
    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc
);

    assign backend_flush = 1'b0;
    assign backend_redirect_pc = 'x;

    id_rat_itf                  id_rat_itf_i();
    id_fl_itf                   id_fl_itf_i();
    id_rob_itf                  id_rob_itf_i();
    id_int_rs_itf               id_int_rs_itf_i();
    rob_rrf_itf                 rob_rrf_itf_i();
    rrf_fl_itf                  rrf_fl_itf_i();
    cdb_itf                     cdb_itfs[CDB_WIDTH]();

    id_stage id_stage_i(
        // .clk                    (clk),
        // .rst                    (rst),

        .from_fifo              (from_fifo),
        .to_rat                 (id_rat_itf_i),
        .to_fl                  (id_fl_itf_i),
        .to_rob                 (id_rob_itf_i),
        .to_int_rs              (id_int_rs_itf_i)
    );

    rat rat_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_id                (id_rat_itf_i),
        .cdb                    (cdb_itfs)
    );

    free_list free_list_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_id                (id_fl_itf_i),
        .from_rrf               (rrf_fl_itf_i)
    );

    rob rob_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_id                (id_rob_itf_i),
        .to_rrf                 (rob_rrf_itf_i),
        .cdb                    (cdb_itfs)
    );

    rrf rrf_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_rob               (rob_rrf_itf_i),
        .to_fl                  (rrf_fl_itf_i)
    );

    int_rs int_rs_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_id                (id_int_rs_itf_i),
        .cdb                    (cdb_itfs),
        .fu_cdb_out             (cdb_itfs[0])
    );

    // Temporary signals for INTM
    assign cdb_itfs[1].valid = 1'b0;
    assign cdb_itfs[1].rob_id = 'x;
    assign cdb_itfs[1].rd_phy = 'x;
    assign cdb_itfs[1].rd_arch = 'x;
    assign cdb_itfs[1].rd_value = 'x;

endmodule
