module br_rs_tb;
    timeunit 1ns;
    timeprecision 1ns;

    import cpu_params::*;
    import rv32i_types::*;
    import uop_types::*;

    bit clk;
    always #5ns clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    ds_rs_itf                   ds_br_rs_itf_i();
    cdb_itf                     cdb_itfs[CDB_WIDTH]();
    rs_prf_itf                  rs_prf_itfs[CDB_WIDTH]();
    br_cdb_itf			        br_cdb_itf();
    br_rs br_rs_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_ds                (ds_br_rs_itf_i),
        .to_prf                 (rs_prf_itfs[2]),
        .cdb                    (cdb_itfs),
        .fu_cdb_out             (cdb_itfs[2]),
        .br_cdb_out             (br_cdb_itf)
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
        cdb_itfs[0].valid <= 1'b0;
        cdb_itfs[0].rob_id <= 'x;
        cdb_itfs[0].rd_phy <= 'x;
        cdb_itfs[0].rd_arch <= 'x;
        cdb_itfs[0].rd_value <= 'x;

        cdb_itfs[1].valid <= 1'b0;
        cdb_itfs[1].rob_id <= 'x;
        cdb_itfs[1].rd_phy <= 'x;
        cdb_itfs[1].rd_arch <= 'x;
        cdb_itfs[1].rd_value <= 'x;

        cdb_itfs[3].valid <= 1'b0;
        cdb_itfs[3].rob_id <= 'x;
        cdb_itfs[3].rd_phy <= 'x;
        cdb_itfs[3].rd_arch <= 'x;
        cdb_itfs[3].rd_value <= 'x;

        rs_prf_itfs[1].rs1_phy   <= '0;
        rs_prf_itfs[1].rs2_phy   <= '0;

        ds_br_rs_itf_i.uop.pc <= 'x;
        ds_br_rs_itf_i.uop.fu_opcode <= 'x;
        ds_br_rs_itf_i.uop.rd_phy <= 'x;
        ds_br_rs_itf_i.uop.rs1_phy <= 'x;
        ds_br_rs_itf_i.uop.rs2_phy <= 'x;
        ds_br_rs_itf_i.uop.rs1_valid <= 1'b0;
        ds_br_rs_itf_i.uop.rs2_valid <= 1'b0;
        ds_br_rs_itf_i.uop.imm <= 'x;
        ds_br_rs_itf_i.uop.rob_id <= 'x;
        ds_br_rs_itf_i.uop.rd_arch <= 'x;
        ds_br_rs_itf_i.uop.predict_taken <= 'x;
        ds_br_rs_itf_i.uop.predict_target <= 'x;
        ds_br_rs_itf_i.valid <= 1'b0;

        repeat (2) @(posedge clk);
    endtask : do_reset

    task test_jal();
        // jal
        // JAL x1, 0xffff (pc = 0x0000_0000)
        // x1 = 0x0000_0004, miss_predict = 1, target_address = 0x0000_ffff
        ds_br_rs_itf_i.uop.rob_id <= '0;

        ds_br_rs_itf_i.uop.rs1_phy <= 6'd0;
        ds_br_rs_itf_i.uop.rs1_valid <= 1'b1;
        ds_br_rs_itf_i.uop.rs2_phy <= 6'd0;
        ds_br_rs_itf_i.uop.rs2_valid <= 1'b1;
        ds_br_rs_itf_i.uop.rd_phy <= 6'd1;
        ds_br_rs_itf_i.uop.fu_opcode <= BR_JAL;
        ds_br_rs_itf_i.uop.pc <= 32'h0000_0000;
        ds_br_rs_itf_i.uop.imm <= 32'h0000_ffff;
        ds_br_rs_itf_i.uop.rd_arch <= 5'd1;
        ds_br_rs_itf_i.uop.predict_taken <= 1'b1;
        ds_br_rs_itf_i.uop.predict_target <= 32'h0000_0004;
        
        ds_br_rs_itf_i.valid <= 1'b1;

        // cycle 1
        // from_id.valid <= 1'b0
        repeat (1) @(posedge clk);
        ds_br_rs_itf_i.valid <= 1'b0;

        // cycle 3, assert cdb_itfs[2].rob_id == 0, cdb_itfs[2].rd_phy == 6'd1, cdb_itfs[2]
        repeat (2) @(posedge clk);
        if (cdb_itfs[2].rd_value == 32'd4 && br_cdb_itf.miss_predict == 1'b0 && br_cdb_itf.target_address == 32'h0000_ffff) begin 
            $display("JAL test passed");
        end else begin 
            $display("JAL test failed");
        end
    endtask : test_jal

    task test_beq(); 
        // beq x0, x0, 0xffff
        // miss_predict = 1, target_address = 0x0000_ffff
        ds_br_rs_itf_i.uop.rob_id <= '0;

        ds_br_rs_itf_i.uop.rs1_phy <= 6'd0;
        ds_br_rs_itf_i.uop.rs1_valid <= 1'b1;
        ds_br_rs_itf_i.uop.rs2_phy <= 6'd0;
        ds_br_rs_itf_i.uop.rs2_valid <= 1'b1;
        ds_br_rs_itf_i.uop.rd_phy <= 6'd1;
        ds_br_rs_itf_i.uop.fu_opcode <= BR_BEQ;
        ds_br_rs_itf_i.uop.pc <= 32'h0000_0000;
        ds_br_rs_itf_i.uop.imm <= 32'h0000_ffff;
        ds_br_rs_itf_i.uop.rd_arch <= 5'd1;
        ds_br_rs_itf_i.uop.predict_taken <= 1'b0;
        ds_br_rs_itf_i.uop.predict_target <= 32'h0000_0004;
        
        ds_br_rs_itf_i.valid <= 1'b1;

        // cycle 1
        // from_id.valid <= 1'b0
        repeat (1) @(posedge clk);
        ds_br_rs_itf_i.valid <= 1'b0;

        // cycle 3, assert cdb_itfs[2].rob_id == 0, cdb_itfs[2].rd_phy == 6'd1, cdb_itfs[2]
        repeat (2) @(posedge clk);
        if (br_cdb_itf.miss_predict == 1'b1 && br_cdb_itf.target_address == 32'h0000_ffff) begin 
            $display("BEQ test passed");
        end else begin 
            $display("BEQ test failed");
        end
    endtask : test_beq

    task test_consecutive_with_simple_dependency(); 
        repeat (1) @(posedge clk);
    
        ds_br_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_simple_dependency

    

    task test_consecutive_with_simple_dependency2(); 
        repeat (1) @(posedge clk);
    
        ds_br_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_simple_dependency2

    task test_consecutive_with_complicated_dependency(); 
        repeat (1) @(posedge clk);
    
        ds_br_rs_itf_i.valid <= 1'b0;
    endtask : test_consecutive_with_complicated_dependency

    task test_full_with_dependency(); 
        repeat (1) @(posedge clk);
        ds_br_rs_itf_i.valid <= 1'b0;
    endtask : test_full_with_dependency

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        do_reset();

        test_jal();
        // test_beq();
        // test_consecutive_no_dependency();
        // test_consecutive_with_simple_dependency();
        // test_consecutive_with_simple_dependency2();
        // test_consecutive_with_complicated_dependency();
        // test_full_with_dependency();
	repeat (30) @(posedge clk);
	$finish;
        
    end

endmodule
