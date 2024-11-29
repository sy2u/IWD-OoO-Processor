module prf
import cpu_params::*;
import prf_types::*;
(
    input   logic               clk,

    rs_prf_itf.prf              from_rs[CDB_WIDTH],
    cdb_itf.prf                 cdb[CDB_WIDTH]
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

    always_comb begin
        for (int j = 0; j < CDB_WIDTH; j++) begin
            if (from_rs_local_in[j].rs1_phy == '0) begin 
                from_rs_local_out[j].rs1_value = '0;
            end else begin
                from_rs_local_out[j].rs1_value = prf_data[from_rs_local_in[j].rs1_phy];
                for (int i = 0; i < CDB_WIDTH; i++) begin
                    if (PRF_FORWARDING[j][i]) begin
                        if (cdb_local[i].valid && (cdb_local[i].rd_phy == from_rs_local_in[j].rs1_phy)) begin 
                            from_rs_local_out[j].rs1_value = cdb_local[i].rd_value;
                        end
                    end
                end
            end
        end
    end

    always_comb begin
        for (int j = 0; j < CDB_WIDTH; j++) begin
            if (from_rs_local_in[j].rs2_phy == '0) begin 
                from_rs_local_out[j].rs2_value = '0;
            end else begin
                from_rs_local_out[j].rs2_value = prf_data[from_rs_local_in[j].rs2_phy];
                for (int i = 0; i < CDB_WIDTH; i++) begin
                    if (PRF_FORWARDING[j][i]) begin
                        if (cdb_local[i].valid && (cdb_local[i].rd_phy == from_rs_local_in[j].rs2_phy)) begin 
                            from_rs_local_out[j].rs2_value = cdb_local[i].rd_value;
                        end
                    end
                end
            end
        end
    end


endmodule
