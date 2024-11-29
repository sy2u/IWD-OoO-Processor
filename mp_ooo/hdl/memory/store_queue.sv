module store_queue
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,

    ds_rs_mono_itf.rs           from_ds,
    agu_lsq_itf.lsq             from_agu,
    stq_rob_itf.stq             to_rob,
    stq_dmem_itf.stq            dmem,
    ldq_stq_itf.stq             from_ldq
);
    stq_entry_t             fifo[STQ_DEPTH];

    //////////////////////////
    // Pointer Update Logic //
    //////////////////////////

    logic   [STQ_IDX:0]     wr_ptr;
    logic   [STQ_IDX-1:0]   wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [STQ_IDX:0]     rd_ptr;
    logic   [STQ_IDX-1:0]   rd_ptr_actual;
    logic                   rd_ptr_flag;
    logic   [STQ_IDX:0]     counter;
    logic   [STQ_IDX:0]     counter_nxt;


    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    logic                   enqueue;
    logic                   dequeue;


    always_ff @(posedge clk) begin
        if (rst || backend_flush) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            counter <= '0;
        end else begin
            if (enqueue) begin
                wr_ptr <= (STQ_IDX+1)'(wr_ptr + 1);
            end
            if (dequeue) begin
                rd_ptr <= (STQ_IDX+1)'(rd_ptr + 1);
            end
            counter <= counter_nxt;
        end
    end

    always_comb begin
        counter_nxt = counter;
        if (enqueue) begin
            counter_nxt = (STQ_IDX+1)'(counter_nxt + 1);
        end
        if (dequeue) begin
            counter_nxt = (STQ_IDX+1)'(counter_nxt - 1);
        end
    end

    ///////////////////////
    // FIFO Update Logic //
    ///////////////////////

    always_ff @(posedge clk) begin
        if (from_agu.valid) begin
            for (int i = 0; i < STQ_DEPTH; i++) begin
                if (fifo[i].rob_id == from_agu.data.rob_id) begin
                    fifo[i].addr_valid <= 1'b1;
                    fifo[i].addr <= from_agu.data.addr;
                    fifo[i].mask <= from_agu.data.mask;
                    fifo[i].wdata <= from_agu.data.wdata;
                    fifo[i].rs1_value_dbg <= from_agu.data.rs1_value_dbg;
                    fifo[i].rs2_value_dbg <= from_agu.data.rs2_value_dbg;
                end
            end
        end

        if (enqueue) begin
            fifo[wr_ptr_actual].rob_id <= from_ds.uop.rob_id;
            fifo[wr_ptr_actual].addr_valid <= 1'b0;
            fifo[wr_ptr_actual].fu_opcode <= from_ds.uop.fu_opcode;
        end
    end

    ///////////////////////////
    // Enqueue/Dequeue Logic //
    ///////////////////////////

    logic                   full;
    logic                   empty;
    logic                   want_dequeue;

    assign enqueue = from_ds.valid && from_ds.ready && from_ds.uop.fu_opcode[3];
    always_comb begin
        if (empty) begin
            want_dequeue = 1'b0;
        end else begin
            want_dequeue = fifo[rd_ptr_actual].addr_valid && (to_rob.rob_head == ROB_PTR_IDX'(fifo[rd_ptr_actual].rob_id / ID_WIDTH)); // check ROB
        end
    end

    assign dequeue = want_dequeue && dmem.ready;

    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign empty = (wr_ptr == rd_ptr);
    assign from_ds.ready = ~full;

    /////////////////////////
    // DCache Access Logic //
    /////////////////////////

    assign dmem.valid = want_dequeue;
    assign dmem.wmask = fifo[rd_ptr_actual].mask;
    assign dmem.addr =  {fifo[rd_ptr_actual].addr[31:2], 2'b00};
    assign dmem.wdata = fifo[rd_ptr_actual].wdata;

    ////////////////
    // CDB Output //
    ////////////////

    assign to_rob.valid = dequeue;
    assign to_rob.rob_id = fifo[rd_ptr_actual].rob_id;
    assign to_rob.addr_dbg = {fifo[rd_ptr_actual].addr[31:2], 2'b00};
    assign to_rob.wmask_dbg = fifo[rd_ptr_actual].mask;
    assign to_rob.wdata_dbg = fifo[rd_ptr_actual].wdata;
    assign to_rob.rs1_value_dbg = fifo[rd_ptr_actual].rs1_value_dbg;
    assign to_rob.rs2_value_dbg = fifo[rd_ptr_actual].rs2_value_dbg;

    /////////////////////////
    // LDQ Interface Logic //
    /////////////////////////

    assign from_ldq.stq_tail = counter;
    assign from_ldq.stq_deq = dequeue;

    logic   [STQ_DEPTH-1:0] same_addr[LDQ_DEPTH]; // either the address is invalid or the address is the same
    logic   [STQ_DEPTH-1:0] potential_conflict[LDQ_DEPTH]; // the store is between the head and the tracked tail

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            same_addr[i] = '0;
            for (int j = 0; j < STQ_DEPTH; j++) begin
                if (~fifo[j].addr_valid || (fifo[j].addr[31:2] == from_ldq.ldq_addr[i][31:2])) begin
                    same_addr[i][j] = 1'b1;
                end
            end
        end
    end

    logic   [STQ_IDX:0]     tracked_tail[LDQ_DEPTH];

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            potential_conflict[i] = '0;
            for (int unsigned j = 0; j < STQ_DEPTH; j++) begin
                // Determine if j is between the head and the tracked tail by LDQ
                tracked_tail[i] = (STQ_IDX+1)'(rd_ptr + from_ldq.ldq_tracker[i] - 1);
                if (tracked_tail[i][STQ_IDX] == rd_ptr[STQ_IDX]) begin // no wrapping
                    potential_conflict[i][j] = (rd_ptr[STQ_IDX-1:0] <= (STQ_IDX)'(j)) && ((STQ_IDX)'(j) <= tracked_tail[i][STQ_IDX-1:0]);
                end else begin // wrapping
                    potential_conflict[i][j] = (rd_ptr[STQ_IDX-1:0] <= (STQ_IDX)'(j)) || ((STQ_IDX)'(j) <= tracked_tail[i][STQ_IDX-1:0]);
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            from_ldq.has_conflicting_store[i] = |(same_addr[i] & potential_conflict[i]);
        end
    end

endmodule
