package cpu_params;

    localparam  unsigned    IF_WIDTH    = 2;

    localparam  unsigned    ID_WIDTH    = 2;
    localparam  unsigned    ID_WIDTH_IDX= $clog2(ID_WIDTH);

    localparam  unsigned    ROB_DEPTH   = 32;
    localparam  unsigned    ROB_PTR_IDX = $clog2(ROB_DEPTH);
    localparam  unsigned    ROB_IDX     = $clog2(ROB_DEPTH * ID_WIDTH);

    localparam  unsigned    PRF_DEPTH   = 64;
    localparam  unsigned    PRF_IDX     = $clog2(PRF_DEPTH);

    localparam unsigned     INTRS_DEPTH     = 8;
    localparam unsigned     INTRS_IDX       = $clog2(INTRS_DEPTH);

    localparam unsigned     INTMRS_DEPTH    = 8;
    localparam unsigned     INTMRS_IDX      = $clog2(INTMRS_DEPTH);

    localparam unsigned     BRRS_DEPTH      = 4;
    localparam unsigned     BRRS_IDX        = $clog2(BRRS_DEPTH);
    localparam  unsigned    CB_DEPTH        = 8;

    localparam  unsigned    MEMRS_DEPTH     = 8;
    localparam  unsigned    MEMRS_IDX       = $clog2(MEMRS_DEPTH);
    localparam  unsigned    LSQ_DEPTH       = 8;
    localparam  unsigned    LDQ_DEPTH       = 8;
    localparam  unsigned    LDQ_IDX         = $clog2(LDQ_DEPTH);
    localparam  unsigned    STQ_DEPTH       = 8;
    localparam  unsigned    STQ_IDX         = $clog2(STQ_DEPTH);
    localparam  unsigned    STB_DEPTH       = 4;
    localparam  unsigned    STB_IDX         = $clog2(STB_DEPTH);

    // Reservation Station Type: 0 - Normal, 1 - Age-ordered
    localparam unsigned     INT_RS_TYPE     = 1;
    localparam unsigned     INTM_RS_TYPE    = 0;

    // Bypass Network
    localparam  unsigned    NUM_RS      = 4; // Number of RS
    localparam  unsigned    CDB_WIDTH   = 4; // Number of CDB, could be different from NUM_RS

    // localparam logic        RS_CDB_BYPASS[NUM_RS][CDB_WIDTH] =
    //     '{'{1, 1, 1, 1}, // INTRS
    //       '{1, 1, 1, 1}, // INTMRS
    //       '{1, 1, 1, 1}, // BRRS
    //       '{1, 1, 1, 1}  // MEMRS
    //       };

    // localparam logic        PRF_FORWARDING[CDB_WIDTH][CDB_WIDTH] =
    //     '{'{1, 1, 1, 1}, // FU_ALU
    //       '{1, 1, 1, 1}, // FU_MDU
    //       '{1, 1, 1, 1}, // FU_BR
    //       '{1, 1, 1, 1}  // FU_AGU
    //       };

    localparam  unsigned    GHR_DEPTH       = 30;
    localparam  unsigned    PHT_IDX         = 9;
    localparam  unsigned    PHT_DEPTH       = 2 ** PHT_IDX;
    localparam  unsigned    BIMODAL_DEPTH   = 2;

    localparam  unsigned    BTB_DEPTH       = 8;
    localparam  unsigned    BTB_IDX         = $clog2(BTB_DEPTH);
    
    // Do not change this
    localparam  unsigned    ARF_DEPTH   = 32;
    localparam  unsigned    ARF_IDX     = $clog2(ARF_DEPTH);

    // DCache Parameters
    localparam  unsigned    D_OFFSET_IDX  = 5;
    localparam  unsigned    D_SET_IDX     = 5;
    localparam  unsigned    D_TAG_IDX     = 22;
    localparam  unsigned    D_NUM_WAYS    = 4;
    localparam  unsigned    D_PLRU_BITS   = D_NUM_WAYS - 1;
    localparam  unsigned    D_WAY_BITS    = $clog2(D_NUM_WAYS);

