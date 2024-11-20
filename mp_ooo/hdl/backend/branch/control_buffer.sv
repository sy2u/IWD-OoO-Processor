module control_buffer
import cpu_params::*;
import uop_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs           from_ds,
    br_cdb_itf.cb               br_cdb_in,
    cb_rob_itf.cb               to_rob,
    input   logic               branch_ready          
);

    localparam              CB_IDX = $clog2(CB_DEPTH);

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic                   miss_predict;
        logic   [31:0]          target_address;
    } cb_entry_t;

    cb_entry_t              fifo[CB_DEPTH];

    logic                   enqueue;
    logic                   full;
    logic                   dequeue;
    logic                   empty;


    logic   [CB_IDX:0]    wr_ptr;
    logic   [CB_IDX-1:0]  wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [CB_IDX:0]    rd_ptr;
    logic   [CB_IDX-1:0]  rd_ptr_actual;
    logic                   rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (enqueue && ~full) begin
                fifo[wr_ptr_actual].rob_id <= from_ds.uop.rob_id;
                wr_ptr <= (CB_IDX+1)'(wr_ptr + 1);
            end

            if (br_cdb_in.valid) begin
                for (int i = 0; i < CB_DEPTH; i++) begin
                    if (fifo[i].rob_id == br_cdb_in.rob_id) begin
                        fifo[i].miss_predict <= br_cdb_in.miss_predict;
                        fifo[i].target_address <= br_cdb_in.target_address;
                    end
                end
            end

            if (dequeue) begin
                rd_ptr <= (CB_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    // enqueue, dequeue
    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign from_ds.ready = ~full;

    assign enqueue = from_ds.valid && branch_ready && ~(from_ds.uop.fu_opcode == BR_AUIPC);
    assign dequeue = to_rob.dequeue;

    // to rob
    assign to_rob.rob_id = fifo[rd_ptr_actual].rob_id;
    assign to_rob.miss_predict = fifo[rd_ptr_actual].miss_predict;
    assign to_rob.target_address = fifo[rd_ptr_actual].target_address;
    assign to_rob.ready = ~empty;

endmodule
