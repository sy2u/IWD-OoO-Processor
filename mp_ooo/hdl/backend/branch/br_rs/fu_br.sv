module fu_br
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,

    input   logic               br_rs_valid,
    output  logic               fu_br_ready,
    input   fu_br_reg_t         fu_br_reg_in,
    cdb_itf.fu                  cdb,
    br_cdb_itf.fu               br_cdb            
);


    fu_br_reg_t      fu_br_reg_out;
    logic            fu_br_valid;

    logic            cdb_ready;
    logic            cdb_valid;
    logic            br_cdb_valid;
    fu_cdb_reg_t     cdb_reg;

    ////////////////
    // FU_BR_REG //
    ////////////////

    assign fu_br_ready = 1'b1;

    always_ff @(posedge clk) begin 
        if (rst || backend_flush) begin 
            fu_br_valid <= '0;
        end else if (fu_br_ready) begin 
            fu_br_valid <= br_rs_valid;
        end
    end

    always_ff @(posedge clk) begin 
        if (br_rs_valid && fu_br_ready) begin 
            fu_br_reg_out <= fu_br_reg_in;
        end
    end

    ////////////
    // FU_BR  //
    ////////////

    // calculate target address
    logic   [31:0]  target_address;

    // calculate branch taken
    logic   [31:0]  a;
    logic   [31:0]  b;
    logic           branch_taken;
    logic           miss_predict;
    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign a = fu_br_reg_out.rs1_value;
    assign b = fu_br_reg_out.rs2_value;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin 
        unique case (fu_br_reg_out.fu_opcode)
            BR_BEQ  : branch_taken = (au == bu);
            BR_BNE  : branch_taken = (au != bu);
            BR_BLT  : branch_taken = (as <  bs);
            BR_BGE  : branch_taken = (as >= bs);
            BR_BLTU : branch_taken = (au <  bu);
            BR_BGEU : branch_taken = (au >= bu);
            BR_JAL  : branch_taken = 1'b1;
            BR_JALR : branch_taken = 1'b1;
	        default : branch_taken = 'x;
        endcase
    end

    always_comb begin 
        if (branch_taken) begin 
            target_address = (fu_br_reg_out.fu_opcode == BR_JALR) ? ((fu_br_reg_out.rs1_value + fu_br_reg_out.imm) & 32'hfffffffe) : fu_br_reg_out.pc + fu_br_reg_out.imm;
        end else begin 
            target_address = fu_br_reg_out.pc + 32'd4;
        end
    end

    assign miss_predict = (branch_taken != fu_br_reg_out.predict_taken) || (target_address != fu_br_reg_out.predict_target);

    // calculate rd_value for jal & jalr
    logic   [31:0]  rd_value;
    always_comb begin
        if (fu_br_reg_out.fu_opcode == BR_AUIPC) begin
            rd_value = fu_br_reg_out.pc + fu_br_reg_out.imm;
        end else begin
            rd_value = fu_br_reg_out.pc + 32'd4;
        end
    end

    ///////////////////
    // fu_br TO CDB //
    ///////////////////
    assign cdb_ready = 1'b1;

    always_ff @(posedge clk) begin 
        if (rst || backend_flush) begin 
            cdb_valid <= '0;
            br_cdb_valid <= '0;
        end else if (cdb_ready) begin 
            cdb_valid <= fu_br_valid;
            br_cdb_valid <= fu_br_valid && ~(fu_br_reg_out.fu_opcode == BR_AUIPC);
        end
    end

    // cdb_reg update
    logic                   cdb_reg_branch_taken;
    logic                   cdb_reg_miss_predict;
    logic   [31:0]          cdb_reg_target_address;
    always_ff @(posedge clk) begin 
        if (rst || backend_flush) begin 
            cdb_reg                     <= '0;
            cdb_reg_miss_predict        <= '0;
            cdb_reg_target_address      <= '0;
            cdb_reg_branch_taken        <= '0;
        end else begin 
            if (fu_br_valid && cdb_ready) begin 
                cdb_reg.rob_id          <= fu_br_reg_out.rob_id;
                cdb_reg.rd_arch         <= fu_br_reg_out.rd_arch;
                cdb_reg.rd_phy          <= fu_br_reg_out.rd_phy;
                cdb_reg.rd_value        <= rd_value;
                cdb_reg.rs1_value_dbg   <= fu_br_reg_out.rs1_value;
                cdb_reg.rs2_value_dbg   <= fu_br_reg_out.rs2_value;

                cdb_reg_miss_predict    <= miss_predict;
                cdb_reg_target_address  <= target_address;
                cdb_reg_branch_taken    <= branch_taken;
            end
        end
    end

    // fu_br_reg to cdb
    assign cdb.rob_id           = cdb_reg.rob_id;
    assign cdb.rd_phy           = cdb_reg.rd_phy;
    assign cdb.rd_arch          = cdb_reg.rd_arch;
    assign cdb.rd_value         = cdb_reg.rd_value;
    assign cdb.valid            = cdb_valid;
    assign cdb.rs1_value_dbg    = cdb_reg.rs1_value_dbg;
    assign cdb.rs2_value_dbg    = cdb_reg.rs2_value_dbg;

    assign br_cdb.rob_id         = cdb_reg.rob_id;
    assign br_cdb.miss_predict   = cdb_reg_miss_predict;
    assign br_cdb.target_address = cdb_reg_target_address;
    assign br_cdb.branch_taken   = cdb_reg_branch_taken;
    assign br_cdb.valid          = br_cdb_valid;

    //////////////////////////
    // Performance Counters //
    //////////////////////////

    logic   [31:0]              perf_br_cnt;
    logic   [31:0]              perf_br_mispredict_cnt;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            perf_br_cnt             <= '0;
            perf_br_mispredict_cnt  <= '0;
        end else if (fu_br_valid) begin 
            perf_br_cnt             <= perf_br_cnt + 1;
            perf_br_mispredict_cnt  <= perf_br_mispredict_cnt + 32'(miss_predict);
        end
    end

endmodule