endpackage

package rv32i_types;

    /* ------------- Instruction Enums --------------- */
    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000,
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101,
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        muldiv_f3_mul= 3'b000,
        muldiv_f3_mulh= 3'b001,
        muldiv_f3_mulhsu= 3'b010,
        muldiv_f3_mulhu= 3'b011,
        muldiv_f3_div= 3'b100,
        muldiv_f3_divu= 3'b101,
        muldiv_f3_rem= 3'b110,
        muldiv_f3_remu= 3'b111
    } muldiv_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [6:0] {
        base           = 7'b0000000,
        muldiv         = 7'b0000001,
        variant        = 7'b0100000
    } funct7_t;

    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;

        struct packed {
            logic [12:12] b_imm_top_1;
            logic [10:5] b_imm_top_2;
            logic [4:0] rs2;
            logic [4:0] rs1;
            logic [2:0] funct3;
            logic [4:1] b_imm_bot_1;
            logic [11:11] b_imm_bot_2;
            rv32i_opcode opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } u_type;

    } instr_t;

endpackage

package fetch_types;
import cpu_params::*;

    typedef struct packed {
        logic   [IF_WIDTH-1:0]  [31:0]  inst;
        logic   [IF_WIDTH-1:0]          predict_taken;
        logic   [IF_WIDTH-1:0]  [31:0]  predict_target;
        logic                   [31:0]  pc;
        logic   [IF_WIDTH-1:0]          valid;
    } fetch_packet_t;

endpackage

package uop_types;
import cpu_params::*;

    typedef enum logic [0:0] {
        OP1_RS1     = 1'b0,
        OP1_ZERO    = 1'b1
    } op1_sel_t;

    typedef enum logic [0:0] {
        OP2_RS2     = 1'b0,
        OP2_IMM     = 1'b1
    } op2_sel_t;

    typedef enum logic [1:0] {
        RS_INT      = 2'b00,
        RS_INTM     = 2'b01,
        RS_BR       = 2'b10,
        RS_MEM      = 2'b11
    } rs_type_t;

    typedef enum logic [1:0] {
        FU_ALU      = 2'b00,
        FU_MDU      = 2'b01,
        FU_BR       = 2'b10,
        FU_AGU      = 2'b11
    } fu_type_t;

    typedef enum logic [3:0] {
        ALU_ADD     = 4'b0000,
        ALU_SLL     = 4'b0001,
        ALU_SRA     = 4'b0010,
        ALU_SUB     = 4'b0011,
        ALU_XOR     = 4'b0100,
        ALU_SRL     = 4'b0101,
        ALU_OR      = 4'b0110,
        ALU_AND     = 4'b0111,
        ALU_SLT     = 4'b1000,
        ALU_SLTU    = 4'b1001
    } aluopc_t;

    typedef enum logic [3:0] {
        MD_MUL      = 4'b000,
        MD_MULH     = 4'b001,
        MD_MULHSU   = 4'b010,
        MD_MULHU    = 4'b011,
        MD_DIV      = 4'b100,
        MD_DIVU     = 4'b101,
        MD_REM      = 4'b110,
        MD_REMU     = 4'b111
    } mdopc_t;

    typedef enum logic [3:0] {
        BR_BEQ      = 4'b0000,
        BR_BNE      = 4'b0001,
        BR_BLT      = 4'b0100,
        BR_BGE      = 4'b0101,
        BR_BLTU     = 4'b0110,
        BR_BGEU     = 4'b0111,
        BR_JAL      = 4'b1000,
        BR_JALR     = 4'b1001,
        BR_AUIPC    = 4'b1111
    } bropc_t;

    typedef enum logic [3:0] {
        MEM_LB      = 4'b0000,
        MEM_LH      = 4'b0001,
        MEM_LW      = 4'b0010,
        MEM_LBU     = 4'b0100,
        MEM_LHU     = 4'b0101,
        MEM_SB      = 4'b1000,
        MEM_SH      = 4'b1001,
        MEM_SW      = 4'b1010
    } memopc_t;

    // Micro-op, the huge meta info that gets passed around the pipeline
    // EDA tools will optimize away anything that is not used in that stage
    typedef struct packed {
        logic                   valid;      // Used during rename & dispatch

        logic   [31:0]          pc;
        logic   [31:0]          inst;

        logic   [1:0]           rs_type;    // Reservation Station type
        logic   [1:0]           fu_type;    // Functional Unit type
        logic   [3:0]           fu_opcode;  // FU opcode
        logic   [0:0]           op1_sel;    // Operand 1 select
        logic   [0:0]           op2_sel;    // Operand 2 select

        logic   [PRF_IDX-1:0]   rd_phy;     // Destination register (physical)
        logic   [PRF_IDX-1:0]   rs1_phy;    // Source register 1 (physical)
        logic   [PRF_IDX-1:0]   rs2_phy;    // Source register 2 (physical)
        logic                   rs1_valid;  // Source register 1 valid (not busy)
        logic                   rs2_valid;  // Source register 2 valid (not busy)
        logic   [31:0]          imm;        // Immediate
        logic   [ROB_IDX-1:0]   rob_id;     // ROB ID

        logic   [ARF_IDX-1:0]   rd_arch;    // Destination register (architectural)
        logic   [ARF_IDX-1:0]   rs1_arch;   // Source register 1 (architectural)
        logic   [ARF_IDX-1:0]   rs2_arch;   // Source register 2 (architectural)

        logic                   predict_taken; // Branch prediction
        logic   [31:0]          predict_target; // Branch prediction target
    } uop_t;

