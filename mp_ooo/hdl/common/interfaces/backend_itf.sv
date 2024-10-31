interface fifo_backend_itf();

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

    modport fifo (
        output              valid,
        input               ready,
        output              data
    );

    modport backend (
        input               valid,
        output              ready,
        input               data
    );

endinterface

interface id_int_rs_itf();

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

    modport id (
        output              valid,
        input               ready,
        output              data
    );

    modport int_rs (
        input               valid,
        output              ready,
        input               data
    );

endinterface

interface id_rob_itf();

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

    modport id (
        output              valid,
        input               ready,
        output              data
    );

    modport rob (
        input               valid,
        output              ready,
        input               data
    );

endinterface

interface id_rat_itf();

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

    modport id (
        output              valid,
        input               ready,
        output              data
    );

    modport rat (
        input               valid,
        output              ready,
        input               data
    );

endinterface