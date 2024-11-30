module lsu_adapter
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    ds_rs_mono_itf.rs           from_ds,
    ds_rs_mono_itf.ds           to_mem_rs,
    ds_rs_mono_itf.ds           to_ldq,
    ds_rs_mono_itf.ds           to_stq
);

    assign to_mem_rs.valid = from_ds.valid && to_ldq.ready && to_stq.ready;
    assign to_mem_rs.uop   = from_ds.uop;
    assign to_stq.valid    = from_ds.valid && to_mem_rs.ready && to_ldq.ready;
    assign to_stq.uop      = from_ds.uop;
    assign to_ldq.valid    = from_ds.valid && to_mem_rs.ready && to_stq.ready;
    assign to_ldq.uop      = from_ds.uop;

    assign from_ds.ready = to_mem_rs.ready && to_ldq.ready && to_stq.ready;

endmodule
