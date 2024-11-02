module inst_queue
import fetch_types::*; #(
            parameter               DEPTH     = 16,
            parameter               WIDTH     = 32
)
(
    input   logic               clk,
    input   logic               rst,

    input   logic               in_valid,
    output  logic               in_ready,
    input   fetch_packet_t      in_packet,

    output  logic               out_valid,
    input   logic               out_ready,
    output  fetch_packet_t      out_packet
);

    localparam                  ADDR_IDX = $clog2(DEPTH);

    fetch_packet_t              fifo[DEPTH];

    logic                       enq_en;
    logic                       full;
    fetch_packet_t              enq_data;
    logic                       deq_en;
    logic                       empty;
    fetch_packet_t              deq_data;

    assign enq_en = in_valid;
    assign in_ready = ~full;
    assign enq_data = in_packet;
    assign deq_en = out_ready;
    assign out_valid = ~empty;
    assign out_packet = deq_data;

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
            fifo <= '{default: 'x};
        end else begin
            if (enq_en && ~full) begin
                fifo[wr_ptr_actual] <= enq_data;
                wr_ptr <= (ADDR_IDX+1)'(wr_ptr + 1);
            end
            if (deq_en && ~empty) begin
                rd_ptr <= (ADDR_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign deq_data = (~empty) ? fifo[rd_ptr_actual] : '{default: 'x};

endmodule
