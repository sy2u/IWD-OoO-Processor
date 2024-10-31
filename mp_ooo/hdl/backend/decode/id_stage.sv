module id_stage
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    // Instruction queue
    fifo_backend_itf.backend    from_fifo

    // RAT

    // Free List

    // ROB

    // INT Reservation Stations

    // INTM Reservation Stations

);

    assign from_fifo.ready = '1;

endmodule
