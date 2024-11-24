module id_stage
import cpu_params::*;
import uop_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // Instruction queue
    fifo_backend_itf.backend    from_fifo,

    // handshake with dispatch stage
    output  logic               nxt_valid,
    input   logic               nxt_ready,
    output  logic               uops_valid[ID_WIDTH],
    output  rs_type_t           rs_type[ID_WIDTH],
    output  uop_t               uops[ID_WIDTH],

    // RAT
    id_rat_itf.id               to_rat,

    // Free List
    id_fl_itf.id                to_fl,

    // ROB
    id_rob_itf.id               to_rob

);
    logic                       uops_raw_valid[ID_WIDTH];
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

        assign uops_raw_valid[i] = from_fifo.packet.valid[i];
        assign uops[i].valid = uops_valid[i];
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
    //     Filter Stage     //
    //////////////////////////

    generate if (ID_WIDTH == 2) begin : filter_2way

        logic   [ID_WIDTH-1:0]  already_dispatched;
        logic   [ID_WIDTH-1:0]  uops_is_br;
        logic   [ID_WIDTH-1:0]  uops_is_mem;
        logic   [ID_WIDTH-1:0]  dispatch_mask;

        always_comb begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                uops_is_br[i] = (rs_type[i] == RS_BR) && uops_raw_valid[i] && from_fifo.valid;
                uops_is_mem[i] = (rs_type[i] == RS_MEM) && uops_raw_valid[i] && from_fifo.valid;
            end
        end

        always_ff @(posedge clk) begin
            if (rst) begin
                already_dispatched <= 2'b11;
            end else begin
                if (uops_is_br[0] || (uops_is_mem[0] && uops_is_mem[1])) begin
                    if (already_dispatched == 2'b11 && to_fl.ready && to_rob.ready && nxt_ready) begin
                        already_dispatched <= 2'b01;
                    end else if (already_dispatched == 2'b01 && to_fl.ready && to_rob.ready && nxt_ready) begin
                        already_dispatched <= 2'b11;
                    end
                end else begin
                    already_dispatched <= 2'b11;
                end
            end
        end

        always_comb begin
            dispatch_mask = 2'b11;
            if (uops_is_br[0]) begin
                if (already_dispatched == 2'b11) begin
                    dispatch_mask = 2'b01;
                end else begin
                    dispatch_mask = 2'b10;
                end
            end
            if (uops_is_mem[0] && uops_is_mem[1]) begin
                if (already_dispatched == 2'b11) begin
                    dispatch_mask = 2'b01;
                end else begin
                    dispatch_mask = 2'b10;
                end
            end
        end

        always_comb begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                uops_valid[i] = uops_raw_valid[i] && dispatch_mask[i] && from_fifo.packet.inst[i] != '0;
            end
        end

        // Backpressure Ready signal
        always_comb begin
            from_fifo.ready = 1'b0;
            if (uops_is_br[0] || (uops_is_mem[0] && uops_is_mem[1])) begin
                from_fifo.ready = already_dispatched == 2'b01 && to_fl.ready && to_rob.ready && nxt_ready;
            end else begin
                from_fifo.ready = to_fl.ready && to_rob.ready && nxt_ready;
            end
        end

    end endgenerate

    generate if (ID_WIDTH == 1) begin : filter_1way
        assign uops_valid[0] = uops_raw_valid[0] && from_fifo.packet.inst[0] != '0;
        assign from_fifo.ready = to_fl.ready && to_rob.ready && nxt_ready;
    end endgenerate

    //////////////////////////
    //     Rename Stage     //
    //////////////////////////

    // Pop from free list if we do need destination register
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_fl.valid[i] = from_fifo.valid && uops_valid[i] && to_rob.ready && nxt_ready && (rd_arch[i] != '0);
    end endgenerate

    // Read from RAT
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rat.rs1_arch[i] = rs1_arch[i];
        assign to_rat.rs2_arch[i] = rs2_arch[i];
        assign uops[i].rs1_phy = to_rat.rs1_phy[i];
        assign uops[i].rs1_valid = to_rat.rs1_valid[i];
        assign uops[i].rs2_phy = to_rat.rs2_phy[i];
        assign uops[i].rs2_valid = to_rat.rs2_valid[i];
    end endgenerate

    // Write to RAT if we do need destination register
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rat.write_en[i] = from_fifo.valid && uops_valid[i] && to_fl.ready && to_rob.ready && nxt_ready && (rd_arch[i] != '0);
        assign to_rat.rd_arch[i] = rd_arch[i];
        assign to_rat.rd_phy[i] = to_fl.free_idx[i];
        assign uops[i].rd_phy = (rd_arch[i] != '0) ? to_fl.free_idx[i] : '0;
    end endgenerate

    // Notify ROB
    assign to_rob.valid = from_fifo.valid && to_fl.ready && nxt_ready;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rob.inst_valid[i] = uops_valid[i];
        assign to_rob.rd_phy[i] = uops[i].rd_phy;
        assign to_rob.rd_arch[i] = rd_arch[i];
        assign uops[i].rob_id = to_rob.rob_id[i];
    end endgenerate


    //////////////////////////
    //    Dispatch Stage    //
    //////////////////////////

    assign nxt_valid = from_fifo.valid && to_fl.ready && to_rob.ready;


    //////////////////////////
    //          RVFI        //
    //////////////////////////

    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rob.rvfi_dbg[i].order = 'x;
        assign to_rob.rvfi_dbg[i].inst = uops[i].inst;
        assign to_rob.rvfi_dbg[i].rs1_addr = rs1_arch[i];
        assign to_rob.rvfi_dbg[i].rs2_addr = rs2_arch[i];
        assign to_rob.rvfi_dbg[i].rs1_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rs2_rdata = 'x;
        assign to_rob.rvfi_dbg[i].rd_addr = rd_arch[i];
        assign to_rob.rvfi_dbg[i].rd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].frd_addr = 'x;
        assign to_rob.rvfi_dbg[i].frd_wdata = 'x;
        assign to_rob.rvfi_dbg[i].pc_rdata = uops[i].pc;
        assign to_rob.rvfi_dbg[i].pc_wdata = from_fifo.packet.predict_target[i];
        assign to_rob.rvfi_dbg[i].mem_addr = 'x;
        assign to_rob.rvfi_dbg[i].mem_rmask = '0;
        assign to_rob.rvfi_dbg[i].mem_wmask = '0;
        assign to_rob.rvfi_dbg[i].mem_rdata = 'x;
        assign to_rob.rvfi_dbg[i].mem_wdata = 'x;
    end endgenerate

endmodule
