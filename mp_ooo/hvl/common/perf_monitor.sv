module perf_monitor
(
    input   logic               clk,
    input   logic               rst
);

    ////////////////////////////////
    // Branch Performance Monitor //
    ////////////////////////////////

    logic   [31:0]              br_cnt;
    logic   [31:0]              br_mispredict_cnt;
    real                        br_mispredict_rate;

    assign br_cnt = top_tb.dut.backend_i.branch_i.br_rs_i.fu_br_i.perf_br_cnt;
    assign br_mispredict_cnt = top_tb.dut.backend_i.branch_i.br_rs_i.fu_br_i.perf_br_mispredict_cnt;

    assign br_mispredict_rate = (br_cnt != 0) ? 
                                real'(br_mispredict_cnt) / real'(br_cnt) : 
                                0.0;

endmodule
