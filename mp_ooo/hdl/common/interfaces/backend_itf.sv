interface fifo_backend_itf();
import cpu_params::*;
import fetch_types::*;

    logic                   valid;
    logic                   ready;
    fetch_packet_t          packet;

    modport fifo (
        output              valid,
        input               ready,
        output              packet
    );

    modport backend (
        input               valid,
        output              ready,
        input               packet
    );

endinterface

interface ds_rs_itf();
import cpu_params::*;
import uop_types::*;

    logic                   valid   [ID_WIDTH];
    logic                   ready;
    uop_t                   uop     [ID_WIDTH];

    modport ds (
        output              valid,
        input               ready,
        output              uop
    );

    modport rs (
        input               valid,
        output              ready,
        input               uop
    );

endinterface

interface ds_rs_mono_itf();
import cpu_params::*;
import uop_types::*;

    logic                   valid;
    logic                   ready;
    uop_t                   uop;

    modport ds (
        output              valid,
        input               ready,
        output              uop
    );

    modport rs (
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
    logic                   inst_valid  [ID_WIDTH];
    logic   [ROB_IDX-1:0]   rob_id      [ID_WIDTH];
    logic   [PRF_IDX-1:0]   rd_phy      [ID_WIDTH];
    logic   [ARF_IDX-1:0]   rd_arch     [ID_WIDTH];
    logic                   is_store    [ID_WIDTH];
    rvfi_dbg_t              rvfi_dbg    [ID_WIDTH];

    modport id (
        output              valid,
        output              inst_valid,
        input               ready,
        input               rob_id,
        output              rd_phy,
        output              rd_arch,
        output              is_store,
        output              rvfi_dbg
    );

    modport rob (
        input               valid,
        input               inst_valid,
        output              ready,
        output              rob_id,
        input               rd_phy,
        input               rd_arch,
        input               is_store,
        input               rvfi_dbg
    );

endinterface

interface id_rat_itf();
import cpu_params::*;

    logic   [ARF_IDX-1:0]   rs1_arch    [ID_WIDTH];
    logic   [ARF_IDX-1:0]   rs2_arch    [ID_WIDTH];
    logic   [PRF_IDX-1:0]   rs1_phy     [ID_WIDTH];
    logic   [PRF_IDX-1:0]   rs2_phy     [ID_WIDTH];
    logic                   rs1_valid   [ID_WIDTH];
    logic                   rs2_valid   [ID_WIDTH];
    logic                   write_en    [ID_WIDTH];
    logic   [ARF_IDX-1:0]   rd_arch     [ID_WIDTH];
    logic   [PRF_IDX-1:0]   rd_phy      [ID_WIDTH];

    modport id (
        output              rs1_arch,
        output              rs2_arch,
        input               rs1_phy,
        input               rs2_phy,
        input               rs1_valid,
        input               rs2_valid,
        output              write_en,
        output              rd_arch,
        output              rd_phy
    );

    modport rat (
        input               rs1_arch,
        input               rs2_arch,
        output              rs1_phy,
        output              rs2_phy,
        output              rs1_valid,
        output              rs2_valid,
        input               write_en,
        input               rd_arch,
        input               rd_phy
    );

endinterface

interface id_fl_itf();
import cpu_params::*;

    logic                   valid   [ID_WIDTH];
    logic                   ready;
    logic   [PRF_IDX-1:0]   free_idx[ID_WIDTH];

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

    logic                   valid   [ID_WIDTH];
    logic   [PRF_IDX-1:0]   rd_phy  [ID_WIDTH];
    logic   [ARF_IDX-1:0]   rd_arch [ID_WIDTH];

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

    logic                   valid       [ID_WIDTH];
    logic   [PRF_IDX-1:0]   stale_idx   [ID_WIDTH];

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

interface br_cdb_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic                   miss_predict;
    logic   [31:0]          target_address;
    logic                   valid;
    logic                   branch_taken;

    modport fu (
        output              rob_id,
        output              miss_predict,
        output              target_address,
        output              valid,
        output              branch_taken
    );

    modport cb (
        input              rob_id,
        input              miss_predict,
        input              target_address,
        input              valid,
        input              branch_taken
    );

endinterface

interface cb_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic                   miss_predict;
    logic   [31:0]          target_address;
    logic                   ready;
    logic                   dequeue;

    modport cb (
        output              rob_id,
        output              miss_predict,
        output              target_address,
        output              ready,
        input               dequeue
    );

    modport rob (
        input              rob_id,
        input              miss_predict,
        input              target_address,
        input              ready,
        output             dequeue
    );
endinterface

interface ls_rob_itf();
import cpu_params::*;

    logic   [ROB_PTR_IDX-1:0]   rob_head;
    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               rmask_dbg;
    logic   [3:0]               wmask_dbg;
    logic   [31:0]              rdata_dbg;
    logic   [31:0]              wdata_dbg;
    logic                       valid;

    modport lsu (
        input               rob_head,
        output              rob_id,
        output              addr_dbg,
        output              rmask_dbg,
        output              wmask_dbg,
        output              rdata_dbg,
        output              wdata_dbg,
        output              valid
    );

    modport rob (
        output              rob_head,
        input               rob_id,
        input               addr_dbg,
        input               rmask_dbg,
        input               wmask_dbg,
        input               rdata_dbg,
        input               wdata_dbg,
        input               valid
    );

endinterface

interface ldq_stq_itf();
import cpu_params::*;

    logic   [STQ_IDX:0]     stq_tail; // Index from 1, 0 means empty
    logic                   stq_deq;
    logic   [STQ_IDX:0]     ldq_tracker[LDQ_DEPTH];
    logic   [31:0]          ldq_addr[LDQ_DEPTH];
    logic   [3:0]           ldq_rmask[LDQ_DEPTH];
    logic                   has_conflicting_store[LDQ_DEPTH];
    // logic                   forward_en[LDQ_DEPTH];
    // logic   [31:0]          forward_wdata[LDQ_DEPTH];

    modport ldq (
        input               stq_tail,
        input               stq_deq,
        output              ldq_tracker,
        output              ldq_addr,
        output              ldq_rmask,
        input               has_conflicting_store
    );

    modport stq (
        output              stq_tail,
        output              stq_deq,
        input               ldq_tracker,
        input               ldq_addr,
        input               ldq_rmask,
        output              has_conflicting_store
    );

endinterface

interface ldq_stb_itf();
import cpu_params::*;

    logic   [31:0]          ldq_addr[LDQ_DEPTH];
    logic   [3:0]           ldq_rmask[LDQ_DEPTH];
    logic                   has_conflicting_store[LDQ_DEPTH];

    modport ldq (
        output              ldq_addr,
        output              ldq_rmask,
        input               has_conflicting_store
    );

    modport stb (
        input               ldq_addr,
        input               ldq_rmask,
        output              has_conflicting_store
    );

endinterface

interface ldq_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               rmask_dbg;
    logic   [31:0]              rdata_dbg;
    logic                       valid;

    modport ldq (
        output              rob_id,
        output              addr_dbg,
        output              rmask_dbg,
        output              rdata_dbg,
        output              valid
    );

    modport rob (
        input               rob_id,
        input               addr_dbg,
        input               rmask_dbg,
        input               rdata_dbg,
        input               valid
    );

endinterface

interface stq_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               wmask_dbg;
    logic   [31:0]              wdata_dbg;
    logic   [31:0]              rs1_value_dbg;
    logic   [31:0]              rs2_value_dbg;
    logic                       valid;
    logic                       ready;

    modport stq (
        output              rob_id,
        output              addr_dbg,
        output              wmask_dbg,
        output              wdata_dbg,
        output              rs1_value_dbg,
        output              rs2_value_dbg,
        output              valid,
        input               ready
    );

    modport rob (
        input               rob_id,
        input               addr_dbg,
        input               wmask_dbg,
        input               wdata_dbg,
        input               rs1_value_dbg,
        input               rs2_value_dbg,
        input               valid,
        output              ready
    );

endinterface

interface stq_stb_itf();
import cpu_params::*;

    logic                       valid;
    logic                       ready;
    logic   [31:0]              addr;
    logic   [3:0]               wmask;
    logic   [31:0]              wdata;

    modport stq (
        output              valid,
        input               ready,
        output              addr,
        output              wmask,
        output              wdata
    );

    modport stb (
        input               valid,
        output              ready,
        input               addr,
        input               wmask,
        input               wdata
    );

endinterface

interface rs_prf_itf();
import cpu_params::*;
import int_rs_types::*;

    logic   [PRF_IDX-1:0]   rs1_phy;
    logic   [PRF_IDX-1:0]   rs2_phy;
    logic   [31:0]          rs1_value;
    logic   [31:0]          rs2_value;
    bypass_t                rs_bypass;

    modport rs (
        output              rs1_phy,
        output              rs2_phy,
        input               rs1_value,
        input               rs2_value,
        output              rs_bypass
    );

    modport prf (
        input               rs1_phy,
        input               rs2_phy,
        output              rs1_value,
        output              rs2_value,
        input               rs_bypass
    );

endinterface

interface agu_lsq_itf();
import cpu_params::*;
import lsu_types::*;

    logic                   valid;
    agu_lsq_t               data;

    modport agu (
        output              valid,
        output              data
    );

    modport lsq (
        input               valid,
        input               data
    );

endinterface

interface cb_bp_itf();
import cpu_params::*;

    logic                   update_en;
    logic   [31:0]          pc;
    logic   [3:0]           fu_opcode;
    logic                   branch_taken;
    logic   [31:0]          target_address;

    modport cb (
        output              update_en,
        output              pc,
        output              fu_opcode,
        output              branch_taken,
        output              target_address
    );

    modport bp (
        input               update_en,
        input               pc,
        input               fu_opcode,
        input               branch_taken,
        input               target_address
    );

endinterface
