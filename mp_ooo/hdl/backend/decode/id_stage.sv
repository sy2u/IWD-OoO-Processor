module id_stage
import cpu_params::*;
(
    // input   logic               clk,
    // input   logic               rst,

    // Instruction queue
    fifo_backend_itf.backend    from_fifo,

    // RAT
    id_rat_itf.id               to_rat,

    // Free List
    id_fl_itf.id                to_fl,

    // ROB
    id_rob_itf.id               to_rob,

    // INT Reservation Stations
    id_int_rs_itf.id            to_int_rs

    // INTM Reservation Stations

);



    assign from_fifo.ready = to_fl.ready && to_rob.ready && to_int_rs.ready;

endmodule
