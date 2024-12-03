module prf
import cpu_params::*;
import prf_types::*;
import int_rs_types::*;
(
    input   logic               clk,

    rs_prf_itf.prf              from_rs[CDB_WIDTH],
    cdb_itf.prf                 cdb[CDB_WIDTH],
    input bypass_network_t      alu_bypass
);
    // physical register file
    logic [31:0]    prf_data            [PRF_DEPTH-1:1];

    // local copy of cdb interface and rs_prf_interface
    cdb_prf_t       cdb_local           [CDB_WIDTH];
    rs_prf_itf_t    from_rs_local_in    [CDB_WIDTH];
    rs_prf_itf_t    from_rs_local_out   [CDB_WIDTH];

    generate 
        for (genvar i = 0; i < CDB_WIDTH; i++) begin 
            assign cdb_local[i].valid       = cdb[i].valid;
            assign cdb_local[i].rd_phy      = cdb[i].rd_phy;
            assign cdb_local[i].rd_value    = cdb[i].rd_value;

            assign from_rs_local_in[i].rs1_phy = from_rs[i].rs1_phy;
            assign from_rs_local_in[i].rs2_phy = from_rs[i].rs2_phy;
            assign from_rs_local_in[i].rs1_value = 'x; // silence Spyglass
            assign from_rs_local_in[i].rs2_value = 'x; // silence Spyglass
            assign from_rs_local_in[i].rs1_bypass_en = from_rs[i].rs1_bypass_en;
            assign from_rs_local_in[i].rs2_bypass_en = from_rs[i].rs2_bypass_en;
            assign from_rs[i].rs1_value     = from_rs_local_out[i].rs1_value;
            assign from_rs[i].rs2_value     = from_rs_local_out[i].rs2_value;
        end
    endgenerate

    always_ff @(posedge clk) begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            if (cdb_local[i].valid && (cdb_local[i].rd_phy != '0)) begin 
                prf_data[cdb_local[i].rd_phy] <= cdb_local[i].rd_value;
            end
        end
    end

    // logic   [CDB_WIDTH-1:0] prf_bypass_rs1 [CDB_WIDTH];
    // logic   [CDB_WIDTH-1:0] prf_bypass_rs2 [CDB_WIDTH];

    // generate for (genvar i = 0; i < CDB_WIDTH; i++) begin
    //     for (genvar j = 0; j < CDB_WIDTH; j++) begin
    //         assign prf_bypass_rs1[i][j] = cdb_local[j].valid && (cdb_local[j].rd_phy != '0) && (cdb_local[j].rd_phy == from_rs_local_in[i].rs1_phy);
    //         assign prf_bypass_rs2[i][j] = cdb_local[j].valid && (cdb_local[j].rd_phy != '0) && (cdb_local[j].rd_phy == from_rs_local_in[i].rs2_phy);
    //     end
    // end endgenerate

    always_comb begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            // Unfortunatly, we cannot generate a case statement based on CDB_WIDTH
            unique case (from_rs_local_in[i].rs1_bypass_en)
                5'b00000: begin
                    from_rs_local_out[i].rs1_value = (from_rs_local_in[i].rs1_phy == '0) ? '0 : prf_data[from_rs_local_in[i].rs1_phy];
                end
                5'b00001: begin
                    from_rs_local_out[i].rs1_value = cdb_local[0].rd_value;
                end
                5'b00010: begin
                    from_rs_local_out[i].rs1_value = cdb_local[1].rd_value;
                end
                5'b00100: begin
                    from_rs_local_out[i].rs1_value = cdb_local[2].rd_value;
                end
                5'b01000: begin
                    from_rs_local_out[i].rs1_value = cdb_local[3].rd_value;
                end
                5'b10000: begin
                    from_rs_local_out[i].rs1_value = alu_bypass.rd_value;
                end
                default: begin
                    from_rs_local_out[i].rs1_value = 'x;
                end
            endcase
        end
    end

    always_comb begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            // Unfortunatly, we cannot generate a case statement based on CDB_WIDTH
            unique case (from_rs_local_in[i].rs2_bypass_en)
                5'b00000: begin
                    from_rs_local_out[i].rs2_value = (from_rs_local_in[i].rs2_phy == '0) ? '0 : prf_data[from_rs_local_in[i].rs2_phy];
                end
                5'b00001: begin
                    from_rs_local_out[i].rs2_value = cdb_local[0].rd_value;
                end
                5'b00010: begin
                    from_rs_local_out[i].rs2_value = cdb_local[1].rd_value;
                end
                5'b00100: begin
                    from_rs_local_out[i].rs2_value = cdb_local[2].rd_value;
                end
                5'b01000: begin
                    from_rs_local_out[i].rs2_value = cdb_local[3].rd_value;
                end
                5'b10000: begin
                    from_rs_local_out[i].rs2_value = alu_bypass.rd_value;
                end
                default: begin
                    from_rs_local_out[i].rs2_value = 'x;
                end
            endcase
        end
    end


endmodule
