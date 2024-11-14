module lsq
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    agu_lsq_itf.lsq             from_agu,
    cdb_itf.fu                  cdb_out,
    ls_cdb_itf.lsu              cdb_out_dbg,
    input   logic   [ROB_IDX-1:0]   rob_head,
    dmem_itf.cpu                dmem

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
        if (from_agu.valid) begin
            for (int i = 0; i < LSQ_DEPTH; i++) begin
                if (fifo[i].rob_id == from_agu.data.rob_id) begin
                    fifo[i].ready <= 1'b1;
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
            fifo[wr_ptr_actual].ready <= 1'b0;
            fifo[wr_ptr_actual].is_store <= from_ds.uop.fu_opcode[3];
            fifo[wr_ptr_actual].fu_opcode <= from_ds.uop.fu_opcode;
            fifo[wr_ptr_actual].rd_arch <= from_ds.uop.rd_arch;
            fifo[wr_ptr_actual].rd_phy <= from_ds.uop.rd_phy;
        end
    end

    ///////////////////////////
    // Enqueue/Dequeue Logic //
    ///////////////////////////

    logic                   full;
    logic                   empty;
    logic                   want_dequeue;
    logic                   want_read;
    logic                   want_write;

    assign enqueue = from_ds.valid && from_ds.ready;
    always_comb begin
        if (empty) begin
            want_dequeue = 1'b0;
        end else begin
            if (fifo[rd_ptr_actual].is_store) begin
                want_dequeue = fifo[rd_ptr_actual].ready && (rob_head == fifo[rd_ptr_actual].rob_id); // check ROB
            end else begin
                want_dequeue = fifo[rd_ptr_actual].ready;
            end
        end
    end
    assign want_read = want_dequeue && ~fifo[rd_ptr_actual].is_store;
    assign want_write = want_dequeue && fifo[rd_ptr_actual].is_store;
    assign dequeue = want_dequeue && dmem.resp; // simple dequeue condition

    assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
    assign empty = (wr_ptr == rd_ptr);
    assign from_ds.ready = ~full;

    /////////////////////////
    // DCache Access Logic //
    /////////////////////////

    logic   [31:0]  dmem_unaligned_addr;

    assign dmem.rmask = (want_read && ~dmem.resp) ? fifo[rd_ptr_actual].mask : '0;
    assign dmem.wmask = (want_write && ~dmem.resp) ? fifo[rd_ptr_actual].mask : '0;
    assign dmem_unaligned_addr = fifo[rd_ptr_actual].addr;
    assign dmem.addr =  {dmem_unaligned_addr[31:2], 2'b00};
    assign dmem.wdata = fifo[rd_ptr_actual].wdata;

    logic   [31:0]  dmem_rdata_wb;
    always_comb begin
        unique case (fifo[rd_ptr_actual].fu_opcode)
            MEM_LB : dmem_rdata_wb = {{24{dmem.rdata[7 +8 *dmem_unaligned_addr[1:0]]}}, dmem.rdata[8 *dmem_unaligned_addr[1:0] +: 8 ]};
            MEM_LBU: dmem_rdata_wb = {{24{1'b0}}                          , dmem.rdata[8 *dmem_unaligned_addr[1:0] +: 8 ]};
            MEM_LH : dmem_rdata_wb = {{16{dmem.rdata[15+16*dmem_unaligned_addr[1]  ]}}, dmem.rdata[16*dmem_unaligned_addr[1]   +: 16]};
            MEM_LHU: dmem_rdata_wb = {{16{1'b0}}                          , dmem.rdata[16*dmem_unaligned_addr[1]   +: 16]};
            MEM_LW : dmem_rdata_wb = dmem.rdata;
            default: dmem_rdata_wb = 'x;
        endcase
    end

    ////////////////
    // CDB Output //
    ////////////////

    assign cdb_out.valid = dequeue;
    assign cdb_out.rob_id = fifo[rd_ptr_actual].rob_id;
    assign cdb_out.rd_phy = fifo[rd_ptr_actual].rd_phy;
    assign cdb_out.rd_arch = fifo[rd_ptr_actual].rd_arch;
    assign cdb_out.rd_value = dmem_rdata_wb;
    assign cdb_out.rs1_value_dbg = fifo[rd_ptr_actual].rs1_value_dbg;
    assign cdb_out.rs2_value_dbg = fifo[rd_ptr_actual].rs2_value_dbg;

    assign cdb_out_dbg.valid = dequeue;
    assign cdb_out_dbg.rob_id = fifo[rd_ptr_actual].rob_id;
    assign cdb_out_dbg.addr_dbg = {dmem_unaligned_addr[31:2], 2'b00};
    assign cdb_out_dbg.rmask_dbg = (~fifo[rd_ptr_actual].is_store) ? fifo[rd_ptr_actual].mask : '0;
    assign cdb_out_dbg.wmask_dbg = (fifo[rd_ptr_actual].is_store) ? fifo[rd_ptr_actual].mask : '0;
    assign cdb_out_dbg.rdata_dbg = dmem.rdata;
    assign cdb_out_dbg.wdata_dbg = fifo[rd_ptr_actual].wdata;

endmodule
