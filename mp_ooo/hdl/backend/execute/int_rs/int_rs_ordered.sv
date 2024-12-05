module int_rs_ordered
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf[INT_ISSUE_WIDTH],
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out[INT_ISSUE_WIDTH],
    output bypass_network_t     alu_bypass
);

    //---------------------------------------------------------------------------------
    // Issue Queue:
    //---------------------------------------------------------------------------------

    logic   [INTRS_DEPTH-1:0]           rs_valid;
    logic   [INTRS_DEPTH-1:0]           rs_request;
    logic   [INTRS_DEPTH-1:0]           rs_grant;
    logic   [INTRS_DEPTH-1:0]           rs_push_en;
    logic   [INTRS_DEPTH-1:0]           rs_clear;
    int_rs_entry_t [INTRS_DEPTH-1:0]    rs_entry;
    int_rs_entry_t                      rs_entry_in[INTRS_DEPTH];
    int_rs_entry_t                      rs_entry_out[INTRS_DEPTH];
    int_rs_entry_t [ID_WIDTH-1:0]       from_ds_entry;
    bypass_t    [INTRS_DEPTH-1:0]       rs_bypass;

    always_comb begin
        for (int w = 0; w < ID_WIDTH; w++) begin
            from_ds_entry[w].rob_id     = from_ds.uop[w].rob_id;
            from_ds_entry[w].rs1_phy    = from_ds.uop[w].rs1_phy;
            from_ds_entry[w].rs1_valid  = from_ds.uop[w].rs1_valid;
            from_ds_entry[w].rs2_phy    = from_ds.uop[w].rs2_phy;
            from_ds_entry[w].rs2_valid  = from_ds.uop[w].rs2_valid;
            from_ds_entry[w].rd_phy     = from_ds.uop[w].rd_phy;
            from_ds_entry[w].rd_arch    = from_ds.uop[w].rd_arch;
            from_ds_entry[w].op1_sel    = from_ds.uop[w].op1_sel;
            from_ds_entry[w].op2_sel    = from_ds.uop[w].op2_sel;
            from_ds_entry[w].imm        = from_ds.uop[w].imm;
            from_ds_entry[w].fu_opcode  = from_ds.uop[w].fu_opcode;
        end
    end

    generate for (genvar i = 0; i < INTRS_DEPTH; i++) begin : rs_array
        rs_entry #(
            .RS_ENTRY_T (int_rs_entry_t)
        ) int_rs_entry_i (
            .clk            (clk),
            .rst            (rst),

            .valid          (rs_valid[i]),
            .request        (rs_request[i]),
            .grant          (rs_grant[i]),

            .push_en        (rs_push_en[i]),
            .entry_in       (rs_entry_in[i]),
            .entry_out      (rs_entry_out[i]),
            .entry          (rs_entry[i]),
            .clear          (rs_clear[i]),
            .wakeup_cdb     (cdb),
            .fast_bypass    (alu_bypass),
            .rs_bypass      (rs_bypass[i])
        );
    end endgenerate

    //---------------------------------------------------------------------------------
    // RS Control:
    //---------------------------------------------------------------------------------

    // pointer to top of the array (like a fifo queue)
    logic [INTRS_IDX-1:0]   int_rs_top, rs_top_next;

    // pop logic
    logic                   alu_ready       [INT_ISSUE_WIDTH];

    // allocate logic
    logic [ID_WIDTH-1:0]    rs_push         [INTRS_DEPTH];     // one-hot
    int_rs_entry_t          rs_push_entry   [INTRS_DEPTH];

    // issue logic
    logic                   int_rs_valid    [INT_ISSUE_WIDTH];
    logic [INTRS_DEPTH-1:0] fu_issue        [INT_ISSUE_WIDTH];  // one-hot
    int_rs_entry_t          issued_entry    [INT_ISSUE_WIDTH];

    // update mux logic
    rs_update_sel_t             rs_update_sel   [INTRS_DEPTH];
    logic [INT_ISSUE_WIDTH-1:0] rs_compress     [INTRS_DEPTH];

    ///////////////////////
    // Mux Select Logic  //
    ///////////////////////

    always_comb begin
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            // init
            rs_update_sel[i] = SELF;
            // compress
            if( rs_valid[i] & |rs_compress[i] ) rs_update_sel[i] = NEXT;
            // push
            if( |rs_push[i] ) rs_update_sel[i] = PUSH_IN;
        end
    end

    always_comb begin
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            unique case (rs_update_sel[i])
                NEXT: begin
                    if( unsigned'(i)+{30'b0, rs_compress[i]} < INTRS_DEPTH ) begin
                        rs_push_en[i] = rs_valid[unsigned'(i)+{30'b0, rs_compress[i]}];
                        rs_clear[i] = ~rs_valid[unsigned'(i)+{30'b0, rs_compress[i]}];
                    end else begin
                        rs_push_en[i] = 1'b0;
                        rs_clear[i] = 1'b1;
                    end
                end
                SELF: begin
                    rs_push_en[i] = 1'b0;
                    rs_clear[i] = 1'b0;
                end
                PUSH_IN: begin
                    rs_push_en[i] = 1'b1;
                    rs_clear[i] = 1'b0;
                end
                default: begin
                    rs_push_en[i] = 1'bx;
                    rs_clear[i] = 1'bx;
                end
            endcase
        end
    end

    always_comb begin : compress_mux 
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            unique case (rs_update_sel[i])
                NEXT: begin
                    if (unsigned'(i)+{30'b0, rs_compress[i]} < INTRS_DEPTH) begin
                        rs_entry_in[i] = rs_entry_out[unsigned'(i)+{30'b0, rs_compress[i]}];
                    end else begin
                        rs_entry_in[i] = 'x;
                    end
                end
                SELF: begin
                    rs_entry_in[i] = 'x;
                end
                PUSH_IN: begin
                    rs_entry_in[i] = rs_push_entry[i];
                end
                default: begin
                    rs_entry_in[i] = 'x;
                end
            endcase
        end
    end

    ///////////////////////
    // Push & Pop Logic  //
    ///////////////////////
    always_ff @(posedge clk) begin
        // rs array reset to all available, and top point to 0
        if (rst) begin
            int_rs_top <= '0;
        end else begin
            int_rs_top <= rs_top_next;
        end
    end

    always_comb begin
        // init
        rs_top_next = int_rs_top;
        // pop
        for( int i = 0; i < INT_ISSUE_WIDTH; i++ ) begin
            if( int_rs_valid[i] & alu_ready[i] ) begin
                rs_top_next = INTRS_IDX'(rs_top_next - 1); 
            end
        end
        // push
        for( int i = 0; i < INTRS_DEPTH; i++ ) rs_push[i] = '0;
        for( int i = 0; i < ID_WIDTH; i++ ) begin
            if( from_ds.valid[i] && from_ds.ready ) begin 
                rs_push[rs_top_next][i] = '1;
                rs_top_next = INTRS_IDX'(rs_top_next + 1);
            end
        end
    end

    generate for (genvar i = 0; i < INTRS_DEPTH; i++) begin
        one_hot_mux #(
            .T          (int_rs_entry_t),
            .NUM_INPUTS (ID_WIDTH)
        ) ohm_push (
            .data_in    (from_ds_entry),
            .select     (rs_push[i]),
            .data_out   (rs_push_entry[i])
        );
    end endgenerate

    //////////////////
    // Issue Logic  //
    //////////////////
    issue_arbiter issue_arbiter_i( 
        .rs_request(rs_request),
        .rs_grant(rs_grant),
        .rs_compress(rs_compress),
        .fu_issue(fu_issue)
    );

    generate for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin
        one_hot_mux #(
            .T          (int_rs_entry_t),
            .NUM_INPUTS (INTRS_DEPTH)
        ) ohm_entry (
            .data_in    (rs_entry),
            .select     (fu_issue[i]),
            .data_out   (issued_entry[i])
        );
        one_hot_mux #(
            .T          (bypass_t),
            .NUM_INPUTS (INTRS_DEPTH)
        ) ohm_bypass (
            .data_in    (rs_bypass),
            .select     (fu_issue[i]),
            .data_out   (to_prf[i].rs_bypass)
        );
    end endgenerate


    ////////////
    // Ready  //
    ////////////
    logic   [INTRS_IDX:0]    n_available_slots;
    always_comb begin
        n_available_slots = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (~rs_valid[i]) begin 
                n_available_slots = (INTRS_IDX+1)'(n_available_slots + 1);
            end
        end
    end
    assign from_ds.ready = (n_available_slots >= (INTRS_IDX+1)'(ID_WIDTH));

    ///////////////////////////
    // communicate with prf  //
    ///////////////////////////
    generate for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin
        assign to_prf[i].rs1_phy = issued_entry[i].rs1_phy;
        assign to_prf[i].rs2_phy = issued_entry[i].rs2_phy;
    end endgenerate

    //---------------------------------------------------------------------------------
    // INT_RS Reg to FU_ALU:
    //---------------------------------------------------------------------------------

    fu_alu_reg_t    fu_alu_reg_in   [INT_ISSUE_WIDTH];

    // send data to fu_alu_reg
    generate for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin
        always_comb begin
            fu_alu_reg_in[i].rob_id       = issued_entry[i].rob_id;
            fu_alu_reg_in[i].rd_phy       = issued_entry[i].rd_phy;
            fu_alu_reg_in[i].rd_arch      = issued_entry[i].rd_arch;
            fu_alu_reg_in[i].op1_sel      = issued_entry[i].op1_sel;
            fu_alu_reg_in[i].op2_sel      = issued_entry[i].op2_sel;
            fu_alu_reg_in[i].fu_opcode    = issued_entry[i].fu_opcode;
            fu_alu_reg_in[i].imm          = issued_entry[i].imm;

            fu_alu_reg_in[i].rs1_value    = to_prf[i].rs1_value;
            fu_alu_reg_in[i].rs2_value    = to_prf[i].rs2_value;
        end
    end endgenerate

    // handshake
    generate for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin
        assign int_rs_valid[i] = |fu_issue[i];
    end endgenerate

    // Functional Units
    bypass_network_t     fu_alu_bypass  [INT_ISSUE_WIDTH];
    assign  alu_bypass = fu_alu_bypass[0];

    generate for (genvar i = 0; i < INT_ISSUE_WIDTH; i++) begin : alu
        fu_alu fu_alu_i(
            .clk                    (clk),
            .rst                    (rst),
            .int_rs_valid           (int_rs_valid[i]),
            .fu_alu_ready           (alu_ready[i]),
            .fu_alu_reg_in          (fu_alu_reg_in[i]),
            .bypass                 (fu_alu_bypass[i]),
            .cdb                    (fu_cdb_out[i])
        );
    end endgenerate

endmodule
