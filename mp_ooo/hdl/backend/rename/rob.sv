module rob
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH]
);



endmodule
