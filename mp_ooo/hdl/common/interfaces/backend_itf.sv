interface fifo_backend_itf();
import cpu_params::*;
import fetch_types::*;

    logic                   valid;
    logic                   ready;
    fetch_packet_t          data;

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
import uop_types::*;

    logic                   valid;
    logic                   ready;
    uop_t                   uop;

    modport id (
        output              valid,
        input               ready,
        output              uop
    );

    modport int_rs (
        input               valid,
        output              ready,
        input               uop
    );

endinterface

interface id_rob_itf();
import cpu_params::*;
import rvfi_types::*;

    logic                   valid;
    logic                   ready;
    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;
    rvfi_dbg_t              rvfi_dbg;

    modport id (
        output              valid,
        input               ready,
        input               rob_id,
        output              rd_phy,
        output              rd_arch,
        output              rvfi_dbg
    );

    modport rob (
        input               valid,
        output              ready,
        output              rob_id,
        input               rd_phy,
        input               rd_arch,
        input               rvfi_dbg
    );

endinterface

interface id_rat_itf();
import cpu_params::*;

    logic   [ARF_IDX-1:0]   read_arch[2];
    logic   [PRF_IDX-1:0]   read_phy[2];
    logic                   read_valid[2];
    logic                   write_en;
    logic   [ARF_IDX-1:0]   write_arch;
    logic   [PRF_IDX-1:0]   write_phy;

    modport id (
        output              read_arch,
        input               read_phy,
        input               read_valid,
        output              write_en,
        output              write_arch,
        output              write_phy
    );

    modport rat (
        input               read_arch,
        output              read_phy,
        output              read_valid,
        input               write_en,
        input               write_arch,
        input               write_phy
    );

endinterface

interface id_fl_itf();
import cpu_params::*;

    logic                   valid;
    logic                   ready;
    logic   [PRF_IDX-1:0]   free_idx;

    modport id (
        output              valid,
        input               ready,
        input               free_idx
    );

    modport fl (
        input               valid,
        output              ready,
        output              free_idx
    );

endinterface

interface rob_rrf_itf();
import cpu_params::*;

    logic                   valid;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;

    modport rob (
        output              valid,
        output              rd_phy,
        output              rd_arch
    );

    modport rrf (
        input               valid,
        input               rd_phy,
        input               rd_arch
    );

endinterface

interface rrf_fl_itf();
import cpu_params::*;

    logic                   valid;
    logic   [PRF_IDX-1:0]   stale_idx;

    modport rrf (
        output              valid,
        output              stale_idx
    );

    modport fl (
        input               valid,
        input               stale_idx
    );

endinterface

interface cdb_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;
    logic   [31:0]          rd_value;
    logic   [31:0]          rs1_value_dbg;
    logic   [31:0]          rs2_value_dbg;
    logic                   valid;

    modport fu (
        output              rob_id,
        output              rd_phy,
        output              rd_arch,
        output              rd_value,
        output              rs1_value_dbg,
        output              rs2_value_dbg,
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
        input               rd_value,
        input               rs1_value_dbg,
        input               rs2_value_dbg,
        input               valid
    );

    modport rat (
        input               rd_phy,
        input               rd_arch,
        input               valid
    );

endinterface


interface rs_prf_itf();
import cpu_params::*;

    logic   [PRF_IDX-1:0]   rs1_phy;
    logic   [PRF_IDX-1:0]   rs2_phy;
    logic   [31:0]          rs1_value;
    logic   [31:0]          rs2_value;

    modport rs (
        output              rs1_phy,
        output              rs2_phy,
        input               rs1_value,
        input               rs2_value
    );

    modport prf (
        input               rs1_phy,
        input               rs2_phy,
        output              rs1_value,
        output              rs2_value
    );

endinterface
