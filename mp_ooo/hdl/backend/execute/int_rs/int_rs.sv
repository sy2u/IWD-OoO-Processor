module int_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    id_int_rs_itf.int_rs        from_id,
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
        always_comb begin 
            for (genvar i = 0; i < CDB_WIDTH; i++) begin 
                cdb_rs[i].valid  = cdb[i].valid;
                cdb_rs[i].rd_phy = cdb[i].rd_phy;
            end
        end
    endgenerate
    // rs array, store uop+available
    uop_t int_rs_array      [INTRS_DEPTH];
    logic int_rs_available  [INTRS_DEPTH];

    // pointer to top of the array (like a fifo queue)
    logic [INTRS_IDX-1:0] int_rs_top;

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
            int_rs_top <= '0;
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                int_rs_available[int_rs_push_idx]           <= 1'b1;
                int_rs_array    [int_rs_push_idx].pc        <= '0;
                int_rs_array    [int_rs_push_idx].fu_opcode <= '0;
                int_rs_array    [int_rs_push_idx].op1_sel   <= '0;
                int_rs_array    [int_rs_push_idx].op2_sel   <= '0;

                int_rs_array    [int_rs_push_idx].rd_phy    <= '0;
                int_rs_array    [int_rs_push_idx].rd_arch   <= '0;

                int_rs_array    [int_rs_push_idx].rs1_phy   <= '0;
                int_rs_array    [int_rs_push_idx].rs1_valid <= '0;
                int_rs_array    [int_rs_push_idx].rs2_phy   <= '0;
                int_rs_array    [int_rs_push_idx].rs2_valid <= '0;

                int_rs_array    [int_rs_push_idx].imm <= '0;
                int_rs_array    [int_rs_push_idx].rob_id     <= '0;
            end
        end else begin 
            // issue > snoop cdb > push
            // push renamed instruction
            if (int_rs_push_en) begin 
                // set rs to unavailable
                int_rs_available[int_rs_push_idx]           <= 1'b0;

                int_rs_array    [int_rs_push_idx].pc        <= from_id.uop.pc;
                int_rs_array    [int_rs_push_idx].fu_opcode <= from_id.uop.fu_opcode;
                int_rs_array    [int_rs_push_idx].op1_sel   <= from_id.uop.op1_sel;
                int_rs_array    [int_rs_push_idx].op2_sel   <= from_id.uop.op2_sel;

                int_rs_array    [int_rs_push_idx].rd_phy    <= from_id.uop.rd_phy;
                int_rs_array    [int_rs_push_idx].rd_arch   <= from_id.uop.rd_arch;

                int_rs_array    [int_rs_push_idx].rs1_phy   <= from_id.uop.rs1_phy;
                int_rs_array    [int_rs_push_idx].rs1_valid <= from_id.uop.rs1_valid;
                int_rs_array    [int_rs_push_idx].rs2_phy   <= from_id.uop.rs2_phy;
                int_rs_array    [int_rs_push_idx].rs2_valid <= from_id.uop.rs2_valid;

                int_rs_array    [int_rs_push_idx].imm <= from_id.uop.imm;
                int_rs_array    [int_rs_push_idx].rob_id     <= from_id.uop.rob_id;
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
                // update top pointer
                int_rs_top <= int_rs_issue_idx + 1'd1;
            end
        end
    end

    // push logic, push instruction to rs if id is valid and rs is ready
    // loop from top until the first available station
    always_comb begin
        int_rs_push_en  = '0;
        int_rs_push_idx = '0;
        if (from_id.valid && from_id.ready) begin 
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                if (int_rs_available[(INTRS_IDX)'(i+int_rs_top)]) begin 
                    int_rs_push_idx = (INTRS_IDX)'(i+int_rs_top);
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
            if (!int_rs_available[(INTRS_IDX)'(i+int_rs_top)]) begin 
                unique case (int_rs_array[(INTRS_IDX)'(i+int_rs_top)].op1_sel)
                    OP1_ZERO, OP1_PC: src1_valid = '1;
                    OP1_RS1: begin 
                        src1_valid = int_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs1_valid;
                        for (int k = 0; k < CDB_WIDTH; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs1_phy)) begin 
                                src1_valid = 1'b1;
                            end
                        end
                    end
                    default: src1_valid = '0;
                endcase

                unique case (int_rs_array[(INTRS_IDX)'(i+int_rs_top)].op2_sel)
                    OP2_ZERO, OP2_IMM: src1_valid = '1;
                    OP2_RS2: begin 
                        src2_valid = int_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs2_valid;
                        for (int k = 0; k < CDB_WIDTH; k++) begin 
                            if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == int_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs2_phy)) begin 
                                src2_valid = 1'b1;
                            end
                        end
                    end
                    default: src2_valid = '0;
                endcase

                if (src1_valid && src2_valid) begin 
                    int_rs_issue_en = '1;
                    int_rs_issue_idx = (INTRS_IDX)'(i+int_rs_top);
                    break;
                end
            end
        end
    end

    // full logic, set rs.ready to 0 if rs is full
    always_comb begin 
        from_id.ready = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (int_rs_available[i]) begin 
                from_id.ready = '1;
                break;
            end
        end
    end
    
    ////////////////
    // INT_RS Reg //
    ////////////////
    int_rs_reg_t    int_rs_reg;

    
    logic           int_rs_reg_ready;
    logic           int_rs_reg_valid;
    

    // communicate with prf
    assign to_prf.rs1_phy = int_rs_array[int_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = int_rs_array[int_rs_issue_idx].rs2_phy;

    // update int_rs_reg
    assign          int_rs_reg_ready = 1'b1;
    always_ff @(posedge clk) begin 
        if (rst) begin 
            int_rs_reg_valid        <= '0;

            int_rs_reg.rob_id       <= '0;
            int_rs_reg.rd_phy       <= '0;
            int_rs_reg.rd_arch      <= '0;
            int_rs_reg.op1_sel      <= '0;
            int_rs_reg.op2_sel      <= '0;
            int_rs_reg.fu_opcode    <= '0;
            int_rs_reg.imm   <= '0;
            int_rs_reg.pc           <= '0;
            int_rs_reg.rs1_value    <= '0;
            int_rs_reg.rs2_value    <= '0;

        end else begin
            int_rs_reg_valid        <= int_rs_issue_en && int_rs_reg_ready;
            if (int_rs_issue_en && int_rs_reg_ready) begin 
            int_rs_reg.rob_id       <= int_rs_array[int_rs_issue_idx].rob_id;
            int_rs_reg.rd_phy       <= int_rs_array[int_rs_issue_idx].rd_phy;
            int_rs_reg.rd_arch      <= int_rs_array[int_rs_issue_idx].rd_arch;
            int_rs_reg.op1_sel      <= int_rs_array[int_rs_issue_idx].op1_sel;
            int_rs_reg.op2_sel      <= int_rs_array[int_rs_issue_idx].op2_sel;
            int_rs_reg.fu_opcode    <= int_rs_array[int_rs_issue_idx].fu_opcode;
            int_rs_reg.imm   <= int_rs_array[int_rs_issue_idx].imm;
            int_rs_reg.pc           <= int_rs_array[int_rs_issue_idx].pc;

            int_rs_reg.rs1_value    <= to_prf.rs1_value;
            int_rs_reg.rs2_value    <= to_prf.rs2_value;
            end
        end
    end
    
    // Functional Units
    fu_alu fu_alu_i(
        .clk                    (clk),
        .rst                    (rst),
        .int_rs_reg             (int_rs_reg),
        .int_rs_reg_valid       (int_rs_reg_valid),
        .cdb                    (fu_cdb_out)
    );

endmodule
