module execute_tb;
    timeunit 1ns;
    timeprecision 1ns;

    import cpu_params::*;
    import rv32i_types::*;
    import uop_types::*;

    bit clk;
    always #5ns clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    id_int_rs_itf               id_int_rs_itf_i();
    cdb_itf                     cdb_itfs[CDB_WIDTH]();
    rs_prf_itf                  rs_prf_itfs[CDB_WIDTH]();
    int_rs int_rs_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_id                (id_int_rs_itf_i),
        .to_prf                 (rs_prf_itfs[0]),
        .cdb                    (cdb_itfs),
        .fu_cdb_out             (cdb_itfs[0])
    );

    prf prf_i(
        .clk                    (clk),
        .rst                    (rst),
        .from_rs                (rs_prf_itfs),
        .cdb                    (cdb_itfs)
    );
    
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        // set cdb and rs_prf_itfs to 0
        cdb_itfs[1].valid = 1'b0;
        cdb_itfs[1].rob_id = 'x;
        cdb_itfs[1].rd_phy = 'x;
        cdb_itfs[1].rd_arch = 'x;
        cdb_itfs[1].rd_value = 'x;

        rs_prf_itfs[1].rs1_phy   = '0;
        rs_prf_itfs[1].rs2_phy   = '0;

        repeat (2) @(posedge clk);
        rst <= 1'b0;

        // x1 (x1) = x2 + 1
        // cycle 0:
        // pc <= 0
        // fu_opcode <= ALU_ADD
        // op1_sel   <= OP1_RS1
        // op2_sel   <= OP2_IMM
        // rd_phy    <= 6'd1
        // rs1_phy   <= 6'd2
        // rs2_phy   <= 6'd0
        // rs1_valid <= 1'b1
        // rs2_valid <= 1'b0
        // imm <= 20'd1
        // rob_id <= '0
        // rd_arch <= 5'd1
        // from_id.valid <= 1'b1
        id_int_rs_itf_i.uop.pc <= '0;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd0;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= '0;
        id_int_rs_itf_i.uop.rd_arch <= 5'd1;
        id_int_rs_itf_i.valid <= 1'b1;

        // cycle 1
        // from_id.valid <= 1'b0
        repeat (1) @(posedge clk);
        id_int_rs_itf_i.valid <= 1'b0;
	repeat (10) @(posedge clk);
	$finish;
        
    end

endmodule