endpackage

package icache_types;

    typedef struct packed {
        logic           read;
        logic   [4:0]   offset;
        logic   [3:0]   set_i;
        logic   [22:0]  tag;
    } icache_stage_reg_t;

    typedef enum logic [1:0] {
        PASS_THRU       = 2'b00, // Any other states where miss does not happen
        ALLOCATE        = 2'b01, // Allocate new cache line
        ALLOCATE_STALL  = 2'b10  // One additional stall after allocate
    } icache_ctrl_fsm_state_t;

endpackage

package dcache_types;
import cpu_params::*;

    typedef struct packed {
        logic   [3:0]   rmask;
        logic   [3:0]   wmask;
        logic   [31:0]  wdata;
        logic   [D_OFFSET_IDX-1:0]   offset;
        logic   [D_SET_IDX-1:0]   set_i;
        logic   [D_TAG_IDX-1:0]  tag;
    } dcache_stage_reg_t;

    typedef enum logic [1:0] {
        PASS_THRU       = 2'b00, // Any other states where miss does not happen
        ALLOCATE        = 2'b01, // Allocate new cache line
        ALLOCATE_STALL  = 2'b10, // One additional stall after allocate
        WB              = 2'b11  // Writeback dirty cache line
    } dcache_ctrl_fsm_state_t;

endpackage

package prf_types;
import cpu_params::*;

    typedef struct packed {
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rd_value;
        logic                   valid;
    } cdb_prf_t;

    typedef struct packed {
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;
    } rs_prf_itf_t;

endpackage

