module frontend_top
(
    input   logic           clk,
    input   logic           rst,

    // I cache connected to arbiter (later)
    cacheline_itf.master    icache_itf
);

    icache icache_i(
        .clk            (clk),
        .rst            (rst),

        .dfp            (icache_itf)
    );

endmodule
