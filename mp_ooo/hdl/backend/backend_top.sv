module backend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    // Instruction Queue
    fifo_backend_itf.backend    from_fifo,

    // Flush signals
    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc
);

    assign backend_flush = 1'b0;
    assign backend_redirect_pc = 'x;

    id_rat_itf                  id_rat_itf_i();
    id_fl_itf                   id_fl_itf_i();
    id_rob_itf                  id_rob_itf_i();
    id_int_rs_itf               id_int_rs_itf_i();

    id_stage id_stage_i(
        // .clk                    (clk),
        // .rst                    (rst),

        .from_fifo              (from_fifo),
        .to_rat                 (id_rat_itf_i),
        .to_fl                  (id_fl_itf_i),
        .to_rob                 (id_rob_itf_i),
        .to_int_rs              (id_int_rs_itf_i)
    );

endmodule
