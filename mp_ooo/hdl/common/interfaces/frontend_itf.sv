interface frontend_fifo_itf();

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

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
