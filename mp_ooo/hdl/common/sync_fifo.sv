module sync_fifo #(
            parameter               DEPTH     = 16,
            parameter               WIDTH     = 32
)
(
    input   logic               clk,
    input   logic               rst,

    input   logic               enq_en,
    output  logic               full,
    input   logic   [WIDTH-1:0] enq_data,

    input   logic               deq_en,
    output  logic               empty,
    output  logic   [WIDTH-1:0] deq_data
);

    localparam              ADDR_IDX = $clog2(DEPTH);

    logic   [WIDTH-1:0]     fifo[DEPTH];

    logic   [ADDR_IDX:0]    wr_ptr;
    logic   [ADDR_IDX-1:0]  wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [ADDR_IDX:0]    rd_ptr;
    logic   [ADDR_IDX-1:0]  rd_ptr_actual;
    logic                   rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                fifo[i] <= 'x;
            end
        end else begin
            if (enq_en && ~full) begin
                fifo[wr_ptr_actual] <= enq_data;
                wr_ptr <= (ADDR_IDX+1)'(wr_ptr + 1);
            end
            if (deq_en && ~empty) begin
                deq_data <= fifo[rd_ptr_actual];
                rd_ptr <= (ADDR_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);

endmodule
