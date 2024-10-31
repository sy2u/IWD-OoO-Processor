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

    id_stage id_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .from_fifo              (from_fifo)
    );

endmodule
