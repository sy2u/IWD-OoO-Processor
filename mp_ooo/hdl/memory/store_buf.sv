module store_buf
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    stq_stb_itf.stb             from_stq,
    stb_dmem_itf.stq            dmem,
    ldq_stb_itf.stb             from_ldq
);
    stb_entry_t             fifo[STB_DEPTH];

    //////////////////////////
    // Pointer Update Logic //
    //////////////////////////

    logic   [STB_IDX:0]     wr_ptr;
    logic   [STB_IDX-1:0]   wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [STB_IDX:0]     rd_ptr;
    logic   [STB_IDX-1:0]   rd_ptr_actual;
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
                wr_ptr <= (STB_IDX+1)'(wr_ptr + 1);
            end
            if (dequeue) begin
                rd_ptr <= (STB_IDX+1)'(rd_ptr + 1);
            end
        end
    end

    ///////////////////////
    // FIFO Update Logic //
    ///////////////////////

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < STB_DEPTH; i++) begin
                fifo[i].valid <= 1'b0;
            end
        end else begin
            if (enqueue) begin
                fifo[wr_ptr_actual].valid <= 1'b1;
                fifo[wr_ptr_actual].addr <= from_stq.addr;
                fifo[wr_ptr_actual].mask <= from_stq.wmask;
                fifo[wr_ptr_actual].wdata <= from_stq.wdata;
            end
            if (dequeue) begin
                fifo[rd_ptr_actual].valid <= 1'b0;
            end
        end
    end

    ///////////////////////////
    // Enqueue/Dequeue Logic //
    ///////////////////////////

    logic                   full;
    logic                   empty;
    logic                   want_dequeue;

    assign enqueue = from_stq.valid && from_stq.ready;

    assign want_dequeue = ~empty;
    assign dequeue = want_dequeue && dmem.ready;

    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign empty = (wr_ptr == rd_ptr);

    assign from_stq.ready = ~full;

    /////////////////////////
    // DCache Access Logic //
    /////////////////////////

    assign dmem.valid = want_dequeue;
    assign dmem.wmask = fifo[rd_ptr_actual].mask;
    assign dmem.addr =  {fifo[rd_ptr_actual].addr[31:2], 2'b00};
    assign dmem.wdata = fifo[rd_ptr_actual].wdata;

    /////////////////////////
    // LDQ Interface Logic //
    /////////////////////////

    logic   [STB_DEPTH-1:0] same_addr[LDQ_DEPTH]; // the address is the same
    // logic   [STB_DEPTH-1:0] potential_conflict[LDQ_DEPTH]; // the store is between the head and the tracked tail
    // logic   [STB_DEPTH-1:0] may_forward[LDQ_DEPTH]; // the store can be forwarded

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            same_addr[i] = '0;
            for (int j = 0; j < STB_DEPTH; j++) begin
                if (fifo[j].valid && fifo[j].addr[31:2] == from_ldq.ldq_addr[i][31:2] && ((from_ldq.ldq_rmask[i] & (~fifo[j].mask)) != from_ldq.ldq_rmask[i])) begin
                    same_addr[i][j] = 1'b1;
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            from_ldq.has_conflicting_store[i] = |same_addr[i];
        end
    end

endmodule
