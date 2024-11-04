module id_stage
import cpu_params::*;
import uop_types::*;
(
    // input   logic               clk,
    // input   logic               rst,

    // Instruction queue
    fifo_backend_itf.backend    from_fifo,

    // RAT
    id_rat_itf.id               to_rat,

    // Free List
    id_fl_itf.id                to_fl,

    // ROB
    id_rob_itf.id               to_rob,

    // INT Reservation Stations
    id_int_rs_itf.id            to_int_rs,

    // INTM Reservation Stations
    id_int_rs_itf.id            to_intm_rs

);
    uop_t                       uop[ID_WIDTH];
    rs_type_t                   rs_type[ID_WIDTH];
    fu_type_t                   fu_type[ID_WIDTH];
    logic   [3:0]               fu_opcode[ID_WIDTH];
    op1_sel_t                   op1_sel[ID_WIDTH];
    op2_sel_t                   op2_sel[ID_WIDTH];
    logic   [31:0]              imm[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rd_arch[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rs1_arch[ID_WIDTH];
    logic   [ARF_IDX-1:0]       rs2_arch[ID_WIDTH];
    logic                       inst_invalid[ID_WIDTH];

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
            .rs2_arch               (rs2_arch[i]),
            .inst_invalid           (inst_invalid[i])
        );

        assign uop[i].pc = from_fifo.packet.pc;
        assign uop[i].inst = from_fifo.packet.inst[i];
        assign uop[i].rs_type = rs_type[i];
        assign uop[i].fu_type = fu_type[i];
        assign uop[i].fu_opcode = fu_opcode[i];
        assign uop[i].op1_sel = op1_sel[i];
        assign uop[i].op2_sel = op2_sel[i];
        assign uop[i].imm = imm[i];
        assign uop[i].rd_arch = rd_arch[i];
        assign uop[i].rs1_arch = rs1_arch[i];
        assign uop[i].rs2_arch = rs2_arch[i];
    end endgenerate


    //////////////////////////
    //     Rename Stage     //
    //////////////////////////

    // Pop from free list if we do need destination register
    logic rs_ready;
    assign rs_ready = (to_int_rs.ready && (rs_type[0] == RS_INT)) || (to_intm_rs.ready && (rs_type[0] == RS_INTM));
    assign to_fl.valid = from_fifo.valid && to_rob.ready && rs_ready && (rd_arch[0] != '0)  && ~inst_invalid[0];

    // Read from RAT
    assign to_rat.read_arch[0] = rs1_arch[0];
    assign to_rat.read_arch[1] = rs2_arch[0];
    assign uop[0].rs1_phy = to_rat.read_phy[0];
    assign uop[0].rs1_valid = to_rat.read_valid[0];
    assign uop[0].rs2_phy = to_rat.read_phy[1];
    assign uop[0].rs2_valid = to_rat.read_valid[1];

    // Write to RAT if we do need destination register
    assign to_rat.write_en = from_fifo.valid && to_fl.ready && to_rob.ready && rs_ready && (rd_arch[0] != '0) && ~inst_invalid[0];
    assign to_rat.write_arch = uop[0].rd_arch;
    assign to_rat.write_phy = to_fl.free_idx;
    assign uop[0].rd_phy = (rd_arch[0] != '0) ? to_fl.free_idx : '0;

    // Notify ROB
    assign to_rob.valid = from_fifo.valid && to_fl.ready && rs_ready && ~inst_invalid[0];
    assign to_rob.inst_valid[0] = from_fifo.packet.valid[0];
    assign to_rob.rd_phy[0] = uop[0].rd_phy;
    assign to_rob.rd_arch[0] = uop[0].rd_arch;
    assign uop[0].rob_id = to_rob.rob_id[0];


    //////////////////////////
    //    Dispatch Stage    //
    //////////////////////////

    // Dispatch to INT Reservation Stations
    assign to_int_rs.valid = from_fifo.valid && to_fl.ready && to_rob.ready && (rs_type[0] == RS_INT) && ~inst_invalid[0];
    assign to_int_rs.uop = uop[0];

    // Dispatch to INTM Reservation Stations
    assign to_intm_rs.valid = from_fifo.valid && to_fl.ready && to_rob.ready && (rs_type[0] == RS_INTM) && ~inst_invalid[0];
    assign to_intm_rs.uop = uop[0];

    // Backpressure Ready signal
    assign from_fifo.ready = to_fl.ready && to_rob.ready && rs_ready && ~inst_invalid[0];

    //////////////////////////
    //          RVFI        //
    //////////////////////////
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rob.rvfi_dbg[i].order = 'x;
        assign to_rob.rvfi_dbg[i].inst = uop[i].inst;
        assign to_rob.rvfi_dbg[i].rs1_addr = uop[i].rs1_arch;
        assign to_rob.rvfi_dbg[i].rs2_addr = uop[i].rs2_arch;
        assign to_rob.rvfi_dbg[i].rs1_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rs2_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rd_addr = uop[i].rd_arch;
        assign to_rob.rvfi_dbg[i].rd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].frd_addr = 'x;
        assign to_rob.rvfi_dbg[i].frd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].pc_rdata = uop[i].pc;
        assign to_rob.rvfi_dbg[i].pc_wdata = 'x;
        assign to_rob.rvfi_dbg[i].mem_addr = 'x;
        assign to_rob.rvfi_dbg[i].mem_rmask = 'x;
        assign to_rob.rvfi_dbg[i].mem_wmask = 'x;
        assign to_rob.rvfi_dbg[i].mem_rdata = 'x;
        assign to_rob.rvfi_dbg[i].mem_wdata = 'x;
    end endgenerate

endmodule
