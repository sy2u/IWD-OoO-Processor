module lru_array #(
            parameter               S_INDEX     = 4,
            parameter               WIDTH       = 3
)(
    input   logic                   clk0,
    input   logic                   rst0,
    input   logic                   csb0,
    input   logic   [S_INDEX-1:0]   addr0,
    input   logic   [WIDTH-1:0]     din0,
    output  logic   [WIDTH-1:0]     dout0,
    input   logic                   csb1,
    input   logic                   web1,
    input   logic   [S_INDEX-1:0]   addr1,
    input   logic   [WIDTH-1:0]     din1
);

            localparam              NUM_SETS    = 2**S_INDEX;

            logic   [S_INDEX-1:0]   addr0_reg;
            logic   [WIDTH-1:0]     din0_reg;

            logic                   web1_reg;
            logic   [S_INDEX-1:0]   addr1_reg;
            logic   [WIDTH-1:0]     din1_reg;

            logic   [WIDTH-1:0]     internal_array [NUM_SETS];

    always_ff @(posedge clk0) begin
        if (rst0) begin
            addr0_reg <= 'x;
            din0_reg  <= 'x;
            web1_reg  <= 1'b1;
            addr1_reg <= 'x;
            din1_reg  <= 'x;
        end else begin
            if (!csb0) begin
                addr0_reg <= addr0;
                din0_reg  <= din0;
            end
            if (!csb1) begin
                web1_reg  <= web1;
                addr1_reg <= addr1;
                din1_reg  <= din1;
            end
        end
    end

    always_ff @(posedge clk0) begin
        if (rst0) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                internal_array[i] <= '0;
            end
        end else begin
            // [Soln 1] One-cycle write
            // if (!web1) begin
            //     internal_array[addr1] <= din1;
            // end
            // [Soln 2] Forwarding
            if (!web1_reg) begin
                internal_array[addr1_reg] <= din1_reg;
            end
        end
    end

    always_comb begin
        // [Soln 1] One-cycle write
        // dout0 = internal_array[addr0_reg];
        // [Soln 2] Forwarding
        dout0 = ((addr0_reg == addr1_reg) && ~web1_reg) ? din1_reg : internal_array[addr0_reg];
    end

endmodule : lru_array

