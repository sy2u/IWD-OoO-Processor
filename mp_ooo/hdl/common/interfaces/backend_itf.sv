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
    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;
    logic   [PRF_IDX-1:0]   rs1_phy;
    logic                   rs1_valid;
    logic   [PRF_IDX-1:0]   rs2_phy;
    logic                   rs2_valid;
    logic                   imm;
    logic                   opcode; // TODO: Determine opcodes

    modport id (
        output              valid,
        input               ready,
        output              rob_id,
        output              rd_phy,
        output              rd_arch,
        output              rs1_phy,
        output              rs1_valid,
        output              rs2_phy,
        output              rs2_valid,
        output              imm,
        output              opcode
    );

    modport int_rs (
        input               valid,
        input               ready,
        input               rob_id,
        input               rd_phy,
        input               rd_arch,
        input               rs1_phy,
        input               rs1_valid,
        input               rs2_phy,
        input               rs2_valid,
        input               imm,
        input               opcode
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

    logic   [ARF_IDX-1:0]   read_arch[2];
    logic   [PRF_IDX-1:0]   read_phy[2];
    logic   [PRF_IDX-1:0]   read_valid[2];
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

    modport rat (
        input               rd_phy,
        input               rd_arch,
        input               valid
    );

endinterface