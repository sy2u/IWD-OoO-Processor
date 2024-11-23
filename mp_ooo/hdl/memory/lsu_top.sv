module lsu_top
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    ls_rob_itf.lsu              fu_cdb_out_dbg,
    cacheline_itf.master        dcache_itf,

    // Flush signals
    input   logic               backend_flush
);

    // Distribute signal from dispatch to RS and LSQ
    ds_rs_mono_itf              ds_mem_rs_i();
    ds_rs_mono_itf              ds_lsq_i();
    assign ds_mem_rs_i.valid = from_ds.valid;
    assign ds_mem_rs_i.uop   = from_ds.uop;
    assign ds_lsq_i.valid    = from_ds.valid;
    assign ds_lsq_i.uop      = from_ds.uop;
    assign from_ds.ready     = ds_mem_rs_i.ready && ds_lsq_i.ready;

    agu_lsq_itf                 agu_lsq_i();

    mem_rs mem_rs_i(
        .clk                    (clk),
        .rst                    (rst || backend_flush),

        .lsu_ready              (from_ds.ready),

        .from_ds                (ds_mem_rs_i),
        .to_prf                 (to_prf),
        .cdb                    (cdb),
        .to_lsq                 (agu_lsq_i)
    );

    dmem_itf                    dmem_itf_i();

    lsq lsq_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_ds                (ds_lsq_i),
        .from_agu               (agu_lsq_i),
        .cdb_out                (fu_cdb_out),
        .from_rob               (fu_cdb_out_dbg),
        .lsu_ready              (from_ds.ready),
        .backend_flush          (backend_flush),

        .dmem                   (dmem_itf_i)
    );

    dcache dcache_i(
        .clk                    (clk),
        .rst                    (rst),

        .ufp                    (dmem_itf_i),

        .dfp                    (dcache_itf)
    );

endmodule
