module lsu_top
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out

    // Flush signals
    // input   logic               backend_flush
);

    // Distribute signal from dispatch to RS and LSQ
    ds_rs_itf                   ds_mem_rs_i();
    ds_rs_itf                   ds_lsq_i();
    assign ds_mem_rs_i.valid = from_ds.valid;
    assign ds_mem_rs_i.uop   = from_ds.uop;
    assign ds_lsq_i.valid    = from_ds.valid;
    assign ds_lsq_i.uop      = from_ds.uop;
    assign from_ds.ready     = ds_mem_rs_i.ready && ds_lsq_i.ready;

    mem_rs mem_rs_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_ds                (ds_mem_rs_i),
        .to_prf                 (to_prf),
        .cdb                    (cdb)
    );

    lsq lsq_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_ds                (ds_lsq_i),
        .fu_cdb_out             (fu_cdb_out)
    );

endmodule
