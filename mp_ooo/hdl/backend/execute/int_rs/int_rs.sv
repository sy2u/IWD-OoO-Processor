module int_rs
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_int_rs_itf.int_rs        from_id,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out
);

    // Reservation Stations


    // Functional Units

    fu_alu fu_alu_i(
        .clk                    (clk),
        .rst                    (rst),

        .cdb                    (fu_cdb_out)
    );

endmodule
