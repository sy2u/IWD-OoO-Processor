module inst_queue
import fetch_types::*; #(
            parameter               DEPTH     = 16
)
(
    input   logic               clk,
    input   logic               rst,

    frontend_fifo_itf.fifo      in,

    fifo_backend_itf.fifo       out
);

    localparam                  ADDR_IDX = $clog2(DEPTH);

    fetch_packet_t              fifo[DEPTH];

    logic                       enq_en;
    logic                       full;
    fetch_packet_t              enq_data;
    logic                       deq_en;
    logic                       empty;
    fetch_packet_t              deq_data;

    assign enq_en = in.valid;
    assign in.ready = ~full;
    assign enq_data = in.packet;
    assign deq_en = out.ready;
    assign out.valid = ~empty;
    assign out.packet = deq_data;

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
    assign deq_data = fifo[rd_ptr_actual];

    //////////////////////////
    // Performance Counters //
    //////////////////////////

    logic   [ADDR_IDX-1:0]      perf_n_elem;
    logic   [ADDR_IDX-1:0]      perf_n_elem_nxt;

    always_ff @(posedge clk) begin
        if (rst) begin
            perf_n_elem <= '0;
        end else begin
            perf_n_elem <= perf_n_elem_nxt;
        end
    end

    always_comb begin
        perf_n_elem_nxt = perf_n_elem;
        if (enq_en && ~full) begin
            perf_n_elem_nxt = (ADDR_IDX)'(perf_n_elem_nxt + 1);
        end
        if (deq_en && ~empty) begin
            perf_n_elem_nxt = (ADDR_IDX)'(perf_n_elem_nxt - 1);
        end
    end

endmodule
