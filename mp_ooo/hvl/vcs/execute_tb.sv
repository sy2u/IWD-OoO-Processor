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
    
    task do_reset();
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        // set cdb and rs_prf_itfs to 0
        cdb_itfs[1].valid <= 1'b0;
        cdb_itfs[1].rob_id <= 'x;
        cdb_itfs[1].rd_phy <= 'x;
        cdb_itfs[1].rd_arch <= 'x;
        cdb_itfs[1].rd_value <= 'x;

        rs_prf_itfs[1].rs1_phy   <= '0;
        rs_prf_itfs[1].rs2_phy   <= '0;

        id_int_rs_itf_i.uop.pc <= 'x;
        id_int_rs_itf_i.uop.fu_opcode <= 'x;
        id_int_rs_itf_i.uop.op1_sel <= 'x;
        id_int_rs_itf_i.uop.op2_sel <= 'x;
        id_int_rs_itf_i.uop.rd_phy <= 'x;
        id_int_rs_itf_i.uop.rs1_phy <= 'x;
        id_int_rs_itf_i.uop.rs2_phy <= 'x;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 'x;
        id_int_rs_itf_i.uop.rob_id <= 'x;
        id_int_rs_itf_i.uop.rd_arch <= 'x;
        id_int_rs_itf_i.valid <= 1'b0;

        repeat (2) @(posedge clk);
    endtask : do_reset

    task test_single_instruction();
        // single add
        // x1 (x1) = x2 + 1
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
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
    endtask : test_single_instruction

    task test_consecutive_no_dependency(); 
        // x1(x1) = x2 + 1: 1
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= '0;
        id_int_rs_itf_i.uop.rd_arch <= 5'd1;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // x3(x3) = x4 xor x4: 0
        id_int_rs_itf_i.uop.fu_opcode <= ALU_XOR;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_RS2;
        id_int_rs_itf_i.uop.rd_phy <= 6'd3;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd4;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd4;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b1;
        id_int_rs_itf_i.uop.rob_id <= 5'd1;
        id_int_rs_itf_i.uop.rd_arch <= 5'd3;
        repeat (1) @(posedge clk);
        // x5(x5) = x6 or '1: ffffffff
        id_int_rs_itf_i.uop.fu_opcode <= ALU_OR;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd5;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd6;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= '1;
        id_int_rs_itf_i.uop.rob_id <= 5'd2;
        id_int_rs_itf_i.uop.rd_arch <= 5'd5;
        repeat (1) @(posedge clk);
        // x7(x7) = x8 and '1: 0
        id_int_rs_itf_i.uop.fu_opcode <= ALU_AND;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd7;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd8;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= '1;
        id_int_rs_itf_i.uop.rob_id <= 5'd3;
        id_int_rs_itf_i.uop.rd_arch <= 5'd7;
        repeat (1) @(posedge clk);
        // x9(x9) = x10 sub 32'd1: ffffffff
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SUB;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd9;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd10;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd4;
        id_int_rs_itf_i.uop.rd_arch <= 5'd9;
        repeat (1) @(posedge clk);
        // x11(x11) = x12 < '1 (u): 1
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SLTU;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd11;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd12;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= '1;
        id_int_rs_itf_i.uop.rob_id <= 5'd5;
        id_int_rs_itf_i.uop.rd_arch <= 5'd11;
        repeat (1) @(posedge clk);
        // x13(x13) = x14 <  '1 (s): 0
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SLT;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd13;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd14;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= '1;
        id_int_rs_itf_i.uop.rob_id <= 5'd6;
        id_int_rs_itf_i.uop.rd_arch <= 5'd13;
        repeat (1) @(posedge clk);
        // x15(x15) = x1 << 32'd1 : 2
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SLL;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd15;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd7;
        id_int_rs_itf_i.uop.rd_arch <= 5'd15;
        repeat (1) @(posedge clk);
        // x16(x16) = x5 >> 32'd1 : 7fffffff
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SRL;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd16;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd5;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd8;
        id_int_rs_itf_i.uop.rd_arch <= 5'd16;
        repeat (1) @(posedge clk);
        // x17(x17) = x5 >> 32'd1 (sla) : ffffffff
        id_int_rs_itf_i.uop.fu_opcode <= ALU_SRA;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd17;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd5;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd9;
        id_int_rs_itf_i.uop.rd_arch <= 5'd17;
        repeat (1) @(posedge clk);

        id_int_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_no_dependency

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        do_reset();

        // test_single_instruction();
        test_consecutive_no_dependency();
        // rst = 1'b1;
        // // set cdb and rs_prf_itfs to 0
        // cdb_itfs[1].valid = 1'b0;
        // cdb_itfs[1].rob_id = 'x;
        // cdb_itfs[1].rd_phy = 'x;
        // cdb_itfs[1].rd_arch = 'x;
        // cdb_itfs[1].rd_value = 'x;

        // rs_prf_itfs[1].rs1_phy   = '0;
        // rs_prf_itfs[1].rs2_phy   = '0;

        // repeat (2) @(posedge clk);
        // rst <= 1'b0;

        // // single add
        // // x1 (x1) = x2 + 1
        // id_int_rs_itf_i.uop.pc <= '0;
        // id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        // id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        // id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        // id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        // id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        // id_int_rs_itf_i.uop.rs2_phy <= 6'd0;
        // id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        // id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        // id_int_rs_itf_i.uop.imm <= 32'd1;
        // id_int_rs_itf_i.uop.rob_id <= '0;
        // id_int_rs_itf_i.uop.rd_arch <= 5'd1;
        // id_int_rs_itf_i.valid <= 1'b1;

        // // cycle 1
        // // from_id.valid <= 1'b0
        // repeat (1) @(posedge clk);
        // id_int_rs_itf_i.valid <= 1'b0;
	repeat (10) @(posedge clk);
	$finish;
        
    end

endmodule
