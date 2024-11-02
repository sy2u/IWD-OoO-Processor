package cpu_params;

    localparam  unsigned    IF_WIDTH    = 1;

    localparam  unsigned    ID_WIDTH    = 1;

    localparam  unsigned    ROB_DEPTH   = 32;
    localparam  unsigned    ROB_IDX     = $clog2(ROB_DEPTH);

    localparam  unsigned    PRF_DEPTH   = 64;
    localparam  unsigned    PRF_IDX     = $clog2(PRF_DEPTH);

    localparam unsigned     INTRS_DEPTH = 8;
    localparam unsigned     INTRS_IDX   = $clog2(INTRS_DEPTH);    

    // Do not change this
    localparam  unsigned    ARF_DEPTH   = 32;
    localparam  unsigned    ARF_IDX     = $clog2(ARF_DEPTH);

    localparam  unsigned    CDB_WIDTH   = 2; // currently only ALU

    

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

package uop_types;
import cpu_params::*;

    typedef enum logic [1:0] {
        OP1_RS1     = 2'b00,
        OP1_ZERO    = 2'b01,
        OP1_PC      = 2'b10
    } op1_sel_t;

    typedef enum logic [1:0] {
        OP2_RS2     = 2'b00,
        OP2_ZERO    = 2'b01,
        OP2_IMM     = 2'b10
    } op2_sel_t;

    typedef enum logic [1:0] {
        RS_INT      = 2'b00,
        RS_INTM     = 2'b01
    } rs_type_t;

    typedef enum logic [1:0] {
        FU_ALU      = 2'b00,
        FU_MD       = 2'b01
    } fu_type_t;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SLL,
        ALU_SRA,
        ALU_SUB,
        ALU_XOR,
        ALU_SRL,
        ALU_OR,
        ALU_AND,
        ALU_SLT,
        ALU_SLTU
    } aluopc_t;

    typedef enum logic [3:0] {
        MD_MUL,
        MD_MULH,
        MD_MULHSU,
        MD_MULHU,
        MD_DIV,
        MD_DIVU,
        MD_REM,
        MD_REMU
    } mdopc_t;

    // Micro-op, the huge meta info that gets passed around the pipeline
    // EDA tools will optimize away anything that is not used in that stage
    typedef struct packed {
        logic   [31:0]          pc;
        logic   [31:0]          inst;

        logic   [1:0]               rs_type;    // Reservation Station type
        // fu_type_t               fu_type;    // Functional Unit type
        logic   [3:0]           fu_opcode;  // FU opcode
        logic   [1:0]           op1_sel;    // Operand 1 select
        logic   [1:0]           op2_sel;    // Operand 2 select

        logic   [PRF_IDX-1:0]   rd_phy;     // Destination register (physical)
        logic   [PRF_IDX-1:0]   rs1_phy;    // Source register 1 (physical)
        logic   [PRF_IDX-1:0]   rs2_phy;    // Source register 2 (physical)
        logic                   rs1_valid;  // Source register 1 valid (not busy)
        logic                   rs2_valid;  // Source register 2 valid (not busy)
        logic   [19:0]          imm_packed; // Packed immediate
        logic   [ROB_IDX-1:0]   rob_id;     // ROB ID

        logic   [ARF_IDX-1:0]   rd_arch;    // Destination register (architectural)
        logic   [ARF_IDX-1:0]   rs1_arch;   // Source register 1 (architectural)
        logic   [ARF_IDX-1:0]   rs2_arch;   // Source register 2 (architectural)
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

package int_rs_types;
import cpu_params::*;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;

        logic   [3:0]           fu_opcode;  
        logic   [1:0]           op1_sel;    
        logic   [1:0]           op2_sel;    

        logic   [31:0]          pc;
        logic   [19:0]          imm_packed;
        logic   [31:0]          rs1_value;
        logic   [31:0]          rs2_value;

    } int_rs_reg_t;

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [31:0]          rd_value;
    } fu_alu_reg_t;
endpackage

