module lsu_top
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    ldq_rob_itf.ldq             ld_to_rob,
    stq_rob_itf.stq             st_to_rob,
    cacheline_itf.master        dcache_itf,
    input bypass_network_t      alu_bypass,

    // Flush signals
    input   logic               backend_flush
);

    // Distribute signal from dispatch to RS and LSQ
    ds_rs_mono_itf              ds_mem_rs_i();
    ds_rs_mono_itf              ds_ldq_i();
    ds_rs_mono_itf              ds_stq_i();
    agu_lsq_itf                 agu_lsq_i();

    lsu_adapter lsu_adapter_i(
        .from_ds                (from_ds),
        .to_mem_rs              (ds_mem_rs_i),
        .to_ldq                 (ds_ldq_i),
        .to_stq                 (ds_stq_i)
    );

    mem_rs mem_rs_i(
        .clk                    (clk),
        .rst                    (rst || backend_flush),

        .from_ds                (ds_mem_rs_i),
        .to_prf                 (to_prf),
        .cdb                    (cdb),
        .to_lsq                 (agu_lsq_i),
        .alu_bypass             (alu_bypass)
    );

    dmem_itf                    dmem_itf_i();
    ldq_dmem_itf                ld_dmem_itf_i();
    stq_stb_itf                 stq_stb_i();
    stb_dmem_itf                st_dmem_itf_i();
    ldq_stq_itf                 ldq_stq_i();
    ldq_stb_itf                 ldq_stb_i();

    load_queue ldq_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .from_ds                (ds_ldq_i),
        .from_agu               (agu_lsq_i),
        .cdb_out                (fu_cdb_out),
        .to_rob                 (ld_to_rob),
        .dmem                   (ld_dmem_itf_i),
        .from_stq               (ldq_stq_i),
        .from_stb               (ldq_stb_i)
    );

    store_queue stq_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .from_ds                (ds_stq_i),
        .from_agu               (agu_lsq_i),
        .to_rob                 (st_to_rob),
        .to_stb                 (stq_stb_i),
        .from_ldq               (ldq_stq_i)
    );

    store_buf stb_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_stq               (stq_stb_i),
        .dmem                   (st_dmem_itf_i),
        .from_ldq               (ldq_stb_i)
    );

    dmem_arbiter dmem_arb_i(
        .clk                    (clk),
        .rst                    (rst),
        .backend_flush          (backend_flush),

        .load                   (ld_dmem_itf_i),
        .store                  (st_dmem_itf_i),
        .cache                  (dmem_itf_i)
    );

    dcache dcache_i(
        .clk                    (clk),
        .rst                    (rst),

        .ufp                    (dmem_itf_i),

        .dfp                    (dcache_itf)
    );

endmodule
