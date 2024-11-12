module mm_stage
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               prv_valid,
    output  logic               prv_ready,
    input   agu_reg_t           agu_reg_in,

    cdb_itf.fu                  cdb_out
);

    agu_reg_t       agu_reg;
    logic           agu_valid;

    ////////////////
    // FU_AGU_REG //
    ////////////////

    // to int_rs
    assign prv_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin 
            agu_valid <= '0;
        end else if (prv_ready) begin 
            agu_valid <= prv_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin 
            agu_reg <= '{default: 'x};
        end else if (prv_valid && prv_ready) begin 
            agu_reg <= agu_reg_in;
        end
    end

    ////////////
    // FU_AGU //
    ////////////

    logic   [31:0]  unaligned_addr;
    assign unaligned_addr = agu_reg.rs1_value + agu_reg.imm;

    // Output to buffer
    assign nxt_valid = agu_valid;
    assign to_lsq.rob_id = agu_reg.rob_id;
    assign to_lsq.addr = {unaligned_addr[31:2], 2'b00};
    assign to_lsq.wdata = agu_reg.rs2_value;

    always_comb begin
        unique case (agu_reg.fu_opcode)
            MEM_LB, MEM_LBU, MEM_SB : to_lsq.mask = 4'b0001 << unaligned_addr[1:0];
            MEM_LH, MEM_LHU, MEM_SH : to_lsq.mask = 4'b0011 << unaligned_addr[1:0];
            MEM_LW, MEM_SW          : to_lsq.mask = 4'b1111;
            default                 : to_lsq.mask = 4'bxxxx;
        endcase
    end

endmodule
