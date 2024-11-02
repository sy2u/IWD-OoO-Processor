import "DPI-C" function string getenv(input string env_name);


module fu_md_tb;

    //---------------------------------------------------------------------------------
    // Generate a clock:
    //---------------------------------------------------------------------------------

    timeunit 1ns;
    timeprecision 1ns;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #5ns clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    //---------------------------------------------------------------------------------
    // Declare FU_MD port signals:
    //---------------------------------------------------------------------------------
    import cpu_params::*;
    import intm_rs_types::*;
    import uop_types::*;

    cdb_itf     cdb();

    logic               flush;
    logic               prv_valid;
    logic               prv_ready;
    logic               nxt_valid;
    logic               nxt_ready;
    intm_rs_reg_t       intm_rs_reg;

    //---------------------------------------------------------------------------------
    // Instantiate the DUT
    //---------------------------------------------------------------------------------

    fu_md dut(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .prv_valid(prv_valid),
        .prv_ready(prv_ready),
        .nxt_valid(nxt_valid),
        .nxt_ready(nxt_ready),
        .intm_rs_reg(intm_rs_reg),
        .cdb(cdb)
    );

    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //---------------------------------------------------------------------------------
    // Write a task to generate reset:
    //---------------------------------------------------------------------------------

    task generate_reset();
        flush <= '0;
        prv_valid <= '0;
        nxt_ready <= '0;
        intm_rs_reg <= '0;

        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);
    endtask : generate_reset

    //---------------------------------------------------------------------------------
    // Write tasks to test various functionalities: Basic Functionality
    //---------------------------------------------------------------------------------

    task single_mult();

        prv_valid <= '1;
        nxt_ready <= '1;
        intm_rs_reg.fu_opcode <= MD_MUL;
        intm_rs_reg.rs1_value <= 32'h5;
        intm_rs_reg.rs2_value <= 32'h3;
        @(posedge clk);
        prv_valid <= '0;
        intm_rs_reg.rs1_value <= 'x;
        intm_rs_reg.rs2_value <= 'x;
        repeat(5) @(posedge clk);

        $display("\033[32mTest: single_mult Finished \033[0m");
    endtask : single_mult

    task all_mult();

        nxt_ready <= '1;

        prv_valid <= '1;
        intm_rs_reg.fu_opcode <= MD_MUL;
        intm_rs_reg.rs1_value <= '1;
        intm_rs_reg.rs2_value <= 32'h39;
        @(posedge clk);
        prv_valid <= '0;
        intm_rs_reg.rs1_value <= 'x;
        intm_rs_reg.rs2_value <= 'x;
        repeat(5) @(posedge clk);

        prv_valid <= '1;
        intm_rs_reg.fu_opcode <= MD_MULH;
        intm_rs_reg.rs1_value <= '1;
        intm_rs_reg.rs2_value <= 32'h39;
        @(posedge clk);
        prv_valid <= '0;
        intm_rs_reg.rs1_value <= 'x;
        intm_rs_reg.rs2_value <= 'x;
        repeat(5) @(posedge clk);

        prv_valid <= '1;
        intm_rs_reg.fu_opcode <= MD_MULHSU;
        intm_rs_reg.rs1_value <= '1;
        intm_rs_reg.rs2_value <= 32'h39;
        @(posedge clk);
        prv_valid <= '0;
        intm_rs_reg.rs1_value <= 'x;
        intm_rs_reg.rs2_value <= 'x;
        repeat(5) @(posedge clk);

        prv_valid <= '1;
        intm_rs_reg.fu_opcode <= MD_MULHSU;
        intm_rs_reg.rs1_value <= 32'h39;
        intm_rs_reg.rs2_value <= '1;
        @(posedge clk);
        prv_valid <= '0;
        intm_rs_reg.rs1_value <= 'x;
        intm_rs_reg.rs2_value <= 'x;
        repeat(5) @(posedge clk);

        $display("\033[32mTest: all_mult Finished \033[0m");
    endtask : all_mult

    //---------------------------------------------------------------------------------
    // Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------

    initial begin

        // generate_reset();
        // single_mult();

        generate_reset();
        all_mult();

        repeat(2) @(posedge clk);

        $finish;
    end

endmodule