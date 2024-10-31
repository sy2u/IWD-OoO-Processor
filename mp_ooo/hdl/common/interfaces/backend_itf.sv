interface fifo_backend_itf();
import cpu_params::*;

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
import cpu_params::*;

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
import cpu_params::*;

    logic                   valid;
    logic                   ready;
    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;

    modport id (
        output              valid,
        input               ready,
        input               rob_id,
        output              rd_phy,
        output              rd_arch
    );

    modport rob (
        input               valid,
        output              ready,
        output              rob_id,
        input               rd_phy,
        input               rd_arch
    );

endinterface

interface id_rat_itf();
import cpu_params::*;

    logic                   valid;
    logic                   ready;
    logic   [31:0]          data;

    modport id (
        output              valid,
        input               ready
    );

    modport rat (
        input               valid,
        output              ready
    );

endinterface

interface cdb_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;
    logic   [31:0]          rd_value;
    logic                   valid;

    modport fu (
        output              rob_id,
        output              rd_phy,
        output              rd_arch,
        output              rd_value,
        output              valid
    );

    modport rs (
        input               rd_phy,
        input               valid
    );

    modport prf (
        input               rd_phy,
        input               rd_value,
        input               valid
    );

    modport rob (
        input               rob_id,
        input               valid
    );

endinterface