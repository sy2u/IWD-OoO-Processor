module br_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_int_rs_itf.int_rs        from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out
    br_cdb_itf.fu               br_cdb_out
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
    // rs array, store uop+available
    uop_t int_rs_array      [INTRS_DEPTH];
    logic int_rs_available  [INTRS_DEPTH];


    // push logic
    logic                 int_rs_push_en;
    logic [INTRS_IDX-1:0] int_rs_push_idx;

    // issue logic
    logic                 int_rs_issue_en;
    logic [INTRS_IDX-1:0] int_rs_issue_idx;
    logic                 src1_valid;
    logic                 src2_valid;

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                int_rs_available[i] <= 1'b1;
            end
        end else begin 
            // issue > snoop cdb > push
            // push renamed instruction
            if (int_rs_push_en) begin 
                // set rs to unavailable
                int_rs_available[int_rs_push_idx]   <= 1'b0;
                int_rs_array[int_rs_push_idx]       <= from_ds.uop;
            end

            // snoop CDB to update rs1/rs2 valid
            for (int i = 0; i < INTRS_DEPTH; i++) begin
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    // if the rs is unavailable (not empty), and rs1/rs2==cdb.rd,
                    // set rs1/rs2 to valid
                    if (cdb_rs[k].valid && !int_rs_available[i]) begin 
                        if (int_rs_array[i].rs1_phy == cdb_rs[k].rd_phy) begin 
                            int_rs_array[i].rs1_valid <= 1'b1;
                        end
                        if (int_rs_array[i].rs2_phy == cdb_rs[k].rd_phy) begin 
                            int_rs_array[i].rs2_valid <= 1'b1;
                        end
                    end
                end 
            end

            // pop issued instruction
            if (int_rs_issue_en) begin 
                // set rs to available
                int_rs_available[int_rs_issue_idx] <= 1'b1;
            end
        end
    end

    // push logic, push instruction to rs if id is valid and rs is ready
    // loop from top until the first available station
    always_comb begin
        int_rs_push_en  = '0;
        int_rs_push_idx = '0;
        if (from_ds.valid && from_ds.ready) begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                if (int_rs_available[(INTRS_IDX)'(unsigned'(i))]) begin 
                    int_rs_push_idx = (INTRS_IDX)'(unsigned'(i));
                    int_rs_push_en = 1'b1;
                    break;
                end
            end
        end
    end

    // issue enable logic
    // loop from top until src all valid
    always_comb begin
        int_rs_issue_en  = '0;
        int_rs_issue_idx = '0; 
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (!int_rs_available[(INTRS_IDX)'(unsigned'(i))]) begin 
                unique case (int_rs_array[(INTRS_IDX)'(unsigned'(i))].op1_sel)
                    OP1_ZERO, OP1_PC: src1_valid = '1;
                    OP1_RS1: begin 
                        src1_valid = int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_valid;
                        for (int k = 0; k < CDB_WIDTH; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs1_phy)) begin 
                                src1_valid = 1'b1;
                            end
                        end
                    end
                    default: src1_valid = '0;
                endcase

                unique case (int_rs_array[(INTRS_IDX)'(unsigned'(i))].op2_sel)
                    OP2_ZERO, OP2_IMM: src2_valid = '1;
                    OP2_RS2: begin 
                        src2_valid = int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs2_valid;
                        for (int k = 0; k < CDB_WIDTH; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(unsigned'(i))].rs2_phy)) begin 
                                src2_valid = 1'b1;
                            end
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
    always_comb begin 
        from_ds.ready = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (int_rs_available[i]) begin 
                from_ds.ready = '1;
                break;
            end
        end
    end
    

    // communicate with prf
    assign to_prf.rs1_phy = int_rs_array[int_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = int_rs_array[int_rs_issue_idx].rs2_phy;

    //////////////////////
    // BR_RS to FU_ALU //
    //////////////////////
    logic           br_rs_valid;
    logic           fu_br_ready;
    fu_br_reg_t     fu_br_reg_in;

    // handshake with fu_alu_reg:
    assign br_rs_valid = int_rs_issue_en;

    // send data to fu_alu_reg
    always_comb begin 
        fu_br_reg_in.rob_id         = int_rs_array[int_rs_issue_idx].rob_id;
        fu_br_reg_in.rd_phy         = int_rs_array[int_rs_issue_idx].rd_phy;
        fu_br_reg_in.rd_arch        = int_rs_array[int_rs_issue_idx].rd_arch;
        fu_br_reg_in.fu_opcode      = int_rs_array[int_rs_issue_idx].fu_opcode;
        fu_br_reg_in.imm            = int_rs_array[int_rs_issue_idx].imm;
        fu_br_reg_in.pc             = int_rs_array[int_rs_issue_idx].pc;
        fu_br_reg_in.predict_taken  = int_rs_array[int_rs_issue_idx].predict_taken;
        fu_br_reg_in.predict_target = int_rs_array[int_rs_issue_idx].predict_target;

        fu_br_reg_in.rs1_value      = to_prf.rs1_value;
        fu_br_reg_in.rs2_value      = to_prf.rs2_value;
    end

    
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

endmodule
