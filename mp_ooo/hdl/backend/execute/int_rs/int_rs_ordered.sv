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
        logic   [0:0]           op1_sel;
        logic   [0:0]           op2_sel;
        logic   [31:0]          imm;
        logic   [3:0]           fu_opcode;
    } int_rs_entry_t;

    // rs array, store uop+available
    int_rs_entry_t          int_rs_array        [INTRS_DEPTH];
    logic                   int_rs_available    [INTRS_DEPTH];
    int_rs_entry_t          rs_array_next       [INTRS_DEPTH];
    logic                   rs_available_next   [INTRS_DEPTH];

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

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            int_rs_top <= '0;
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                int_rs_available[i] <= 1'b1;
            end
        end else begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin
                // compress and push rs array
                int_rs_array[i]  <= rs_array_next[i];
                int_rs_available[i] <= rs_available_next[i];
            end
            // pop and push pointer tracking
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

    always_comb begin : compress_mux // single issue type, one-slot compress
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            rs_array_next[i] = 'x;
            rs_available_next[i] = 1'b1;
            unique case (rs_update_sel[i])
                PREV: begin       
                    if( i < INTRS_DEPTH-1 ) begin
                        rs_array_next[i] = int_rs_array[i+1];
                        rs_available_next[i] = int_rs_available[i+1];
                    end
                end
                SELF: begin
                    rs_array_next[i] = int_rs_array[i];
                    rs_available_next[i] = int_rs_available[i];
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
                    rs_array_next[i].op1_sel = from_ds.uop[rs_push_sel[i]].op1_sel;
                    rs_array_next[i].op2_sel = from_ds.uop[rs_push_sel[i]].op2_sel;
                    rs_array_next[i].imm = from_ds.uop[rs_push_sel[i]].imm;
                    rs_array_next[i].fu_opcode = from_ds.uop[rs_push_sel[i]].fu_opcode;
                end
                default: ;
            endcase
            // snoop CDB to update rs1/rs2 valid
            for (int k = 0; k < CDB_WIDTH; k++) begin 
                if (cdb_rs[k].valid && !int_rs_available[i]) begin 
                    if (int_rs_array[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                        if ( rs_update_sel[i] == SELF ) begin
                            rs_array_next[i].rs1_valid = 1'b1;
                        end else if ( i > 0 ) begin
                            if ( rs_update_sel[i-1] == PREV ) rs_array_next[i-1].rs1_valid = 1'b1;
                        end
                    end
                    if (int_rs_array[i].rs2_phy == cdb_rs[k].rd_phy) begin 
                        if ( rs_update_sel[i] == SELF ) begin
                            rs_array_next[i].rs2_valid = 1'b1;
                        end else if ( i > 0 ) begin
                            if ( rs_update_sel[i-1] == PREV ) rs_array_next[i-1].rs2_valid = 1'b1;
                        end
                    end
                end
            end
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

    // issue enable logic, already oldest first
    // loop from top until src all valid
    logic   src1_valid, src2_valid;
    always_comb begin
        int_rs_issue_en  = '0;
        int_rs_issue_idx = '0; 
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (!int_rs_available[(INTRS_IDX)'(unsigned'(i))]) begin 
                unique case (int_rs_array[(INTRS_IDX)'(unsigned'(i))].op1_sel)
                    OP1_ZERO: src1_valid = '1;
                    OP1_RS1: begin 
                        src1_valid = int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_valid;
                        for (int k = 0; k < 1; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                                src1_valid = 1'b1;
                            end
                        end
                        if (fu_alu_bypass.valid && (fu_alu_bypass.rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                            src1_valid = 1'b1;
                        end
                    end
                    default: src1_valid = '0;
                endcase

                unique case (int_rs_array[(INTRS_IDX)'(unsigned'(i))].op2_sel)
                    OP2_IMM: src2_valid = '1;
                    OP2_RS2: begin 
                        src2_valid = int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs2_valid;
                        for (int k = 0; k < 1; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs2_phy)) begin 
                                src2_valid = 1'b1;
                            end
                        end
                        if (fu_alu_bypass.valid && (fu_alu_bypass.rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs2_phy)) begin 
                            src2_valid = 1'b1;
                        end
                    end
                    default: src2_valid = '0;
                endcase

                if (src1_valid && src2_valid) begin 
                    int_rs_issue_en = '1;
                    int_rs_issue_idx = (INTRS_IDX)'(unsigned'(i));
                    break;
                end
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    logic   [INTRS_IDX:0]    n_available_slots;
    always_comb begin 
        n_available_slots = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (int_rs_available[i]) begin 
                n_available_slots = (INTRS_IDX+1)'(n_available_slots + 1);
            end
        end
    end
    assign from_ds.ready = (n_available_slots >= (INTRS_IDX+1)'(ID_WIDTH));

    // communicate with prf
    assign to_prf.rs1_phy = int_rs_array[int_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = int_rs_array[int_rs_issue_idx].rs2_phy;

    //////////////////////
    // INT_RS to FU_ALU //
    //////////////////////
    fu_alu_reg_t    fu_alu_reg_in;

    // handshake with fu_alu_reg:
    assign int_rs_valid = int_rs_issue_en;

    // send data to fu_alu_reg
    always_comb begin 
        fu_alu_reg_in.rob_id       = int_rs_array[int_rs_issue_idx].rob_id;
        fu_alu_reg_in.rd_phy       = int_rs_array[int_rs_issue_idx].rd_phy;
        fu_alu_reg_in.rd_arch      = int_rs_array[int_rs_issue_idx].rd_arch;
        fu_alu_reg_in.op1_sel      = int_rs_array[int_rs_issue_idx].op1_sel;
        fu_alu_reg_in.op2_sel      = int_rs_array[int_rs_issue_idx].op2_sel;
        fu_alu_reg_in.fu_opcode    = int_rs_array[int_rs_issue_idx].fu_opcode;
        fu_alu_reg_in.imm          = int_rs_array[int_rs_issue_idx].imm;
        fu_alu_reg_in.pc           = 'x;

        fu_alu_reg_in.rs1_value    = (fu_alu_bypass.valid && (fu_alu_bypass.rd_phy == int_rs_array[int_rs_issue_idx].rs1_phy)) ?
                                    fu_alu_bypass.rd_value : to_prf.rs1_value;
        fu_alu_reg_in.rs2_value    = (fu_alu_bypass.valid && (fu_alu_bypass.rd_phy == int_rs_array[int_rs_issue_idx].rs2_phy)) ? 
                                    fu_alu_bypass.rd_value : to_prf.rs2_value;
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
