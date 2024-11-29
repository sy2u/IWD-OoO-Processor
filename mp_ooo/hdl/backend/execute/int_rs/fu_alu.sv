module fu_alu
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               int_rs_valid,
    output  logic               fu_alu_ready,
    input   fu_alu_reg_t        fu_alu_reg_in,
    output  bypass_network_t    bypass,
    cdb_itf.fu                  cdb
);


    fu_alu_reg_t     fu_alu_reg_out;
    logic            fu_alu_valid;

    logic            cdb_ready;
    logic            cdb_valid;
    fu_cdb_reg_t     cdb_reg;

    ////////////////
    // FU_ALU_REG //
    ////////////////

    // to int_rs
    // assign fu_alu_ready = ~fu_alu_valid || (fu_alu_valid && cdb_ready)
    assign fu_alu_ready = 1'b1;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            fu_alu_valid <= '0;
        end else if (fu_alu_ready) begin 
            fu_alu_valid <= int_rs_valid;
        end
    end

    always_ff @(posedge clk) begin 
        if (int_rs_valid && fu_alu_ready) begin 
            fu_alu_reg_out <= fu_alu_reg_in;
        end
    end

    ////////////
    // FU_ALU //
    ////////////
    logic   [31:0]  a;
    logic   [31:0]  b;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    logic  [31:0]   alu_out;
    always_comb begin 
        unique case (fu_alu_reg_out.op1_sel) 
            OP1_RS1:  a = fu_alu_reg_out.rs1_value;
            OP1_ZERO: a = '0;
            default:  a = '0;
        endcase

        unique case (fu_alu_reg_out.op2_sel) 
            OP2_RS2:  b = fu_alu_reg_out.rs2_value;
            OP2_IMM:  b = fu_alu_reg_out.imm;
            default:  b = '0;
        endcase
    end

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin 
        unique case (fu_alu_reg_out.fu_opcode)
            ALU_ADD : alu_out = au + bu;
            ALU_SLL : alu_out = au <<  bu[4:0];
            ALU_SRA : alu_out = unsigned'(as >>> bu[4:0]);
            ALU_SUB : alu_out = au -   bu;
            ALU_XOR : alu_out = au ^   bu;
            ALU_SRL : alu_out = au >>  bu[4:0];
            ALU_OR  : alu_out = au |   bu;
            ALU_AND : alu_out = au &   bu;
            ALU_SLT : alu_out = {31'd0, (as <  bs)};
            ALU_SLTU: alu_out = {31'd0, (au <  bu)};
	    default : alu_out = 'x;
        endcase
    end

    assign bypass.valid     = fu_alu_valid;
    assign bypass.rd_phy    = fu_alu_reg_out.rd_phy;
    assign bypass.rd_value  = alu_out;

    ///////////////////
    // FU_ALU TO CDB //
    ///////////////////
    assign cdb_ready = 1'b1;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            cdb_valid <= '0;
        end else if (cdb_ready) begin 
            cdb_valid <= fu_alu_valid;
        end
    end

    // cdb_reg update
    
    always_ff @(posedge clk) begin 
        if (rst) begin 
            cdb_reg       <= '0;
        end else begin 
            if (fu_alu_valid && cdb_ready) begin 
                cdb_reg.rob_id          <= fu_alu_reg_out.rob_id;
                cdb_reg.rd_arch         <= fu_alu_reg_out.rd_arch;
                cdb_reg.rd_phy          <= fu_alu_reg_out.rd_phy;
                cdb_reg.rd_value        <= alu_out;
                cdb_reg.rs1_value_dbg   <= fu_alu_reg_out.rs1_value;
                cdb_reg.rs2_value_dbg   <= fu_alu_reg_out.rs2_value;
            end
        end
    end

    // fu_alu_reg to cdb
    assign cdb.rob_id           = cdb_reg.rob_id;
    assign cdb.rd_phy           = cdb_reg.rd_phy;
    assign cdb.rd_arch          = cdb_reg.rd_arch;
    assign cdb.rd_value         = cdb_reg.rd_value;
    assign cdb.valid            = cdb_valid;
    assign cdb.rs1_value_dbg    = cdb_reg.rs1_value_dbg;
    assign cdb.rs2_value_dbg    = cdb_reg.rs2_value_dbg;

endmodule
