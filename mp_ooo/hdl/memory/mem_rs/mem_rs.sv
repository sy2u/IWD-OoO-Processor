module mem_rs
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    agu_lsq_itf.agu             to_lsq,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    ///////////////////////////
    // Reservation Stations  //
    ///////////////////////////

    logic   [MEMRS_DEPTH-1:0]            rs_valid;
    logic   [MEMRS_DEPTH-1:0]            rs_request;
    logic   [MEMRS_DEPTH-1:0]            rs_grant;
    logic   [MEMRS_DEPTH-1:0]            rs_push_en;
    mem_rs_entry_t   [MEMRS_DEPTH-1:0]   rs_entry;
    mem_rs_entry_t   [MEMRS_DEPTH-1:0]   rs_entry_in;
    mem_rs_entry_t                       from_ds_entry;
    mem_rs_entry_t                       issued_entry;
    bypass_t   [MEMRS_DEPTH-1:0]         rs_bypass;

    always_comb begin
        from_ds_entry.rob_id     = from_ds.uop.rob_id;
        from_ds_entry.rs1_phy    = from_ds.uop.rs1_phy;
        from_ds_entry.rs1_valid  = from_ds.uop.rs1_valid;
        from_ds_entry.rs2_phy    = from_ds.uop.rs2_phy;
        from_ds_entry.rs2_valid  = from_ds.uop.rs2_valid;
        from_ds_entry.imm        = from_ds.uop.imm;
        from_ds_entry.fu_opcode  = from_ds.uop.fu_opcode;
    end

    generate for (genvar i = 0; i < MEMRS_DEPTH; i++) begin : rs_array
        rs_entry #(
            .RS_ENTRY_T (mem_rs_entry_t)
        ) mem_rs_entry_i (
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
            .fast_bypass(alu_bypass),
            .rs_bypass  (rs_bypass[i])
        );
    end endgenerate

    // Push Logic
    logic   [MEMRS_DEPTH-1:0]   entry_push_en_arr;

    always_comb begin
        rs_push_en = '0;
        if (from_ds.valid && from_ds.ready) begin
            // Look for first available RS entry
            for (int i = 0; i < MEMRS_DEPTH; i++) begin
                if (!rs_valid[(MEMRS_IDX)'(unsigned'(i))]) begin
                    rs_push_en[i] = 1'b1;
                    break;
                end
            end
        end
    end

    generate for (genvar i = 0; i < MEMRS_DEPTH; i++) begin : push_muxes
        assign rs_entry_in[i] = from_ds_entry;
    end endgenerate

    // Issue Logic
    // loop from top and issue the first entry requesting for issue
    always_comb begin
        rs_grant = '0;
        for (int i = 0; i < MEMRS_DEPTH; i++) begin
            if (rs_request[i]) begin
                rs_grant[i] = 1'b1;
                break;
            end
        end
    end

    one_hot_mux #(
        .T          (mem_rs_entry_t),
        .NUM_INPUTS (MEMRS_DEPTH)
    ) ohm (
        .data_in    (rs_entry),
        .select     (rs_grant),
        .data_out   (issued_entry)
    );

    one_hot_mux #(
        .T          (bypass_t),
        .NUM_INPUTS (MEMRS_DEPTH)
    ) ohm_rs1 (
        .data_in    (rs_bypass),
        .select     (rs_grant),
        .data_out   (to_prf.rs_bypass)
    );

    // full logic, set rs.ready to 0 if rs is full
    assign from_ds.ready = |(~rs_valid);

    // communicate with prf
    assign to_prf.rs1_phy = issued_entry.rs1_phy;
    assign to_prf.rs2_phy = issued_entry.rs2_phy;

    ///////////////////////
    // INT_MEM to FU_AGU //
    ///////////////////////
    agu_reg_t       agu_reg_in;
    agu_lsq_t       agu_lsq;

    assign agu_reg_in.rob_id = issued_entry.rob_id;
    assign agu_reg_in.fu_opcode = issued_entry.fu_opcode;
    assign agu_reg_in.imm = issued_entry.imm;
    assign agu_reg_in.rs1_value = to_prf.rs1_value;
    assign agu_reg_in.rs2_value = to_prf.rs2_value;

    fu_agu fu_agu_i(
        .clk(clk),
        .rst(rst),

        .prv_valid  (|rs_request),
        .prv_ready  (),
        .agu_reg_in (agu_reg_in),

        .nxt_valid  (to_lsq.valid),
        .to_lsq     (to_lsq.data)
    );

endmodule
