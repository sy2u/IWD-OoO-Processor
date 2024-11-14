module mm_stage
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               prv_valid,
    output  logic               prv_ready,
    input   agu_reg_t           agu_reg_in,

    cdb_itf.fu                  cdb_out
);

endmodule
