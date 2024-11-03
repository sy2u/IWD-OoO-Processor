module intm_rs
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
    uop_t intm_rs_array     [INTRS_DEPTH];
    logic int_rs_available  [INTRS_DEPTH];

    // pointer to top of the array (like a fifo queue)
    logic [INTRS_IDX-1:0] int_rs_top;

    // push logic
    logic                 int_rs_push_en;
    logic [INTRS_IDX-1:0] int_rs_push_idx;

    // issue logic
    logic                 intm_rs_issue_en;
    logic [INTRS_IDX-1:0] intm_rs_issue_idx;
    logic                 src1_valid;
    logic                 src2_valid;
    logic                 fu_md_ready, fu_md_valid;

    // rs array update
    always_ff @(posedge clk) begin 
        // rs array reset to all available, and top point to 0
        if (rst) begin 
            int_rs_top <= '0;
            for (int i = 0; i < INTRS_DEPTH; i++) begin 
                int_rs_available[i]           <= 1'b1;
                intm_rs_array    [i].fu_opcode <= '0;

                intm_rs_array    [i].rd_phy    <= '0;
                intm_rs_array    [i].rd_arch   <= '0;

                intm_rs_array    [i].rs1_phy   <= '0;
                intm_rs_array    [i].rs1_valid <= '0;
                intm_rs_array    [i].rs2_phy   <= '0;
                intm_rs_array    [i].rs2_valid <= '0;

                intm_rs_array    [i].rob_id    <= '0;
            end
        end else begin 
            // issue > snoop cdb > push
            // push renamed instruction
            if (int_rs_push_en) begin 
                // set rs to unavailable
                int_rs_available[int_rs_push_idx]           <= 1'b0;

                intm_rs_array    [int_rs_push_idx].fu_opcode <= from_id.uop.fu_opcode;

                intm_rs_array    [int_rs_push_idx].rd_phy    <= from_id.uop.rd_phy;
                intm_rs_array    [int_rs_push_idx].rd_arch   <= from_id.uop.rd_arch;

                intm_rs_array    [int_rs_push_idx].rs1_phy   <= from_id.uop.rs1_phy;
                intm_rs_array    [int_rs_push_idx].rs1_valid <= from_id.uop.rs1_valid;
                intm_rs_array    [int_rs_push_idx].rs2_phy   <= from_id.uop.rs2_phy;
                intm_rs_array    [int_rs_push_idx].rs2_valid <= from_id.uop.rs2_valid;

                intm_rs_array    [int_rs_push_idx].rob_id     <= from_id.uop.rob_id;
            end

            // snoop CDB to update rs1/rs2 valid
            for (int i = 0; i < INTRS_DEPTH; i++) begin
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    // if the rs is unavailable (not empty), and rs1/rs2==cdb.rd,
                    // set rs1/rs2 to valid
                    if (cdb_rs[k].valid && !int_rs_available[i]) begin 
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
            if (fu_md_valid) begin 
                // set rs to available
                int_rs_available[intm_rs_issue_idx] <= 1'b1;
                // update top pointer
                int_rs_top <= intm_rs_issue_idx + 1'd1;
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
        intm_rs_issue_en = '0;
        intm_rs_issue_idx = '0; 
        src1_valid       = '0;
        src2_valid       = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            if (!int_rs_available[(INTRS_IDX)'(i+int_rs_top)]) begin 
                src1_valid = intm_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs1_valid;
                src2_valid = intm_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs2_valid;
                for (int k = 0; k < CDB_WIDTH; k++) begin 
                    if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == intm_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs1_phy)) begin 
                        src1_valid = 1'b1;
                    end
                    if (cdb_rs[k].valid && (cdb_rs[k].rd_phy == intm_rs_array[(INTRS_IDX)'(i+int_rs_top)].rs2_phy)) begin 
                        src2_valid = 1'b1;
                    end
                end
                if (src1_valid && src2_valid) begin 
                    intm_rs_issue_en = '1;
                    intm_rs_issue_idx = (INTRS_IDX)'(i+int_rs_top);
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
    
    //---------------------------------------------------------------------------------
    // INTM_RS Reg:
    //---------------------------------------------------------------------------------

    // communicate with prf
    assign to_prf.rs1_phy = intm_rs_array[intm_rs_issue_idx].rs1_phy;
    assign to_prf.rs2_phy = intm_rs_array[intm_rs_issue_idx].rs2_phy;

    intm_rs_reg_t   intm_rs_reg;
    logic           intm_rs_reg_valid;

    // update intm_rs_reg
    always_ff @(posedge clk) begin 
        if (rst) begin 
            intm_rs_reg_valid        <= '0;

            intm_rs_reg.rob_id       <= '0;
            intm_rs_reg.rd_phy       <= '0;
            intm_rs_reg.rd_arch      <= '0;
            intm_rs_reg.fu_opcode    <= '0;
            intm_rs_reg.rs1_value    <= '0;
            intm_rs_reg.rs2_value    <= '0;
        end else begin
            intm_rs_reg_valid           <= intm_rs_issue_en && fu_md_ready;
            if (intm_rs_issue_en && fu_md_ready) begin 
                intm_rs_reg.rob_id      <= intm_rs_array[intm_rs_issue_idx].rob_id;
                intm_rs_reg.rd_phy      <= intm_rs_array[intm_rs_issue_idx].rd_phy;
                intm_rs_reg.rd_arch     <= intm_rs_array[intm_rs_issue_idx].rd_arch;
                intm_rs_reg.fu_opcode   <= intm_rs_array[intm_rs_issue_idx].fu_opcode;
                intm_rs_reg.rs1_value   <= to_prf.rs1_value;
                intm_rs_reg.rs2_value   <= to_prf.rs2_value;
            end
        end
    end
    
    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------
    fu_mul fu_mul_i(
        .clk(clk),
        .rst(rst),
        .flush('0),
        .prv_valid(intm_rs_reg_valid),
        .prv_ready(fu_md_ready),
        .nxt_valid(fu_md_valid),
        .nxt_ready('1), // RS is basically ff, always ready
        .intm_rs_reg(intm_rs_reg),
        .cdb(fu_cdb_out)
    );

endmodule
