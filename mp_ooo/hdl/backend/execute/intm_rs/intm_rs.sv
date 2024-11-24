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

    typedef struct packed {
        logic   [ROB_IDX-1:0]   rob_id;
        logic   [PRF_IDX-1:0]   rs1_phy;
        logic                   rs1_valid;
        logic   [PRF_IDX-1:0]   rs2_phy;
        logic                   rs2_valid;
        logic   [PRF_IDX-1:0]   rd_phy;
        logic   [ARF_IDX-1:0]   rd_arch;
        logic   [3:0]           fu_opcode;
    } intm_rs_entry_t;


    // rs array, store uop+available
    intm_rs_entry_t         intm_rs_array       [INTMRS_DEPTH];
    intm_rs_entry_t         rs_array_next       [INTMRS_DEPTH];
    logic                   intm_rs_available   [INTMRS_DEPTH];
    logic                   rs_available_next   [INTMRS_DEPTH];

    // pointer to top of the array (like a fifo queue)
    logic [INTMRS_IDX-1:0]  intm_rs_top, rs_top_next;

    // push & pop logic
    logic                   intm_rs_pop_en;
    logic                   intm_rs_push_en   [ID_WIDTH];
    logic [INTMRS_IDX-1:0]  intm_rs_push_idx  [ID_WIDTH];

    // issue logic
    logic                   intm_rs_issue_en;
    logic [INTMRS_IDX-1:0]  intm_rs_issue_idx;
    logic                   fu_md_ready, fu_md_valid;

    intm_rs_reg_t           intm_rs_in;
    logic                   intm_rs_in_valid;

    // update logic
    rs_update_sel_t         rs_update_sel   [INTMRS_DEPTH];
    logic [ID_WIDTH_IDX-1:0]rs_push_sel     [INTMRS_DEPTH];

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            intm_rs_top <= '0;
            for (int i = 0; i < INTMRS_DEPTH; i++) begin 
                intm_rs_available[i] <= 1'b1;
            end
        end else begin 
            // snoop CDB to update rs1/rs2 valid
            for (int i = 0; i < INTMRS_DEPTH; i++) begin
                intm_rs_array[i]  <= rs_array_next[i];
                intm_rs_available[i] <= rs_available_next[i];
            end
            intm_rs_top <= rs_top_next;
        end
    end

    // mux select logic
    always_comb begin : compress_control
        for (int i = 0; i < INTMRS_DEPTH; i++) begin
            rs_push_sel[i] = '0;
            rs_update_sel[i] = SELF;
            if( intm_rs_pop_en ) begin
                if( (INTMRS_IDX)'(unsigned'(i))>=intm_rs_issue_idx ) rs_update_sel[i] = PREV;
            end
            for( int j = 0; j < ID_WIDTH; j++ ) begin 
                if ( intm_rs_push_en[j] && ((INTMRS_IDX)'(unsigned'(i)) == intm_rs_push_idx[j]) ) begin
                    rs_update_sel[i] = PUSH_IN;
                    rs_push_sel[i] = ID_WIDTH_IDX'(unsigned'(j));
                end
            end
        end
    end

    always_comb begin : compress_mux // single issue type, one-slot compress
        for (int i = 0; i < INTMRS_DEPTH; i++) begin
            rs_array_next[i] = 'x;
            rs_available_next[i] = 1'b1;
            unique case (rs_update_sel[i])
                PREV: begin       
                    if( i < INTMRS_DEPTH-1 ) begin
                        rs_array_next[i] = intm_rs_array[i+1];
                        rs_available_next[i] = intm_rs_available[i+1];
                    end
                end
                SELF: begin
                    rs_array_next[i] = intm_rs_array[i];
                    rs_available_next[i] = intm_rs_available[i];
                end
                PUSH_IN: begin
                    rs_available_next[i] = 1'b0;
                    rs_array_next[i].rob_id  = from_ds.uop[rs_push_sel[i]].rob_id;
                    rs_array_next[i].rs1_phy = from_ds.uop[rs_push_sel[i]].rs1_phy;
                    rs_array_next[i].rs1_valid = from_ds.uop[rs_push_sel[i]].rs1_valid;
                    rs_array_next[i].rs2_phy = from_ds.uop[rs_push_sel[i]].rs2_phy;
                    rs_array_next[i].rs2_valid = from_ds.uop[rs_push_sel[i]].rs2_valid;
                    rs_array_next[i].rd_phy = from_ds.uop[rs_push_sel[i]].rd_phy;
                    rs_array_next[i].rd_arch = from_ds.uop[rs_push_sel[i]].rd_arch;
                    rs_array_next[i].fu_opcode = from_ds.uop[rs_push_sel[i]].fu_opcode;
                end
                default: ;
            endcase
            // snoop CDB to update rs1/rs2 valid
            for (int k = 0; k < CDB_WIDTH; k++) begin 
                if (cdb_rs[k].valid && !intm_rs_available[i]) begin 
                    if (intm_rs_array[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                        if ( rs_update_sel[i] == SELF ) begin
                            rs_array_next[i].rs1_valid = 1'b1;
                        end else if ( i > 0 ) begin
                            if (rs_update_sel[i-1] == PREV) rs_array_next[i-1].rs1_valid = 1'b1;
                        end
                    end
                    if (intm_rs_array[i].rs2_phy == cdb_rs[k].rd_phy) begin 
                        if ( rs_update_sel[i] == SELF ) begin
                            rs_array_next[i].rs2_valid = 1'b1;
                        end else if ( i > 0 ) begin
                            if (rs_update_sel[i-1] == PREV) rs_array_next[i-1].rs2_valid = 1'b1;
                        end
                    end
                end
            end
        end
    end

    // issue enable logic: oldest first
    // loop from top until src all valid
    logic   src1_valid, src2_valid;
    always_comb begin
        intm_rs_issue_en = '0;
        intm_rs_issue_idx = '0; 
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; INTMRS_IDX'(unsigned'(i)) < intm_rs_top; i++) begin 
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
                break;
            end
        end
    end

    // push and pop logic
    always_comb begin
        rs_top_next = intm_rs_top;
        // pop
        intm_rs_pop_en = '0;
        if( intm_rs_in_valid && fu_md_ready ) begin 
            intm_rs_pop_en = '1;
            rs_top_next = INTMRS_IDX'(rs_top_next - 1); 
        end
        // push
        for( int i = 0; i < ID_WIDTH; i++ ) begin
            intm_rs_push_en[i] = '0;
            intm_rs_push_idx[i] = 'x;
            if( from_ds.valid[i] && from_ds.ready ) begin 
                intm_rs_push_en[i] = '1;
                intm_rs_push_idx[i] = rs_top_next;
                rs_top_next = INTMRS_IDX'(rs_top_next + 1);
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    logic   [INTMRS_IDX:0]    n_available_slots;
    always_comb begin 
        n_available_slots = '0;
        for (int i = 0; i < INTMRS_DEPTH; i++) begin 
            if (intm_rs_available[i]) begin 
                n_available_slots = (INTRS_IDX+1)'(n_available_slots + 1);
            end
        end
    end
    assign from_ds.ready = (n_available_slots >= (INTRS_IDX+1)'(ID_WIDTH));

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
