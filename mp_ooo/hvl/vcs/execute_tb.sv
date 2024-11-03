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

    task test_consecutive_with_simple_dependency(); 
        // x1(x1) = x0 + 1: 1
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd0;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd0;
        id_int_rs_itf_i.uop.rd_arch <= 5'd1;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // x2(x2) = x1 + 1 : 2
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rd_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.rob_id <= 5'd1;
        id_int_rs_itf_i.uop.rd_arch <= 5'd2;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
    
        id_int_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_simple_dependency

    

    task test_consecutive_with_simple_dependency2(); 
        // 0: x2 = x1 + 1: (x1 invalid) 
        // 1: x3 = x1 + 1:   (x1 invalid)
        // 2: x1 = x0 + 1    (x0 valid)

        // result:
        // cycle 0: #2 x1 = 1, #0 issued
        // cycle 1: #0 in fu, all x1 set to valid, so #1 issued
        // cycle 2: #0 x2 = 2, #1 in fu
        // cycle 3: #1 x3 = 2

        // 0: x2 = x1 + 1: (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd0; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);

        // 1: x3 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd1;
        id_int_rs_itf_i.uop.rd_phy <= 6'd3;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);

        // 2: x1 = x0 + 1    (x0 valid)
        id_int_rs_itf_i.uop.rob_id <= 5'd2;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
    
        id_int_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_simple_dependency2

    task test_consecutive_with_complicated_dependency(); 
        // 0: x2 = x1 + 1: (x1 invalid) 
        // 1: x3 = x1 + 1:   (x1 invalid)
        // 2: x4 = x2 + x3:  (x2, x3 invalid)
        // 3: x7 = x2 + x4   (x2, x4 invalid)
        // 4: x5 = x2 xor x3 (x2, x3 invalid)
        // 5: x6 = x4 + x5   (x4, x5 invalid)
        // 6: x1 = x0 + 1    (x0 valid)

        // result:
        // cycle 0: #6 x1 = 1, #0 (x2) issued
        // cycle 1: all x1 set to valid, so #1 (x3) issued, #0 (x2) in fu, 
        // cycle 2: #0 x2 = 2, #1 (x3) in fu
        // cycle 3: #1 x3 = 2, all x2 set to valid, so #2 (x4) issued
        // cycle 4: all x3 is set to valid, so #4 (x5) issued, #2 (x4) in fu
        // cycle 5: #2 x4 = 4, #3 (x7) issued, #4 (x5) in fu
        // cycle 6: #4 (x5) = 0, all x4 is set to valid, so #5 (x6) issued, #3 (x7) in fu
        // cycle 7: #3 x7 = 6, #5 (x6) in fu
        // cycle 8: #5 x6 = 4

        // 0: x2 = x1 + 1: (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd0; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);

        // 1: x3 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd1;
        id_int_rs_itf_i.uop.rd_phy <= 6'd3;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);

        // 2: x4 = x2 + x3:  (x2, x3 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd2;
        id_int_rs_itf_i.uop.rd_phy <= 6'd4;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd3;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_RS2;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
        // 3: x7 = x2 + x4   (x2, x4 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd3;
        id_int_rs_itf_i.uop.rd_phy <= 6'd7;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd4;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_RS2;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
        // 4: x5 = x2 xor x3 (x2, x3 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd4;
        id_int_rs_itf_i.uop.rd_phy <= 6'd5;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd3;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_XOR;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_RS2;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
        // 5: x6 = x4 + x5   (x4, x5 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd5;
        id_int_rs_itf_i.uop.rd_phy <= 6'd6;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd4;
        id_int_rs_itf_i.uop.rs2_phy <= 6'd5;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_RS2;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
        // 6: x1 = x0 + 1    (x0 valid)
        id_int_rs_itf_i.uop.rob_id <= 5'd6;
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);
    
        id_int_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_complicated_dependency

    task test_full_with_dependency(); 
        // 0: x2 = x1 + 1: (x1 invalid) 
        // 1: x3 = x1 + 1:   (x1 invalid)
        // 2: x4 = x1 + 1:   (x1 invalid)
        // 3: x5 = x1 + 1:   (x1 invalid)
        // 4: x6 = x1 + 1:   (x1 invalid)
        // 5: x7 = x1 + 1:   (x1 invalid)
        // 6: x8 = x1 + 1:   (x1 invalid)
        // 7: x1 = x0 + 1    (x0 invalid)
        // 8: x9 = x1 + 1    (x1 invalid)
        // 9: x10 = x1 + 1   (x1 invalid, x0 valid)
        // 10: x11 = x1 + 1  (x1 invalid)
        // 11: x12 = x1 + 1  (x1 valid)

        // result:
        // cycle 0: #6 x1 = 1, #0 (x2) issued
        // cycle 1: all x1 set to valid, so #1 (x3) issued, #0 (x2) in fu, 
        // cycle 2: #0 x2 = 2, #1 (x3) in fu
        // cycle 3: #1 x3 = 2, all x2 set to valid, so #2 (x4) issued
        // cycle 4: all x3 is set to valid, so #4 (x5) issued, #2 (x4) in fu
        // cycle 5: #2 x4 = 4, #3 (x7) issued, #4 (x5) in fu
        // cycle 6: #4 (x5) = 0, all x4 is set to valid, so #5 (x6) issued, #3 (x7) in fu
        // cycle 7: #3 x7 = 6, #5 (x6) in fu
        // cycle 8: #5 x6 = 4

        // 0: x2 = x1 + 1: (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd0; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd2;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);

        // 1: x3 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd1;
        id_int_rs_itf_i.uop.rd_phy <= 6'd3;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        repeat (1) @(posedge clk);

        // 2: x4 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd2; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd4;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 3: x5 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd3; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd5;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 4: x6 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd4; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd6;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 5: x7 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd5; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd7;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 6: x8 = x1 + 1:   (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd6; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd8;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 7: x1 = x0 + 1    (x0 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd7; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd1;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd0;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 8: x9 = x1 + 1    (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd8; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd9;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 9: x10 = x1 + 1    (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd9; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd10;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;

        cdb_itfs[1].valid <= 1'b1;
        cdb_itfs[1].rob_id <= 'x;
        cdb_itfs[1].rd_phy <= 6'd0;
        cdb_itfs[1].rd_arch <= 6'd0;
        cdb_itfs[1].rd_value <= 32'd0;
        repeat (1) @(posedge clk);
        // 10: x11 = x1 + 1    (x1 invalid)
        id_int_rs_itf_i.uop.rob_id <= 5'd10; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd11;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b0;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        // 11: x12 = x1 + 1    (x1 valid)
        id_int_rs_itf_i.uop.rob_id <= 5'd11; 
        id_int_rs_itf_i.uop.rd_phy <= 6'd12;
        id_int_rs_itf_i.uop.rs1_phy <= 6'd1;
        id_int_rs_itf_i.uop.imm <= 32'd1;
        id_int_rs_itf_i.uop.fu_opcode <= ALU_ADD;
        id_int_rs_itf_i.uop.op1_sel <= OP1_RS1;
        id_int_rs_itf_i.uop.op2_sel <= OP2_IMM;
        id_int_rs_itf_i.uop.rs1_valid <= 1'b1;
        id_int_rs_itf_i.uop.rs2_valid <= 1'b0;
        id_int_rs_itf_i.valid <= 1'b1;
        repeat (1) @(posedge clk);
        id_int_rs_itf_i.valid <= 1'b0;
    endtask : test_full_with_dependency

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        do_reset();

        // test_single_instruction();
        // test_consecutive_no_dependency();
        // test_consecutive_with_simple_dependency();
        // test_consecutive_with_simple_dependency2();
        // test_consecutive_with_complicated_dependency();
        test_full_with_dependency();
	repeat (30) @(posedge clk);
	$finish;
        
    end

endmodule