package int_rs_types;
import cpu_params::*;
import uop_types::*;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [0:0]           op1_sel;
        logic   [0:0]           op2_sel;
        logic   [31:0]          imm;
        logic   [3:0]           fu_opcode;
    } int_rs_entry_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [3:0]           fu_opcode;
    } intm_rs_entry_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [31:0]          imm;
        logic   [31:0]          pc;
        logic   [3:0]           fu_opcode;
        logic                   predict_taken;
        logic   [31:0]          predict_target;
    } br_rs_entry_t;

    typedef struct packed {
        logic   [31:0]          rd_value;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic                   valid;
    } cdb_rs_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;

        logic   [3:0]           fu_opcode;  
        logic   [0:0]           op1_sel;    
        logic   [0:0]           op2_sel;    

        logic   [31:0]          imm;
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;

    } fu_alu_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;

        logic   [3:0]           fu_opcode;  

        logic   [31:0]          pc;
        logic   [31:0]          imm;
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;

        logic                   predict_taken; // Branch prediction
        logic   [31:0]          predict_target; // Branch prediction target

    } fu_br_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rd_value;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } fu_cdb_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [3:0]           fu_opcode;  
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;
    } intm_rs_reg_t;

    typedef enum logic [1:0] {  
        PREV        = 2'b00,
        SELF        = 2'b10,
        PUSH_IN     = 2'b11
    } rs_update_sel_t;

    typedef struct packed{
        logic                   valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rd_value;
    } bypass_network_t;

endpackage

package lsu_types;
import cpu_params::*;

    typedef struct packed {
        logic   [PRF_IDX-1:0]   rd_phy;
        logic                   valid;
    } cdb_rs_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [31:0]          imm;
        logic   [3:0]           fu_opcode;
    } mem_rs_entry_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [3:0]           fu_opcode;
        logic   [31:0]          imm;
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;
    } agu_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [31:0]          addr;
        logic   [31:0]          wdata;
        logic   [3:0]           mask;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } agu_lsq_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic                   ready;
        logic                   is_store;
        logic   [3:0]           fu_opcode;
        logic   [31:0]          addr;
        logic   [3:0]           mask;
        logic   [31:0]          wdata;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } lsq_entry_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic                   addr_valid;
        logic   [31:0]          addr;
        logic   [3:0]           mask;
        logic   [31:0]          wdata;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } stq_entry_t;

    typedef struct packed {
        logic                   valid;
        logic   [31:0]          addr;
        logic   [3:0]           mask;
        logic   [31:0]          wdata;
    } stb_entry_t;

    typedef struct packed {
        logic                   valid; // If the entry is valid
        logic                   addr_valid; // If the addr and mask is ready
        logic   [STQ_IDX:0]     track_stq_ptr;
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [3:0]           fu_opcode;
        logic   [31:0]          addr;
        logic   [3:0]           mask;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } ldq_entry_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [1:0]           addr_2;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [3:0]           fu_opcode;
        logic   [31:0]          addr_dbg;
        logic   [3:0]           mask_dbg;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
        // logic                   forward_en;
        // logic   [31:0]          forward_wdata;
    } load_stage_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rd_value;
        logic   [31:0]          rs1_value_dbg;
        logic   [31:0]          rs2_value_dbg;
    } lsu_cdb_reg_t;

endpackage

package rat_types;
import cpu_params::*;

    typedef struct packed {
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic                   valid;
    } cdb_rat_t;

endpackage

package rvfi_types;
import cpu_params::*;

    typedef struct packed {
        logic                   commit;
        logic   [63:0]          order;
        logic   [31:0]          inst;
        logic   [4:0]           rs1_addr;
        logic   [4:0]           rs2_addr;
        logic   [31:0]          rs1_rdata;
        logic   [31:0]          rs2_rdata;
        logic   [4:0]           rd_addr;
        logic   [31:0]          rd_wdata;
        logic   [4:0]           frd_addr;
        logic   [31:0]          frd_wdata;
        logic   [31:0]          pc_rdata;
        logic   [31:0]          pc_wdata;
        logic   [31:0]          mem_addr;
        logic   [3:0]           mem_rmask;
        logic   [3:0]           mem_wmask;
        logic   [31:0]          mem_rdata;
        logic   [31:0]          mem_wdata;
    } rvfi_dbg_t;

endpackage
