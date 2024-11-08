module id_stage
import cpu_params::*;
import uop_types::*;
(
    // input   logic               clk,
    // input   logic               rst,

    // Instruction queue
    fifo_backend_itf.backend    from_fifo,

    // handshake with dispatch stage
    output  logic               nxt_valid,
    input   logic               nxt_ready,
    output  uop_t               uops[ID_WIDTH],

    // RAT
    id_rat_itf.id               to_rat,

    // Free List
    id_fl_itf.id                to_fl,

    // ROB
    id_rob_itf.id               to_rob

);
    rs_type_t                   rs_type[ID_WIDTH];
    fu_type_t                   fu_type[ID_WIDTH];
    logic   [3:0]               fu_opcode[ID_WIDTH];
    op1_sel_t                   op1_sel[ID_WIDTH];
    op2_sel_t                   op2_sel[ID_WIDTH];
    logic   [31:0]              imm[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rd_arch[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rs1_arch[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rs2_arch[ID_WIDTH];

    //////////////////////////
    //     Decode Stage     //
    //////////////////////////

    generate for (genvar i = 0; i < ID_WIDTH; i++) begin : decoders
        decoder decoder_i(
            .inst                   (from_fifo.packet.inst[i]),

            .rs_type                (rs_type[i]),
            .fu_type                (fu_type[i]),
            .fu_opcode              (fu_opcode[i]),
            .op1_sel                (op1_sel[i]),
            .op2_sel                (op2_sel[i]),
            .imm                    (imm[i]),
            .rd_arch                (rd_arch[i]),
            .rs1_arch               (rs1_arch[i]),
            .rs2_arch               (rs2_arch[i])
        );

        assign uops[i].valid = from_fifo.packet.valid[i];
        assign uops[i].pc = from_fifo.packet.pc + unsigned'(i) * 4;
        assign uops[i].inst = from_fifo.packet.inst[i];
        assign uops[i].rs_type = rs_type[i];
        assign uops[i].fu_type = fu_type[i];
        assign uops[i].fu_opcode = fu_opcode[i];
        assign uops[i].op1_sel = op1_sel[i];
        assign uops[i].op2_sel = op2_sel[i];
        assign uops[i].imm = imm[i];
        assign uops[i].rd_arch = rd_arch[i];
        assign uops[i].rs1_arch = rs1_arch[i];
        assign uops[i].rs2_arch = rs2_arch[i];
        assign uops[i].predict_taken = from_fifo.packet.predict_taken[i];
        assign uops[i].predict_target = from_fifo.packet.predict_target[i];
    end endgenerate


    //////////////////////////
    //     Rename Stage     //
    //////////////////////////

    // Pop from free list if we do need destination register
    assign to_fl.valid = from_fifo.valid && to_rob.ready && nxt_ready && (rd_arch[0] != '0);

    // Read from RAT
    assign to_rat.read_arch[0] = rs1_arch[0];
    assign to_rat.read_arch[1] = rs2_arch[0];
    assign uops[0].rs1_phy = to_rat.read_phy[0];
    assign uops[0].rs1_valid = to_rat.read_valid[0];
    assign uops[0].rs2_phy = to_rat.read_phy[1];
    assign uops[0].rs2_valid = to_rat.read_valid[1];

    // Write to RAT if we do need destination register
    assign to_rat.write_en = from_fifo.valid && to_fl.ready && to_rob.ready && nxt_ready && (rd_arch[0] != '0);
    assign to_rat.write_arch = uops[0].rd_arch;
    assign to_rat.write_phy = to_fl.free_idx;
    assign uops[0].rd_phy = (rd_arch[0] != '0) ? to_fl.free_idx : '0;

    // Notify ROB
    assign to_rob.valid = from_fifo.valid && to_fl.ready && nxt_ready;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rob.inst_valid[i] = from_fifo.packet.valid[i];
        assign to_rob.rd_phy[i] = uops[i].rd_phy;
        assign to_rob.rd_arch[i] = uops[i].rd_arch;
        assign uops[i].rob_id = to_rob.rob_id[i];
    end endgenerate


    //////////////////////////
    //    Dispatch Stage    //
    //////////////////////////

    assign nxt_valid = from_fifo.valid && to_fl.ready && to_rob.ready;

    // Backpressure Ready signal
    assign from_fifo.ready = to_fl.ready && to_rob.ready && nxt_ready;


    //////////////////////////
    //          RVFI        //
    //////////////////////////

    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rob.rvfi_dbg[i].order = 'x;
        assign to_rob.rvfi_dbg[i].inst = uops[i].inst;
        assign to_rob.rvfi_dbg[i].rs1_addr = uops[i].rs1_arch;
        assign to_rob.rvfi_dbg[i].rs2_addr = uops[i].rs2_arch;
        assign to_rob.rvfi_dbg[i].rs1_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rs2_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rd_addr = uops[i].rd_arch;
        assign to_rob.rvfi_dbg[i].rd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].frd_addr = 'x;
        assign to_rob.rvfi_dbg[i].frd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].pc_rdata = uops[i].pc;
        assign to_rob.rvfi_dbg[i].pc_wdata = 'x;
        assign to_rob.rvfi_dbg[i].mem_addr = 'x;
        assign to_rob.rvfi_dbg[i].mem_rmask = 'x;
        assign to_rob.rvfi_dbg[i].mem_wmask = 'x;
        assign to_rob.rvfi_dbg[i].mem_rdata = 'x;
        assign to_rob.rvfi_dbg[i].mem_wdata = 'x;
    end endgenerate

endmodule
