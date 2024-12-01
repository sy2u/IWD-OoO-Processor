module int_rs_ordered
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
    ///////////////////////////
    // Reservation Stations  //
    ///////////////////////////

    logic   [INTRS_DEPTH-1:0]           rs_valid;
    // logic   [INTRS_DEPTH-1:0]           rs_will_be_valid;
    logic   [INTRS_DEPTH-1:0]           rs_request;
    logic   [INTRS_DEPTH-1:0]           rs_grant;
    logic   [INTRS_DEPTH-1:0]           rs_push_en;
    logic   [INTRS_DEPTH-1:0]           rs_clear;
    int_rs_entry_t                      rs_entry[INTRS_DEPTH];
    int_rs_entry_t                      rs_entry_in[INTRS_DEPTH];
    int_rs_entry_t                      rs_entry_out[INTRS_DEPTH];
    int_rs_entry_t                      from_ds_entry[ID_WIDTH];
    int_rs_entry_t                      issued_entry;

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
            // .will_be_valid  (rs_will_be_valid[i]),
            .request        (rs_request[i]),
            .grant          (rs_grant[i]),

            .push_en        (rs_push_en[i]),
            .entry_in       (rs_entry_in[i]),
            .entry_out      (rs_entry_out[i]),
            .entry          (rs_entry[i]),
            .clear          (rs_clear[i]),
            .wakeup_cdb     (cdb)
        );
    end endgenerate

    // pointer to top of the array (like a fifo queue)
    logic [INTRS_IDX-1:0]   int_rs_top, rs_top_next;
    // pop logic
    logic                   int_rs_pop_en;
    logic                   int_rs_valid;
    logic                   fu_alu_ready;

    // push logic
    logic                   int_rs_push_en    [ID_WIDTH];
    logic [INTRS_IDX-1:0]   int_rs_push_idx   [ID_WIDTH];

    // issue logic
    logic                   int_rs_issue_en;
    logic [INTRS_IDX-1:0]   int_rs_issue_idx;

    // update logic
    rs_update_sel_t         rs_update_sel   [INTRS_DEPTH];
    logic [ID_WIDTH_IDX-1:0]rs_push_sel     [INTRS_DEPTH];

    bypass_network_t        fu_alu_bypass;

    // rs available update
    always_ff @(posedge clk) begin
        // rs array reset to all available, and top point to 0
        if (rst) begin
            int_rs_top <= '0;
        end else begin
            int_rs_top <= rs_top_next;
        end
    end

    // mux select logic
    always_comb begin : compress_control
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            rs_push_sel[i] = '0;
            rs_update_sel[i] = SELF;
            if( int_rs_pop_en ) begin
                if( (INTRS_IDX)'(unsigned'(i))>=int_rs_issue_idx ) rs_update_sel[i] = PREV;
            end
            for( int j = 0; j < ID_WIDTH; j++ ) begin 
                if ( int_rs_push_en[j] && ((INTRS_IDX)'(unsigned'(i)) == int_rs_push_idx[j]) ) begin
                    rs_update_sel[i] = PUSH_IN;
                    rs_push_sel[i] = ID_WIDTH_IDX'(unsigned'(j));
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            unique case (rs_update_sel[i])
                PREV: begin
                    if( i < INTRS_DEPTH-1 ) begin
                        rs_push_en[i] = rs_valid[i+1];
                        rs_clear[i] = !rs_valid[i+1];
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

    always_comb begin : compress_mux // single issue type, one-slot compress
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            unique case (rs_update_sel[i])
                PREV: begin
                    if (i < INTRS_DEPTH-1) begin
                        rs_entry_in[i] = rs_entry_out[i+1];
                    end else begin
                        rs_entry_in[i] = 'x;
                    end
                end
                SELF: begin
                    rs_entry_in[i] = 'x;
                end
                PUSH_IN: begin
                    rs_entry_in[i] = from_ds_entry[rs_push_sel[i]];
                end
                default: begin
                    rs_entry_in[i] = 'x;
                end
            endcase
        end
    end

    // push and pop logic
    always_comb begin
        rs_top_next = int_rs_top;
        // pop
        int_rs_pop_en = '0;
        if( int_rs_valid && fu_alu_ready ) begin 
            int_rs_pop_en = '1;
            rs_top_next = INTRS_IDX'(rs_top_next - 1); 
        end
        // push
        for( int i = 0; i < ID_WIDTH; i++ ) begin
            int_rs_push_en[i] = '0;
            int_rs_push_idx[i] = 'x;
            if( from_ds.valid[i] && from_ds.ready ) begin 
                int_rs_push_en[i] = '1;
                int_rs_push_idx[i] = rs_top_next;
                rs_top_next = INTRS_IDX'(rs_top_next + 1);
            end
        end
    end

    // Issue Logic
    // loop from top and issue the first entry requesting for issue
    always_comb begin
        rs_grant = '0;
        int_rs_issue_idx = 'x;
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            if (rs_request[i]) begin
                rs_grant[i] = 1'b1;
                int_rs_issue_idx = (INTRS_IDX)'(unsigned'(i));
                break;
            end
        end
    end

    assign issued_entry = rs_entry[int_rs_issue_idx];

    // ready logic
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

    // communicate with prf
    assign to_prf.rs1_phy = issued_entry.rs1_phy;
    assign to_prf.rs2_phy = issued_entry.rs2_phy;

    //////////////////////
    // INT_RS to FU_ALU //
    //////////////////////
    fu_alu_reg_t    fu_alu_reg_in;

    // handshake with fu_alu_reg:
    assign int_rs_valid = |rs_grant;

    // send data to fu_alu_reg
    always_comb begin
        fu_alu_reg_in.rob_id       = issued_entry.rob_id;
        fu_alu_reg_in.rd_phy       = issued_entry.rd_phy;
        fu_alu_reg_in.rd_arch      = issued_entry.rd_arch;
        fu_alu_reg_in.op1_sel      = issued_entry.op1_sel;
        fu_alu_reg_in.op2_sel      = issued_entry.op2_sel;
        fu_alu_reg_in.fu_opcode    = issued_entry.fu_opcode;
        fu_alu_reg_in.imm          = issued_entry.imm;

        fu_alu_reg_in.rs1_value    = to_prf.rs1_value;
        fu_alu_reg_in.rs2_value    = to_prf.rs2_value;
    end


    // Functional Units
    fu_alu fu_alu_i(
        .clk                    (clk),
        .rst                    (rst),
        .int_rs_valid           (int_rs_valid),
        .fu_alu_ready           (fu_alu_ready),
        .fu_alu_reg_in          (fu_alu_reg_in),
        .bypass                 (fu_alu_bypass),
        .cdb                    (fu_cdb_out)
    );

endmodule
