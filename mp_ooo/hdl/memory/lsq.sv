module lsq
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    agu_lsq_itf.lsq             from_agu,
    cdb_itf.fu                  cdb_out

    // Flush signals
    // input   logic               backend_flush
);

    localparam              LSQ_IDX = $clog2(LSQ_DEPTH);

    lsq_entry_t             fifo[LSQ_DEPTH];

    //////////////////////////
    // Pointer Update Logic //
    //////////////////////////

    logic   [LSQ_IDX:0]     wr_ptr;
    logic   [LSQ_IDX-1:0]   wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [LSQ_IDX:0]     rd_ptr;
    logic   [LSQ_IDX-1:0]   rd_ptr_actual;
    logic                   rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    logic                   enqueue;
    logic                   dequeue;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (enqueue) begin
                wr_ptr <= (LSQ_IDX+1)'(wr_ptr + 1);
            end
            if (dequeue) begin
                rd_ptr <= (LSQ_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    ///////////////////////
    // FIFO Update Logic //
    ///////////////////////

    always_ff @(posedge clk) begin
        if (enqueue) begin
            fifo[wr_ptr_actual].rob_id <= from_ds.uop.rob_id;
            fifo[wr_ptr_actual].ready <= 1'b0;
            fifo[wr_ptr_actual].is_store <= from_ds.uop.fu_opcode[3];
            fifo[wr_ptr_actual].rd_arch <= from_ds.uop.rd_arch;
            fifo[wr_ptr_actual].rd_phy <= from_ds.uop.rd_phy;
        end

        if (from_agu.valid) begin
            for (int i = 0; i < LSQ_DEPTH; i++) begin
                if (fifo[i].rob_id == from_agu.rob_id) begin
                    fifo[i].ready <= 1'b1;
                    fifo[i].addr <= from_agu.addr;
                    fifo[i].mask <= from_agu.mask;
                    fifo[i].wdata <= from_agu.wdata;
                end
            end
        end
    end

    ///////////////////////////
    // Enqueue/Dequeue Logic //
    ///////////////////////////

    logic                   full;
    logic                   empty;
    logic                   want_dequeue;
    logic                   mm_stage_ready;

    assign enqueue = from_ds.valid && from_ds.ready;
    assign want_dequeue = ~empty && fifo[rd_ptr_actual].ready;
    assign dequeue = want_dequeue && mm_stage_ready; // simple dequeue condition

    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign empty = (wr_ptr_actual == rd_ptr_actual);
    assign from_ds.ready = ~full;

    mm_stage mm_stage_i(
        .clk        (clk),
        .rst        (rst),

        .prv_valid  (want_dequeue),
        .prv_ready  (mm_stage_ready),
        .agu_reg_in (fifo[rd_ptr_actual].agu_reg),

        .cdb_out    (cdb_out)
    );

endmodule
