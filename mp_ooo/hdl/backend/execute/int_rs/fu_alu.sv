module fu_alu
import cpu_params::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   int_rs_reg_t        int_rs_reg,
    input   logic               int_rs_reg_valid,
    cdb_itf.fu                  cdb
);

    logic   [31:0]  a;
    logic   [31:0]  b;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    logic  [31:0]   alu_out;
    always_comb begin 
        unique case (int_rs_reg.op1_sel) 
            OP1_RS1:  a = int_rs_reg.rs1_value;
            OP1_ZERO: a = '0;
            OP1_PC:   a = int_rs_reg.pc;
            default:  a = '0;
        endcase

        unique case (int_rs_reg.op2_sel) 
            OP2_RS2:  b = int_rs_reg.rs2_value;
            OP2_ZERO: b = '0;
            OP2_IMM:  b = int_rs_reg.imm_packed;
            default:  b = '0;
        endcase
    end

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin 
        unique case (int_rs_reg.fu_opcode)
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
        endcase
    end

    // fu_alu_reg update
    fu_alu_reg_t fu_alu_reg;
    logic        fu_alu_reg_valid;
    logic        fu_alu_reg_ready;
    assign fu_alu_reg_ready = 1'b1;
    always_ff @(posedge clk) begin 
        if (rst) begin 
            fu_alu_reg_valid <= 1b'0;
            fu_alu_reg       <= '0;
        end else begin 
            fu_alu_reg_valid        <= int_rs_reg_valid && fu_alu_reg_ready;
            if (int_rs_reg_valid && fu_alu_reg_ready) begin 
                fu_alu_reg.rob_id   <= int_rs_reg.rob_id;
                fu_alu_reg.rd_arch  <= int_rs_reg.rd_arch;
                fu_alu_reg.rd_phy   <= int_rs_reg.rd_phy;
                fu_alu_reg.rd_value <= alu_out;
            end
        end
    end

    // fu_alu_reg to cdb
    assign cdb.rob_id   = fu_alu_reg.rob_id;
    assign cdb.rd_phy   = fu_alu_reg.rd_phy;
    assign cdb.rd_arch  = fu_alu_reg.rd_arch;
    assign cdb.rd_value = fu_alu_reg.rd_value;
    assign cdb.valid    = fu_alu_reg.valid;

endmodule
