module id_stage
import cpu_params::*;
import uop_types::*;
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

    uop_t                       uop_in;
    uop_t                       uop;

    assign uop.inst = from_fifo.data;

    // decoder decoder_i(
    //     .uop_in                 (uop_in),
    //     .uop_out                (uop)
    // );

    // Rename
    assign to_rat.read_arch[0] = uop.rs1_arch;
    assign to_rat.read_arch[1] = uop.rs2_arch;
    assign to_rat.write_en = from_fifo.valid && to_fl.ready;
    assign to_rat.write_arch = uop.rd_arch;
    assign to_rat.write_phy = to_fl.free_idx;

    assign uop.rs1_phy = to_rat.read_phy[0];
    assign uop.rs2_phy = to_rat.read_phy[1];
    assign uop.rd_phy = to_rat.write_phy;

    // Notify ROB
    assign to_rob.rd_phy = uop.rd_phy;
    assign to_rob.rd_arch = uop.rd_arch;
    assign uop.rob_id = to_rob.rob_id;

    // Dispatch to INT Reservation Stations

    // Valid-Ready signals
    assign to_rob.valid = from_fifo.valid;
    assign to_fl.valid = from_fifo.valid;
    assign to_int_rs.valid = from_fifo.valid;
    assign from_fifo.ready = to_fl.ready && to_rob.ready && to_int_rs.ready;

endmodule
