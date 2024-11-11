module lsq
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    agu_lsq_itf.lsq             from_agu,
    cdb_itf.fu                  fu_cdb_out

    // Flush signals
    // input   logic               backend_flush
);

    localparam              LSQ_IDX = $clog2(LSQ_DEPTH);

    uop_t                   fifo[LSQ_DEPTH];

    logic   [LSQ_IDX:0]     wr_ptr;
    logic   [LSQ_IDX-1:0]   wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [LSQ_IDX:0]     rd_ptr;
    logic   [LSQ_IDX-1:0]   rd_ptr_actual;
    logic                   rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
        end else begin
            if (from_ds.valid && from_ds.ready) begin
                fifo[wr_ptr_actual] <= from_ds.uop;
                wr_ptr <= (LSQ_IDX+1)'(wr_ptr + 1);
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_ptr <= '0;
        end else begin
            // if (from_ds.valid && from_ds.ready) begin
            //     fifo[wr_ptr_actual] <= from_ds.uop;
            //     rd_ptr <= (LSQ_IDX+1)'(rd_ptr + 1);
            // end
        end
    end

    assign from_ds.ready = ~((wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag));

    assign fu_cdb_out.valid = 1'b0;

endmodule
