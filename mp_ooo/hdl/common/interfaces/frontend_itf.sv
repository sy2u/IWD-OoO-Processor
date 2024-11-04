interface frontend_fifo_itf();
import fetch_types::*;

    logic                   valid;
    logic                   ready;
    fetch_packet_t          packet;

    modport frontend (
        output              valid,
        input               ready,
        output              packet
    );

    modport fifo (
        input               valid,
        output              ready,
        input               packet
    );

endinterface
