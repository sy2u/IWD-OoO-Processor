interface frontend_fifo_itf();
import fetch_types::*;

    logic                   valid;
    logic                   ready;
    fetch_packet_t          data;

    modport frontend (
        output              valid,
        input               ready,
        output              data
    );

    modport fifo (
        input               valid,
        output              ready,
        input               data
    );

endinterface
