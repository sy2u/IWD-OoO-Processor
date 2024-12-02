module intm_rs_normal
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out
);

    //---------------------------------------------------------------------------------
    // Reservation Stations:
    //---------------------------------------------------------------------------------

    logic   [INTMRS_DEPTH-1:0]          rs_valid;
    logic   [INTMRS_DEPTH-1:0]          rs_request;
    logic   [INTMRS_DEPTH-1:0]          rs_grant;
    logic   [INTMRS_DEPTH-1:0]          rs_push_en;
    intm_rs_entry_t [INTMRS_DEPTH-1:0]  rs_entry;
    intm_rs_entry_t [INTMRS_DEPTH-1:0]  rs_entry_in;
    intm_rs_entry_t [ID_WIDTH-1:0]      from_ds_entry;
    intm_rs_entry_t                     issued_entry;

    always_comb begin
        for (int w = 0; w < ID_WIDTH; w++) begin
            from_ds_entry[w].rob_id     = from_ds.uop[w].rob_id;
            from_ds_entry[w].rs1_phy    = from_ds.uop[w].rs1_phy;
            from_ds_entry[w].rs1_valid  = from_ds.uop[w].rs1_valid;
            from_ds_entry[w].rs2_phy    = from_ds.uop[w].rs2_phy;
            from_ds_entry[w].rs2_valid  = from_ds.uop[w].rs2_valid;
            from_ds_entry[w].rd_phy     = from_ds.uop[w].rd_phy;
            from_ds_entry[w].rd_arch    = from_ds.uop[w].rd_arch;
            from_ds_entry[w].fu_opcode  = from_ds.uop[w].fu_opcode;
        end
    end

    generate for (genvar i = 0; i < INTMRS_DEPTH; i++) begin : rs_array
        rs_entry #(
            .RS_ENTRY_T (intm_rs_entry_t)
        ) intm_rs_entry_i (
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
            .wakeup_cdb (cdb)
        );
    end endgenerate

    // Push Logic
    // A bit nasty
    logic   [INTMRS_DEPTH-1:0]   [ID_WIDTH-1:0]  entry_push_en_arr;
    logic   [INTMRS_DEPTH-1:0]                   allocated;

    always_comb begin
        for (int i = 0; i < INTMRS_DEPTH; i++) begin
            entry_push_en_arr[i] = '0;
        end
        allocated = '0;
        for (int w = 0; w < ID_WIDTH; w++) begin
            if (from_ds.valid[w] && from_ds.ready) begin
                // Look for first available RS entry not already allocated this cycle
                for (int i = 0; i < INTMRS_DEPTH; i++) begin
                    if (!rs_valid[(INTMRS_IDX)'(unsigned'(i))] && !allocated[i]) begin
                        entry_push_en_arr[i][w] = 1'b1;
                        allocated[i] = 1'b1;  // Mark this entry as allocated
                        break;
                    end
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < INTMRS_DEPTH; i++) begin
            rs_push_en[i] = |entry_push_en_arr[i];
        end
    end

    generate for (genvar i = 0; i < INTMRS_DEPTH; i++) begin : push_muxes
        one_hot_mux #(
            .T          (intm_rs_entry_t),
            .NUM_INPUTS (ID_WIDTH)
        ) push_mux (
            .data_in    (from_ds_entry),
            .select     (entry_push_en_arr[i]),
            .data_out   (rs_entry_in[i])
        );
    end endgenerate

    // Issue Logic
    // loop from top and issue the first entry requesting for issue
    logic           fu_md_ready;

    always_comb begin
        rs_grant = '0;
        for (int i = 0; i < INTMRS_DEPTH; i++) begin
            if (rs_request[i] && fu_md_ready) begin
                rs_grant[i] = 1'b1;
                break;
            end
        end
    end

    // One-hot mux to select the issued entry
    one_hot_mux #(
        .T          (intm_rs_entry_t),
        .NUM_INPUTS (INTMRS_DEPTH)
    ) ohm (
        .data_in    (rs_entry),
        .select     (rs_grant),
        .data_out   (issued_entry)
    );

    // ready logic
    logic   [INTMRS_IDX:0]    n_available_slots;
    always_comb begin
        n_available_slots = '0;
        for (int i = 0; i < INTMRS_DEPTH; i++) begin 
            if (~rs_valid[i]) begin 
                n_available_slots = (INTMRS_IDX+1)'(n_available_slots + 1);
            end
        end
    end
    assign from_ds.ready = (n_available_slots >= (INTMRS_IDX+1)'(ID_WIDTH));

    //---------------------------------------------------------------------------------
    // INTM_RS Reg:
    //---------------------------------------------------------------------------------

    logic           intm_rs_in_valid;
    intm_rs_reg_t   intm_rs_in;
    logic           fu_md_valid;

    // communicate with prf
    assign to_prf.rs1_phy = issued_entry.rs1_phy;
    assign to_prf.rs2_phy = issued_entry.rs2_phy;

    assign intm_rs_in_valid = |rs_request;

    // update intm_rs_in
    always_comb begin
        intm_rs_in.rob_id      = issued_entry.rob_id;
        intm_rs_in.rd_phy      = issued_entry.rd_phy;
        intm_rs_in.rd_arch     = issued_entry.rd_arch;
        intm_rs_in.fu_opcode   = issued_entry.fu_opcode;
        intm_rs_in.rs1_value   = to_prf.rs1_value;
        intm_rs_in.rs2_value   = to_prf.rs2_value;
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------
    fu_md fu_md_i(
        .clk(clk),
        .rst(rst),
        .flush('0),
        .prv_valid(intm_rs_in_valid),
        .prv_ready(fu_md_ready),
        .nxt_valid(fu_md_valid),
        .nxt_ready('1),
        .intm_rs_in(intm_rs_in),
        .cdb(fu_cdb_out)
    );

    // fu_mul fu_mul_i(
    //     .clk(clk),
    //     .rst(rst),
    //     .flush('0),
    //     .prv_valid(intm_rs_in_valid),
    //     .prv_ready(fu_md_ready),
    //     .nxt_valid(fu_md_valid),
    //     .nxt_ready('1), // RS is basically ff, always ready
    //     .intm_rs_in(intm_rs_in),
    //     .cdb(fu_cdb_out)
    // );

endmodule
