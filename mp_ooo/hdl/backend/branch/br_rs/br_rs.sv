module br_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs        	from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    br_cdb_itf.fu               br_cdb_out,
    input   logic               branch_ready,
    input bypass_network_t      alu_bypass
);
    ///////////////////////////
    // Reservation Stations  //
    ///////////////////////////

    logic   [BRRS_DEPTH-1:0]            rs_valid;
    logic   [BRRS_DEPTH-1:0]            rs_request;
    logic   [BRRS_DEPTH-1:0]            rs_grant;
    logic   [BRRS_DEPTH-1:0]            rs_push_en;
    br_rs_entry_t   [BRRS_DEPTH-1:0]    rs_entry;
    br_rs_entry_t   [BRRS_DEPTH-1:0]    rs_entry_in;
    br_rs_entry_t                       from_ds_entry;
    br_rs_entry_t                       issued_entry;

    assign from_ds_entry.rob_id     = from_ds.uop.rob_id;
    assign from_ds_entry.rs1_phy    = from_ds.uop.rs1_phy;
    assign from_ds_entry.rs1_valid  = from_ds.uop.rs1_valid;
    assign from_ds_entry.rs2_phy    = from_ds.uop.rs2_phy;
    assign from_ds_entry.rs2_valid  = from_ds.uop.rs2_valid;
    assign from_ds_entry.rd_phy     = from_ds.uop.rd_phy;
    assign from_ds_entry.rd_arch    = from_ds.uop.rd_arch;
    assign from_ds_entry.imm        = from_ds.uop.imm;
    assign from_ds_entry.pc         = from_ds.uop.pc;
    assign from_ds_entry.fu_opcode  = from_ds.uop.fu_opcode;
    assign from_ds_entry.predict_taken = from_ds.uop.predict_taken;
    assign from_ds_entry.predict_target = from_ds.uop.predict_target;

    generate for (genvar i = 0; i < BRRS_DEPTH; i++) begin : rs_array
        rs_entry #(
            .RS_ENTRY_T (br_rs_entry_t)
        ) br_rs_entry_i (
            .clk        (clk),
            .rst        (rst),

            .valid      (rs_valid[i]),
            .request    (rs_request[i]),
            .grant      (rs_grant[i]),

            .push_en    (rs_push_en[i]),
            .entry_in   (rs_entry_in[i]),
            .entry_out  (),
            .entry      (rs_entry[i]),
            .clear      (1'b0),
            .wakeup_cdb (cdb),
            .fast_bypass (alu_bypass)
        );
    end endgenerate

    // Push Logic
    logic   [BRRS_DEPTH-1:0]   entry_push_en_arr;

    always_comb begin
        rs_push_en = '0;
        if (from_ds.valid && branch_ready) begin
            // Look for first available RS entry
            for (int i = 0; i < BRRS_DEPTH; i++) begin
                if (!rs_valid[(BRRS_IDX)'(unsigned'(i))]) begin
                    rs_push_en[i] = 1'b1;
                    break;
                end
            end
        end
    end

    generate for (genvar i = 0; i < BRRS_DEPTH; i++) begin : push_muxes
        assign rs_entry_in[i] = from_ds_entry;
    end endgenerate

    // Issue Logic
    // loop from top and issue the first entry requesting for issue
    always_comb begin
        rs_grant = '0;
        for (int i = 0; i < BRRS_DEPTH; i++) begin
            if (rs_request[i]) begin
                rs_grant[i] = 1'b1;
                break;
            end
        end
    end

    one_hot_mux #(
        .T          (br_rs_entry_t),
        .NUM_INPUTS (BRRS_DEPTH)
    ) ohm (
        .data_in    (rs_entry),
        .select     (rs_grant),
        .data_out   (issued_entry)
    );

    // full logic, set rs.ready to 0 if rs is full
    assign from_ds.ready = |(~rs_valid);

    // communicate with prf
    assign to_prf.rs1_phy = issued_entry.rs1_phy;
    assign to_prf.rs2_phy = issued_entry.rs2_phy;

    //////////////////////
    // BR_RS to FU_ALU //
    //////////////////////
    logic           br_rs_valid;
    logic           fu_br_ready;
    fu_br_reg_t     fu_br_reg_in;

    // handshake with fu_alu_reg:
    assign br_rs_valid = |rs_request;

    // send data to fu_alu_reg
    assign fu_br_reg_in.rob_id         = issued_entry.rob_id;
    assign fu_br_reg_in.rd_phy         = issued_entry.rd_phy;
    assign fu_br_reg_in.rd_arch        = issued_entry.rd_arch;
    assign fu_br_reg_in.fu_opcode      = issued_entry.fu_opcode;
    assign fu_br_reg_in.imm            = issued_entry.imm;
    assign fu_br_reg_in.pc             = issued_entry.pc;
    assign fu_br_reg_in.predict_taken  = issued_entry.predict_taken;
    assign fu_br_reg_in.predict_target = issued_entry.predict_target;

    assign fu_br_reg_in.rs1_value      = (alu_bypass.valid && alu_bypass.rd_phy == issued_entry.rs1_phy) ? alu_bypass.rd_value :  to_prf.rs1_value;
    assign fu_br_reg_in.rs2_value      = (alu_bypass.valid && alu_bypass.rd_phy == issued_entry.rs2_phy) ? alu_bypass.rd_value :  to_prf.rs2_value;

    // Functional Units
    fu_br fu_br_i(
        .clk                    (clk),
        .rst                    (rst),

        .br_rs_valid            (br_rs_valid),
        .fu_br_ready            (fu_br_ready),
        .fu_br_reg_in           (fu_br_reg_in),
        .cdb                    (fu_cdb_out),
        .br_cdb                 (br_cdb_out)
    );

    // pipeline_reg 

endmodule
