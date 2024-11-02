import "DPI-C" function string getenv(input string env_name);


module rat_tb;

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
    // Declare RAT port signals:
    //---------------------------------------------------------------------------------
    import cpu_params::*;
    id_rat_itf  id_rat_itf_i();
    cdb_itf     cdb_itfs[CDB_WIDTH]();

    //---------------------------------------------------------------------------------
    // Instantiate the DUT
    //---------------------------------------------------------------------------------

    rat dut(
        .clk(clk),
        .rst(rst),
        .from_id(id_rat_itf_i),
        .cdb(cdb_itfs)
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
        id_rat_itf_i.read_arch[0] <= '0;
        id_rat_itf_i.read_arch[1] <= '0;
        id_rat_itf_i.write_en <= '0;
        id_rat_itf_i.write_arch <= '0;
        id_rat_itf_i.write_phy <= '0;

        cdb_itfs[0].rd_phy <= '0;
        cdb_itfs[0].rd_arch <= '0;
        cdb_itfs[0].valid <= '0;
        cdb_itfs[1].rd_phy <= '0;
        cdb_itfs[1].rd_arch <= '0;
        cdb_itfs[1].valid <= '0;

        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);
    endtask : generate_reset

    //---------------------------------------------------------------------------------
    // Write tasks to test various functionalities: Basic Functionality
    //---------------------------------------------------------------------------------

    task read_from_rat();
        // read out
        for( int i = 0; i < 32; i++ ) begin  
            @(posedge clk);      
            id_rat_itf_i.read_arch[0] <= 5'(i);
            id_rat_itf_i.read_arch[1] <= 5'(31-i);
        end

        $display("\033[32mTest: read_from_rat Finished \033[0m");
    endtask : read_from_rat

    task write_from_freelist();
        // write in
        for( int i = 0; i < 32; i++ ) begin  
            @(posedge clk);      
            id_rat_itf_i.write_en <= '1;
            id_rat_itf_i.write_arch <= 5'(i);
            id_rat_itf_i.write_phy <= 6'(31-i);
        end
        id_rat_itf_i.write_en <= '0;

        $display("\033[32mTest: write_from_freelist Finished \033[0m");
    endtask : write_from_freelist

    task cdb_set_valid();
        @(posedge clk);
        // match
        cdb_itfs[0].valid <= '1;
        cdb_itfs[0].rd_arch <= 5'h1f;
        cdb_itfs[0].rd_phy <= '0;
        @(posedge clk);
        cdb_itfs[0].valid <= '1;
        cdb_itfs[0].rd_arch <= 5'h10;
        cdb_itfs[0].rd_phy <= 6'h0f;
        @(posedge clk);
        // doesn't match
        cdb_itfs[0].valid <= '1;
        cdb_itfs[0].rd_arch <= 5'h12;
        cdb_itfs[0].rd_phy <= 6'h20;
        @(posedge clk);
        cdb_itfs[0].valid <= '0;
        $display("\033[32mTest: cdb_set_valid Finished \033[0m");
    endtask : cdb_set_valid

    //---------------------------------------------------------------------------------
    // Write tasks to test various functionalities: Corner Case
    //---------------------------------------------------------------------------------

    task transparent_rat();
        @(posedge clk);
        @(posedge clk);
        // cdb
        cdb_itfs[0].valid <= '1;
        cdb_itfs[0].rd_arch <= 5'h05;
        cdb_itfs[0].rd_phy <= 6'h1a;
        cdb_itfs[1].valid <= '1;
        cdb_itfs[1].rd_arch <= 5'h06;
        cdb_itfs[1].rd_phy <= 6'h19;
        // id
        id_rat_itf_i.read_arch[0] <= 5'h05;
        id_rat_itf_i.read_arch[1] <= 5'h06; 
        @(posedge clk);
        cdb_itfs[0].valid <= '0;
       
        $display("\033[32mTest: transparent_rat Finished \033[0m");
    endtask : transparent_rat

    //---------------------------------------------------------------------------------
    // Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------

    initial begin

        generate_reset();
        read_from_rat();
        write_from_freelist();
        cdb_set_valid();
        read_from_rat();
        transparent_rat();
        repeat(2) @(posedge clk);

        $finish;
    end

endmodule