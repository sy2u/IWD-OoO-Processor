module intm_rs
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

    // local copy of cdb
    cdb_rs_t cdb_rs[CDB_WIDTH];
    generate 
        for (genvar i = 0; i < CDB_WIDTH; i++) begin 
            assign cdb_rs[i].valid  = cdb[i].valid;
            assign cdb_rs[i].rd_phy = cdb[i].rd_phy;
        end
    endgenerate

    // rs array, store uop+available
    uop_t intm_rs_array     [INTMRS_DEPTH];
    logic intm_rs_available [INTMRS_DEPTH];

    // push logic
    logic                 intm_rs_push_en   [ID_WIDTH];
    logic [INTMRS_IDX-1:0] intm_rs_push_idx  [ID_WIDTH];

    // issue logic
    logic                   intm_rs_issue_en;
    logic [INTMRS_IDX-1:0]  intm_rs_issue_idx;
    logic                   src1_valid;
    logic                   src2_valid;
    logic                   fu_md_ready, fu_md_valid;

    intm_rs_reg_t   intm_rs_in;
    logic           intm_rs_in_valid;

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            for (int i = 0; i < INTMRS_DEPTH; i++) begin 
                intm_rs_available[i]         <= 1'b1;
            end
        end else begin 
            // issue > snoop cdb > push
            // push renamed instruction
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (intm_rs_push_en[i]) begin 
                    // set rs to unavailable
                    intm_rs_available[intm_rs_push_idx[i]]   <= 1'b0;
                    intm_rs_array[intm_rs_push_idx[i]]       <= from_ds.uop[i];
                end
            end

            // snoop CDB to update rs1/rs2 valid
            for (int i = 0; i < INTMRS_DEPTH; i++) begin
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    // if the rs is unavailable (not empty), and rs1/rs2==cdb.rd,
                    // set rs1/rs2 to valid
                    if (cdb_rs[k].valid && !intm_rs_available[i]) begin 
                        if (intm_rs_array[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                            intm_rs_array[i].rs1_valid <= 1'b1;
                        end
                        if (intm_rs_array[i].rs2_phy == cdb_rs[k].rd_phy) begin 
                            intm_rs_array[i].rs2_valid <= 1'b1;
                        end
                    end
                end 
            end

            // pop issued instruction
            if (intm_rs_in_valid && fu_md_ready) begin 
                // set rs to available
                intm_rs_available[intm_rs_issue_idx] <= 1'b1;
            end
        end
    end

    // push logic, push instruction to rs if id is valid and rs is ready
    // loop from top until the first available station
    logic [INTMRS_DEPTH-1:0] assigned_this_cycle;
    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            intm_rs_push_en[i]  = 1'b0;
            intm_rs_push_idx[i] = '0;
        end
        assigned_this_cycle = '0;
        for (int p = 0; p < ID_WIDTH; p++) begin
            if (from_ds.valid[p] && from_ds.ready) begin
                // Look for first available RS entry not already assigned this cycle
                for (int i = 0; i < INTMRS_DEPTH; i++) begin
                    if (intm_rs_available[(INTMRS_IDX)'(unsigned'(i))] && ~assigned_this_cycle[i]) begin
                        intm_rs_push_idx[p] = (INTMRS_IDX)'(unsigned'(i));
                        intm_rs_push_en[p] = 1'b1;
                        assigned_this_cycle[i] = 1'b1;  // Mark this entry as assigned
                        break;
                    end
                end
            end
        end
    end

    // issue enable logic
    // loop from top until src all valid
    always_comb begin
        intm_rs_issue_en = '0;
        intm_rs_issue_idx = '0; 
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; i < INTMRS_DEPTH; i++) begin 
            if (!intm_rs_available[(INTMRS_IDX)'(unsigned'(i))]) begin 
                src1_valid = intm_rs_array[(INTMRS_IDX)'(unsigned'(i))].rs1_valid;
                src2_valid = intm_rs_array[(INTMRS_IDX)'(unsigned'(i))].rs2_valid;
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == intm_rs_array[(INTMRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                        src1_valid = 1'b1;
                    end
                    if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == intm_rs_array[(INTMRS_IDX)'(unsigned'(i))].rs2_phy)) begin 
                        src2_valid = 1'b1;
                    end
                end
                if (src1_valid && src2_valid) begin
                    intm_rs_issue_en = '1;
                    intm_rs_issue_idx = (INTMRS_IDX)'(unsigned'(i));
                end
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    logic   [INTMRS_IDX:0]    n_available_slots;
    always_comb begin 
        n_available_slots = '0;
        for (int i = 0; i < INTMRS_DEPTH; i++) begin 
            if (intm_rs_available[i]) begin 
                n_available_slots = (INTMRS_IDX+1)'(n_available_slots + 1);
            end
        end
    end
    assign from_ds.ready = (n_available_slots >= (INTMRS_IDX+1)'(ID_WIDTH));

    //---------------------------------------------------------------------------------
    // INTM_RS Reg:
    //---------------------------------------------------------------------------------

    // communicate with prf
    assign to_prf.rs1_phy = intm_rs_array[intm_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = intm_rs_array[intm_rs_issue_idx].rs2_phy;

    // update intm_rs_in
    always_comb begin
        intm_rs_in  = '0;
        intm_rs_in_valid = intm_rs_issue_en;
        if (intm_rs_issue_en) begin  
            intm_rs_in.rob_id      = intm_rs_array[intm_rs_issue_idx].rob_id;
            intm_rs_in.rd_phy      = intm_rs_array[intm_rs_issue_idx].rd_phy;
            intm_rs_in.rd_arch     = intm_rs_array[intm_rs_issue_idx].rd_arch;
            intm_rs_in.fu_opcode   = intm_rs_array[intm_rs_issue_idx].fu_opcode;
            intm_rs_in.rs1_value   = to_prf.rs1_value;
            intm_rs_in.rs2_value   = to_prf.rs2_value;
        end
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
